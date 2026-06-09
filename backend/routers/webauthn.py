import os
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from typing import Any, Dict
import logging

import models
import auth as auth_utils
from auth import get_current_user
from database import get_db

from webauthn import (
    generate_registration_options,
    verify_registration_response,
    options_to_json,
    base64url_to_bytes,
    generate_authentication_options,
    verify_authentication_response,
)
from webauthn.helpers.structs import (
    RegistrationCredential,
    AuthenticationCredential,
    AuthenticatorSelectionCriteria,
    UserVerificationRequirement,
)

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/auth/webauthn",
    tags=["WebAuthn (Passkeys)"]
)

# In-memory challenge store (adatto per single-node app SQLite)
# Map: user_email -> challenge_string
RP_ID = os.getenv("RP_ID", "forgefit.ghome.it")
RP_NAME = "ForgeFit App"
ORIGIN = os.getenv("WEBAUTHN_ORIGIN", f"https://{RP_ID}")

registration_challenges: Dict[str, str] = {}
authentication_challenges: Dict[str, str] = {}


@router.get("/register/generate-options")
def get_registration_options(current_user: models.User = Depends(get_current_user)):
    """Genera le opzioni per registrare un nuovo Passkey (Autenticato)"""
    
    # Existing passkeys per evitare doppie registrazioni dello stesso authenticator
    exclude_credentials = []
    if current_user.passkeys:
        for pk in current_user.passkeys:
            exclude_credentials.append(
                {"id": base64url_to_bytes(pk.credential_id), "type": "public-key"}
            )

    options = generate_registration_options(
        rp_id=RP_ID,
        rp_name=RP_NAME,
        user_id=str(current_user.id).encode(),
        user_name=current_user.email,
        user_display_name=f"{current_user.first_name} {current_user.last_name}",
        exclude_credentials=exclude_credentials,
        authenticator_selection=AuthenticatorSelectionCriteria(
            user_verification=UserVerificationRequirement.PREFERRED
        ),
    )
    
    registration_challenges[current_user.email] = options.challenge
    return options_to_json(options)


@router.post("/register/verify")
def verify_registration(
    data: Dict[str, Any], 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    """Verifica e salva la registrazione del Passkey"""
    expected_challenge = registration_challenges.get(current_user.email)
    if not expected_challenge:
        raise HTTPException(status_code=400, detail="Challenge non trovato o scaduto.")
        
    try:
        credential = RegistrationCredential.parse_raw(data)
        
        verification = verify_registration_response(
            credential=credential,
            expected_challenge=base64url_to_bytes(expected_challenge),
            expected_origin=ORIGIN,
            expected_rp_id=RP_ID,
            require_user_verification=False,
        )
        
        # Salva a DB
        new_passkey = models.PasskeyCredential(
            credential_id=verification.credential_id.decode("utf-8") if isinstance(verification.credential_id, bytes) else str(verification.credential_id),
            user_id=current_user.id,
            public_key=verification.credential_public_key.hex() if isinstance(verification.credential_public_key, bytes) else str(verification.credential_public_key),
            sign_count=verification.sign_count,
            name="Passkey Dispositivo"
        )
        db.add(new_passkey)
        db.commit()
        
        # Pulisci la challenge
        del registration_challenges[current_user.email]
        
        return {"verified": True, "message": "Dispositivo registrato con successo"}
        
    except Exception as e:
        logger.error(f"Errore verifica webauthn: {e}")
        raise HTTPException(status_code=400, detail=f"Registrazione fallita: {str(e)}")


@router.get("/login/generate-options")
def get_login_options(email: str, db: Session = Depends(get_db)):
    """Genera le opzioni per il login con Passkey. Richiede l'email dell'utente."""
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        # Prevent user enumeration, returns empty options or a dummy challenge
        raise HTTPException(status_code=404, detail="Utente non trovato")

    if not user.passkeys:
        raise HTTPException(status_code=400, detail="Nessun passkey registrato per questo utente.")

    allow_credentials = []
    for pk in user.passkeys:
        allow_credentials.append(
            {"id": base64url_to_bytes(pk.credential_id), "type": "public-key"}
        )

    options = generate_authentication_options(
        rp_id=RP_ID,
        allow_credentials=allow_credentials,
        user_verification=UserVerificationRequirement.PREFERRED,
    )
    
    authentication_challenges[user.email] = options.challenge
    return options_to_json(options)


@router.post("/login/verify")
def verify_login(
    email: str,
    data: Dict[str, Any], 
    db: Session = Depends(get_db)
):
    """Verifica il payload di login WebAuthn ed emette i JWT."""
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=401, detail="Credenziali non valide")
        
    expected_challenge = authentication_challenges.get(user.email)
    if not expected_challenge:
        raise HTTPException(status_code=400, detail="Challenge non trovato o scaduto.")
        
    try:
        credential = AuthenticationCredential.parse_raw(data)
        
        # Trova la chiave corrispondente
        passkey = next((pk for pk in user.passkeys if pk.credential_id == credential.id), None)
        if not passkey:
            raise HTTPException(status_code=401, detail="Passkey sconosciuto")

        verification = verify_authentication_response(
            credential=credential,
            expected_challenge=base64url_to_bytes(expected_challenge),
            expected_origin=ORIGIN,
            expected_rp_id=RP_ID,
            credential_public_key=bytes.fromhex(passkey.public_key) if isinstance(passkey.public_key, str) else passkey.public_key,
            credential_current_sign_count=passkey.sign_count,
            require_user_verification=False,
        )
        
        # Update sign count
        passkey.sign_count = verification.new_sign_count
        db.commit()
        
        # Pulisci
        del authentication_challenges[user.email]
        
        # Genera JWT Token
        token = auth_utils.create_access_token(subject=user.email)
        refresh = auth_utils.create_refresh_token(subject=user.email)
        
        logger.info(f"Login WebAuthn riuscito per: {user.email}")
        
        import schemas
        return schemas.TokenResponse(
            access_token=token,
            refresh_token=refresh,
            role=user.role,
            user_id=user.id,
            version="1.3.0",
            user=schemas.UserResponse.model_validate(user)
        )
        
    except Exception as e:
        logger.error(f"Errore login webauthn: {e}")
        raise HTTPException(status_code=401, detail=f"Login fallito: {str(e)}")
