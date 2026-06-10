# schemas.py
# Modelli Pydantic per la validazione dei dati in ingresso (request) e in uscita (response).
# Separati dai modelli SQLAlchemy per mantenere il disaccoppiamento tra DB e API layer.

from pydantic import BaseModel, EmailStr, Field, AliasChoices
from typing import Optional, Any
from version import APP_VERSION


# ---------------------------------------------------------------------------
# Schemi per l'utente (User)
# ---------------------------------------------------------------------------

class UserCreate(BaseModel):
    """
    Schema per la registrazione di un nuovo utente (POST /api/register).
    Tutti i campi biometrici sono opzionali per permettere registrazioni parziali.
    """
    email: EmailStr = Field(..., description="Email univoca dell'utente")
    first_name: str = Field(..., min_length=1, validation_alias="nome")
    last_name: str = Field(..., min_length=1, validation_alias="cognome")
    age: int = Field(..., ge=1, le=120, validation_alias="eta")

    # Misurazioni biometriche opzionali (in kg e cm)
    weight: Optional[float] = Field(None, gt=0, validation_alias=AliasChoices("weight", "peso"))
    height: Optional[float] = Field(None, gt=0, validation_alias=AliasChoices("height", "altezza"))
    biceps: Optional[float] = Field(None, gt=0, validation_alias=AliasChoices("biceps", "bicipite"))
    chest: Optional[float] = Field(None, gt=0, validation_alias=AliasChoices("chest", "petto"))
    hips: Optional[float] = Field(None, gt=0, validation_alias=AliasChoices("hips", "fianchi"))
    waist: Optional[float] = Field(None, gt=0, validation_alias=AliasChoices("waist", "vita"))
    thigh: Optional[float] = Field(None, gt=0, validation_alias=AliasChoices("thigh", "coscia"))
    calf: Optional[float] = Field(None, gt=0, validation_alias=AliasChoices("calf", "polpaccio"))
    neck: Optional[float] = Field(None, gt=0, validation_alias=AliasChoices("neck", "collo"))
    wrist: Optional[float] = Field(None, gt=0, validation_alias=AliasChoices("wrist", "polso"))
    gender: Optional[str] = Field(None, validation_alias=AliasChoices("gender", "sesso"))
    password: Optional[str] = Field(None)


class UserResponse(BaseModel):
    """
    Schema per la risposta dopo la registrazione o la lettura di un utente.
    Espone solo i dati sicuri (esclude eventuali campi sensibili futuri come password).
    """
    id: int
    email: EmailStr
    first_name: str = Field(..., validation_alias=AliasChoices("first_name", "nome"))
    last_name: str = Field(..., validation_alias=AliasChoices("last_name", "cognome"))
    age: int = Field(..., validation_alias=AliasChoices("age", "eta"))
    weight: Optional[float] = Field(None, validation_alias=AliasChoices("weight", "peso"))
    height: Optional[float] = Field(None, validation_alias=AliasChoices("height", "altezza"))
    biceps: Optional[float] = Field(None, validation_alias=AliasChoices("biceps", "bicipite"))
    chest: Optional[float] = Field(None, validation_alias=AliasChoices("chest", "petto"))
    hips: Optional[float] = Field(None, validation_alias=AliasChoices("hips", "fianchi"))
    waist: Optional[float] = Field(None, validation_alias=AliasChoices("waist", "vita"))
    thigh: Optional[float] = Field(None, validation_alias=AliasChoices("thigh", "coscia"))
    calf: Optional[float] = Field(None, validation_alias=AliasChoices("calf", "polpaccio"))
    neck: Optional[float] = Field(None, validation_alias=AliasChoices("neck", "collo"))
    wrist: Optional[float] = Field(None, validation_alias=AliasChoices("wrist", "polso"))
    gender: Optional[str] = Field(None, validation_alias=AliasChoices("gender", "sesso"))

    bmi: Optional[float] = None
    bmr: Optional[int] = None
    whr: Optional[float] = None
    acqua_litri: Optional[float] = None
    proteine_min: Optional[int] = None
    proteine_max: Optional[int] = None
    body_fat_perc: Optional[float] = None
    version: Optional[str] = APP_VERSION

    class Config:
        from_attributes = True
        populate_by_name = True

