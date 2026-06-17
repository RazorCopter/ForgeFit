from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
import os
from auth import get_current_user
import models

router = APIRouter()

@router.get("/backup")
def export_database_backup(current_user: models.User = Depends(get_current_user)):
    if current_user.role != 'admin':
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
        
    file_path = "data/fitness.db"
    if not os.path.exists(file_path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Database not found")
        
    return FileResponse(
        path=file_path, 
        filename="fitness_backup.db", 
        media_type="application/octet-stream"
    )
