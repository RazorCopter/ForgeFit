# auth.py
# Modulo centralizzato per l'autenticazione:
#   - Hashing / verifica password con bcrypt (passlib)
#   - Generazione / decodifica JWT con PyJWT
#
# ⚠️  In produzione, SECRET_KEY va letto da variabile d'ambiente.

import jwt
from datetime import datetime, timedelta, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from database import get_db
import models

import os
from dotenv import load_dotenv
import config_manager

load_dotenv()

# ---------------------------------------------------------------------------
# Configurazione
# ---------------------------------------------------------------------------
SECRET_KEY = os.getenv("JWT_SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError(
        "JWT_SECRET_KEY non impostata. "
        "Aggiungila al file .env o alle variabili d'ambiente prima di avviare il server."
    )
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 14
REFRESH_TOKEN_EXPIRE_DAYS = 30

# Schema HTTP Bearer per l'estrazione del token dall'header Authorization
bearer_scheme = HTTPBearer(auto_error=True)

# Contesto passlib per bcrypt
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ---------------------------------------------------------------------------
# Password utilities
# ---------------------------------------------------------------------------

def hash_password(password: str) -> str:
    """Restituisce l'hash bcrypt della password in chiaro."""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifica che la password in chiaro corrisponda all'hash salvato."""
    return pwd_context.verify(plain_password, hashed_password)


# ---------------------------------------------------------------------------
# JWT utilities
# ---------------------------------------------------------------------------

def create_access_token(subject: str) -> str:
    """Genera un access JWT con scadenza 7 giorni."""
    expire = datetime.now(timezone.utc) + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
    payload = {"sub": subject, "exp": expire, "type": "access"}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(subject: str) -> str:
    """Genera un refresh JWT con scadenza 30 giorni."""
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {"sub": subject, "exp": expire, "type": "refresh"}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_refresh_token(token: str) -> str:
    """
    Decodifica un refresh token e restituisce il subject (email).
    Solleva HTTPException 401 se il token è scaduto, non valido, o non è di tipo refresh.
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token non è un refresh token.")
        subject: str = payload.get("sub")
        if not subject:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token malformato.")
        return subject
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token scaduto. Effettua nuovamente il login.")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token non valido.")


def decode_token(token: str) -> dict:
    """
    Decodifica e verifica il JWT.
    Solleva HTTPException 401 se il token è scaduto, non valido,
    o non è un access token (impedisce l'uso di refresh token come access).
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "access":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token non valido: tipo errato.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token scaduto. Effettua nuovamente il login.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token non valido.",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ---------------------------------------------------------------------------
# Dipendenza FastAPI: get_current_user
# ---------------------------------------------------------------------------

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> models.User:
    """
    Dipendenza FastAPI per proteggere gli endpoint.
    Legge il token dall'header 'Authorization: Bearer <token>',
    lo decodifica e restituisce l'utente autenticato dal database.
    Solleva 401 se il token è assente, scaduto o non valido.
    Solleva 404 se l'utente nel token non esiste più nel DB.
    """
    payload = decode_token(credentials.credentials)
    email: str = payload.get("sub")
    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token malformato: subject mancante.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 1. Controlla se è l'Admin configurato nel file
    admin_config = config_manager.get_admin_config()
    if admin_config and admin_config.get("username") == email:
        # Restituiamo un oggetto "finto" models.User per l'admin configurato
        return models.User(
            id=0,
            email=admin_config["username"],
            first_name=admin_config["pt_name"],
            last_name="PT",
            age=30,  # Età placeholder per l'admin
            role="admin",
            hashed_password=admin_config["hashed_password"]
        )

    # 2. Altrimenti cerca nel database (Clienti)
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Utente del token non trovato nel sistema.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user
