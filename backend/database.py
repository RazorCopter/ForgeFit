# database.py
# Configurazione del database SQLite tramite SQLAlchemy.
# Questo modulo espone il motore (engine), la sessione e la classe base per i modelli.

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
import os

# URL del database SQLite locale.
# Il file fitness.db verrà creato nella stessa cartella del progetto.
SQLALCHEMY_DATABASE_URL = "sqlite:///./data/fitness.db"

# Assicura che la directory /data esista
os.makedirs("data", exist_ok=True)

# Creazione del motore SQLAlchemy.
# connect_args={"check_same_thread": False} è necessario solo per SQLite
# perché di default SQLite permette una sola connessione per thread.
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False}
)

# SessionLocal è la factory per le sessioni di database.
# autocommit=False e autoflush=False garantiscono il controllo manuale delle transazioni.
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base è la classe padre da cui ereditano tutti i modelli SQLAlchemy.
# Utilizziamo la sintassi moderna (SQLAlchemy 2.0) con classe ereditata.
class Base(DeclarativeBase):
    pass


# Dependency per FastAPI: fornisce una sessione DB per ogni request e la chiude dopo.
def get_db():
    """
    Generator che crea una sessione DB per ogni richiesta HTTP.
    Viene usato come dipendenza iniettata nei route handlers tramite Depends().
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
