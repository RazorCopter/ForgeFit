@echo off
title Git Auto-Push
echo ==========================================
echo       GIT PUSH AUTOMATICO
echo ==========================================
echo.

:: Richiede il commento all'utente
set /p commit_msg="Inserisci il commento del commit: "

:: Controllo se il commento è vuoto
if "%commit_msg%"=="" (
    echo.
    echo [ERRORE] Il commento non puo' essere vuoto! Operazione annullata.
    echo.
    pause
    exit /b
)

echo.
echo [1/3] Aggiunta dei file in corso (git add .)...
git add .

echo.
echo [2/3] Creazione del commit...
git commit -m "%commit_msg%"

echo.
echo [3/3] Invio al server (git push origin main)...
git push origin main

echo.
echo ==========================================
echo       OPERAZIONE COMPLETATA!
echo ==========================================
echo.
pause