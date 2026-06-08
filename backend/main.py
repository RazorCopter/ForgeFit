# main.py
# Entry point dell'applicazione FastAPI.
# Configura CORS, monta i file statici e definisce tutti gli endpoint REST.

import csv
import io
import json
import logging
import os
import shutil
import google.generativeai as genai
from typing import Optional
from dotenv import load_dotenv
import ai_service
import config_manager

load_dotenv() # Carica variabili da .env

from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, StreamingResponse
from sqlalchemy.orm import Session

# Import dei modelli per la registrazione dei metadati di SQLAlchemy
import models
import schemas
import auth
from auth import get_current_user
from database import engine, get_db

# ---------------------------------------------------------------------------
# Inizializzazione logger
# ---------------------------------------------------------------------------
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ===========================================================================
# Funzioni Helper per Configurazioni di Sistema
# ===========================================================================

# ---------------------------------------------------------------------------
# La creazione delle tabelle è stata spostata nell'evento 'startup' dell'app.


# ---------------------------------------------------------------------------
# DATABASE SEEDING - Catalogo esercizi massivo al primo avvio
# Viene eseguito solo se ExerciseCatalog è vuota (count == 0).
# ---------------------------------------------------------------------------
def seed_catalog() -> None:
    """
    Popola il catalogo esercizi con un set completo di esercizi suddivisi
    per gruppo muscolare. Viene eseguita una sola volta al primo avvio:
    se la tabella contiene già dati, la funzione esce immediatamente.
    """
    from database import SessionLocal  # import locale per evitare import circolari

    db = SessionLocal()
    try:
        if db.query(models.ExerciseCatalog).count() > 0:
            logger.info("Catalogo esercizi già popolato — seeding saltato.")
            return

        logger.info("Tabella ExerciseCatalog vuota — avvio seeding catalogo...")

        esercizi = [
            # ----------------------------------------------------------------
            # PETTO
            # ----------------------------------------------------------------
            models.ExerciseCatalog(
                nome="Panca Piana Bilanciere", gruppo_muscolare="Petto",
                default_serie=4, default_ripetizioni="8-10", default_recupero_secondi=120,
                default_note="Scapole depresse e addotte.",
            ),
            models.ExerciseCatalog(
                nome="Spinte Panca Inclinata Manubri", gruppo_muscolare="Petto",
                default_serie=4, default_ripetizioni="10-12", default_recupero_secondi=90,
                default_note="Massimo allungamento al petto.",
            ),
            models.ExerciseCatalog(
                nome="Croci ai Cavi dall'alto", gruppo_muscolare="Petto",
                default_serie=3, default_ripetizioni="12-15", default_recupero_secondi=60,
                default_note="Focus sulla contrazione di picco, strizzare in chiusura.",
            ),
            models.ExerciseCatalog(
                nome="Croci ai Cavi dal basso", gruppo_muscolare="Petto",
                default_serie=3, default_ripetizioni="12-15", default_recupero_secondi=60,
                default_note="Movimento dal basso verso l'alto, focus petto alto.",
            ),
            models.ExerciseCatalog(
                nome="Pectoral Machine", gruppo_muscolare="Petto",
                default_serie=3, default_ripetizioni="12", default_recupero_secondi=60,
                default_note="Gomiti alti, non incassare il collo.",
            ),
            models.ExerciseCatalog(
                nome="Chest Press Machine", gruppo_muscolare="Petto",
                default_serie=3, default_ripetizioni="10", default_recupero_secondi=90,
                default_note="Spinta esplosiva, ritorno controllato.",
            ),
            models.ExerciseCatalog(
                nome="Dip alle parallele", gruppo_muscolare="Petto",
                default_serie=3, default_ripetizioni="Max", default_recupero_secondi=90,
                default_note="Busto inclinato in avanti per focus petto.",
            ),
            # ----------------------------------------------------------------
            # SCHIENA
            # ----------------------------------------------------------------
            models.ExerciseCatalog(
                nome="Trazioni alla Sbarra / Pull-up", gruppo_muscolare="Schiena",
                default_serie=4, default_ripetizioni="Max", default_recupero_secondi=120,
                default_note="Tirare con i gomiti, petto in fuori.",
            ),
            models.ExerciseCatalog(
                nome="Lat Machine presa larga", gruppo_muscolare="Schiena",
                default_serie=4, default_ripetizioni="8-10", default_recupero_secondi=90,
                default_note="Tirare al petto, non dietro la nuca.",
            ),
            models.ExerciseCatalog(
                nome="Lat Machine presa inversa/stretta", gruppo_muscolare="Schiena",
                default_serie=3, default_ripetizioni="10-12", default_recupero_secondi=90,
                default_note="Focus sul gran dorsale in allungamento.",
            ),
            models.ExerciseCatalog(
                nome="Rematore Bilanciere", gruppo_muscolare="Schiena",
                default_serie=4, default_ripetizioni="8-10", default_recupero_secondi=120,
                default_note="Schiena dritta parallela al suolo, core contratto.",
            ),
            models.ExerciseCatalog(
                nome="Rematore Manubrio singolo", gruppo_muscolare="Schiena",
                default_serie=3, default_ripetizioni="10 per braccio", default_recupero_secondi=90,
                default_note="Tirare verso l'anca, non verso il petto.",
            ),
            models.ExerciseCatalog(
                nome="Pulley Basso", gruppo_muscolare="Schiena",
                default_serie=3, default_ripetizioni="10-12", default_recupero_secondi=90,
                default_note="Allungare bene in fase eccentrica senza perdere la lombare.",
            ),
            models.ExerciseCatalog(
                nome="Pull-down a braccia tese ai cavi", gruppo_muscolare="Schiena",
                default_serie=3, default_ripetizioni="15", default_recupero_secondi=60,
                default_note="Isolamento del dorsale, braccia quasi tese.",
            ),
            # ----------------------------------------------------------------
            # GAMBE
            # ----------------------------------------------------------------
            models.ExerciseCatalog(
                nome="Squat con Bilanciere", gruppo_muscolare="Gambe",
                default_serie=4, default_ripetizioni="6-8", default_recupero_secondi=120,
                default_note="Rompere il parallelo, peso sul centro del piede.",
            ),
            models.ExerciseCatalog(
                nome="Leg Press 45°", gruppo_muscolare="Gambe",
                default_serie=4, default_ripetizioni="10-12", default_recupero_secondi=90,
                default_note="Non stendere completamente le ginocchia in cima.",
            ),
            models.ExerciseCatalog(
                nome="Affondi Bulgari manubri", gruppo_muscolare="Gambe",
                default_serie=3, default_ripetizioni="10 per gamba", default_recupero_secondi=90,
                default_note="Ginocchio in linea con la punta, scendere in verticale.",
            ),
            models.ExerciseCatalog(
                nome="Leg Extension", gruppo_muscolare="Gambe",
                default_serie=3, default_ripetizioni="15", default_recupero_secondi=60,
                default_note="Pausa di 1 sec in massima contrazione.",
            ),
            models.ExerciseCatalog(
                nome="Leg Curl seduto", gruppo_muscolare="Gambe",
                default_serie=3, default_ripetizioni="12-15", default_recupero_secondi=60,
                default_note="Controllare la fase di discesa.",
            ),

            models.ExerciseCatalog(
                nome="Stacchi a gambe tese / RDL", gruppo_muscolare="Gambe",
                default_serie=4, default_ripetizioni="8-10", default_recupero_secondi=90,
                default_note="Sentire l'allungamento dei femorali.",
            ),
            models.ExerciseCatalog(
                nome="Calf Machine in piedi", gruppo_muscolare="Gambe",
                default_serie=4, default_ripetizioni="15-20", default_recupero_secondi=60,
                default_note="Movimento completo, pausa in massimo allungamento.",
            ),
            # ----------------------------------------------------------------
            # GLUTEI
            # ----------------------------------------------------------------
            models.ExerciseCatalog(
                nome="Hip Thrust bilanciere", gruppo_muscolare="Glutei",
                default_serie=4, default_ripetizioni="10-12", default_recupero_secondi=120,
                default_note="Sguardo avanti, spinta forte dai talloni.",
            ),
            models.ExerciseCatalog(
                nome="Slanci ai cavi / Kickback", gruppo_muscolare="Glutei",
                default_serie=3, default_ripetizioni="12-15 per gamba", default_recupero_secondi=60,
                default_note="Focus sulla contrazione di picco, non usare la schiena.",
            ),
            models.ExerciseCatalog(
                nome="Ponte Glutei a terra / Glute Bridge", gruppo_muscolare="Glutei",
                default_serie=3, default_ripetizioni="15", default_recupero_secondi=60,
                default_note="Pausa di 1 sec in alto.",
            ),
            models.ExerciseCatalog(
                nome="Abductor Machine", gruppo_muscolare="Glutei",
                default_serie=3, default_ripetizioni="15-20", default_recupero_secondi=60,
                default_note="Movimento controllato in apertura e chiusura.",
            ),
            # ----------------------------------------------------------------
            # SPALLE
            # ----------------------------------------------------------------
            models.ExerciseCatalog(
                nome="Military Press Bilanciere", gruppo_muscolare="Spalle",
                default_serie=4, default_ripetizioni="8-10", default_recupero_secondi=120,
                default_note="Traiettoria dritta, core serrato.",
            ),
            models.ExerciseCatalog(
                nome="Arnold Press Manubri", gruppo_muscolare="Spalle",
                default_serie=3, default_ripetizioni="10-12", default_recupero_secondi=90,
                default_note="Rotazione fluida dei polsi durante la spinta.",
            ),
            models.ExerciseCatalog(
                nome="Alzate Laterali Manubri", gruppo_muscolare="Spalle",
                default_serie=4, default_ripetizioni="15", default_recupero_secondi=60,
                default_note="Mignolo leggermente ruotato verso l'alto, braccia non completamente tese.",
            ),
            models.ExerciseCatalog(
                nome="Alzate Laterali ai cavi", gruppo_muscolare="Spalle",
                default_serie=3, default_ripetizioni="15 per braccio", default_recupero_secondi=60,
                default_note="Tensione continua per tutto l'arco di movimento.",
            ),
            models.ExerciseCatalog(
                nome="Face Pull ai cavi altezza occhi", gruppo_muscolare="Spalle",
                default_serie=3, default_ripetizioni="15", default_recupero_secondi=60,
                default_note="Tirare verso il viso, aprire i gomiti per il deltoide posteriore.",
            ),
            models.ExerciseCatalog(
                nome="Peck Deck Inverso", gruppo_muscolare="Spalle",
                default_serie=3, default_ripetizioni="12-15", default_recupero_secondi=60,
                default_note="Fermo di 1 sec in massima apertura.",
            ),
            # ----------------------------------------------------------------
            # BRACCIA
            # ----------------------------------------------------------------
            models.ExerciseCatalog(
                nome="Curl Bilanciere in piedi", gruppo_muscolare="Braccia",
                default_serie=4, default_ripetizioni="8-10", default_recupero_secondi=90,
                default_note="Gomiti incollati ai fianchi, nessun cheating di schiena.",
            ),
            models.ExerciseCatalog(
                nome="Curl Manubri alternato", gruppo_muscolare="Braccia",
                default_serie=3, default_ripetizioni="12 per braccio", default_recupero_secondi=60,
                default_note="Supinazione completa in salita.",
            ),
            models.ExerciseCatalog(
                nome="Panca Scott / Preacher Curl", gruppo_muscolare="Braccia",
                default_serie=3, default_ripetizioni="10", default_recupero_secondi=60,
                default_note="Non iperestendere il gomito in discesa.",
            ),
            models.ExerciseCatalog(
                nome="French Press Bilanciere EZ", gruppo_muscolare="Braccia",
                default_serie=4, default_ripetizioni="10", default_recupero_secondi=90,
                default_note="Gomiti fermi e stretti, scendere verso la fronte.",
            ),
            models.ExerciseCatalog(
                nome="Pushdown Tricipiti ai cavi con corda", gruppo_muscolare="Braccia",
                default_serie=3, default_ripetizioni="12-15", default_recupero_secondi=60,
                default_note="Aprire la corda in chiusura.",
            ),
            models.ExerciseCatalog(
                nome="Estensioni dietro nuca al cavo", gruppo_muscolare="Braccia",
                default_serie=3, default_ripetizioni="12", default_recupero_secondi=60,
                default_note="Focus sull'allungamento del capo lungo del tricipite.",
            ),
            # ----------------------------------------------------------------
            # CORE E ACCESSORI
            # ----------------------------------------------------------------
            models.ExerciseCatalog(
                nome="Crunch al cavo inginocchiato", gruppo_muscolare="Core",
                default_serie=3, default_ripetizioni="15", default_recupero_secondi=60,
                default_note="Flettere la colonna, non usare le anche.",
            ),
            models.ExerciseCatalog(
                nome="Plank classico", gruppo_muscolare="Core",
                default_serie=3, default_ripetizioni="60 sec", default_recupero_secondi=60,
                default_note="Glutei stretti, scapole protratte.",
            ),
            models.ExerciseCatalog(
                nome="Hyperextension / Estensioni lombari", gruppo_muscolare="Core",
                default_serie=3, default_ripetizioni="15", default_recupero_secondi=60,
                default_note="Arrotolare e srotolare la colonna, senza strattoni.",
            ),
        ]

        db.add_all(esercizi)
        db.commit()
        logger.info(f"Seeding completato: {len(esercizi)} esercizi inseriti nel catalogo.")

    except Exception as exc:
        db.rollback()
        logger.error(f"Errore durante il seeding del catalogo: {exc}", exc_info=True)
        raise
    finally:
        db.close()