class UserUpdateAdmin(BaseModel):
    """
    Schema per l'aggiornamento dei dati anagrafici e password da parte dell'admin.
    """
    email: Optional[EmailStr] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    password: Optional[str] = None

# ---------------------------------------------------------------------------
# Schemi per la scheda di allenamento (WorkoutPlan)
# ---------------------------------------------------------------------------

class WorkoutPlanCreate(BaseModel):
    """
    Schema per la creazione di una nuova versione della scheda (POST /api/plans/{user_id}).
    """
    plan: Any = Field(..., description="Scheda di allenamento come oggetto JSON libero")
    label: Optional[str] = Field(None, description="Etichetta opzionale (es. 'Fase 1 — Ipertrofia')")


class WorkoutPlanResponse(BaseModel):
    """
    Schema di risposta per la scheda attiva (GET /api/plans/{user_id}).
    """
    user_email: EmailStr
    user_id: int
    plan: Any = Field(..., description="Scheda di allenamento deserializzata da JSON")
    version: int = 1
    label: Optional[str] = None

    class Config:
        from_attributes = True


class WorkoutPlanHistoryItem(BaseModel):
    """Una voce dello storico piani di un utente."""
    id: int
    version: int
    label: Optional[str] = None
    created_at: Any
    plan: Any

    class Config:
        from_attributes = True


# ---------------------------------------------------------------------------
# Schemi per il catalogo esercizi (ExerciseCatalog)
# ---------------------------------------------------------------------------

class ExerciseCatalogCreate(BaseModel):
    """
    Schema per la creazione o aggiornamento di un esercizio nel catalogo
    (POST /api/catalog e PUT /api/catalog/{exercise_id}).
    I campi di setup sono strutturati e tipizzati per garantire il contratto
    JSON con l'app mobile.
    """
    nome: str = Field(..., min_length=1, description="Nome univoco dell'esercizio")
    gruppo_muscolare: str = Field(..., min_length=1, description="Gruppo muscolare principale (es. 'Petto', 'Gambe')")
    default_serie: Optional[int] = Field(None, ge=1, description="Numero di serie default (es. 4)")
    default_ripetizioni: Optional[str] = Field(None, description="Ripetizioni default (es. '10' o '8-12')")
    default_recupero_secondi: Optional[int] = Field(None, ge=0, description="Recupero in secondi (es. 90)")
    default_note: Optional[str] = Field(None, description="Note di esecuzione default")
    video_url: Optional[str] = Field(None, description="URL del video tutorial YouTube (opzionale)")


class ExerciseCatalogResponse(BaseModel):
    """
    Schema di risposta per la lettura di un esercizio dal catalogo
    (GET /api/catalog e GET /api/catalog/{exercise_id}).
    """
    id: int
    nome: str
    gruppo_muscolare: str
    default_serie: Optional[int]
    default_ripetizioni: Optional[str]
    default_recupero_secondi: Optional[int]
    default_note: Optional[str]
    video_url: Optional[str] = None

    class Config:
        # Permette la lettura diretta da oggetti SQLAlchemy
        from_attributes = True


# ---------------------------------------------------------------------------
# Schemi generici per messaggi di risposta
# ---------------------------------------------------------------------------

class MessageResponse(BaseModel):
    """Schema generico per risposte di conferma o errore con un messaggio testuale."""
    message: str


# ---------------------------------------------------------------------------
# Schemi per l'autenticazione JWT
# ---------------------------------------------------------------------------

