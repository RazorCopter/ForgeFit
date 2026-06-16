from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import models
import schemas
from database import get_db
from auth import get_current_user
import logging

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/measurements",
    tags=["Misure"]
)

@router.get(
    "/history/{user_id}",
    response_model=list[schemas.MeasurementResponse],
    summary="Ottieni lo storico misurazioni di un utente",
)
def get_measurement_history(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Non hai i permessi per visualizzare le misurazioni di un altro utente."
        )

    target_user = db.query(models.User).filter(models.User.id == user_id).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="Utente non trovato.")

    measurements = db.query(models.Measurement).filter(
        models.Measurement.user_id == user_id
    ).order_by(models.Measurement.created_at.asc()).all()

    return measurements

@router.delete(
    "/{measurement_id}",
    response_model=schemas.MessageResponse,
    summary="Elimina una misurazione specifica",
)
def delete_measurement(
    measurement_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Elimina un record biometrico dal database tramite il suo ID. Solo proprietario o admin."""
    meas = db.query(models.Measurement).filter(models.Measurement.id == measurement_id).first()
    if not meas:
        raise HTTPException(status_code=404, detail="Misurazione non trovata.")
    
    if current_user.role != "admin" and meas.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Accesso negato: non puoi eliminare misurazioni di altri utenti.")
    
    db.delete(meas)
    db.commit()
    logger.info(f"Misurazione ID {measurement_id} eliminata.")
    return {"message": "Misurazione eliminata correttamente."}


@router.put(
    "/{measurement_id}",
    response_model=schemas.MeasurementResponse,
    summary="Aggiorna una misurazione esistente",
)
def update_measurement(
    measurement_id: int,
    data: schemas.MeasurementCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Aggiorna i valori di una misurazione esistente. Solo proprietario o admin."""
    meas = db.query(models.Measurement).filter(models.Measurement.id == measurement_id).first()
    if not meas:
        raise HTTPException(status_code=404, detail="Misurazione non trovata.")

    if current_user.role != "admin" and meas.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Accesso negato: non puoi modificare misurazioni di altri utenti.")

    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(meas, key, value)
    
    db.commit()
    db.refresh(meas)
    logger.info(f"Misurazione ID {measurement_id} aggiornata.")
    return meas


@router.post("", response_model=schemas.MeasurementResponse, status_code=status.HTTP_201_CREATED, summary="Salva una nuova misurazione biometrica")
def create_measurement(
    data: schemas.MeasurementCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Salva una nuova misurazione biometrica nel database per l'utente loggato.
    Supporta la data retroattiva passata tramite 'created_at' (per la sync offline).
    """
    new_meas = models.Measurement(
        user_id=current_user.id,
        weight=data.weight,
        chest=data.chest,
        waist=data.waist,
        hips=data.hips,
        biceps=data.biceps,
        thigh=data.thigh,
        calf=data.calf,
        neck=data.neck,
        wrist=data.wrist,
        goal=data.goal,
    )
    if data.created_at:
        new_meas.created_at = data.created_at

    db.add(new_meas)
    db.commit()
    db.refresh(new_meas)
    logger.info(f"Nuova misurazione salvata per l'utente {current_user.email} (ID: {new_meas.id})")
    return new_meas