# seed_admin è stata rimossa per favorire il setup iniziale dinamico.


# Il seeding è stato spostato nell'evento 'startup' dell'app.

# ---------------------------------------------------------------------------
# Istanza FastAPI
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Forge Fit API",
    description="Backend per la gestione di utenti, schede di allenamento e catalogo esercizi.",
    version="1.1.8",
)


@app.on_event("startup")
def on_startup():
    """
    All'avvio dell'applicazione:
    1. Crea le tabelle nel database se non esistono.
    2. Esegue il seeding del catalogo esercizi.
    3. Esegue il seeding dell'utente amministratore.
    """
    logger.info("Inizializzazione database in corso...")
    # Crea tabelle
    models.Base.metadata.create_all(bind=engine)
    # Seeding
    seed_catalog()
    # seed_admin()  <-- Rimossa
    if not config_manager.is_admin_configured():
        logger.warning("ATTENZIONE: Personal Trainer non configurato. Effettuare il setup iniziale dalla dashboard.")
    else:
        logger.info("Personal Trainer configurato correttamente.")
    logger.info("Inizializzazione completata con successo.")

# ---------------------------------------------------------------------------
# Middleware CORS - domini autorizzati via env var ALLOWED_ORIGINS
# Formato: lista separata da virgole, es. "https://app.example.com,http://localhost:8083"
# ---------------------------------------------------------------------------
_raw_origins = os.getenv("ALLOWED_ORIGINS")
if not _raw_origins or not _raw_origins.strip():
    _raw_origins = "http://localhost:8083,http://localhost:3000,https://forgefit.ghome.it,http://10.0.0.105:8083,https://fitconsole.ghome.it"