class AuthRegisterRequest(BaseModel):
    """
    Schema per la registrazione di un account con password
    (POST /api/auth/register).
    La password viene ricevuta in chiaro e SUBITO hashata — mai salvata as-is.
    """
    email: EmailStr = Field(..., description="Email univoca dell'account")
    password: str = Field(..., min_length=6, description="Password in chiaro (min 6 caratteri)")
    first_name: str = Field(..., min_length=1, validation_alias="nome")
    last_name: str = Field(..., min_length=1, validation_alias="cognome")
    age: int = Field(..., ge=1, le=120, validation_alias="eta")
    gender: Optional[str] = Field(None, validation_alias="sesso")
    
    # Dati biometrici opzionali inviati dall'app mobile durante il signup
    weight: Optional[float] = Field(None, validation_alias="peso")
    height: Optional[float] = Field(None, validation_alias="altezza")
    biceps: Optional[float] = Field(None, validation_alias="bicipite")
    chest: Optional[float] = Field(None, validation_alias="petto")
    hips: Optional[float] = Field(None, validation_alias="fianchi")
    waist: Optional[float] = Field(None, validation_alias="vita")
    thigh: Optional[float] = Field(None, validation_alias="coscia")
    calf: Optional[float] = Field(None, validation_alias="polpaccio")
    neck: Optional[float] = Field(None, validation_alias="collo")
    wrist: Optional[float] = Field(None, validation_alias="polso")


class LoginRequest(BaseModel):
    """Schema per il login con email e password (POST /api/auth/login)."""
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    """Schema di risposta del login: access_token JWT, refresh_token, tipo (bearer) e ruolo utente."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    role: str
    user_id: int
    version: str = APP_VERSION
    user: UserResponse


class RefreshTokenRequest(BaseModel):
    """Schema per la richiesta di rinnovo access token tramite refresh token."""
    refresh_token: str


class RefreshTokenResponse(BaseModel):
    """Schema di risposta del refresh: nuovo access_token."""
    access_token: str
    token_type: str = "bearer"


class ChangePasswordRequest(BaseModel):
    """Schema per il cambio password (PUT /api/auth/change-password)."""
    vecchia_password: str
    nuova_password: str = Field(..., min_length=6)


# ---------------------------------------------------------------------------
# Schemi per le misurazioni (Measurement)
# ---------------------------------------------------------------------------

from datetime import datetime

class MeasurementCreate(BaseModel):
    """Schema per salvare una nuova misurazione fisica."""
    weight: Optional[float] = Field(None, validation_alias=AliasChoices("weight", "peso"))
    chest: Optional[float] = Field(None, validation_alias=AliasChoices("chest", "petto"))
    waist: Optional[float] = Field(None, validation_alias=AliasChoices("waist", "vita"))
    hips: Optional[float] = Field(None, validation_alias=AliasChoices("hips", "fianchi"))
    biceps: Optional[float] = Field(None, validation_alias=AliasChoices("biceps", "bicipite"))
    thigh: Optional[float] = Field(None, validation_alias=AliasChoices("thigh", "coscia"))
    calf: Optional[float] = Field(None, validation_alias=AliasChoices("calf", "polpaccio"))
    neck: Optional[float] = Field(None, validation_alias=AliasChoices("neck", "collo"))
    wrist: Optional[float] = Field(None, validation_alias=AliasChoices("wrist", "polso"))
    goal: Optional[str] = None


class MeasurementResponse(MeasurementCreate):
    """Schema per la risposta contenente i dati storici di una misurazione."""
    id: int
    user_id: int
    created_at: datetime

    class Config:
        from_attributes = True


class UserProgressResponse(BaseModel):
    """Schema aggregato per visualizzare il progresso completo di un cliente."""
    user: UserResponse
    measurements: list[MeasurementResponse]
    last_plan: Optional[Any] = None

class AIGenerateRequest(BaseModel):
    """Schema per la richiesta di generazione scheda tramite AI."""
    user_id: int
    experience_level: str = "Intermedio"
    pt_notes: Optional[str] = ""
    training_days: int = Field(default=3, ge=1, le=7, description="Numero di giorni di allenamento")
    training_time: int = Field(default=60, ge=20, le=120, description="Durata massima sessione in minuti")
    model_name: Optional[str] = Field(default="gemini-3.5-flash", description="Il modello AI da utilizzare")

    class Config:
        populate_by_name = True
        from_attributes = True

_ALLOWED_CONTEXT_KEYS = {"age", "height", "goal", "type", "weight", "gender"}

class AIAnalyzeRequest(BaseModel):
    """Schema per la validazione della richiesta di analisi AI generica (Passthrough)."""
    prompt_text: str = Field(..., max_length=2000, description="Il testo del prompt da inviare all'AI (max 2000 caratteri)")
    context_data: dict = Field(default_factory=dict, description="Dati di contesto opzionali per l'analisi")
    model_name: Optional[str] = Field(default="gemini-3.5-flash", description="Il modello AI da utilizzare")

    @classmethod
    def model_validator_context(cls, values):
        ctx = values.get("context_data", {})
        filtered = {k: v for k, v in ctx.items() if k in _ALLOWED_CONTEXT_KEYS}
        values["context_data"] = filtered
        return values

    class Config:
        populate_by_name = True

class AIAnalyzeResponse(BaseModel):
    """Schema di risposta per l'analisi AI generica."""
    text: str

