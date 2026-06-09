# Changelog — ForgeFit

Tutte le modifiche rilevanti vengono documentate in questo file.  
Formato: `[versione] — YYYY-MM-DD` → sezioni **Added / Changed / Fixed / Removed**.

---

## [1.5.0] — 2026-06-09

### Added
- **Passkeys (WebAuthn)**: Implementata l'autenticazione biometrica senza password tramite Passkeys. Gli utenti possono ora registrare il proprio dispositivo (FaceID/TouchID/Windows Hello) e accedere istantaneamente con l'impronta digitale o il volto, anche se l'app non è installata nativamente ma gira nel browser come PWA.
- **SyncService Background Resiliente**: Implementata una coda asincrona offline/online robusta per `CompletedWorkout` e `BiometricRecord`. I dati pendenti che falliscono il caricamento a causa di problemi di rete vengono ora salvati con `isSynced: false` e spinti in background ogni 5 minuti e all'avvio dell'app.

---

## [1.4.0] — 2026-06-09

### Added
- **Video Splash Screen**: Sostituita l'immagine statica di caricamento con un video animato in loop (`splash_video.mp4`), migliorando l'impatto visivo all'avvio.

### Fixed
- **Frontend Hive Fallback**: Aggiunto recovery automatico (`Hive.deleteBoxFromDisk`) in caso di corruzione dei dati locali (`RangeError`), per prevenire crash su web e app mobile.
- **Frontend Logout Pulito**: Implementata la cancellazione globale e sicura dei dati in cache (`DatabaseService.clearAllData()`) ad ogni logout.
- **Frontend Interceptor 401**: Intercettazione proattiva degli errori di token scaduto (HTTP 401) via `navigatorKey` per forzare il logout sicuro dell'utente in tempo reale.
- **Backend Rate Limiter (`slowapi`)**: Corretta la firma del parametro `request` in `auth_login` per prevenire errori 500 Bad Gateway in fase di autenticazione.
- **Backend AI Schemas**: Aggiunto lo schema `AIAnalyzeResponse` precedentemente omesso e corretto il mapping attributi (`context_data`, `prompt_text`) nel passthrough AI.

---

## [1.3.0] — 2026-06-08

### Changed / Fixed
- **Architettura Backend Modulare**: Refactoring totale di main.py in moduli dedicati dentro ackend/routers/ (i.py, uth.py, catalog.py, measurements.py, plans.py, system.py, users.py, workouts.py).
- **Supporto Offline (PWA)**: Implementato lutter_service_worker.js custom con policy Network-First per consentire l'utilizzo dell'app anche senza connessione internet in palestra.
- **Sicurezza & UX**: Aggiunto modulo slowapi in FastAPI per rate limiting.
- **Pulizia Bundle**: Rimosso definitivamente youtube_player_iframe da Flutter e shared_preferences, alleggerendo il pacchetto e risolvendo dipendenze obsolete.
- Risoluzione finale punti audit: Confirmation dialogs per cancellazione account e storico, Splash Screen logic async, BottomBar Gradient corretto, timer globale unificato in day_detail_screen.dart, e feedback ultima sincronizzazione UI.

---

## [1.2.0] — 2026-06-08

### Changed / Fixed
- Eseguite modifiche strutturali da lista task:
  - Protezione cancellazione dati Hive su errore apertura box
  - JWT spostati da SharedPreferences a flutter_secure_storage
  - Wrappati log sensibili con kDebugMode
  - Colore delta biometrico corretto
  - Rimosso dead code in _exportBackup
  - Deduplicata la logica di sincronizzazione della scheda (PlanService)
  - Aggiunte le note esercizio durante la sessione attiva
  - Aggiunte etichette date sull'asse X del grafico volume
  - Haptic feedback alla conferma della serie e scadenza del timer
  - Fix tracking esercizi completati tramite indice per supportare esercizi duplicati
  - BiometricTrendsScreen reso reattivo ai nuovi inserimenti

---

## [1.1.8] — 2026-06-08

### Fixed
- **Installazione App (PWA) / CORS**: Risolto il blocco di Cloudflare Access sul file `manifest.json`. È stato aggiunto l'attributo `crossorigin="use-credentials"` al tag link HTML. Ora il browser invia i cookie di sessione di Cloudflare anche per il caricamento del manifest, permettendo al prompt PWA di apparire correttamente.

---

## [1.1.7] — 2026-06-08

### Fixed
- **Installazione App (PWA)**: Corretto un errore di sintassi nel file `manifest.json` (parentesi mancante) che impediva ai browser di riconoscere l'app come installabile e di mostrare il popup di installazione su Android e desktop.

