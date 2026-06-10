from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
import os
import shutil
import models
import schemas
from database import engine, get_db
from auth import get_current_user
import ai_service
import logging

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/system",
    tags=["Sistema"]
)

@router.get("/backup", summary="Scarica il database SQLite (Solo Admin)")
def download_database_backup(current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")
    
    db_path = "data/fitness.db"
    if not os.path.exists(db_path):
        raise HTTPException(status_code=404, detail="Database non trovato.")
    
    return FileResponse(path=db_path, filename="fitness.db", media_type="application/octet-stream")


@router.post("/restore", summary="Ripristina il database SQLite (Solo Admin)")
async def restore_database_backup(
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")
    
    if not file.filename.endswith(".db"):
        raise HTTPException(status_code=400, detail="Formato file non valido. Caricare un file .db")

    try:
        engine.dispose()
        db_path = "data/fitness.db"
        with open(db_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        logger.info(f"Database RIPRISTINATO con successo da {current_user.email}")
        return {"message": "Database ripristinato con successo. L'applicazione userà ora il nuovo snapshot."}
    except Exception as e:
        logger.error(f"Errore durante il ripristino del database: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Errore durante il ripristino: {str(e)}")


@router.get("/models", response_model=list[schemas.AIModelResponse], summary="Ottieni modelli AI supportati (Whitelist)")
def get_supported_ai_models(current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")
    
    whitelist = [
        {"id": "gemini-2.5-flash", "name": "Gemini 2.5 Flash (Affidabile ed Economico - Default)"},
        {"id": "gemini-3.5-flash", "name": "Gemini 3.5 Flash (Bilanciato e Veloce)"},
        {"id": "gemini-3.5-pro", "name": "Gemini 3.5 Pro (Ragionamento Complesso)"},
        {"id": "gemini-3.5-flash-lite", "name": "Gemini 3.5 Flash-Lite (Ultra Veloce)"},
    ]
    return whitelist


@router.get("/settings", summary="Ottieni impostazioni di sistema")
def get_system_settings(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permesso negato.")
    
    _, ai_model = ai_service.get_ai_config(db)
    key_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "ai_api_key_override").first()
    
    return {
        "ai_model": ai_model,
        "ai_api_key_override": key_setting.value if key_setting else ""
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
    if data.ai_api_key_override:
        if not key_setting:
            key_setting = models.SystemSettings(key="ai_api_key_override", value=data.ai_api_key_override)
            db.add(key_setting)
        else:
            key_setting.value = data.ai_api_key_override
    else:
        if key_setting:
            db.delete(key_setting)

    db.commit()
    return {"message": "Impostazioni aggiornate con successo."}
