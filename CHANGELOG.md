# Changelog — ForgeFit

Tutte le modifiche rilevanti vengono documentate in questo file.  
Formato: `[versione] — YYYY-MM-DD` → sezioni **Added / Changed / Fixed / Removed**.

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
