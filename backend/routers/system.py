from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from fastapi.responses import FileResponse, StreamingResponse
from starlette.background import BackgroundTask
from sqlalchemy.orm import Session
import os
import sqlite3
import tempfile
import edge_tts
from pathlib import Path
import models
import schemas
from database import engine, get_db
from auth import get_current_user
from version import APP_VERSION
import ai_service
import logging

logger = logging.getLogger(__name__)

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
DATABASE_PATH = DATA_DIR / "fitness.db"
PRE_RESTORE_BACKUP_PATH = DATA_DIR / "fitness.pre-restore.db"
SQLITE_MAGIC = b"SQLite format 3\x00"
RESTORE_CHUNK_SIZE = 1024 * 1024
DEFAULT_MAX_RESTORE_BYTES = 512 * 1024 * 1024

REQUIRED_DATABASE_SCHEMA = {
    "users": {
        "id", "email", "first_name", "last_name", "age", "role",
        "hashed_password",
    },
    "measurements": {"id", "user_id", "created_at"},
    "workout_plans": {"id", "user_id", "plan_json", "version", "created_at"},
    "exercise_catalog": {"id", "nome", "gruppo_muscolare"},
    "system_settings": {"key", "value"},
    "workout_logs": {
        "id", "user_id", "title", "date", "duration_seconds",
        "exercises_json",
    },
}


def _remove_file(path: str | Path) -> None:
    try:
        Path(path).unlink(missing_ok=True)
    except OSError:
        logger.warning("Impossibile eliminare il file temporaneo di backup", exc_info=True)


def _validate_database(path: str | Path) -> None:
    """Verifica integrita, chiavi esterne e schema minimo senza modificare il DB."""
    database_path = Path(path).resolve()
    uri = f"{database_path.as_uri()}?mode=ro"
    with sqlite3.connect(uri, uri=True) as conn:
        integrity_rows = conn.execute("PRAGMA integrity_check").fetchall()
        if integrity_rows != [("ok",)]:
            raise sqlite3.DatabaseError("integrity_check non superato")

        if conn.execute("PRAGMA foreign_key_check").fetchone() is not None:
            raise sqlite3.DatabaseError("foreign_key_check non superato")

        tables = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
        if set(REQUIRED_DATABASE_SCHEMA) - tables:
            raise sqlite3.DatabaseError(
                "schema incompatibile: tabelle obbligatorie mancanti"
            )

        for table, required_columns in REQUIRED_DATABASE_SCHEMA.items():
            columns = {
                row[1] for row in conn.execute(f'PRAGMA table_info("{table}")')
            }
            if required_columns - columns:
                raise sqlite3.DatabaseError(
                    f"schema incompatibile: colonne obbligatorie mancanti in {table}"
                )


def _create_consistent_backup(source_path: Path, destination_path: Path) -> None:
    """Crea uno snapshot consistente tramite la SQLite Online Backup API."""
    source_uri = f"{source_path.resolve().as_uri()}?mode=ro"
    with sqlite3.connect(source_uri, uri=True) as source:
        with sqlite3.connect(destination_path) as destination:
            source.backup(destination)
    _validate_database(destination_path)


def _max_restore_bytes() -> int:
    raw = os.getenv("MAX_RESTORE_BYTES", str(DEFAULT_MAX_RESTORE_BYTES))
    try:
        return max(1, int(raw))
    except ValueError:
        logger.warning("MAX_RESTORE_BYTES non valido; uso il limite predefinito")
        return DEFAULT_MAX_RESTORE_BYTES

router = APIRouter(
    prefix="/api/system",
    tags=["Sistema"]
)

