@echo off
echo =====================================================
echo Inizio procedura di pubblicazione per ForgeFit...
echo =====================================================
echo.

:: 1. Compilazione dell'app Web
echo [1/4] Compilazione in corso (flutter build web)...
call flutter build web --release --dart-define=API_BASE_URL=https://fitconsole.ghome.it
echo.

:: 2. Aggiungi tutte le modifiche e FORZA la cartella build/web
echo [2/4] Aggiunta delle modifiche allo stage...
git add .
:: LA SOLUZIONE DEFINITIVA: Forziamo l'upload della web app compilata
git add -f build/web/
echo.

:: 3. Controllo stato dei file (Così vedi cosa sta per essere pushato)
echo [3/4] Controllo stato dei file...
git status
echo.

:: 4. Richiedi e crea il commit
echo [4/4] Creazione del commit...
set /p COMMIT_MSG="Inserisci il messaggio per questo commit: "

:: Se premi invio senza scrivere nulla, usa un messaggio di default
if "%COMMIT_MSG%"=="" set COMMIT_MSG="Release client web aggiornata"

git commit -m "%COMMIT_MSG%"
echo.

:: 5. Spingi tutto sul repository remoto
echo [5/5] Push sul repository remoto (origin main)...
git push origin main
echo.

echo =====================================================
echo Operazione completata! Vai su Portainer e aggiorna lo stack.
echo =====================================================
pause