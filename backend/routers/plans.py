from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import json
import models
import schemas
from database import get_db
from auth import get_current_user
import logging

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/plans",
    tags=["Schede"]
)

_catalog_cache: dict | None = None

def _get_catalog_dict(db) -> dict:
    global _catalog_cache
    if _catalog_cache is not None:
        return _catalog_cache
    rows = db.query(models.ExerciseCatalog).all()
    _catalog_cache = {row.nome: row.video_url for row in rows if row.video_url}
    return _catalog_cache

def invalidate_catalog_cache() -> None:
    global _catalog_cache
    _catalog_cache = None

@router.post(
    "/{user_id}",
    response_model=schemas.WorkoutPlanResponse,
    summary="Salva o aggiorna la scheda di allenamento",
)
def save_or_update_plan(
    user_id: int,
    plan_data: schemas.WorkoutPlanCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Permessi insufficienti: solo il Personal Trainer puÃ² salvare schede.")
    
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"Utente con ID '{user_id}' non trovato.")

    plan_json_str = json.dumps(plan_data.plan, ensure_ascii=False)

    last = db.query(models.WorkoutPlan).filter(
        models.WorkoutPlan.user_id == user.id
    ).order_by(models.WorkoutPlan.version.desc()).first()
    next_version = (last.version + 1) if last else 1

    new_plan = models.WorkoutPlan(
        user_id=user.id,
        plan_json=plan_json_str,
        version=next_version,
        label=plan_data.label,
    )
    db.add(new_plan)
    db.commit()
    db.refresh(new_plan)
    logger.info(f"Scheda v{next_version} creata per utente ID: {user.id} (label: {plan_data.label!r})")

    return schemas.WorkoutPlanResponse(
        user_email=user.email,
        user_id=user.id,
        plan=plan_data.plan,
        version=next_version,
        label=plan_data.label,
    )

@router.get(
    "/{user_id}",
    response_model=schemas.WorkoutPlanResponse,
    summary="Scarica la scheda di allenamento",
)
def get_plan(user_id: int, db: Session = Depends(get_db),
            current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Accesso negato: puoi visualizzare solo la tua scheda.")
    
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"Utente con ID '{user_id}' non trovato.")

    plan = db.query(models.WorkoutPlan).filter(
        models.WorkoutPlan.user_id == user.id
    ).order_by(models.WorkoutPlan.version.desc()).first()

    if not plan:
        raise HTTPException(status_code=404, detail=f"Nessuna scheda attiva trovata per l'utente {user.first_name}.")

    plan_data = json.loads(plan.plan_json)
    
    catalog_map = _get_catalog_dict(db)
    
    if "giorni" in plan_data:
        for giorno in plan_data["giorni"]:
            if "esercizi" in giorno:
                for ex in giorno["esercizi"]:
                    ex_name = ex.get("nome")
                    if ex_name in catalog_map:
                        ex["video_url"] = catalog_map[ex_name]

    return schemas.WorkoutPlanResponse(
        user_email=user.email,
        user_id=user.id,
        plan=plan_data,
        version=plan.version,
        label=plan.label,
    )

@router.get(
    "/{user_id}/history",
    response_model=list[schemas.WorkoutPlanHistoryItem],
    summary="Storico versioni schede di un utente",
)
def get_plan_history(
    user_id: int,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Accesso negato.")
    plans = db.query(models.WorkoutPlan).filter(
        models.WorkoutPlan.user_id == user_id
    ).order_by(models.WorkoutPlan.version.desc()).limit(limit).all()

    return [
        schemas.WorkoutPlanHistoryItem(
            id=p.id,
            version=p.version,
            label=p.label,
            created_at=p.created_at.isoformat() + "Z" if p.created_at else None,
            plan=json.loads(p.plan_json),
        )
        for p in plans
    ]

@router.delete("/{user_id}/history/{plan_id}", summary="Elimina una scheda dallo storico")
def delete_plan_from_history(user_id: int, plan_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Solo il Personal Trainer puo' eliminare schede.")
    plan = db.query(models.WorkoutPlan).filter(models.WorkoutPlan.id == plan_id, models.WorkoutPlan.user_id == user_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Scheda non trovata.")
    db.delete(plan)
    db.commit()
    return {"status": "ok", "message": "Scheda eliminata dallo storico."}

