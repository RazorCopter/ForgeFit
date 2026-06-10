# main.py
# Entry point dell'applicazione FastAPI.
# Configura CORS, monta i file statici e definisce tutti gli endpoint REST.

import csv
import io
import json
import logging
import os
import shutil
from contextlib import asynccontextmanager
import google.generativeai as genai
from typing import Optional
from dotenv import load_dotenv
import ai_service
import config_manager
from version import APP_VERSION

load_dotenv() # Carica variabili da .env

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from limiter import limiter

# Import dei modelli per la registrazione dei metadati di SQLAlchemy
import models
import schemas
import auth
from auth import get_current_user
from database import engine, get_db
from routers import measurements, auth as auth_router, plans, workouts, users, catalog, system, ai, admin


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
        count = db.query(models.ExerciseCatalog).count()

        esercizi = [
            # ----------------------------------------------------------------
            # PETTO
            # ----------------------------------------------------------------
            models.ExerciseCatalog(
                nome="Panca Piana Bilanciere", gruppo_muscolare="Petto",
                default_serie=4, default_ripetizioni="8-10", default_recupero_secondi=120,
                default_note="Scapole depresse e addotte.",
                video_url="https://www.youtube.com/watch?v=nclAIgM4NJE"
            ),
            models.ExerciseCatalog(
                nome="Spinte Panca Inclinata Manubri", gruppo_muscolare="Petto",
                default_serie=4, default_ripetizioni="10-12", default_recupero_secondi=90,
                default_note="Massimo allungamento al petto.",
                video_url="https://www.youtube.com/watch?v=Hujpl-ujRtg"
            ),
            models.ExerciseCatalog(
                nome="Croci ai Cavi dall'alto", gruppo_muscolare="Petto",
                default_serie=3, default_ripetizioni="12-15", default_recupero_secondi=60,
                default_note="Focus sulla contrazione di picco, strizzare in chiusura.",
                video_url="https://www.youtube.com/watch?v=-kZ5A7aPiCw"
            ),
            models.ExerciseCatalog(
                nome="Croci ai Cavi dal basso", gruppo_muscolare="Petto",
                default_serie=3, default_ripetizioni="12-15", default_recupero_secondi=60,
                default_note="Movimento dal basso verso l'alto, focus petto alto.",
                video_url="https://www.youtube.com/watch?v=jzKDCuJVLjo"
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
                video_url="https://www.youtube.com/watch?v=dYF2d_I24uE"
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
                video_url="https://www.youtube.com/watch?v=1e-Ks7gpp44"
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
                video_url="https://www.youtube.com/watch?v=e2Waz_LKmNQ"
            ),
            models.ExerciseCatalog(
                nome="Arnold Press Manubri", gruppo_muscolare="Spalle",
                default_serie=3, default_ripetizioni="10-12", default_recupero_secondi=90,
                default_note="Rotazione fluida dei polsi durante la spinta.",
                video_url="https://www.youtube.com/watch?v=hyLSswC97MA"
            ),
            models.ExerciseCatalog(
                nome="Alzate Laterali Manubri", gruppo_muscolare="Spalle",
                default_serie=4, default_ripetizioni="15", default_recupero_secondi=60,
                default_note="Mignolo leggermente ruotato verso l'alto, braccia non completamente tese.",
                video_url="https://www.youtube.com/watch?v=PhFOzmpjUak"
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
                video_url="https://www.youtube.com/watch?v=0Po47vvj9g4"
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
                video_url="https://www.youtube.com/watch?v=RhVdFHcHKDE"
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
                video_url="https://www.youtube.com/watch?v=FANzZyWdmbs"
            ),
            models.ExerciseCatalog(
                nome="Pushdown Tricipiti ai cavi con corda", gruppo_muscolare="Braccia",
                default_serie=3, default_ripetizioni="12-15", default_recupero_secondi=60,
                default_note="Aprire la corda in chiusura.",
                video_url="https://www.youtube.com/watch?v=vdwP7HxDAo4"
            ),
            models.ExerciseCatalog(
                nome="Estensioni dietro nuca al cavo", gruppo_muscolare="Braccia",
                default_serie=3, default_ripetizioni="12", default_recupero_secondi=60,
                default_note="Focus sull'allungamento del capo lungo del tricipite.",
                video_url="https://www.youtube.com/shorts/U5Fi0VQpzmc"
            ),
            # ----------------------------------------------------------------
            # CORE E ACCESSORI
            # ----------------------------------------------------------------
            models.ExerciseCatalog(
                nome="Crunch al cavo inginocchiato", gruppo_muscolare="Core",
                default_serie=3, default_ripetizioni="15", default_recupero_secondi=60,
                default_note="Flettere la colonna, non usare le anche.",
                video_url="https://www.youtube.com/watch?v=um0ZlKz30KQv"
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

        if count == 0:
            logger.info("Tabella ExerciseCatalog vuota — avvio seeding catalogo...")
            db.add_all(esercizi)
            db.commit()
            logger.info(f"Seeding completato: {len(esercizi)} esercizi inseriti nel catalogo.")
        else:
            # Aggiornamento dei record esistenti (per video_url e altri default)
            for ex in esercizi:
                db_ex = db.query(models.ExerciseCatalog).filter(models.ExerciseCatalog.nome == ex.nome).first()
                if db_ex:
                    if ex.video_url and not db_ex.video_url:
                        db_ex.video_url = ex.video_url
                else:
                    db.add(ex)
            db.commit()
            logger.info("Catalogo esercizi aggiornato con successo.")


    except Exception as exc:
        db.rollback()
        logger.error(f"Errore durante il seeding del catalogo: {exc}", exc_info=True)
        raise
    finally:
        db.close()


# seed_admin è stata rimossa per favorire il setup iniziale dinamico.


# Il seeding è stato spostato nell'evento 'startup' dell'app.

# ---------------------------------------------------------------------------
# Lifespan — startup/shutdown dell'applicazione
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(_app: FastAPI):
    logger.info("Inizializzazione database in corso...")
    models.Base.metadata.create_all(bind=engine)
    
    # Esegui migrazione manuale per aggiungere la colonna title se non esiste
    try:
        import sqlite3
        conn = sqlite3.connect("./data/fitness.db")
        conn.execute("ALTER TABLE workout_logs ADD COLUMN title VARCHAR")
        conn.commit()
        conn.close()
        logger.info("Colonna 'title' aggiunta a workout_logs con successo (migrazione).")
    except Exception as e:
        # Se la colonna esiste già o c'è un altro errore, ignoriamo
        pass

    seed_catalog()
    if not config_manager.is_admin_configured():
        logger.warning("ATTENZIONE: Personal Trainer non configurato. Effettuare il setup iniziale dalla dashboard.")
    else:
        logger.info("Personal Trainer configurato correttamente.")
    logger.info("Inizializzazione completata con successo.")
    yield


# ---------------------------------------------------------------------------
# Istanza FastAPI
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Forge Fit API",
    description="Backend per la gestione di utenti, schede di allenamento e catalogo esercizi.",
    version=APP_VERSION,
    lifespan=lifespan,
)

# Collega il limiter (istanza condivisa da limiter.py) all'app
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.include_router(auth_router.router)
app.include_router(plans.router)
app.include_router(workouts.router)

app.include_router(users.router)
app.include_router(catalog.router)
app.include_router(system.router)
app.include_router(ai.router)
app.include_router(measurements.router)
app.include_router(admin.router, prefix="/api/admin", tags=["admin"])

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
    allow_origin_regex=".*",
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


# CRUD MISURAZIONI sono stati spostati nel router measurements.


# ---------------------------------------------------------------------------
# Gli endpoint di Autenticazione (register, login, setup, ecc.)
# sono stati spostati in routers/auth.py
# ---------------------------------------------------------------------------


# ===========================================================================
# Mount File Statici - ULTIMO (Greedy catch-all)
# ===========================================================================
app.mount("/", StaticFiles(directory="static", html=True), name="static")

