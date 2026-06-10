from sqlalchemy import Column, Integer, String, Float, Text, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import math

from database import Base


class User(Base):
    """
    Tabella 'users': contiene i dati anagrafici e biometrici di ogni utente.
    L'email è usata come identificativo univoco per le operazioni dall'app mobile
    e dalla dashboard del Personal Trainer.
    """
    __tablename__ = "users"

    # Chiave primaria auto-incrementale
    id = Column(Integer, primary_key=True, index=True)

    # Email unica per ogni utente, indicizzata per query veloci
    email = Column(String, unique=True, index=True, nullable=False)

    # Dati anagrafici
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    age = Column(Integer, nullable=False)  # età in anni

    # Misurazioni biometriche (in kg e cm)
    weight = Column(Float, nullable=True)       # peso corporeo in kg
    height = Column(Float, nullable=True)       # altezza in cm
    biceps = Column(Float, nullable=True)       # circonferenza bicipite in cm
    chest = Column(Float, nullable=True)        # circonferenza petto in cm
    hips = Column(Float, nullable=True)         # circonferenza fianchi in cm
    waist = Column(Float, nullable=True)        # circonferenza vita in cm
    thigh = Column(Float, nullable=True)        # circonferenza coscia in cm
    calf = Column(Float, nullable=True)         # circonferenza polpaccio in cm
    neck = Column(Float, nullable=True)         # circonferenza collo in cm
    wrist = Column(Float, nullable=True)        # circonferenza polso in cm

    # Sesso biologico / genere (es. "Maschio", "Femmina", "Altro")
    gender = Column(String, nullable=True)

    # Ruolo dell'utente per RBAC: 'admin' (Personal Trainer) o 'client' (Atleta)
    role = Column(String, nullable=False, default="client")

    # Password hashata (bcrypt) — null per i clienti registrati dal PT senza account
    hashed_password = Column(String, nullable=True)

    # Relazioni
    workout_plans = relationship("WorkoutPlan", back_populates="owner", cascade="all, delete-orphan")
    measurements = relationship("Measurement", back_populates="owner", cascade="all, delete-orphan")
    workout_logs = relationship("WorkoutLog", back_populates="owner", cascade="all, delete-orphan")

    @property
    def bmi(self):
        if self.weight and self.height and self.height > 0:
            height_m = self.height / 100
            return round(self.weight / (height_m ** 2), 1)
        return None

    @property
    def bmr(self):
        if self.weight and self.height and self.age:
            if self.gender and self.gender.lower().startswith('f'):
                return int(10 * self.weight + 6.25 * self.height - 5 * self.age - 161)
            else:
                return int(10 * self.weight + 6.25 * self.height - 5 * self.age + 5)
        return None

    @property
    def whr(self):
        if self.waist and self.hips and self.hips > 0:
            return round(self.waist / self.hips, 2)
        return None

    @property
    def acqua_litri(self):
        if self.weight:
            return round((self.weight * 35) / 1000, 1)
        return None

    @property
    def proteine_min(self):
        if self.weight:
            return int(self.weight * 1.6)
        return None

    @property
    def proteine_max(self):
        if self.weight:
            return int(self.weight * 2.2)
        return None

    @property
    def body_fat_perc(self):
        if self.waist and self.height and self.neck and self.height > 0:
            try:
                if self.gender and self.gender.lower().startswith('f'):
                    if self.hips:
                        val = self.waist + self.hips - self.neck
                        if val > 0:
                            bf = 495 / (1.29579 - 0.35004 * math.log10(val) + 0.22100 * math.log10(self.height)) - 450
                            return round(bf, 1)
                else:
                    val = self.waist - self.neck
                    if val > 0:
                        bf = 495 / (1.0324 - 0.19077 * math.log10(val) + 0.15456 * math.log10(self.height)) - 450
                        return round(bf, 1)
            except (ValueError, ZeroDivisionError):
                return None
        return None


class Measurement(Base):
    """
    Tabella 'measurements': storicizza le misure fisiche degli utenti nel tempo.
    """
    __tablename__ = "measurements"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    weight = Column(Float, nullable=True)
    chest = Column(Float, nullable=True)
    waist = Column(Float, nullable=True)
    hips = Column(Float, nullable=True)
    biceps = Column(Float, nullable=True)
    thigh = Column(Float, nullable=True)
    calf = Column(Float, nullable=True)
    neck = Column(Float, nullable=True)
    wrist = Column(Float, nullable=True)
    goal = Column(String, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    owner = relationship("User", back_populates="measurements")


class WorkoutPlan(Base):
    """
    Tabella 'workout_plans': storicizza tutte le versioni delle schede per ogni utente.
    Ogni assegnazione crea un nuovo record; la scheda attiva è quella con created_at più recente.
    """
    __tablename__ = "workout_plans"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    plan_json = Column(Text, nullable=False)

    # Numero versione progressivo per utente (1, 2, 3 …)
    version = Column(Integer, nullable=False, default=1)
    # Etichetta opzionale assegnata dal PT (es. "Fase 1 — Ipertrofia")
    label = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    owner = relationship("User", back_populates="workout_plans")


class ExerciseCatalog(Base):
    """
    Tabella 'exercise_catalog': catalogo globale degli esercizi disponibili.
    Ogni esercizio è unico per nome e contiene informazioni sul gruppo muscolare
    coinvolto e sui valori di default strutturati suggeriti dal Personal Trainer.
    """
    __tablename__ = "exercise_catalog"

    # Chiave primaria auto-incrementale
    id = Column(Integer, primary_key=True, index=True)

    # Nome dell'esercizio, univoco nel catalogo (es. "Panca Piana", "Squat")
    nome = Column(String, unique=True, index=True, nullable=False)

    # Gruppo muscolare principale coinvolto (es. "Petto", "Gambe", "Schiena")
    gruppo_muscolare = Column(String, nullable=False)

    # Campi strutturati del setup default — garantiscono il contratto JSON con l'app mobile
    default_serie = Column(Integer, nullable=True)              # es. 4
    default_ripetizioni = Column(String, nullable=True)         # es. "10" o "8-12"
    default_recupero_secondi = Column(Integer, nullable=True)   # es. 90
    default_note = Column(String, nullable=True)                # es. "Presa larga"

    # URL opzionale al video tutorial su YouTube (es. "https://youtu.be/xyz")
    video_url = Column(String, nullable=True)


class SystemSettings(Base):
    """
    Tabella 'system_settings': memorizza le impostazioni globali dell'applicazione,
    come la configurazione del modello IA da utilizzare o le chiavi API.
    """
    __tablename__ = "system_settings"

    key = Column(String, primary_key=True, index=True)
    value = Column(String, nullable=True)

class WorkoutLog(Base):
    """
    Tabella 'workout_logs': storicizza gli allenamenti completati.
    """
    __tablename__ = "workout_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    date = Column(DateTime(timezone=True), server_default=func.now())
    duration_seconds = Column(Integer, nullable=True)
    
    # Campo JSON per memorizzare l'intero payload dell'allenamento
    # Struttura: [{"name": "Panca", "sets": [{"weight": 100, "reps": 10, "timeUnderTension": 45}]}]
    exercises_json = Column(Text, nullable=False)

    owner = relationship("User", back_populates="workout_logs")


