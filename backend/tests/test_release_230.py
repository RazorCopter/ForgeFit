import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

os.environ.setdefault("JWT_SECRET_KEY", "forgefit-test-secret-never-use-in-production")

import auth as auth_utils
import models
import routers.system as system_router
from database import Base, get_db
from main import app


@pytest.fixture()
def db_session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    testing_session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    session = testing_session()

    def override_get_db():
        try:
            yield session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    try:
        yield session
    finally:
        app.dependency_overrides.clear()
        session.close()
        engine.dispose()


@pytest.fixture()
def client(db_session):
    return TestClient(app)


def register_client(client: TestClient, email: str = "atleta@example.com") -> dict:
    response = client.post(
        "/api/auth/register",
        json={
            "email": email,
            "password": "password-sicura-123",
            "nome": "Mario",
            "cognome": "Rossi",
            "eta": 30,
            "sesso": "Maschio",
            "peso": 80,
            "altezza": 180,
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_registration_returns_complete_session_and_initial_measurement(client, db_session):
    payload = register_client(client)

    assert payload["access_token"]
    assert payload["refresh_token"]
    assert payload["role"] == "client"
    assert payload["user_id"] == payload["user"]["id"]
    assert payload["user"]["email"] == "atleta@example.com"
    assert db_session.query(models.Measurement).count() == 1

    me = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {payload['access_token']}"},
    )
    assert me.status_code == 200
    assert me.json()["id"] == payload["user_id"]


def test_registration_rejects_short_password(client):
    response = client.post(
        "/api/auth/register",
        json={
            "email": "short@example.com",
            "password": "1234567",
            "nome": "Nome",
            "cognome": "Cognome",
            "eta": 30,
        },
    )
    assert response.status_code == 422


def test_workout_history_is_stably_paginated(client, db_session):
    registration = register_client(client, "pagination@example.com")
    user_id = registration["user_id"]
    start = datetime(2025, 1, 1, tzinfo=timezone.utc)
    for index in range(205):
        db_session.add(
            models.WorkoutLog(
                user_id=user_id,
                title=f"Workout {index}",
                date=start + timedelta(minutes=index),
                duration_seconds=60,
                exercises_json="[]",
            )
        )
    db_session.commit()

    headers = {"Authorization": f"Bearer {registration['access_token']}"}
    first = client.get(
        f"/api/workouts/history/{user_id}?skip=0&limit=100",
        headers=headers,
    )
    second = client.get(
        f"/api/workouts/history/{user_id}?skip=100&limit=100",
        headers=headers,
    )
    third = client.get(
        f"/api/workouts/history/{user_id}?skip=200&limit=100",
        headers=headers,
    )

    assert first.status_code == second.status_code == third.status_code == 200
    rows = first.json() + second.json() + third.json()
    assert len(rows) == 205
    assert len({row["id"] for row in rows}) == 205
    assert [row["title"] for row in rows[:3]] == ["Workout 0", "Workout 1", "Workout 2"]


def test_system_settings_never_return_secret_values(client, db_session):
    admin = models.User(
        email="admin@example.com",
        first_name="Admin",
        last_name="ForgeFit",
        age=30,
        role="admin",
        hashed_password=auth_utils.hash_password("password-sicura-123"),
    )
    db_session.add(admin)
    db_session.add(models.SystemSettings(key="ai_api_key_override", value="secret-google"))
    db_session.add(models.SystemSettings(key="deepseek_api_key_override", value="secret-deepseek"))
    db_session.commit()

    token = auth_utils.create_access_token(subject=admin.email)
    response = client.get(
        "/api/system/settings",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["has_ai_api_key_override"] is True
    assert body["has_deepseek_api_key_override"] is True
    assert "secret-google" not in response.text
    assert "secret-deepseek" not in response.text


def test_dashboard_uses_safe_dom_for_user_controlled_identity_fields():
    source = (Path(__file__).parents[1] / "static" / "index.html").read_text(encoding="utf-8")

    assert "tb.innerHTML = data.map(u =>" not in source
    assert "sel.innerHTML = '<option value=\"\">— Seleziona cliente" not in source
    assert "nameEl.textContent = fullName" in source
    assert "emailTd.textContent = email" in source
    assert "el.textContent = (ok ? '✅ ' : '❌ ')" in source


def test_logout_preserves_local_data_unless_reset_is_explicit():
    frontend_root = Path(__file__).parents[2] / "frontend" / "lib"
    auth_source = (frontend_root / "core" / "auth_service.dart").read_text(
        encoding="utf-8"
    )
    setup_source = (frontend_root / "screens" / "setup_screen.dart").read_text(
        encoding="utf-8"
    )

    assert "logout({bool clearLocalData = false})" in auth_source
    assert "if (clearLocalData)" in auth_source
    assert "AuthService.logout(clearLocalData: true)" in setup_source


def test_sqlite_online_backup_is_valid_and_accepts_extra_legacy_tables(tmp_path):
    source_path = tmp_path / "source.db"
    backup_path = tmp_path / "backup.db"
    source_engine = create_engine(f"sqlite:///{source_path}")
    Base.metadata.create_all(bind=source_engine)
    source_engine.dispose()

    # Il backup reale 2.2.4 contiene questa tabella vuota: le tabelle extra
    # devono essere preservate e non rendere lo snapshot incompatibile.
    import sqlite3
    with sqlite3.connect(source_path) as connection:
        connection.execute(
            "CREATE TABLE passkey_credentials (credential_id VARCHAR PRIMARY KEY)"
        )

    system_router._create_consistent_backup(source_path, backup_path)
    system_router._validate_database(backup_path)

    with sqlite3.connect(backup_path) as connection:
        tables = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
    assert "passkey_credentials" in tables


def test_restore_validation_rejects_an_unrelated_sqlite_database(tmp_path):
    import sqlite3
    unrelated_path = tmp_path / "unrelated.db"
    with sqlite3.connect(unrelated_path) as connection:
        connection.execute("CREATE TABLE unrelated (id INTEGER PRIMARY KEY)")

    with pytest.raises(sqlite3.DatabaseError, match="schema incompatibile"):
        system_router._validate_database(unrelated_path)
