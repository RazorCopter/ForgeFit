@echo off
echo =====================================================
echo Inizio procedura di pubblicazione per ForgeFit...
echo =====================================================
echo.

:: 1. Controlla lo stato dei file modificati
echo [1/4] Controllo stato dei file...
git status
echo.

:: 0. Compilazione dell'app Web
echo [0/4] Compilazione in corso (flutter build web)...
call flutter build web --release --dart-define=API_BASE_URL=https://fitconsole.ghome.it

:: 2. Aggiungi tutte le modifiche allo stage
echo [2/4] Aggiunta delle modifiche allo stage (git add .)...
git add .
echo.

:: 3. Richiedi e crea il commit
echo [3/4] Creazione del commit...
set /p COMMIT_MSG="Inserisci il messaggio per questo commit: "

:: Se premi invio senza scrivere nulla, usa un messaggio di default
if "%COMMIT_MSG%"=="" set COMMIT_MSG="Aggiornamento di sistema"

git commit -m "%COMMIT_MSG%"
echo.

:: 4. Spingi tutto sul repository remoto
echo [4/4] Push sul repository remoto (origin main)...
git push origin main
echo.

echo =====================================================
echo Operazione completata!
echo =====================================================
pause