class WorkoutLogCreate(BaseModel):
    """Schema per il salvataggio di un allenamento (POST /api/workouts/save)."""
    user_id: int
    title: Optional[str] = ""
    duration_seconds: int
    exercises: list[dict] = Field(..., description="Lista di esercizi completati con serie, kg, e reps")

class WorkoutLogResponse(BaseModel):
    id: int
    user_id: int
    title: Optional[str] = ""
    date: datetime
    duration_seconds: Optional[int]
    exercises: Any = None

    @classmethod
    def from_orm_log(cls, log) -> "WorkoutLogResponse":
        import json
        exercises = []
        try:
            exercises = json.loads(log.exercises_json)
        except Exception:
            pass
        return cls(
            id=log.id,
            user_id=log.user_id,
            title=log.title,
            date=log.date,
            duration_seconds=log.duration_seconds,
            exercises=exercises,
        )

    class Config:
        from_attributes = True


# ---------------------------------------------------------------------------
# Schemi per il setup iniziale del Personal Trainer
# ---------------------------------------------------------------------------

class AdminSetupRequest(BaseModel):
    """Schema per il primo avvio: configurazione del Personal Trainer."""
    pt_name: str = Field(..., min_length=1, description="Nome del Personal Trainer")
    username: str = Field(..., description="Nome utente/Email di accesso")
    password: str = Field(..., min_length=6, description="Password di accesso")
    confirm_password: str = Field(..., min_length=6, description="Conferma password")


class SetupStatusResponse(BaseModel):
    """Schema per verificare se il sistema è già stato configurato."""
    is_configured: bool


# ---------------------------------------------------------------------------
# Schemi per le Impostazioni di Sistema e Modelli IA
# ---------------------------------------------------------------------------

class SystemSettingsUpdate(BaseModel):
    """Schema per aggiornare le impostazioni di sistema."""
    ai_model: str
    ai_api_key_override: Optional[str] = None
    deepseek_api_key_override: Optional[str] = None


class AIModelResponse(BaseModel):
    """Schema per i modelli AI disponibili (Whitelist)."""
    id: str
    name: str


# ---------------------------------------------------------------------------
# Schema per lo sblocco AI (POST /api/auth/unlock-ai)
# ---------------------------------------------------------------------------

class UnlockAIRequest(BaseModel):
    """Schema per la verifica del codice di sblocco AI."""
    code: str = Field(..., min_length=1, description="Codice di sblocco AI (es. forza42)")


class UnlockAIResponse(BaseModel):
    """Schema di risposta per lo sblocco AI."""
    valid: bool
    expires_at: Optional[str] = Field(None, description="ISO8601 — data di scadenza del codice")