@router.get("/backup", summary="Scarica il database SQLite (Solo Admin)")
def download_database_backup(current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")

    if not DATABASE_PATH.is_file():
        raise HTTPException(status_code=404, detail="Database non trovato.")

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(
        dir=DATA_DIR, prefix="fitness-backup-", suffix=".db"
    )
    os.close(fd)
    try:
        _create_consistent_backup(DATABASE_PATH, Path(tmp_path))
    except (OSError, sqlite3.DatabaseError):
        _remove_file(tmp_path)
        logger.exception("Creazione backup SQLite fallita")
        raise HTTPException(status_code=500, detail="Creazione backup fallita.")

    return FileResponse(
        path=tmp_path,
        filename="fitness.db",
        media_type="application/octet-stream",
        background=BackgroundTask(_remove_file, tmp_path),
    )


@router.post("/restore", summary="Ripristina il database SQLite (Solo Admin)")
async def restore_database_backup(
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    max_restore_bytes = _max_restore_bytes()
    tmp_path: str | None = None
    recovery_tmp_path: str | None = None
    try:
        fd, tmp_path = tempfile.mkstemp(dir=DATA_DIR, suffix=".restore.tmp")
        uploaded_bytes = 0
        with os.fdopen(fd, "wb") as f:
            while chunk := await file.read(RESTORE_CHUNK_SIZE):
                uploaded_bytes += len(chunk)
                if uploaded_bytes > max_restore_bytes:
                    raise HTTPException(
                        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        detail="Backup troppo grande.",
                    )
                f.write(chunk)

        if uploaded_bytes < len(SQLITE_MAGIC):
            raise HTTPException(status_code=400, detail="File SQLite non valido.")
        with open(tmp_path, "rb") as uploaded_file:
            if uploaded_file.read(len(SQLITE_MAGIC)) != SQLITE_MAGIC:
                raise HTTPException(status_code=400, detail="File SQLite non valido.")

        _validate_database(tmp_path)

        # Mantiene una copia consistente del database sostituito per il rollback.
        if DATABASE_PATH.is_file():
            recovery_fd, recovery_tmp_path = tempfile.mkstemp(
                dir=DATA_DIR, suffix=".pre-restore.tmp"
            )
            os.close(recovery_fd)
            _create_consistent_backup(DATABASE_PATH, Path(recovery_tmp_path))
            os.replace(recovery_tmp_path, PRE_RESTORE_BACKUP_PATH)
            recovery_tmp_path = None

        # Swap atomico solo dopo validazione e creazione del punto di recupero.
        engine.dispose()
        os.replace(tmp_path, DATABASE_PATH)
        tmp_path = None
        ai_service.invalidate_ai_config_cache()

        logger.info("Database ripristinato con successo dall'amministratore autenticato")
        return {
            "message": (
                "Database ripristinato con successo. "
                "Il database precedente è disponibile come fitness.pre-restore.db."
            )
        }
    except HTTPException:
        raise
    except sqlite3.DatabaseError as e:
        logger.warning("Backup SQLite rifiutato: %s", e)
        raise HTTPException(
            status_code=400,
            detail="Database corrotto o non compatibile con ForgeFit.",
        )
    except Exception:
        logger.exception("Errore durante il ripristino del database")
        raise HTTPException(status_code=500, detail="Errore durante il ripristino.")
    finally:
        if tmp_path:
            _remove_file(tmp_path)
        if recovery_tmp_path:
            _remove_file(recovery_tmp_path)


@router.get("/models", response_model=list[schemas.AIModelResponse], summary="Ottieni modelli AI supportati (Whitelist)")
def get_supported_ai_models(current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")
    
    whitelist = [
        {"id": "gemini-1.5-flash", "name": "Gemini 1.5 Flash (Affidabile ed Economico - Default)"},
        {"id": "gemini-2.0-flash", "name": "Gemini 2.0 Flash (Veloce e Moderno)"},
        {"id": "gemini-1.5-pro", "name": "Gemini 1.5 Pro (Ragionamento Complesso)"},
        {"id": "deepseek-chat", "name": "DeepSeek V3"},
        {"id": "deepseek-reasoner", "name": "DeepSeek R1"},
    ]
    return whitelist


@router.get("/settings", summary="Ottieni impostazioni di sistema")
def get_system_settings(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")
    
    _, ai_model, _ = ai_service.get_ai_config(db)
    key_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "ai_api_key_override").first()
    deepseek_key_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "deepseek_api_key_override").first()
    
    return {
        "ai_model": ai_model,
        # I secret non devono mai essere restituiti al browser, neppure a un admin.
        "has_ai_api_key_override": bool(key_setting and key_setting.value),
        "has_deepseek_api_key_override": bool(deepseek_key_setting and deepseek_key_setting.value),
    }


@router.put("/settings", summary="Aggiorna impostazioni di sistema")
def update_system_settings(data: schemas.SystemSettingsUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")
        
    model_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "ai_model").first()
    if not model_setting:
        model_setting = models.SystemSettings(key="ai_model", value=data.ai_model)
        db.add(model_setting)
    else:
        model_setting.value = data.ai_model
        
    key_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "ai_api_key_override").first()
    if data.ai_api_key_override is not None:
        if data.ai_api_key_override:
            if not key_setting:
                key_setting = models.SystemSettings(key="ai_api_key_override", value=data.ai_api_key_override)
                db.add(key_setting)
            else:
                key_setting.value = data.ai_api_key_override
        elif key_setting:
            db.delete(key_setting)
            
    deepseek_key_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "deepseek_api_key_override").first()
    if data.deepseek_api_key_override is not None:
        if data.deepseek_api_key_override:
            if not deepseek_key_setting:
                deepseek_key_setting = models.SystemSettings(key="deepseek_api_key_override", value=data.deepseek_api_key_override)
                db.add(deepseek_key_setting)
            else:
                deepseek_key_setting.value = data.deepseek_api_key_override
        elif deepseek_key_setting:
            db.delete(deepseek_key_setting)

    db.commit()
    ai_service.invalidate_ai_config_cache()
    return {"message": "Impostazioni aggiornate con successo."}


@router.get("/tts", summary="Genera sintesi vocale neurale tramite Edge TTS")
async def get_edge_tts(text: str, current_user: models.User = Depends(get_current_user)):
    if not text.strip():
        raise HTTPException(status_code=400, detail="Il testo non può essere vuoto.")
    try:
        communicate = edge_tts.Communicate(text, "it-IT-GiuseppeNeural")
        async def audio_generator():
            async for chunk in communicate.stream():
                if chunk["type"] == "audio":
                    yield chunk["data"]
        return StreamingResponse(audio_generator(), media_type="audio/mpeg")
    except Exception as e:
        logger.error(f"Errore generazione Edge TTS: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Errore TTS: {str(e)}")


@router.get("/version", summary="Ottieni la versione corrente dell'applicazione")
def get_version():
    return {"version": APP_VERSION}