---

## [1.1.6] — 2026-06-08

### Added
- **YouTube Embed Nativo**: Aggiunto il pacchetto `youtube_player_iframe` per incorporare nativamente i video YouTube (se disponibili per l'esercizio) all'interno dell'app. I video si riproducono senza problemi CORS direttamente nella schermata dell'allenamento. Sostituisce il vecchio pulsante "Guarda Tutorial".

---

## [1.1.5] — 2026-06-08

### Fixed
- **Ordinamento giorni scheda**: I giorni di allenamento ora vengono ordinati numericamente (Giorno 1, 2, 3…) dopo il parsing del JSON, indipendentemente dall'ordine in cui il backend li restituisce.

---

## [1.1.4] — 2026-06-08

### Fixed
- **CORS eliminato alla radice**: Il frontend Nginx ora fa da reverse-proxy per tutte le chiamate `/api/` verso il container backend. Browser e API sono serviti dalla stessa origin (`forgefit.ghome.it`), eliminando completamente la necessità di header CORS.

### Changed
- **`frontend/nginx.conf`**: Aggiunto blocco `location /api/` con `proxy_pass` verso `http://backend:8000`.
- **`frontend/Dockerfile`**: Build web con `--dart-define=API_BASE_URL=` (URL relative) per instradare le chiamate API attraverso il proxy Nginx locale anziché cross-origin verso `fitconsole.ghome.it`.

---

## [1.1.3] — 2026-06-08

### Fixed
- **CORS Empty Env Handling**: Gestione migliorata del fallback per le origini CORS nel backend. Se la variabile d'ambiente `ALLOWED_ORIGINS` è presente ma vuota o contiene solo spazi (ad esempio, impostata vuota in Portainer), il backend ora applica correttamente l'elenco di fallback predefinito, risolvendo gli errori di CORS.

## [1.1.2] — 2026-06-08

### Fixed
- **CORS Fallback**: Aggiunti i domini di produzione `forgefit.ghome.it`, `fitconsole.ghome.it` e l'IP locale `10.0.0.105:8083` come fallback predefiniti nelle origini CORS consentite dal backend nel caso in cui la variabile d'ambiente `ALLOWED_ORIGINS` sia assente.
- **Portainer Deploy Script**: Corretto il bug nello script PowerShell che azzerava le variabili d'ambiente dello stack Portainer durante i redeploy. Ora le variabili preesistenti vengono conservate correttamente.

## [1.1.1] — 2026-06-08

### Fixed
- **Database robusto**: Aggiunta gestione degli errori (try-catch) durante l'apertura delle box Hive con pulizia automatica/ricreazione in caso di box corrotta o schema mismatch, prevenendo crash all'avvio su web.
- **BiometricRecord JSON mapping**: Corretto il mapping della chiave `hips` (in italiano `fianchi`), `calf` (`polpaccio`), `neck` (`collo`) e `wrist` (`polso`) nel parser `fromJson` per garantire compatibilità bidirezionale con i dati esportati.

## [1.1.0] — 2026-06-08

### Added
- **Rest timer — prossima serie visibile**: durante il periodo di recupero viene mostrata una card con il numero di serie, il peso (kg) e le ripetizioni previste per la serie successiva, così l'atleta può preparare l'attrezzatura in anticipo.
- **Bottone GO! a fine countdown**: al termine del conto alla rovescia il timer non avvia più automaticamente la serie successiva. Appare invece un pulsante **GO!** (con animazione elastica) che l'utente deve premere esplicitamente per iniziare la serie. Il flusso garantisce piena consapevolezza prima di riprendere il carico.

### Changed
- `RestTimerWidget`: aggiunto parametro opzionale `nextSet: NextSetInfo?`; la callback `onFinish` è ora invocata solo alla pressione del bottone GO! (non allo scadere del timer).
- `ActiveSessionScreen`: calcola e passa `NextSetInfo` al `RestTimerWidget` alla conferma di ogni serie.

---

## [1.0.0] — 2026-06-01

### Added
- Prima release stabile del monorepo ForgeFit (frontend Flutter + backend FastAPI).
- Autenticazione JWT con auto-logout su token scaduto.
- Scheda di allenamento offline-first (Hive).
- Sessione attiva con stopwatch, timer recupero circolare, storico serie pre-popolato.
- Statistiche: volume, 1RM Epley, grafici `fl_chart`.
- Misurazioni biometriche con trend.
- Sblocco AI server-side (codice settimanale verificato su backend).
- Report AI con Google Gemini.
- Dashboard Personal Trainer (HTML statico).
- Docker Compose per deploy produzione.