allowed_origins = [o.strip() for o in _raw_origins.split(",") if o.strip()]
logger.info(f"CORS Allowed Origins: {allowed_origins}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Mount cartella static per la dashboard HTML del Personal Trainer
# ---------------------------------------------------------------------------
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/", include_in_schema=False)
def root():
    """Serve la dashboard HTML del Personal Trainer."""
    return FileResponse("static/index.html")


@app.get("/policy", include_in_schema=False)
def policy():
    """Serve la pagina dei Termini e Condizioni / Privacy Policy."""
    return FileResponse("static/policy.html")


# ===========================================================================
# POST /api/register - Registra un nuovo utente con dati biometrici
# ===========================================================================
@app.post(
    "/api/register",
    response_model=schemas.UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registra un nuovo utente",
    tags=["Utenti"],
)
def register_user(
    user_data: schemas.UserCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    Salva un nuovo cliente nel DB. Solo per ADMIN (Personal Trainer).
    """
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può registrare nuovi clienti.")
    # Controlla se l'email è già presente
    existing = db.query(models.User).filter(models.User.email == user_data.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Email '{user_data.email}' già registrata.",
        )

    user_dict = user_data.model_dump()
    plain_password = user_dict.pop("password", None)
    
    if plain_password:
        user_dict["hashed_password"] = auth.hash_password(plain_password)
    
    # Mappatura esplicita per il modello SQLAlchemy (English)
    new_user = models.User(
        email=user_data.email,
        first_name=user_data.first_name,
        last_name=user_data.last_name,
        age=user_data.age,
        weight=user_data.weight,
        height=user_data.height,
        biceps=user_data.biceps,
        chest=user_data.chest,
        hips=user_data.hips,
        waist=user_data.waist,
        thigh=user_data.thigh,
        calf=user_data.calf,
        neck=user_data.neck,
        wrist=user_data.wrist,
        gender=user_data.gender,
        hashed_password=user_dict.get("hashed_password")
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # --- CREAZIONE MISURAZIONE INIZIALE ---
    # Creiamo un record nello storico solo se è stato inserito almeno un valore biometrico
    if any([user_data.weight, user_data.chest, user_data.waist, user_data.hips, 
            user_data.biceps, user_data.thigh, user_data.calf, user_data.neck, user_data.wrist]):
        initial_meas = models.Measurement(
            user_id=new_user.id,
            weight=new_user.weight,
            chest=new_user.chest,
            waist=new_user.waist,
            hips=new_user.hips,
            biceps=new_user.biceps,
            thigh=new_user.thigh,
            calf=new_user.calf,
            neck=new_user.neck,
            wrist=new_user.wrist,
            goal="Misurazione iniziale (registrazione)"
        )
        db.add(initial_meas)
        db.commit()
    # -------------------------------------

    logger.info(f"Cliente registrato dal PT: {new_user.email} (ID: {new_user.id})")
    return new_user


# ---------------------------------------------------------------------------
# CRUD MISURAZIONI (Aggiornamento ed Eliminazione)
# ---------------------------------------------------------------------------

@app.delete(
    "/api/measurements/{measurement_id}",
    response_model=schemas.MessageResponse,
    summary="Elimina una misurazione specifica",
    tags=["Misure"],
)
def delete_measurement(
    measurement_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Elimina un record biometrico dal database tramite il suo ID. Solo proprietario o admin."""
    meas = db.query(models.Measurement).filter(models.Measurement.id == measurement_id).first()
    if not meas:
        raise HTTPException(status_code=404, detail="Misurazione non trovata.")
    
    # Isola i dati: solo l'admin o il proprietario possono eliminare
    if current_user.role != "admin" and meas.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Accesso negato: non puoi eliminare misurazioni di altri utenti.")
    
    db.delete(meas)
    db.commit()
    logger.info(f"Misurazione ID {measurement_id} eliminata.")
    return {"message": "Misurazione eliminata correttamente."}


@app.put(
    "/api/measurements/{measurement_id}",
    response_model=schemas.MeasurementResponse,
    summary="Aggiorna una misurazione esistente",
    tags=["Misure"],
)
def update_measurement(
    measurement_id: int,
    data: schemas.MeasurementCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Aggiorna i valori di una misurazione esistente. Solo proprietario o admin."""
    meas = db.query(models.Measurement).filter(models.Measurement.id == measurement_id).first()
    if not meas:
        raise HTTPException(status_code=404, detail="Misurazione non trovata.")

    # Isola i dati: solo l'admin o il proprietario possono aggiornare
    if current_user.role != "admin" and meas.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Accesso negato: non puoi modificare misurazioni di altri utenti.")

    # Aggiornamento campi
    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(meas, key, value)
    
    db.commit()
    db.refresh(meas)
    logger.info(f"Misurazione ID {measurement_id} aggiornata.")
    return meas


# ===========================================================================
# POST /api/auth/register - Crea un account con password (per il PT)
# ===========================================================================
@app.post(
    "/api/auth/register",
    response_model=schemas.UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registra un account con password",
    tags=["Autenticazione"],
)
def auth_register(data: schemas.AuthRegisterRequest, db: Session = Depends(get_db)):
    """
    Crea un nuovo account con email e password (per il Personal Trainer).
    La password viene hashata con bcrypt prima del salvataggio.
    Restituisce 409 se l'email è già in uso.
    """
    if db.query(models.User).filter(models.User.email == data.email).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Email '{data.email}' già registrata.",
        )
    new_user = models.User(
        email=data.email,
        first_name=data.first_name,
        last_name=data.last_name,
        age=data.age,
        gender=data.gender,
        # Dati biometrici
        weight=data.weight,
        height=data.height,
        biceps=data.biceps,
        chest=data.chest,
        hips=data.hips,
        waist=data.waist,
        thigh=data.thigh,
        calf=data.calf,
        neck=data.neck,
        wrist=data.wrist,
        hashed_password=auth.hash_password(data.password),
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # --- CREAZIONE MISURAZIONE INIZIALE ---
    if any([data.weight, data.chest, data.waist, data.hips, 
            data.biceps, data.thigh, data.calf, data.neck, data.wrist]):
        initial_meas = models.Measurement(
            user_id=new_user.id,
            weight=new_user.weight,
            chest=new_user.chest,
            waist=new_user.waist,
            hips=new_user.hips,
            biceps=new_user.biceps,
            thigh=new_user.thigh,
            calf=new_user.calf,
            neck=new_user.neck,
            wrist=new_user.wrist,
            goal="Misurazione iniziale (registrazione da app)"
        )
        db.add(initial_meas)
        db.commit()
    # -------------------------------------

    logger.info(f"Nuovo account creato da app: {new_user.email} (ID: {new_user.id})")
    return new_user


# ===========================================================================
# POST /api/auth/login - Login con email+password, restituisce JWT
# ===========================================================================
@app.post(
    "/api/auth/login",
    response_model=schemas.TokenResponse,
    summary="Login e ottenimento JWT",
    tags=["Autenticazione"],
)
def auth_login(data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """
    Verifica email (username) e password, restituisce un JWT valido 7 giorni.
    OAuth2PasswordRequestForm riceve i dati via form-data (username/password).
    """
    # 1. Controlla prima l'Admin nel file di configurazione
    admin_config = config_manager.get_admin_config()
    if admin_config and admin_config.get("username") == data.username:
        if auth.verify_password(data.password, admin_config["hashed_password"]):
            token = auth.create_access_token(subject=data.username)
            refresh = auth.create_refresh_token(subject=data.username)
            logger.info(f"Login PT (File Config) riuscito: {data.username}")
            return schemas.TokenResponse(
                access_token=token,
                refresh_token=refresh,
                role="admin",
                user_id=0,
                version="1.1.8",
                user=schemas.UserResponse(
                    id=0,
                    email=data.username,
                    first_name=admin_config["pt_name"],
                    last_name="PT",
                    age=30
                )
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenziali Amministratore non valide.",
                headers={"WWW-Authenticate": "Bearer"},
            )

    # 2. Altrimenti cerca nel database (Clienti)
    user = db.query(models.User).filter(models.User.email == data.username).first()
    if not user or not user.hashed_password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenziali non valide.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not auth.verify_password(data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenziali non valide.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = auth.create_access_token(subject=user.email)
    refresh = auth.create_refresh_token(subject=user.email)
    logger.info(f"Login cliente riuscito: {user.email} (Ruolo: {user.role})")
    return schemas.TokenResponse(
        access_token=token,
        refresh_token=refresh,
        role=user.role,
        user_id=user.id,
        version="1.1.8",
        user=schemas.UserResponse.model_validate(user)
    )


# ===========================================================================
# SETUP INIZIALE PT
# ===========================================================================

@app.get(
    "/api/auth/setup-status",
    response_model=schemas.SetupStatusResponse,
    summary="Verifica se il PT è già configurato",
    tags=["Autenticazione"],
)
def get_setup_status():
    """Restituisce true se il file admin_config.json esiste."""
    return {"is_configured": config_manager.is_admin_configured()}


@app.post(
    "/api/auth/setup",
    response_model=schemas.MessageResponse,
    summary="Configurazione iniziale del Personal Trainer",
    tags=["Autenticazione"],
)
def setup_admin(data: schemas.AdminSetupRequest):
    """
    Crea il file admin_config.json al primo avvio.
    Fallisce se il sistema è già configurato.
    """
    if config_manager.is_admin_configured():
        raise HTTPException(status_code=400, detail="Sistema già configurato.")
    
    if data.password != data.confirm_password:
        raise HTTPException(status_code=400, detail="Le password non coincidono.")

    hashed = auth.hash_password(data.password)
    success = config_manager.save_admin_config(
        pt_name=data.pt_name,
        username=data.username,
        hashed_password=hashed
    )
    
    if not success:
        raise HTTPException(status_code=500, detail="Errore durante il salvataggio della configurazione.")
    
    logger.info(f"Setup iniziale completato. PT: {data.pt_name} ({data.username})")
    return {"message": "Configurazione completata con successo. Ora puoi accedere."}


# ===========================================================================
# PUT /api/auth/change-password - Cambia la password dell'utente corrente
# ===========================================================================
@app.put(
    "/api/auth/change-password",
    response_model=schemas.MessageResponse,
    summary="Cambia la password dell'utente autenticato",
    tags=["Autenticazione"],
)
def change_password(
    data: schemas.ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Verifica la vecchia password e imposta la nuova.
    Richiede autenticazione JWT.
    """
    # 1. Verifica vecchia password
    if not auth.verify_password(data.vecchia_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La vecchia password non è corretta.",
        )

    # 2. Aggiorna password
    current_user.hashed_password = auth.hash_password(data.nuova_password)
    db.commit()
    logger.info(f"Password aggiornata per: {current_user.email}")
    return {"message": "Password aggiornata con successo."}


# ===========================================================================
# POST /api/auth/refresh — Rinnova access token tramite refresh token
# ===========================================================================
@app.post(
    "/api/auth/refresh",
    response_model=schemas.RefreshTokenResponse,
    summary="Rinnova l'access token usando il refresh token",
    tags=["Autenticazione"],
)
def refresh_access_token(data: schemas.RefreshTokenRequest, db: Session = Depends(get_db)):
    """
    Verifica il refresh token e restituisce un nuovo access token senza richiedere
    nuovamente le credenziali. Il refresh token rimane valido fino alla sua scadenza (30 giorni).
    """
    subject = auth.decode_refresh_token(data.refresh_token)

    # Verifica che l'utente esista ancora (potrebbe essere stato eliminato)
    admin_config = config_manager.get_admin_config()
    if not (admin_config and admin_config.get("username") == subject):
        user = db.query(models.User).filter(models.User.email == subject).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Utente non trovato.")

    new_token = auth.create_access_token(subject=subject)
    logger.info(f"Access token rinnovato per: {subject}")
    return schemas.RefreshTokenResponse(access_token=new_token)


# ===========================================================================
# GET /api/auth/me - Restituisce il profilo dell'utente autenticato
# ===========================================================================
@app.get(
    "/api/auth/me",
    response_model=schemas.UserResponse,
    summary="Recupera il profilo dell'utente loggato",
    tags=["Autenticazione"],
)
def get_me(current_user: models.User = Depends(get_current_user)):
    """
    Restituisce i dati anagrafici e biometrici dell'utente associato al token JWT.
    """
    return current_user


# ===========================================================================
# POST /api/auth/unlock-ai - Verifica codice sblocco AI (server-side)
# ===========================================================================
@app.post(
    "/api/auth/unlock-ai",
    response_model=schemas.UnlockAIResponse,
    summary="Verifica il codice di sblocco funzionalità AI",
    tags=["Autenticazione"],
)
def unlock_ai(
    data: schemas.UnlockAIRequest,
    current_user: models.User = Depends(get_current_user),
):
    """
    Riceve un codice di sblocco AI dal client autenticato e lo verifica
    server-side. Il codice è un HMAC-SHA256 troncato a 8 char derivato dalla
    JWT_SECRET_KEY + anno + settimana ISO. Non è indovinabile senza la chiave.
    """
    import hmac
    import hashlib
    from datetime import datetime, timezone, timedelta
    from auth import SECRET_KEY

    now = datetime.now(timezone.utc)
    iso_year, iso_week, _ = now.isocalendar()
    # Deriva il codice: HMAC-SHA256(secret, "YYYY-WXX") troncato a 8 caratteri esadecimali
    message = f"{iso_year}-W{iso_week:02d}".encode()
    expected_code = hmac.new(SECRET_KEY.encode(), message, hashlib.sha256).hexdigest()[:8]

    if not hmac.compare_digest(data.code.strip().lower(), expected_code):
        logger.info(f"Codice AI non valido per utente {current_user.email} (settimana {iso_year}-W{iso_week:02d})")
        return schemas.UnlockAIResponse(valid=False)


    # Scadenza: domenica della settimana corrente alle 23:59:59 UTC
    days_until_sunday = 6 - now.weekday()
    if days_until_sunday < 0:
        days_until_sunday = 0
    expires = (now + timedelta(days=days_until_sunday)).replace(
        hour=23, minute=59, second=59, microsecond=0
    )

    logger.info(f"Sblocco AI concesso a {current_user.email} fino a {expires.isoformat()}")
    return schemas.UnlockAIResponse(valid=True, expires_at=expires.isoformat())


# ===========================================================================
# GET /api/auth/ai-unlock-code — Mostra il codice corrente (solo Admin)
# ===========================================================================
@app.get(
    "/api/auth/ai-unlock-code",
    summary="Restituisce il codice di sblocco AI della settimana corrente (Solo Admin)",
    tags=["Autenticazione"],
)
def get_ai_unlock_code(current_user: models.User = Depends(get_current_user)):
    """Usato dalla dashboard PT per comunicare il codice settimanale ai clienti."""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato.")
    import hmac as _hmac
    import hashlib
    from datetime import datetime, timezone
    from auth import SECRET_KEY
    now = datetime.now(timezone.utc)
    iso_year, iso_week, _ = now.isocalendar()
    message = f"{iso_year}-W{iso_week:02d}".encode()
    code = _hmac.new(SECRET_KEY.encode(), message, hashlib.sha256).hexdigest()[:8]
    return {"week": f"{iso_year}-W{iso_week:02d}", "code": code}


# ===========================================================================
# POST /api/plans/generate-ai - Genera scheda tramite Gemini
# ===========================================================================
@app.post(
    "/api/plans/generate-ai",
    summary="Genera una scheda di allenamento tramite AI (Gemini)",
    tags=["AI"],
)
def generate_ai_plan(
    data: schemas.AIGenerateRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    Usa Gemini 1.5 Flash per generare una scheda JSON.
    Se l'utente è un client, genera SOLO per se stesso ignorando user_id nel body.
    Se l'utente è admin, usa l'user_id specificato.
    """
    # FORZATURA IDENTITY: Se non è admin, forziamo l'ID dell'utente loggato
    user_id_to_use = current_user.id if current_user.role != "admin" else data.user_id

    # 1. Recupera Utente
    user = db.query(models.User).filter(models.User.id == user_id_to_use).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utente non trovato.")

    # 2. Recupera ultima misurazione
    latest = db.query(models.Measurement).filter(
        models.Measurement.user_id == user.id
    ).order_by(models.Measurement.created_at.desc()).first()
    
    # Dati biometrici per il prompt
    weight = latest.weight if latest else user.weight
    height = user.height
    chest = latest.chest if latest else user.chest
    waist = latest.waist if latest else user.waist
    
    # Metriche avanzate calcolate dinamicamente dal modello
    bmi = user.bmi
    bmr = user.bmr
    body_fat = user.body_fat_perc
    
    # 3. Recupera Catalogo Esercizi (solo i nomi)
    catalog = db.query(models.ExerciseCatalog).all()
    # Creiamo una lista pulita e numerata per l'AI per evitare confusione
    exercise_list = "\n".join([f"- {e.nome}" for e in catalog])

    # 4. Configura e Ottieni Modello Gemini (Dinamico)
    try:
        model = ai_service.get_model(db, model_override=data.model_name if hasattr(data, 'model_name') else None)
    except ValueError as ve:
        raise HTTPException(status_code=500, detail=str(ve))

    # 4.5 Recupero Storico Allenamenti
    # Cerchiamo se l'utente ha già una scheda salvata nel sistema
    last_plan_obj = db.query(models.WorkoutPlan).filter(models.WorkoutPlan.user_id == user.id).first()
    if last_plan_obj:
        try:
            # Decodifichiamo il JSON per estrarre solo i nomi degli esercizi
            old_data = json.loads(last_plan_obj.plan_json)
            storico_lista = []
            for g in old_data.get("giorni", []):
                for e in g.get("esercizi", []):
                    storico_lista.append(f"{e.get('nome')} ({e.get('serie')}x{e.get('ripetizioni')})")
            storico_esercizi = "L'utente ha eseguito recentemente: " + ", ".join(storico_lista)
        except:
            storico_esercizi = "Presente una scheda precedente ma con formato non leggibile."
    else:
        storico_esercizi = "Nessun allenamento precedente registrato. Crea una scheda di base per iniziare il percorso."

    # 5. Costruzione Prompt
    prompt = f"""
    Agisci come un Personal Trainer d'élite esperto in programmazione dell'allenamento.
    Crea una scheda di allenamento strutturata di ESATTAMENTE {data.training_days} giorni per questo cliente.
    
    VINCOLO TEMPORALE: Ogni sessione di allenamento deve essere completata in massimo {data.training_time} minuti.
    Regola il volume (serie/ripetizioni) e il numero di esercizi (massimo 5-7 per sessione) per rispettare questo limite.

    DATI CLIENTE E FISIOLOGIA:
    - Sesso: {user.gender}
    - Età: {user.age} anni
    - Livello: {data.experience_level}
    - Peso: {weight} kg
    - Altezza: {height} cm
    - Circonferenze attuali: Petto {chest}cm, Vita {waist}cm
    - Indicatori Avanzati: BMI {bmi}, BMR {bmr} kcal, Massa Grassa stimata {body_fat}%
    - Note aggiuntive PT: {data.pt_notes or "Nessuna nota specifica"}

    STORICO ALLENAMENTI RECENTI:
    {storico_esercizi}

    REGOLE FONDAMENTALI:
    1. SELEZIONE ESERCIZI: Scegli gli esercizi SOLO ED ESCLUSIVAMENTE da questa lista ufficiale del catalogo. NON INVENTARE nomi o varianti simili:
    {exercise_list}
    2. NUMERO GIORNI: Devi generare ESATTAMENTE {data.training_days} giorni di allenamento (né uno in più, né uno in meno).
    3. DURATA SESSIONE: La sessione deve durare massimo {data.training_time} minuti inclusi i recuperi.
    4. RECUPERO: Il campo "recupero_secondi" deve essere ESCLUSIVAMENTE un numero intero che rappresenta i secondi (es. 90, 120). USA SEMPRE la chiave "recupero_secondi", non "recupero".
    5. GRUPPO: Specifica sempre il gruppo muscolare principale dell'esercizio.
    6. FORMATO: Restituisci la risposta ESCLUSIVAMENTE in formato JSON valido, senza testo prima o dopo.

    STRUTTURA JSON RICHIESTA:
    {{
    "giorni": [
        {{
        "nome_giorno": "Giorno 1 (es. Petto e Tricipiti)",
        "esercizi": [
            {{
            "gruppo": "Petto",
            "nome": "Nome esatto dal catalogo",
            "serie": 4,
            "ripetizioni": "8-10",
            "recupero_secondi": 90,
            "note": "Spiegazione tecnica."
            }}
        ]
        }}
    ]
    }}
    """

    try:
        response = model.generate_content(
            prompt,
            generation_config=genai.types.GenerationConfig(
                response_mime_type="application/json",
            )
        )
        
        # Parsing della risposta
        plan_json = json.loads(response.text)
        logger.info(f"Scheda AI generata con successo per utente ID {user.id}")
        return plan_json
        
    except Exception as e:
        logger.error(f"Errore generazione AI: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Errore durante la generazione AI: {str(e)}")


# ===========================================================================
# POST /api/plans/{user_id} - Salva o aggiorna scheda (usato dal PT)
# ===========================================================================
@app.post(
    "/api/plans/{user_id}",
    response_model=schemas.WorkoutPlanResponse,
    summary="Salva o aggiorna la scheda di allenamento",
    tags=["Schede"],
)
def save_or_update_plan(
    user_id: int,
    plan_data: schemas.WorkoutPlanCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Il Personal Trainer invia la scheda JSON per un utente identificato via ID.
    Solo gli utenti con ruolo 'admin' possono eseguire questa operazione.
    """
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permessi insufficienti: solo il Personal Trainer può salvare schede.")
    
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"Utente con ID '{user_id}' non trovato.")

    plan_json_str = json.dumps(plan_data.plan, ensure_ascii=False)

    # Calcola il prossimo numero di versione per questo utente
    last = db.query(models.WorkoutPlan).filter(
        models.WorkoutPlan.user_id == user.id
    ).order_by(models.WorkoutPlan.version.desc()).first()
    next_version = (last.version + 1) if last else 1

    new_plan = models.WorkoutPlan(
        user_id=user.id,
        plan_json=plan_json_str,
        version=next_version,
        label=plan_data.label,
    )
    db.add(new_plan)
    db.commit()
    db.refresh(new_plan)
    logger.info(f"Scheda v{next_version} creata per utente ID: {user.id} (label: {plan_data.label!r})")

    return schemas.WorkoutPlanResponse(
        user_email=user.email,
        user_id=user.id,
        plan=plan_data.plan,
        version=next_version,
        label=plan_data.label,
    )


# ===========================================================================
# GET /api/plans/{user_id} - Scarica scheda (usato dall'app mobile)
# ===========================================================================
@app.get(
    "/api/plans/{user_id}",
    response_model=schemas.WorkoutPlanResponse,
    summary="Scarica la scheda di allenamento",
    tags=["Schede"],
)
def get_plan(user_id: int, db: Session = Depends(get_db),
            current_user: models.User = Depends(get_current_user)):
    """
    Scarica la scheda JSON dell'utente tramite ID.
    UN UTENTE PUÒ SCARICARE SOLO LA PROPRIA SCHEDA (Data Isolation).
    """
    # Verifica isolamento: se non è admin e l'ID non corrisponde al suo, neghiamo l'accesso
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Accesso negato: puoi visualizzare solo la tua scheda.")
    
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"Utente con ID '{user_id}' non trovato.")

    plan = db.query(models.WorkoutPlan).filter(
        models.WorkoutPlan.user_id == user.id
    ).order_by(models.WorkoutPlan.version.desc()).first()

    if not plan:
        raise HTTPException(status_code=404, detail=f"Nessuna scheda attiva trovata per l'utente {user.first_name}.")

    plan_data = json.loads(plan.plan_json)
    
    # --- ARRICCHIMENTO DINAMICO ---
    catalog_map = {ex.nome: ex.video_url for ex in db.query(models.ExerciseCatalog).all()}
    
    if "giorni" in plan_data:
        for giorno in plan_data["giorni"]:
            if "esercizi" in giorno:
                for ex in giorno["esercizi"]:
                    ex_name = ex.get("nome")
                    if ex_name in catalog_map:
                        ex["video_url"] = catalog_map[ex_name]
    # -----------------------------

    return schemas.WorkoutPlanResponse(
        user_email=user.email,
        user_id=user.id,
        plan=plan_data,
        version=plan.version,
        label=plan.label,
    )


# ===========================================================================
# GET /api/plans/{user_id}/history - Storico versioni schede
# ===========================================================================
@app.get(
    "/api/plans/{user_id}/history",
    response_model=list[schemas.WorkoutPlanHistoryItem],
    summary="Storico versioni schede di un utente",
    tags=["Schede"],
)
def get_plan_history(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Restituisce tutte le versioni delle schede assegnate a un utente, dalla più recente.
    Accessibile dall'admin per qualsiasi utente; dal cliente solo per sé stesso.
    """
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Accesso negato.")
    plans = db.query(models.WorkoutPlan).filter(
        models.WorkoutPlan.user_id == user_id
    ).order_by(models.WorkoutPlan.version.desc()).all()

    return [
        schemas.WorkoutPlanHistoryItem(
            id=p.id,
            version=p.version,
            label=p.label,
            created_at=p.created_at,
            plan=json.loads(p.plan_json),
        )
        for p in plans
    ]


# ===========================================================================
# GET /api/users - Lista tutti gli utenti (utility per il PT) — PROTETTO
# ===========================================================================
@app.get(
    "/api/users",
    response_model=list[schemas.UserResponse],
    summary="Lista tutti gli utenti registrati",
    tags=["Utenti"],
)
def list_users(db: Session = Depends(get_db),
              current_user: models.User = Depends(get_current_user)):
    """
    Restituisce tutti gli utenti registrati nel sistema. Solo per ADMIN.
    """
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può vedere la lista utenti.")
    users = db.query(models.User).all()

    result = []
    for user in users:
        latest = db.query(models.Measurement).filter(
            models.Measurement.user_id == user.id
        ).order_by(models.Measurement.created_at.desc()).first()

        # Costruisce la risposta senza toccare l'oggetto ORM in sessione
        response = schemas.UserResponse.model_validate(user)
        if latest:
            response.weight = latest.weight if latest.weight is not None else response.weight
            response.chest  = latest.chest  if latest.chest  is not None else response.chest
            response.hips   = latest.hips   if latest.hips   is not None else response.hips
            response.waist  = latest.waist  if latest.waist  is not None else response.waist
            response.biceps = latest.biceps if latest.biceps is not None else response.biceps
            response.thigh  = latest.thigh  if latest.thigh  is not None else response.thigh
            response.calf   = latest.calf   if latest.calf   is not None else response.calf
            response.neck   = latest.neck   if latest.neck   is not None else response.neck
            response.wrist  = latest.wrist  if latest.wrist  is not None else response.wrist
        result.append(response)

    return result


# ===========================================================================
# DELETE /api/users/{email} - Elimina utente e (cascade) la sua scheda — PROTETTO
# ===========================================================================
@app.delete(
    "/api/users/{email}",
    response_model=schemas.MessageResponse,
    summary="Elimina un utente e la sua scheda",
    tags=["Utenti"],
)
def delete_user(email: str, db: Session = Depends(get_db),
               current_user: models.User = Depends(get_current_user)):
    """
    Elimina un utente identificato dalla sua email. Solo per ADMIN.
    """
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può eliminare utenti.")
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Utente '{email}' non trovato.",
        )

    db.delete(user)  # Il cascade elimina anche il WorkoutPlan collegato
    db.commit()
    logger.info(f"Utente eliminato: {email}")
    return {"message": f"Utente '{email}' e la sua scheda eliminati con successo."}


# ===========================================================================
# GET /api/users/export - Esporta tutti gli utenti in formato CSV
# ===========================================================================
# ===========================================================================


@app.get(
    "/api/users/export",
    summary="Esporta la lista clienti in CSV",
    tags=["Utenti"],
    response_class=StreamingResponse,
)
def export_users_csv(db: Session = Depends(get_db),
                     current_user: models.User = Depends(get_current_user)):
    """
    Genera e scarica un file CSV con tutti gli utenti registrati.
    Le colonne esportate sono: id, email, nome, cognome, eta, peso, altezza,
    bicipite, petto, vita, coscia.
    """
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può esportare i dati.")
    users = db.query(models.User).all()
    output = io.StringIO()
    writer = csv.writer(output)
    # Intestazione
    writer.writerow(["id", "email", "first_name", "last_name", "age",
                     "weight", "height", "biceps", "chest", "waist", "thigh", "calf", "neck", "wrist", "gender"])
    for u in users:
        writer.writerow([
            u.id, u.email, u.first_name, u.last_name, u.age,
            u.weight or "", u.height or "", u.biceps or "",
            u.chest or "", u.waist or "", u.thigh or "", u.calf or "", u.neck or "", u.wrist or "", u.gender or "",
        ])
    output.seek(0)
    logger.info(f"Export CSV: {len(users)} utenti")
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=clienti.csv"},
    )


# ===========================================================================
# POST /api/users/import - Importa clienti da file CSV (upsert per email)
# ===========================================================================
@app.post(
    "/api/users/import",
    response_model=schemas.MessageResponse,
    summary="Importa clienti da un file CSV",
    tags=["Utenti"],
)
async def import_users_csv(file: UploadFile = File(...), db: Session = Depends(get_db),
                           current_user: models.User = Depends(get_current_user)):
    """
    Importa clienti da un file CSV caricato. Solo per ADMIN.
    """
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può importare dati.")
    content = await file.read()
    text = content.decode("utf-8-sig")  # gestisce BOM di Excel
    reader = csv.DictReader(io.StringIO(text))

    inseriti = aggiornati = saltati = 0
    for row in reader:
        try:
            email = row.get("email", "").strip().lower()
            first_name = row.get("first_name", row.get("nome", "")).strip()
            last_name = row.get("last_name", row.get("cognome", "")).strip()
            age_raw = row.get("age", row.get("eta", "")).strip()
            
            if not email or not first_name or not last_name or not age_raw:
                saltati += 1
                continue
            age = int(age_raw)

            def _float(val: str):
                v = val.strip() if val else ""
                return float(v) if v else None

            existing = db.query(models.User).filter(models.User.email == email).first()
            if existing:
                existing.first_name = first_name
                existing.last_name = last_name
                existing.age = age
                existing.weight = _float(row.get("weight", row.get("peso", "")))
                existing.height = _float(row.get("height", row.get("altezza", "")))
                existing.biceps = _float(row.get("biceps", row.get("bicipite", "")))
                existing.chest = _float(row.get("chest", row.get("petto", "")))
                existing.waist = _float(row.get("waist", row.get("vita", "")))
                existing.hips = _float(row.get("hips", row.get("fianchi", "")))
                existing.thigh = _float(row.get("thigh", row.get("coscia", "")))
                existing.calf = _float(row.get("calf", row.get("polpaccio", "")))
                existing.neck = _float(row.get("neck", row.get("collo", "")))
                existing.wrist = _float(row.get("wrist", row.get("polso", "")))
                existing.gender = row.get("gender", row.get("sesso", "")).strip() or None
                aggiornati += 1
            else:
                new_user = models.User(
                    email=email, first_name=first_name, last_name=last_name, age=age,
                    weight=_float(row.get("weight", row.get("peso", ""))),
                    height=_float(row.get("height", row.get("altezza", ""))),
                    biceps=_float(row.get("biceps", row.get("bicipite", ""))),
                    chest=_float(row.get("chest", row.get("petto", ""))),
                    waist=_float(row.get("waist", row.get("vita", ""))),
                    hips=_float(row.get("hips", row.get("fianchi", ""))),
                    thigh=_float(row.get("thigh", row.get("coscia", ""))),
                    calf=_float(row.get("calf", row.get("polpaccio", ""))),
                    neck=_float(row.get("neck", row.get("collo", ""))),
                    wrist=_float(row.get("wrist", row.get("polso", ""))),
                    gender=row.get("gender", row.get("sesso", "")).strip() or None,
                )
                db.add(new_user)
                inseriti += 1
        except Exception as exc:
            logger.warning(f"Import CSV - riga saltata: {exc}")
            saltati += 1

    db.commit()
    msg = f"Import completato: {inseriti} inseriti, {aggiornati} aggiornati, {saltati} saltati."
    logger.info(msg)
    return {"message": msg}


# ===========================================================================
# CATALOGO ESERCIZI - CRUD completo su /api/catalog
# ===========================================================================

# ---------------------------------------------------------------------------
# GET /api/catalog - Lista tutti gli esercizi del catalogo
# ---------------------------------------------------------------------------
@app.get(
    "/api/catalog",
    response_model=list[schemas.ExerciseCatalogResponse],
    summary="Lista tutti gli esercizi del catalogo",
    tags=["Catalogo Esercizi"],
)
def list_exercises(db: Session = Depends(get_db)):
    """
    Restituisce l'elenco completo degli esercizi presenti nel catalogo.
    Utile per popolare dropdown o liste nell'app mobile e nella dashboard.
    """
    return db.query(models.ExerciseCatalog).order_by(models.ExerciseCatalog.nome).all()


# ---------------------------------------------------------------------------
# GET /api/catalog/{exercise_id} - Legge un singolo esercizio per ID
# ---------------------------------------------------------------------------
@app.get(
    "/api/catalog/{exercise_id}",
    response_model=schemas.ExerciseCatalogResponse,
    summary="Dettaglio di un esercizio",
    tags=["Catalogo Esercizi"],
)
def get_exercise(exercise_id: int, db: Session = Depends(get_db)):
    """
    Restituisce i dettagli di un singolo esercizio identificato dal suo ID numerico.
    Restituisce 404 se l'esercizio non esiste nel catalogo.
    """
    exercise = db.query(models.ExerciseCatalog).filter(
        models.ExerciseCatalog.id == exercise_id
    ).first()
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Esercizio con ID {exercise_id} non trovato.",
        )
    return exercise


# ---------------------------------------------------------------------------
# POST /api/catalog - Aggiunge un nuovo esercizio al catalogo
# ---------------------------------------------------------------------------
@app.post(
    "/api/catalog",
    response_model=schemas.ExerciseCatalogResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Aggiunge un esercizio al catalogo",
    tags=["Catalogo Esercizi"],
)
def create_exercise(exercise_data: schemas.ExerciseCatalogCreate, db: Session = Depends(get_db),
                    current_user: models.User = Depends(get_current_user)):
    """
    Aggiunge un nuovo esercizio al catalogo globale. Solo per ADMIN.
    """
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può modificare il catalogo.")
    # Controlla duplicati per nome
    existing = db.query(models.ExerciseCatalog).filter(
        models.ExerciseCatalog.nome == exercise_data.nome
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Esercizio '{exercise_data.nome}' già presente nel catalogo.",
        )

    new_exercise = models.ExerciseCatalog(**exercise_data.model_dump())
    db.add(new_exercise)
    db.commit()
    db.refresh(new_exercise)
    logger.info(f"Esercizio aggiunto al catalogo: '{new_exercise.nome}' (ID: {new_exercise.id})")
    return new_exercise


# ---------------------------------------------------------------------------
# PUT /api/catalog/{exercise_id} - Aggiorna un esercizio esistente
# ---------------------------------------------------------------------------
@app.put(
    "/api/catalog/{exercise_id}",
    response_model=schemas.ExerciseCatalogResponse,
    summary="Aggiorna un esercizio del catalogo",
    tags=["Catalogo Esercizi"],
)
def update_exercise(
    exercise_id: int,
    exercise_data: schemas.ExerciseCatalogCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Aggiorna i dati di un esercizio. Solo per ADMIN.
    """
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può modificare il catalogo.")
    exercise = db.query(models.ExerciseCatalog).filter(
        models.ExerciseCatalog.id == exercise_id
    ).first()
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Esercizio con ID {exercise_id} non trovato.",
        )

    # Controlla che il nuovo nome non sia già usato da un ALTRO esercizio
    name_conflict = db.query(models.ExerciseCatalog).filter(
        models.ExerciseCatalog.nome == exercise_data.nome,
        models.ExerciseCatalog.id != exercise_id,
    ).first()
    if name_conflict:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Il nome '{exercise_data.nome}' è già usato da un altro esercizio.",
        )

    # Applica le modifiche
    exercise.nome = exercise_data.nome
    exercise.gruppo_muscolare = exercise_data.gruppo_muscolare
    exercise.default_serie = exercise_data.default_serie
    exercise.default_ripetizioni = exercise_data.default_ripetizioni
    exercise.default_recupero_secondi = exercise_data.default_recupero_secondi
    exercise.default_note = exercise_data.default_note
    exercise.video_url = exercise_data.video_url
    db.commit()
    db.refresh(exercise)
    logger.info(f"Esercizio aggiornato: ID {exercise_id} → '{exercise.nome}'")
    return exercise


# ---------------------------------------------------------------------------
# DELETE /api/catalog/{exercise_id} - Rimuove un esercizio dal catalogo
# ---------------------------------------------------------------------------
@app.delete(
    "/api/catalog/{exercise_id}",
    response_model=schemas.MessageResponse,
    summary="Rimuove un esercizio dal catalogo",
    tags=["Catalogo Esercizi"],
)
def delete_exercise(exercise_id: int, db: Session = Depends(get_db),
                    current_user: models.User = Depends(get_current_user)):
    """
    Elimina un esercizio dal catalogo. Solo per ADMIN.
    """
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può modificare il catalogo.")
    exercise = db.query(models.ExerciseCatalog).filter(
        models.ExerciseCatalog.id == exercise_id
    ).first()
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Esercizio con ID {exercise_id} non trovato.",
        )

    nome = exercise.nome
    db.delete(exercise)
    db.commit()
    logger.info(f"Esercizio rimosso dal catalogo: '{nome}' (ID: {exercise_id})")
    return {"message": f"Esercizio '{nome}' rimosso dal catalogo con successo."}


