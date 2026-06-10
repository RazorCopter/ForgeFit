from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
import csv
import io
import models
import schemas
from database import get_db
from auth import get_current_user
import logging

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/users",
    tags=["Utenti"]
)

@router.get(
    "",
    response_model=list[schemas.UserResponse],
    summary="Lista tutti gli utenti registrati",
)
def list_users(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può vedere la lista utenti.")
    users = db.query(models.User).offset(skip).limit(limit).all()

    result = []
    for user in users:
        latest = db.query(models.Measurement).filter(
            models.Measurement.user_id == user.id
        ).order_by(models.Measurement.created_at.desc()).first()

        response = schemas.UserResponse.model_validate(user)
        if latest:
            response.weight = latest.weight if latest.weight is not None else response.weight
            response.chest  = latest.chest  if latest.chest  is not None else response.chest
            response.hips   = latest.hips   if latest.hips   is not None else response.hips
            response.waist  = latest.waist  if latest.waist  is not None else response.waist
            response.biceps = latest.biceps if latest.biceps is not None else response.biceps
            response.thigh  = latest.thigh  if latest.thigh  is not None else response.thigh
            response.calf   = latest.calf   if latest.calf   is not None else response.calf
            response.neck   = latest.neck   if latest.neck   is not None else response.neck
            response.wrist  = latest.wrist  if latest.wrist  is not None else response.wrist
        result.append(response)

    return result
@router.put(
    "/{user_id}",
    response_model=schemas.MessageResponse,
    summary="Aggiorna i dati anagrafici e la password di un utente (solo admin)",
)
def update_user(
    user_id: int, 
    payload: schemas.UserUpdateAdmin, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può modificare gli utenti.")
    
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"Utente con ID {user_id} non trovato.")
        
    if payload.email:
        # Check if email is already taken by someone else
        existing = db.query(models.User).filter(models.User.email == payload.email).first()
        if existing and existing.id != user_id:
            raise HTTPException(status_code=400, detail="Questa email è già in uso da un altro utente.")
        user.email = payload.email
        
    if payload.first_name:
        user.first_name = payload.first_name
        
    if payload.last_name:
        user.last_name = payload.last_name
        
    if payload.password and payload.password.strip():
        from auth import hash_password
        user.hashed_password = hash_password(payload.password)
        
    db.commit()
    logger.info(f"Dati utente {user_id} aggiornati dall'admin")
    return {"message": "Dati utente aggiornati con successo."}


@router.delete(
    "/{email}",
    response_model=schemas.MessageResponse,
    summary="Elimina un utente e la sua scheda",
)
def delete_user(email: str, db: Session = Depends(get_db),
               current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può eliminare utenti.")
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Utente '{email}' non trovato.",
        )

    db.delete(user)
    db.commit()
    logger.info(f"Utente eliminato: {email}")
    return {"message": f"Utente '{email}' e la sua scheda eliminati con successo."}

@router.get(
    "/export",
    summary="Esporta la lista clienti in CSV",
    response_class=StreamingResponse,
)
def export_users_csv(db: Session = Depends(get_db),
                     current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può esportare i dati.")
    users = db.query(models.User).all()
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["id", "email", "first_name", "last_name", "age",
                     "weight", "height", "biceps", "chest", "waist", "thigh", "calf", "neck", "wrist", "gender"])
    for u in users:
        writer.writerow([
            u.id, u.email, u.first_name, u.last_name, u.age,
            u.weight or "", u.height or "", u.biceps or "",
            u.chest or "", u.waist or "", u.thigh or "", u.calf or "", u.neck or "", u.wrist or "", u.gender or "",
        ])
    output.seek(0)
    logger.info(f"Export CSV: {len(users)} utenti")
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=clienti.csv"},
    )

@router.post(
    "/import",
    response_model=schemas.MessageResponse,
    summary="Importa clienti da un file CSV",
)
async def import_users_csv(file: UploadFile = File(...), db: Session = Depends(get_db),
                           current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Accesso negato: solo il Personal Trainer può importare dati.")
    content = await file.read()
    text = content.decode("utf-8-sig")
    reader = csv.DictReader(io.StringIO(text))

    inseriti = aggiornati = saltati = 0
    for row in reader:
        try:
            email = row.get("email", "").strip().lower()
            first_name = row.get("first_name", row.get("nome", "")).strip()
            last_name = row.get("last_name", row.get("cognome", "")).strip()
            age_raw = row.get("age", row.get("eta", "")).strip()
            
            if not email or not first_name or not last_name or not age_raw:
                saltati += 1
                continue
            age = int(age_raw)

            def _float(val: str):
                v = val.strip() if val else ""
                return float(v) if v else None

            existing = db.query(models.User).filter(models.User.email == email).first()
            if existing:
                existing.first_name = first_name
                existing.last_name = last_name
                existing.age = age
                existing.weight = _float(row.get("weight", row.get("peso", "")))
                existing.height = _float(row.get("height", row.get("altezza", "")))
                existing.biceps = _float(row.get("biceps", row.get("bicipite", "")))
                existing.chest = _float(row.get("chest", row.get("petto", "")))
                existing.waist = _float(row.get("waist", row.get("vita", "")))
                existing.hips = _float(row.get("hips", row.get("fianchi", "")))
                existing.thigh = _float(row.get("thigh", row.get("coscia", "")))
                existing.calf = _float(row.get("calf", row.get("polpaccio", "")))
                existing.neck = _float(row.get("neck", row.get("collo", "")))
                existing.wrist = _float(row.get("wrist", row.get("polso", "")))
                existing.gender = row.get("gender", row.get("sesso", "")).strip() or None
                aggiornati += 1
            else:
                new_user = models.User(
                    email=email, first_name=first_name, last_name=last_name, age=age,
                    weight=_float(row.get("weight", row.get("peso", ""))),
                    height=_float(row.get("height", row.get("altezza", ""))),
                    biceps=_float(row.get("biceps", row.get("bicipite", ""))),
                    chest=_float(row.get("chest", row.get("petto", ""))),
                    waist=_float(row.get("waist", row.get("vita", ""))),
                    hips=_float(row.get("hips", row.get("fianchi", ""))),
                    thigh=_float(row.get("thigh", row.get("coscia", ""))),
                    calf=_float(row.get("calf", row.get("polpaccio", ""))),
                    neck=_float(row.get("neck", row.get("collo", ""))),
                    wrist=_float(row.get("wrist", row.get("polso", ""))),
                    gender=row.get("gender", row.get("sesso", "")).strip() or None,
                )
                db.add(new_user)
                inseriti += 1
        except Exception as exc:
            logger.warning(f"Import CSV - riga saltata: {exc}")
            saltati += 1

    db.commit()
    msg = f"Import completato: {inseriti} inseriti, {aggiornati} aggiornati, {saltati} saltati."
    logger.info(msg)
    return {"message": msg}

@router.get(
    "/{user_id}/progress",
    response_model=schemas.UserProgressResponse,
    summary="Ottiene il progresso completo di un cliente",
)
def get_client_progress(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    import json
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Accesso negato: non puoi visualizzare i progressi di altri utenti.")
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Cliente non trovato.")

    measurements = db.query(models.Measurement).filter(
        models.Measurement.user_id == user_id
    ).order_by(models.Measurement.created_at.asc()).all()

    last_plan_record = db.query(models.WorkoutPlan).filter(
        models.WorkoutPlan.user_id == user_id
    ).first()
    
    last_plan = None
    if last_plan_record:
        last_plan = json.loads(last_plan_record.plan_json)

    return {
        "user": user,
        "measurements": measurements,
        "last_plan": last_plan
    }
