from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from fastapi.responses import FileResponse, StreamingResponse
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

    content = await file.read()

    # Verifica magic bytes SQLite: "SQLite format 3\x00"
    SQLITE_MAGIC = b"SQLite format 3\x00"
    if not content.startswith(SQLITE_MAGIC):
        raise HTTPException(status_code=400, detail="File non valido: non è un database SQLite.")

    # Scrivi su file temporaneo e verifica integrità prima di sovrascrivere
    db_path = str(Path(__file__).parent.parent / "data" / "fitness.db")
    tmp_path: str | None = None
    try:
        fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(db_path), suffix=".tmp")
        with os.fdopen(fd, "wb") as f:
            f.write(content)

        conn = sqlite3.connect(tmp_path)
        try:
            conn.execute("PRAGMA integrity_check")
        finally:
            conn.close()

        # Swap atomico: sovrascrive il DB live solo se il file è integro
        engine.dispose()
        os.replace(tmp_path, db_path)
        tmp_path = None

        logger.info(f"Database RIPRISTINATO con successo da {current_user.email}")
        return {"message": "Database ripristinato con successo. L'applicazione userà ora il nuovo snapshot."}
    except sqlite3.DatabaseError as e:
        raise HTTPException(status_code=400, detail=f"Database caricato corrotto: {e}")
    except Exception as e:
        logger.error(f"Errore durante il ripristino del database: {e}")
        raise HTTPException(status_code=500, detail=f"Errore durante il ripristino: {e}")
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)


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
