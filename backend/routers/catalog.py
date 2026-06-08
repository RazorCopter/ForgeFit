from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import models
import schemas
from database import get_db
from auth import get_current_user
import logging

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/catalog",
    tags=["Catalogo Esercizi"]
)

@router.get(
    "",
    response_model=list[schemas.ExerciseCatalogResponse],
    summary="Lista tutti gli esercizi del catalogo",
)
def list_exercises(db: Session = Depends(get_db)):
    return db.query(models.ExerciseCatalog).order_by(models.ExerciseCatalog.nome).all()

@router.get(
    "/{exercise_id}",
    response_model=schemas.ExerciseCatalogResponse,
    summary="Dettaglio di un esercizio",
)
def get_exercise(exercise_id: int, db: Session = Depends(get_db)):
    exercise = db.query(models.ExerciseCatalog).filter(
        models.ExerciseCatalog.id == exercise_id
    ).first()
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Esercizio con ID {exercise_id} non trovato.",
        )
    return exercise

@router.post(
    "",
    response_model=schemas.ExerciseCatalogResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Aggiunge un esercizio al catalogo",
)
def create_exercise(exercise_data: schemas.ExerciseCatalogCreate, db: Session = Depends(get_db),
                    current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può modificare il catalogo.")
    
    existing = db.query(models.ExerciseCatalog).filter(
        models.ExerciseCatalog.nome == exercise_data.nome
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Esercizio '{exercise_data.nome}' già presente nel catalogo.",
        )

    new_exercise = models.ExerciseCatalog(**exercise_data.model_dump())
    db.add(new_exercise)
    db.commit()
    db.refresh(new_exercise)
    logger.info(f"Esercizio aggiunto al catalogo: '{new_exercise.nome}' (ID: {new_exercise.id})")
    return new_exercise

@router.put(
    "/{exercise_id}",
    response_model=schemas.ExerciseCatalogResponse,
    summary="Aggiorna un esercizio del catalogo",
)
def update_exercise(
    exercise_id: int,
    exercise_data: schemas.ExerciseCatalogCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può modificare il catalogo.")
    exercise = db.query(models.ExerciseCatalog).filter(
        models.ExerciseCatalog.id == exercise_id
    ).first()
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Esercizio con ID {exercise_id} non trovato.",
        )

    name_conflict = db.query(models.ExerciseCatalog).filter(
        models.ExerciseCatalog.nome == exercise_data.nome,
        models.ExerciseCatalog.id != exercise_id,
    ).first()
    if name_conflict:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Il nome '{exercise_data.nome}' è già usato da un altro esercizio.",
        )

    exercise.nome = exercise_data.nome
    exercise.gruppo_muscolare = exercise_data.gruppo_muscolare
    exercise.default_serie = exercise_data.default_serie
    exercise.default_ripetizioni = exercise_data.default_ripetizioni
    exercise.default_recupero_secondi = exercise_data.default_recupero_secondi
    exercise.default_note = exercise_data.default_note
    exercise.video_url = exercise_data.video_url
    db.commit()
    db.refresh(exercise)
    logger.info(f"Esercizio aggiornato: ID {exercise_id} → '{exercise.nome}'")
    return exercise

@router.delete(
    "/{exercise_id}",
    response_model=schemas.MessageResponse,
    summary="Rimuove un esercizio dal catalogo",
)
def delete_exercise(exercise_id: int, db: Session = Depends(get_db),
                    current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può modificare il catalogo.")
    exercise = db.query(models.ExerciseCatalog).filter(
        models.ExerciseCatalog.id == exercise_id
    ).first()
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Esercizio con ID {exercise_id} non trovato.",
        )

    nome = exercise.nome
    db.delete(exercise)
    db.commit()
    logger.info(f"Esercizio rimosso dal catalogo: '{nome}' (ID: {exercise_id})")
    return {"message": f"Esercizio '{nome}' rimosso dal catalogo con successo."}