# ===========================================================================
# ENDPOINT DI SISTEMA E IMPOSTAZIONI
# ===========================================================================

@app.get("/api/system/backup", summary="Scarica il database SQLite (Solo Admin)", tags=["Sistema"])
def download_database_backup(current_user: models.User = Depends(get_current_user)):
    """Restituisce il file fitness.db per backup."""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")
    
    db_path = "data/fitness.db"
    if not os.path.exists(db_path):
        raise HTTPException(status_code=404, detail="Database non trovato.")
    
    return FileResponse(path=db_path, filename="fitness.db", media_type="application/octet-stream")


@app.post("/api/system/restore", summary="Ripristina il database SQLite (Solo Admin)", tags=["Sistema"])
async def restore_database_backup(
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user)
):
    """
    Carica un file .db e sovrascrive il database attuale.
    Solo per ADMIN.
    """
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")
    
    # Validazione estensione
    if not file.filename.endswith(".db"):
        raise HTTPException(status_code=400, detail="Formato file non valido. Caricare un file .db")

    try:
        # Chiudi connessioni attive per evitare lock su Windows
        engine.dispose()
        
        db_path = "data/fitness.db"
        
        # Salvataggio del nuovo file
        with open(db_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        logger.info(f"Database RIPRISTINATO con successo da {current_user.email}")
        return {"message": "Database ripristinato con successo. L'applicazione userà ora il nuovo snapshot."}
    except Exception as e:
        logger.error(f"Errore durante il ripristino del database: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Errore durante il ripristino: {str(e)}")


@app.get("/api/system/models", response_model=list[schemas.AIModelResponse], summary="Ottieni modelli AI supportati (Whitelist)", tags=["Sistema"])
def get_supported_ai_models(current_user: models.User = Depends(get_current_user)):
    """Ritorna una lista curata di modelli AI supportati ufficialmente."""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")
    
    # Lista curata (Whitelist) decisa dall'Architect
    whitelist = [
        {"id": "gemini-2.5-flash", "name": "Gemini 2.5 Flash (Bilanciato e Veloce - Default)"},
        {"id": "gemini-2.5-pro", "name": "Gemini 2.5 Pro (Ragionamento Complesso)"},
        {"id": "gemini-2.5-flash-lite", "name": "Gemini 2.5 Flash-Lite (Ultra Veloce)"},
    ]
    return whitelist


@app.get("/api/system/settings", summary="Ottieni impostazioni di sistema", tags=["Sistema"])
def get_system_settings(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Restituisce le configurazioni attuali."""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")
    
    # Usa il service per recuperare la config (che ha già i fallback)
    _, ai_model = ai_service.get_ai_config(db)
    
    # Recupero manuale della chiave override per il form
    key_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "ai_api_key_override").first()
    
    return {
        "ai_model": ai_model,
        "ai_api_key_override": key_setting.value if key_setting else ""
    }


@app.put("/api/system/settings", summary="Aggiorna impostazioni di sistema", tags=["Sistema"])
def update_system_settings(data: schemas.SystemSettingsUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Aggiorna le configurazioni AI."""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")
        
    # Model
    model_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "ai_model").first()
    if not model_setting:
        model_setting = models.SystemSettings(key="ai_model", value=data.ai_model)
        db.add(model_setting)
    else:
        model_setting.value = data.ai_model
        
    # API Key Override
    key_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "ai_api_key_override").first()
    if data.ai_api_key_override:
        if not key_setting:
            key_setting = models.SystemSettings(key="ai_api_key_override", value=data.ai_api_key_override)
            db.add(key_setting)
        else:
            key_setting.value = data.ai_api_key_override
    else:
        # Se vuoto, cancella l'override dal DB
        if key_setting:
            db.delete(key_setting)

    db.commit()
    return {"message": "Impostazioni aggiornate con successo."}

