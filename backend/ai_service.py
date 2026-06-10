# ai_service.py
# Modulo per l'integrazione con l'AI (Gemini Flash e DeepSeek).
# Gestisce la generazione dei prompt, l'analisi dei trend biometrici e l'interazione unificata.

import os
import logging
import google.generativeai as genai
import openai
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional, Tuple, Generator
import models

logger = logging.getLogger(__name__)

class UnifiedAIModel:
    """Wrapper astratto per chiamare in modo trasparente Gemini o DeepSeek."""
    def __init__(self, provider: str, model_name: str, api_key: str):
        self.provider = provider
        self.model_name = model_name
        self.api_key = api_key
        
        if self.provider == "gemini":
            genai.configure(api_key=self.api_key)
            self.client = genai.GenerativeModel(self.model_name)
        elif self.provider == "deepseek":
            self.client = openai.OpenAI(
                api_key=self.api_key,
                base_url="https://api.deepseek.com/v1"
            )

    def generate_content(self, prompt: str, generation_config=None, stream: bool = False):
        if self.provider == "gemini":
            kwargs = {"stream": stream}
            if generation_config:
                kwargs["generation_config"] = generation_config
            response = self.client.generate_content(prompt, **kwargs)
            return response
            
        elif self.provider == "deepseek":
            # Convertiamo il generation_config in params per openai
            response_format = {"type": "text"}
            if generation_config and hasattr(generation_config, 'response_mime_type'):
                if generation_config.response_mime_type == "application/json":
                    response_format = {"type": "json_object"}
                    # DeepSeek requires "json" to be in the prompt if using json_object
                    if "json" not in prompt.lower():
                        prompt += "\nOutput in JSON format."

            response = self.client.chat.completions.create(
                model=self.model_name,
                messages=[{"role": "user", "content": prompt}],
                stream=stream,
                response_format=response_format
            )

            if stream:
                # Creiamo un generatore fittizio che simula chunk.text
                class ChunkMock:
                    def __init__(self, text):
                        self.text = text
                        
                def iter_stream():
                    for chunk in response:
                        if chunk.choices and len(chunk.choices) > 0:
                            content = chunk.choices[0].delta.content
                            if content:
                                yield ChunkMock(content)
                return iter_stream()
            else:
                class ResponseMock:
                    def __init__(self, text):
                        self.text = text
                return ResponseMock(response.choices[0].message.content)

def get_ai_config(db: Session) -> Tuple[str, str, str]:
    """
    Recupera le configurazioni AI salvate nel DB, oppure usa i fallback di sistema.
    Restituisce (api_key, model_name, deepseek_api_key).
    """
    model_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "ai_model").first()
    key_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "ai_api_key_override").first()
    deepseek_setting = db.query(models.SystemSettings).filter(models.SystemSettings.key == "deepseek_api_key_override").first()
    
    # Fallback sicuro: gemini-2.5-flash
    ai_model = model_setting.value if model_setting and model_setting.value else "gemini-2.5-flash"
    api_key_override = key_setting.value if key_setting and key_setting.value else None
    deepseek_api_key_override = deepseek_setting.value if deepseek_setting and deepseek_setting.value else None
    
    api_key = api_key_override or os.getenv("GOOGLE_API_KEY")
    deepseek_api_key = deepseek_api_key_override or os.getenv("DEEPSEEK_API_KEY")
    
    return api_key, ai_model, deepseek_api_key

def get_model(db: Session, model_override: Optional[str] = None) -> UnifiedAIModel:
    """
    Inizializza e restituisce un'istanza unificata del modello (Gemini o DeepSeek).
    """
    api_key, db_model, deepseek_api_key = get_ai_config(db)
    
    selected_model = model_override if model_override else db_model
    
    logger.info(f"AI Service: Inizializzazione modello '{selected_model}'")
    
    if selected_model.startswith("deepseek-"):
        if not deepseek_api_key:
            logger.error("Configurazione AI mancante: API Key DeepSeek non trovata.")
            raise ValueError("Configurazione AI incompleta: inserire una chiave API DeepSeek valida.")
        return UnifiedAIModel(provider="deepseek", model_name=selected_model, api_key=deepseek_api_key)
    else:
        if not api_key:
            logger.error("Configurazione AI mancante: API Key Gemini non trovata.")
            raise ValueError("Configurazione AI incompleta: inserire una chiave API Google valida.")
        
        try:
            return UnifiedAIModel(provider="gemini", model_name=selected_model, api_key=api_key)
        except Exception as e:
            logger.error(f"Errore durante l'inizializzazione del modello {selected_model}: {e}")
            if selected_model != "gemini-2.5-flash":
                logger.warning("Tentativo di fallback su gemini-2.5-flash")
                return UnifiedAIModel(provider="gemini", model_name="gemini-2.5-flash", api_key=api_key)
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
