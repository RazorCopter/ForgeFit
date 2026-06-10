# Changelog — ForgeFit

## [1.8.3] — 2026-06-10
### Changed
- **AI Models:** Aggiunto `gemini-2.5-flash` alla whitelist dei modelli e impostato come default globale per evitare addebiti extra previsti dai futuri tier di Gemini 3.x.

## [1.8.2] — 2026-06-10
### Fixed
- **AI timeout:** Risolto errore 524 Cloudflare durante la generazione di schede. Il backend ora sfrutta `StreamingResponse` per inviare i frammenti in tempo reale (keep-alive) bypassando il timeout di inattività dei load balancer.
- **Wakelock:** Implementato fallback globale nativo tramite JS nel web `index.html` per assicurare che il display non si spenga durante il workout su iOS e Android.

## [1.8.1] — 2026-06-10
### Fixed
- **SyncService:** Risolto bug che azzerava gli esercizi scaricati dal server sovrascrivendo la cronologia locale con array vuoti.
- **Wakelock (PWA):** Spostata l'abilitazione del blocco schermo direttamente negli handler dei bottoni (Avvia Tutto / Start) per bypassare i blocchi energetici di Safari iOS e Android Chrome, risolvendo il problema dello schermo che si spegneva durante il workout.
- **Backend:** Fix import mancante (`models` invece di `UserProfile`) in `backend/routers/admin.py` che mandava in crash il backend.


## [1.8.0] — 2026-06-10
### Changed
- Upgrade dell'intelligenza artificiale: i modelli selezionabili passano ufficialmente alla nuova famiglia Gemini 3.5 (Flash, Pro, e Flash-Lite), offrendo maggiore velocità e ragionamento.
- Rimozione del vecchio endpoint `/api/register` obsoleto (e dei dati biometrici superflui durante la registrazione) dal `main.py` per una totale pulizia e coerenza architetturale.


## [1.7.9] — 2026-06-10
### Changed
- Rimossi i tasti obsoleti e fuorvianti di "Importa/Esporta Backup" locale dalla schermata `SetupScreen` per evitare conflitti con la sincronizzazione in tempo reale.
- Spostata la logica di esportazione del database a livello server: creato nuovo endpoint `/api/admin/backup` per scaricare direttamente l'intero database di produzione SQLite.

## [1.7.8] — 2026-06-10
### Added
- Integrazione del pacchetto `wakelock_plus` per mantenere lo schermo sempre acceso durante la sessione di allenamento (impedendo lo standby del dispositivo sia su Web PWA che su app mobile).

## [1.7.7] — 2026-06-10
### Fixed
- Corretto un artefatto visivo in `SetupScreen` per cui veniva renderizzata una versione del backend cablata fissa (1.7.4) nell'istante di caricamento prima che `SyncService` finisse. Ora usa un `ValueNotifier` per aggiornarsi reattivamente.

## [1.7.6] — 2026-06-10
### Added
- Implementato il 2-way sync completo (pull): se un utente cancella un allenamento tramite API/FitConsole, il prossimo avvio dell'app riconoscerà che l'ID non è più presente sul server e cancellerà silenziosamente la sessione "orfana" anche dal database locale Hive del telefono/browser.

## [1.7.5] — 2026-06-10
### Fixed
- Eliminata l'ultima chiamata ridondante a `/api/auth/me` proveniente da `SetupScreen`. Ora l'app all'avvio effettua esattamente 1 singola chiamata per ogni risorsa necessaria.

## [1.7.4] — 2026-06-10
### Fixed
- Ottimizzazione chiamate API ridondanti all'avvio: il profilo utente è ora sincronizzato in maniera centralizzata per evitare età fallaci in `AnalysisScreen` e sono state eliminate chiamate duplicate a `workouts` e `auth/me` dalle singole schede per alleggerire il carico di avvio.
- Fix in backend `auth.py`: utilizzo della variabile `APP_VERSION` dinamica al posto della stringa "1.7.2" hardcoded in `TokenResponse`.

## [1.7.3] — 2026-06-10
### Fixed
- Risolto un bug critico di duplicazione degli allenamenti in storico. Il frontend ora aggiorna il proprio UUID locale con l'ID autoincrementale assegnato dal backend, prevenendo salvataggi multipli durante i successivi cicli di sincronizzazione offline.

## [1.7.2] — 2026-06-10
### Added
- Aggiunto endpoint `DELETE /api/workouts/{log_id}` per permettere l'eliminazione remota degli allenamenti dallo storico.
### Fixed
- L'eliminazione locale di un allenamento sul client mobile ora notifica il backend affinché l'allenamento venga rimosso anche in FitConsole (la dashboard web).
- I dati dell'utente (età e altezza) risultavano "0" in `AnalysisScreen` perché l'account Admin non prevede questi dati nella configurazione. Ora il fallback è noto come un comportamento atteso e sicuro per l'amministratore.