# ===========================================================================
# Mount File Statici
# ===========================================================================

# ===========================================================================
# MISURAZIONI - Storicizzazione dati biometrici
# ===========================================================================

@app.post(
    "/api/measurements",
    response_model=schemas.MeasurementResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Salva una nuova misurazione fisica",
    tags=["Misure"],
)
def create_measurement(
    data: schemas.MeasurementCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Salva un nuovo set di misure (peso, petto, vita, ecc.) per l'utente loggato.
    Le misure non sovrascrivono le precedenti, permettendo di tracciare il trend.
    Richiede autenticazione JWT.
    """
    new_meas = models.Measurement(
        user_id=current_user.id,
        **data.model_dump()
    )
    db.add(new_meas)
    db.commit()
    db.refresh(new_meas)
    logger.info(f"Nuova misurazione salvata per l'utente {current_user.email} (ID: {new_meas.id})")
    return new_meas


# ---------------------------------------------------------------------------
# GET /api/admin/clients/{user_id}/progress - Dettaglio progressi cliente
# ---------------------------------------------------------------------------
@app.get(
    "/api/admin/clients/{user_id}/progress",
    response_model=schemas.UserProgressResponse,
    summary="Ottiene il progresso completo di un cliente",
    tags=["Utenti"],
)
def get_client_progress(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Restituisce i dati anagrafici, tutte le misurazioni storiche e l'ultima scheda.
    Solo se ADMIN o se il richiedente è l'utente stesso.
    """
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Accesso negato: non puoi visualizzare i progressi di altri utenti.")
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Cliente non trovato.")

    measurements = db.query(models.Measurement).filter(
        models.Measurement.user_id == user_id
    ).order_by(models.Measurement.created_at.asc()).all()

    last_plan_record = db.query(models.WorkoutPlan).filter(
        models.WorkoutPlan.user_id == user_id
    ).first()
    
    last_plan = None
    if last_plan_record:
        last_plan = json.loads(last_plan_record.plan_json)

    return {
        "user": user,
        "measurements": measurements,
        "last_plan": last_plan
    }


# ===========================================================================
# POST /api/analysis/generate - Analisi AI dei progressi (Report)
# ===========================================================================
@app.post(
    "/api/analysis/generate",
    summary="Genera un report di analisi dei progressi tramite AI",
    tags=["AI"],
)
def generate_athlete_analysis(
    model_name: Optional[str] = "gemini-2.5-flash",
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    Analizza lo storico biometrico dell'utente e restituisce un feedback
    tecnico e motivazionale generato dall'AI.
    """
    # 2. Generazione Analisi
    try:
        model = ai_service.get_model(db, model_override=model_name)
        prompt = ai_service.generate_athlete_analysis_prompt(current_user, db)
        
        response = model.generate_content(prompt)
        logger.info(f"Report analisi generato per utente ID {current_user.id}")
        return {"analysis": response.text}
    except Exception as e:
        logger.error(f"Errore generazione report AI: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Errore durante l'analisi AI: {str(e)}")


# ===========================================================================
# POST /api/ai/analyze - Endpoint Passthrough per AI (Zero-Trust)
# ===========================================================================
@app.post(
    "/api/ai/analyze",
    summary="Interroga Gemini in sicurezza (Passthrough)",
    tags=["AI"],
)
def ai_analyze_passthrough(
    request: schemas.AIAnalyzeRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    Riceve un prompt dal client autenticato, lo arricchisce e lo invia a Gemini.
    Zero-Trust: l'API Key non lascia mai il server.
    """
    # 1. Recupero Modello e Inizializzazione (Dinamico)
    try:
        model = ai_service.get_model(db, model_override=request.model_name if hasattr(request, 'model_name') else None)
        
        # Costruzione del prompt unendo testo e contesto
        full_prompt = f"{request.prompt_text}\n\nCONTESTO AGGIUNTIVO:\n{json.dumps(request.context_data, indent=2)}"
        
        # Chiamata a Gemini
        response = model.generate_content(full_prompt)
        
        logger.info(f"AI Passthrough: Richiesta completata per {current_user.email}")
        return {
            "status": "success",
            "analysis": response.text
        }
        
    except Exception as e:
        logger.error(f"Errore durante la chiamata a Gemini: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Errore AI Passthrough: {str(e)}")
# ===========================================================================
# API - Salvataggio Allenamento
# ===========================================================================

@app.post(
    "/api/workouts/save",
    response_model=schemas.WorkoutLogResponse,
    summary="Salva un allenamento completato",
    tags=["Allenamento"]
)
def save_workout(
    payload: schemas.WorkoutLogCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    Salva un allenamento completato nel database in modo persistente.
    Richiede autenticazione. Se l'utente non è admin, può salvare solo per se stesso.
    """
    if current_user.role != "admin" and current_user.id != payload.user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Non hai i permessi per salvare l'allenamento di un altro utente."
        )

    # Verifica esistenza utente target
    target_user = db.query(models.User).filter(models.User.id == payload.user_id).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="Utente non trovato.")

    # Converte la lista di dict in stringa JSON
    exercises_str = json.dumps(payload.exercises)

    new_log = models.WorkoutLog(
        user_id=payload.user_id,
        duration_seconds=payload.duration_seconds,
        exercises_json=exercises_str
    )

    db.add(new_log)
    db.commit()
    db.refresh(new_log)

    logger.info(f"Allenamento salvato per utente {payload.user_id} (Log ID: {new_log.id})")
    return schemas.WorkoutLogResponse.from_orm_log(new_log)



# ===========================================================================
# GET /api/workouts/suggestions/{user_id} — Progressive overload automatico
# ===========================================================================
@app.get(
    "/api/workouts/suggestions/{user_id}",
    summary="Suggerimenti progressive overload per ogni esercizio",
    tags=["Allenamento"],
)
def get_overload_suggestions(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Analizza le ultime 3 sessioni per ogni esercizio e restituisce:
    - il peso suggerito per la prossima sessione
    - il motivo (target raggiunto, sotto target, nessun dato)

    Regola: se nelle ultime 3 sessioni tutte le serie erano >= target reps
    con quel peso, suggerisce +2.5 kg. Altrimenti mantiene.
    """
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Accesso negato.")

    logs = db.query(models.WorkoutLog).filter(
        models.WorkoutLog.user_id == user_id
    ).order_by(models.WorkoutLog.date.desc()).limit(20).all()

    # Raggruppa le ultime 3 sessioni per esercizio
    exercise_sessions: dict[str, list[dict]] = {}
    for log in logs:
        try:
            exercises = json.loads(log.exercises_json)
        except Exception:
            continue
        for ex in exercises:
            name = ex.get("name", "")
            if not name:
                continue
            if name not in exercise_sessions:
                exercise_sessions[name] = []
            if len(exercise_sessions[name]) < 3:
                exercise_sessions[name].append(ex)

    suggestions = {}
    for ex_name, sessions in exercise_sessions.items():
        if not sessions:
            continue
        last_session = sessions[0]
        sets = last_session.get("sets", [])
        if not sets:
            suggestions[ex_name] = {"suggested_weight": None, "reason": "no_data"}
            continue

        last_weight = max((s.get("weight", 0) for s in sets), default=0)
        # Controlla se in tutte le sessioni disponibili le reps erano on-target
        all_on_target = True
        for session in sessions:
            for s in session.get("sets", []):
                target = s.get("targetReps", s.get("target_reps", 0))
                actual = s.get("reps", s.get("actualReps", 0))
                if target and actual and actual < target:
                    all_on_target = False
                    break

        if all_on_target and len(sessions) >= 2:
            suggested = round((last_weight + 2.5) * 2) / 2  # arrotonda a 0.5
            suggestions[ex_name] = {"suggested_weight": suggested, "reason": "target_reached", "last_weight": last_weight}
        else:
            suggestions[ex_name] = {"suggested_weight": last_weight, "reason": "maintain", "last_weight": last_weight}

    return {"suggestions": suggestions}


# ===========================================================================
# Mount File Statici - ULTIMO (Greedy catch-all)
# ===========================================================================
app.mount("/", StaticFiles(directory="static", html=True), name="static")

