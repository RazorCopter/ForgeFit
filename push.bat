@echo off
echo =====================================================
echo Inizio procedura di pubblicazione per ForgeFit...
echo =====================================================
echo.

:: 1. Controlla lo stato dei file modificati
echo [1/4] Controllo stato dei file...
git status
echo.

:: 2. Aggiungi tutte le modifiche allo stage
echo [2/4] Aggiunta delle modifiche allo stage (git add .)...
git add .
echo.

:: 3. Crea un "pacchetto" con un messaggio chiaro
echo [3/4] Creazione del commit...
git commit -m "fix: risolto routing dinamico API, fix flusso di login e aggiunta favicon ForgeFit"
echo.

:: 4. Spingi tutto sul repository remoto
echo [4/4] Push sul repository remoto (origin main)...
git push origin main
echo.

echo =====================================================
echo Operazione completata!
echo =====================================================
pause