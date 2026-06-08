from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
import models
import schemas
import auth as auth_utils
from auth import get_current_user
from database import get_db
import config_manager
import logging

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/auth",
    tags=["Autenticazione"]
)


@router.post(
    "/register",
    response_model=schemas.UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registra un account con password",
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
        hashed_password=auth_utils.hash_password(data.password),
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

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

    logger.info(f"Nuovo account creato da app: {new_user.email} (ID: {new_user.id})")
    return new_user


@router.post(
    "/login",
    response_model=schemas.TokenResponse,
    summary="Login e ottenimento JWT",
)
def auth_login(data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """
    Verifica email (username) e password, restituisce un JWT valido 7 giorni.
    """
    admin_config = config_manager.get_admin_config()
    if admin_config and admin_config.get("username") == data.username:
        if auth_utils.verify_password(data.password, admin_config["hashed_password"]):
            token = auth_utils.create_access_token(subject=data.username)
            refresh = auth_utils.create_refresh_token(subject=data.username)
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

    user = db.query(models.User).filter(models.User.email == data.username).first()
    if not user or not user.hashed_password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenziali non valide.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not auth_utils.verify_password(data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenziali non valide.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = auth_utils.create_access_token(subject=user.email)
    refresh = auth_utils.create_refresh_token(subject=user.email)
    logger.info(f"Login cliente riuscito: {user.email} (Ruolo: {user.role})")
    return schemas.TokenResponse(
        access_token=token,
        refresh_token=refresh,
        role=user.role,
        user_id=user.id,
        version="1.1.8",
        user=schemas.UserResponse.model_validate(user)
    )


@router.get(
    "/setup-status",
    response_model=schemas.SetupStatusResponse,
    summary="Verifica se il PT è già configurato",
)
def get_setup_status():
    """Restituisce true se il file admin_config.json esiste."""
    return {"is_configured": config_manager.is_admin_configured()}


@router.post(
    "/setup",
    response_model=schemas.MessageResponse,
    summary="Configurazione iniziale del Personal Trainer",
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

    hashed = auth_utils.hash_password(data.password)
    success = config_manager.save_admin_config(
        pt_name=data.pt_name,
        username=data.username,
        hashed_password=hashed
    )
    
    if not success:
        raise HTTPException(status_code=500, detail="Errore durante il salvataggio della configurazione.")
    
    logger.info(f"Setup iniziale completato. PT: {data.pt_name} ({data.username})")
    return {"message": "Configurazione completata con successo. Ora puoi accedere."}


@router.put(
    "/change-password",
    response_model=schemas.MessageResponse,
    summary="Cambia la password dell'utente autenticato",
)
def change_password(
    data: schemas.ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if not auth_utils.verify_password(data.vecchia_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La vecchia password non è corretta.",
        )

    current_user.hashed_password = auth_utils.hash_password(data.nuova_password)
    db.commit()
    logger.info(f"Password aggiornata per: {current_user.email}")
    return {"message": "Password aggiornata con successo."}


@router.post(
    "/refresh",
    response_model=schemas.RefreshTokenResponse,
    summary="Rinnova l'access token usando il refresh token",
)
def refresh_access_token(data: schemas.RefreshTokenRequest, db: Session = Depends(get_db)):
    subject = auth_utils.decode_refresh_token(data.refresh_token)

    admin_config = config_manager.get_admin_config()
    if not (admin_config and admin_config.get("username") == subject):
        user = db.query(models.User).filter(models.User.email == subject).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Utente non trovato.")

    new_token = auth_utils.create_access_token(subject=subject)
    logger.info(f"Access token rinnovato per: {subject}")
    return schemas.RefreshTokenResponse(access_token=new_token)


@router.get(
    "/me",
    response_model=schemas.UserResponse,
    summary="Recupera il profilo dell'utente loggato",
)
def get_me(current_user: models.User = Depends(get_current_user)):
    return current_user


@router.post(
    "/unlock-ai",
    response_model=schemas.UnlockAIResponse,
    summary="Verifica il codice di sblocco funzionalità AI",
)
def unlock_ai(
    data: schemas.UnlockAIRequest,
    current_user: models.User = Depends(get_current_user),
):
    import hmac
    import hashlib
    from datetime import datetime, timezone, timedelta
    from auth import SECRET_KEY

    now = datetime.now(timezone.utc)
    iso_year, iso_week, _ = now.isocalendar()
    message = f"{iso_year}-W{iso_week:02d}".encode()
    expected_code = hmac.new(SECRET_KEY.encode(), message, hashlib.sha256).hexdigest()[:8]

    if not hmac.compare_digest(data.code.strip().lower(), expected_code):
        logger.info(f"Codice AI non valido per utente {current_user.email} (settimana {iso_year}-W{iso_week:02d})")
        return schemas.UnlockAIResponse(valid=False)

    days_until_sunday = 6 - now.weekday()
    if days_until_sunday < 0:
        days_until_sunday = 0
    expires = (now + timedelta(days=days_until_sunday)).replace(
        hour=23, minute=59, second=59, microsecond=0
    )

    logger.info(f"Sblocco AI concesso a {current_user.email} fino a {expires.isoformat()}")
    return schemas.UnlockAIResponse(valid=True, expires_at=expires.isoformat())


@router.get(
    "/ai-unlock-code",
    summary="Restituisce il codice di sblocco AI della settimana corrente (Solo Admin)",
)
def get_ai_unlock_code(current_user: models.User = Depends(get_current_user)):
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