Tutte le modifiche rilevanti vengono documentate in questo file.  
Formato: `[versione] — YYYY-MM-DD` → sezioni **Added / Changed / Fixed / Removed**.

---

## [1.7.1] — 2026-06-10

### Fixed
- **Sincronizzazione Storico Allenamenti**: Aggiunto il salvataggio e recupero del campo `title` nel backend per gli allenamenti completati. Questo risolve il bug per cui il badge mensile ("cerchietto") non si aggiornava sui dispositivi remoti a causa del titolo nullo.

---

## [1.7.0] — 2026-06-10

### Fixed & Changed
- **Audit Sicurezza & Fix**: Risolti i problemi evidenziati nel recente audit di sicurezza e funzionale:
  - Rimosso `allow_origin_regex=".*"` dal middleware CORS in backend.
  - Implementata paginazione (`skip`/`limit`) sugli endpoint `/api/users` e `/api/workouts/history`.
  - Sistemato memory leak (`dispose()` dei TextEditingController) in `AnalysisScreen`.
  - Le statistiche ora recuperano i dati mancanti dal server (`GET /api/workouts/history`) invece di usare solo la cache Hive.
  - UI `WorkoutSessionScreen` migliorata con dettagli dell'esercizio corrente al posto di un semplice spinner.
  - Mapping icone per giorno dinamico basato sul nome in `home_screen`.
- **Dipendenze**: Aggiunto `connectivity_plus` e aggiornate dipendenze frontend.

---

## [1.6.4] — 2026-06-10

### Fixed
- **App PWA Android**: Risolto il bug che mostrava la barra di sistema rossa su Chrome/Android (impostato il theme-color corretto a `#141419`).
- **Pannello Admin**: Aggiunta la voce mancante `Core` nel menu a tendina "Gruppo Muscolare" durante la creazione di un nuovo esercizio.
- **Pannello Admin**: Copiata l'iconcina `favicon.ico` per eliminare l'errore 404 sui browser web.
- **Autenticazione**: Risolto il conflitto di account (Errore 404 Schede) quando il Personal Trainer accedeva con il proprio account sull'app mobile.

---

## [1.6.3] — 2026-06-10

### Added
- **Storico Schede**: Aggiunta la possibilità di navigare nello storico delle schede di allenamento sia dal Pannello Admin (nel Builder) sia dall'app per il Cliente (nella schermata principale).

---

## [1.6.2] — 2026-06-10

### Added
- **Pannello Admin**: Aggiunta la possibilità di modificare i dati anagrafici (nome, cognome, email) e la password degli utenti direttamente dalla tabella "Clienti Registrati".

---

## [1.6.1] — 2026-06-10

### Removed & Changed
- **Passkeys (WebAuthn)**: Rimozione totale di tutto il sistema Passkey dall'intero applicativo (Frontend e Backend).
- **Sessione JWT**: Estesa la durata del token di sessione da 7 a 14 giorni.

---

## [1.6.0] — 2026-06-10

### Fixed & Changed
- **Passkeys (WebAuthn)**: Spostata la registrazione della Passkey nella schermata "Setup & Sicurezza" ("Sicurezza account") rimuovendola dal menu Analisi IA.
- **Passkeys (WebAuthn)**: Risolto errore server `400 Bad Request` in fase di registrazione/login. Aggiornata la libreria `python-webauthn` v2 per usare `parse_registration_credential_json` invece di `parse_raw`.

---

## [1.5.1] — 2026-06-09

### Fixed
- **Version Number**: Sincronizzata la versione dell'app a `1.5.1` globalmente (frontend e backend).

---

## [1.5.0] — 2026-06-09

### Added
- **Passkeys (WebAuthn)**: Implementata l'autenticazione biometrica senza password tramite Passkeys. Gli utenti possono ora registrare il proprio dispositivo (FaceID/TouchID/Windows Hello) e accedere istantaneamente con l'impronta digitale o il volto, anche se l'app non è installata nativamente ma gira nel browser come PWA.
- **SyncService Resiliente (Two-Way Sync)**: Implementata una sincronizzazione a due vie (Push/Pull) per Workouts e Misure Biometriche. I dati creati offline vengono ritentati in background ogni 5 minuti. Inoltre, facendo login su un nuovo dispositivo o premendo "Sincronizza ora", l'app popola il database locale (Hive) scaricando interamente lo storico dal server (nuove API backend `/history/{user_id}`).

### Fixed
- **CORS Login Errore (Server non raggiungibile)**: Aggiunta la direttiva `allow_origin_regex=".*"` in `main.py` per garantire che il middleware CORS di FastAPI permetta le richieste da qualsiasi URL e porta, risolvendo il problema del "Server non raggiungibile" quando il client e il server sono su reti locali diverse ma non proxate o elencate tra le origin hardcoded.

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
