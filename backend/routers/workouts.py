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
    prefix="/api/workouts",
    tags=["Allenamento"]
)

@router.post(
    "/save",
    response_model=schemas.WorkoutLogResponse,
    summary="Salva un allenamento completato",
)
def save_workout(
    payload: schemas.WorkoutLogCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role != "admin" and current_user.id != payload.user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Non hai i permessi per salvare l'allenamento di un altro utente."
        )

    target_user = db.query(models.User).filter(models.User.id == payload.user_id).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="Utente non trovato.")

    exercises_str = json.dumps(payload.exercises)

    new_log = models.WorkoutLog(
        user_id=payload.user_id,
        duration_seconds=payload.duration_seconds,
        exercises_json=exercises_str
    )

    db.add(new_log)
    db.commit()
    db.refresh(new_log)

    logger.info(f"Allenamento salvato per utente {payload.user_id} (Log ID: {new_log.id})")
    return schemas.WorkoutLogResponse.from_orm_log(new_log)

@router.get(
    "/suggestions/{user_id}",
    summary="Suggerimenti progressive overload per ogni esercizio",
)
def get_overload_suggestions(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Accesso negato.")

    logs = db.query(models.WorkoutLog).filter(
        models.WorkoutLog.user_id == user_id
    ).order_by(models.WorkoutLog.date.desc()).limit(20).all()

    exercise_sessions: dict[str, list[dict]] = {}
    for log in logs:
        try:
            exercises = json.loads(log.exercises_json)
        except Exception:
            continue
        for ex in exercises:
            name = ex.get("name", "")
            if not name:
                continue
            if name not in exercise_sessions:
                exercise_sessions[name] = []
            if len(exercise_sessions[name]) < 3:
                exercise_sessions[name].append(ex)

    suggestions = {}
    for ex_name, sessions in exercise_sessions.items():
        if not sessions:
            continue
        last_session = sessions[0]
        sets = last_session.get("sets", [])
        if not sets:
            suggestions[ex_name] = {"suggested_weight": None, "reason": "no_data"}
            continue

        last_weight = max((s.get("weight", 0) for s in sets), default=0)
        all_on_target = True
        for session in sessions:
            for s in session.get("sets", []):
                target = s.get("targetReps", s.get("target_reps", 0))
                actual = s.get("reps", s.get("actualReps", 0))
                if target and actual and actual < target:
                    all_on_target = False
                    break

        if all_on_target and len(sessions) >= 2:
            suggested = round((last_weight + 2.5) * 2) / 2 
            suggestions[ex_name] = {"suggested_weight": suggested, "reason": "target_reached", "last_weight": last_weight}
        else:
            suggestions[ex_name] = {"suggested_weight": last_weight, "reason": "maintain", "last_weight": last_weight}

    return {"suggestions": suggestions}
