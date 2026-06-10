# ai_service.py
# Modulo per l'integrazione con l'AI (Gemini Flash).
# Gestisce la generazione dei prompt, l'analisi dei trend biometrici e l'interazione con Google Generative AI.

import os
import logging
import google.generativeai as genai
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional, Tuple
import models

logger = logging.getLogger(__name__)

def get_ai_config(db: Session) -> Tuple[str, str]:
    """
    Recupera le configurazioni AI salvate nel DB, oppure usa i fallback di sistema.
    Restituisce (api_key, model_name).
    """
    model_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "ai_model").first()
    key_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "ai_api_key_override").first()
    
    # Fallback sicuro: gemini-2.5-flash
    ai_model = model_setting.value if model_setting and model_setting.value else "gemini-2.5-flash"
    api_key_override = key_setting.value if key_setting and key_setting.value else None
    
    api_key = api_key_override or os.getenv("GOOGLE_API_KEY")
    return api_key, ai_model

def get_model(db: Session, model_override: Optional[str] = None) -> genai.GenerativeModel:
    """
    Inizializza e restituisce un'istanza del modello Gemini configurata dinamicamente.
    Utilizza l'API Key configurata (override o env) e il modello specificato (o default).
    """
    api_key, db_model = get_ai_config(db)
    
    if not api_key:
        logger.error("Configurazione AI mancante: API Key non trovata.")
        raise ValueError("Configurazione AI incompleta: inserire una chiave API valida.")

    # Configurazione globale di Google AI
    genai.configure(api_key=api_key)
    
    # Priorità: model_override (dal client) > db_model (dalle impostazioni) > fallback
    selected_model = model_override if model_override else db_model
    
    logger.info(f"AI Service: Inizializzazione modello '{selected_model}'")
    
    try:
        return genai.GenerativeModel(selected_model)
    except Exception as e:
        logger.error(f"Errore durante l'inizializzazione del modello {selected_model}: {e}")
        # Fallback estremo se il modello selezionato fallisce (es. 404)
        if selected_model != "gemini-2.5-flash":
            logger.warning("Tentativo di fallback su gemini-2.5-flash")
            return genai.GenerativeModel("gemini-2.5-flash")
        raise

def generate_athlete_analysis_prompt(user: models.User, db: Session) -> str:
    """
    Genera un prompt dettagliato per l'AI includendo i dati biometrici attuali
    e lo storico delle ultime 5 misurazioni per l'analisi del trend.
    """
    history = db.query(models.Measurement).filter(
        models.Measurement.user_id == user.id
    ).order_by(models.Measurement.created_at.desc()).limit(5).all()

    prompt = f"Sei un Personal Trainer esperto e un analista di dati sportivi.\n"
    prompt += f"Analizza il profilo dell'atleta: {user.first_name} {user.last_name}\n"
    prompt += f"Profilo base: Età {user.age}, Sesso {user.gender or 'Non specificato'}\n\n"

    if history:
        prompt += "--- STORICO PROGRESSI DELL'ATLETA (Ultime 5 misurazioni) ---\n"
        for m in reversed(history):
            date_str = m.created_at.strftime("%d/%m/%Y")
            prompt += (f"- DATA: {date_str} | PESO: {m.weight}kg | "
                       f"PETTO: {m.chest}cm | VITA: {m.waist}cm | "
                       f"FIANCHI: {m.hips}cm | BICIPITE: {m.biceps}cm | "
                       f"COSCIA: {m.thigh}cm | POLPACCIO: {m.calf}cm | OBIETTIVO: {m.goal or 'N/D'}\n")
        prompt += "--------------------------------------------------------\n\n"
    else:
        prompt += "Nota: Non sono ancora presenti misurazioni storiche nel database per questo atleta.\n\n"

    prompt += (
        "In base allo storico sopra riportato, identifica il trend (es. perdita di grasso addominale, "
        "aumento massa muscolare, stasi del peso) e genera un breve report tecnico e motivazionale. "
        "Suggerisci se mantenere l'attuale intensità o apportare modifiche al volume di allenamento."
    )
    
    return prompt
