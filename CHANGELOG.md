# Changelog — ForgeFit

## [2.1.13] — 2026-06-16

### Fixed
- **FitConsole ReferenceError Fix**: Risolto il ReferenceError per cui non era possibile accedere alla variabile `badge` prima della sua inizializzazione nel caricamento delle schede dal backend.

## [2.1.12] — 2026-06-16

### Added
- **Dynamic Muscle Group Badges (FitConsole)**: Allineati i colori dei badge dei gruppi muscolari nel builder di FitConsole a quelli ufficiali usati nell'app client Flutter (Petto -> Ciano, Schiena -> Viola chiaro, Gambe/Glutei -> Ciano profondo, Spalle -> Arancione, Braccia -> Rosa, Addome/Core -> Verde, Altri -> Viola).

## [2.1.11] — 2026-06-16

### Fixed
- **FitConsole Plan Builder Improvements**: 
  - Risolto il bug per cui il box di notifica di salvataggio avvenuto con successo non appariva/non era visibile (ora posizionato stabilmente in cima sopra la lista dei giorni).
  - Aggiunto il caricamento/aggiornamento automatico dello storico delle schede dopo un salvataggio riuscito (simulando la selezione utente), evitando di dover ricaricare manualmente la pagina con F5.
  - Aggiunti i pulsanti di ordinamento Sposta su (▲) e Sposta giù (▼) per ciascun esercizio all'interno dei giorni del builder, consentendo di riordinare facilmente la sequenza degli esercizi in scheda.

## [2.1.10] — 2026-06-16

### Fixed
- **Nerd Analytics Stats Layout**: Ottimizzato il layout dei 3 box delle statistiche in alto nella scheda Stats. Ridotto il padding interno dei box e la dimensione delle icone, aggiunto un `FittedBox` per riscalare automaticamente i testi dei valori senza troncarli con l'ellipsis, e spostato il nome dell'esercizio del "Best Set" come sottotitolo nell'angolo in alto a destra anziché concatenato nel valore principale. Risolto anche il bug di formattazione che aggiungeva un `.0` decimale non necessario ai valori interi come le ore.

## [2.1.9] — 2026-06-16

### Added
- **Docker Compose Environment**: Esposta la variabile d'ambiente `EMERGENCY_MASTER_KEY` nel `docker-compose.yml` del backend per consentire la configurazione centralizzata tramite le variabili di ambiente dello Stack di Portainer.

## [2.1.8] — 2026-06-16

### Fixed
- **Emergency Password Reset Rate Limiting**: Aggiunto rate limit di 3 richieste all'ora (`3/hour`) sull'endpoint `/api/auth/reset-password-emergency` per prevenire attacchi brute-force sulla master key.

## [2.1.7] — 2026-06-16

### Fixed
- **AI Performance Tab Loading**: Risolto il caricamento infinito dello spinner sotto "Performance Analysis" nel tab AI del frontend. Aggiunto un listener reattivo su Hive per aggiornare automaticamente il profilo utente all'avvenuta sincronizzazione e blindata l'inizializzazione con try-catch.
- **Safe Profile Casts**: Risolti possibili errori di casting a runtime durante il parsing dal backend dei campi numerici `bmr`, `proteine_min` e `proteine_max` (gestendo sia int che double).

## [2.1.6] — 2026-06-16

### Added
- **Voice Coach Customization**: Modificata la voce neurale di default sul backend impostando la voce maschile italiana `it-IT-GiuseppeNeural` su richiesta dell'utente.
- **TTS Pronunciation & Accents**: Ottimizzati i testi della sintesi vocale nel frontend inserendo gli accenti fonetici corretti (es. *ripòsati*) per migliorare la fluidità e la correttezza della pronuncia del coach.
- **Edge TTS Stability**: Risolto l'errore di handshake WebSocket 403 (Sec-MS-GEC) aggiornando `edge-tts>=7.2.8` e corretto il nome della voce neurale italiana da `it-IT-ElisaNeural` a `it-IT-ElsaNeural` prima del passaggio a `it-IT-GiuseppeNeural`.

## [2.1.2] — 2026-06-16

### Added
- **Flutter Web Compatibility**: Risolto il supporto e la compatibilità web del servizio di sintesi vocale (`VoiceService`), consentendo la riproduzione fluida di Edge TTS tramite buffer audio in memoria ed evitando crash legati a plugin di piattaforma non supportati.

## [2.1.1] — 2026-06-16

### Added
- **Edge TTS Integration**: Integrata la sintesi vocale neurale cloud di Microsoft Edge (voce `it-IT-ElisaNeural`) con caching locale automatico dell'audio MP3 e fallback offline su `flutter_tts` locale.
- **Refactoring Deprecazioni**: Risolti oltre 130 avvisi di deprecazione di `withOpacity` convertendoli in `withValues(alpha: ...)`.

## [2.1.0] — 2026-06-16

### Added
- **Cyber Body Map**: Nuova schermata interattiva con heatmap muscolare neon procedurale (CustomPainter) fronte/retro. Calcola il volume degli ultimi 30 giorni per distretto muscolare e mostra suggerimenti e statistiche in overlay glassmorphism.
- **AI Voice Coach**: Sintesi vocale (`flutter_tts`) in lingua italiana con supporto al ducking dell'audio di sottofondo (Spotify, ecc.) su cuffie e altoparlanti. Include interruttore rapido nella toolbar del workout e nelle impostazioni generali.
- **Emergency Password Reset**: Endpoint di emergenza protetto `/api/auth/reset-password-emergency` per recuperare password tramite master key definita in `.env`.
- **POST /api/measurements**: Nuovo endpoint nel backend per consentire la corretta persistenza delle misurazioni biometriche nel cloud.

### Fixed
- **Offline Biometrics Sync**: Risolto il disallineamento temporale inviando il timestamp originale `created_at` dal frontend per evitare record duplicati e grafici incongruenti.
- **Gemini Model Whitelist**: Allineamento del fallback AI stabili sul backend a `gemini-1.5-flash`.

## [2.0.4] — 2026-06-16

### Changed
- **Home Screen UI Redesign**: Riorganizzato l'header "La tua Settimana". Spostati il selettore del piano (Storico/Attuale) e l'indicatore di sincronizzazione (Sinc: Wi-Fi) all'interno di una singola dashboard control bar unificata con effetto glassmorphism per risolvere i problemi di overflow e migliorare l'estetica.

## [2.0.3] — 2026-06-16

### Added
- **Gamification Popups**: Aggiunta l'animazione dei confetti personalizzati in base al colore del traguardo direttamente nel popup di sblocco. Sostituita la vecchia icona MDI nel popup con le nuove illustrazioni neon.

## [2.0.2] — 2026-06-16

### Added
- **Gamification Assets**: Generate 8 immagini custom 2D in stile neon per i traguardi.
- **Tooltip Interattivo**: Aggiunto un tooltip con descrizione dettagliata e data di sblocco che compare al tocco sui traguardi conquistati.

### Changed
- Sostituito il `CustomPainter` procedurale con `Image.asset` per visualizzare le nuove grafiche dei badge.

## [2.0.1] — 2026-06-16

### Added
- **UI Traguardi Dedicated Tab**: Aggiunta una nuova tab dedicata "Traguardi" nella Bottom Navigation Bar (tra AI e Setup).
- **Badge Gagliardetto Custom**: Creato un `CustomPainter` per disegnare proceduralmente i badge degli achievement a forma di gagliardetto, abbandonando le icone MDI standard. I badge sbloccati presentano un effetto glow neon e un gradiente vivido.

### Changed
- Rimosso il blocco dei Traguardi dalla schermata di Setup per una UI più pulita.

## [2.0.0] — 2026-06-16

### Added
- **Gamification & Achievements**: Aggiunto un sistema di traguardi (es. Primo Allenamento, Costanza, PR Hunter) con popup animati e griglia di riepilogo in Setup.
- **Integrazione Wearable/Salute**: Scrittura automatica degli allenamenti su Google Fit (Android) e Apple Health (iOS) tramite `HealthService`.
- **Miglioramenti UI/UX**: Inserite animazioni Lottie per gli stati vuoti, chip per Gruppo Muscolare sulle card degli esercizi e Bottom Navigation bar animata.
- **Offline-First**: Nuovo indicatore `cloud_off` per gli allenamenti non ancora sincronizzati col backend.
- **Statistiche Interattive**: Aggiunti i tooltip `lineTouchData` a tutti i grafici delle statistiche (Volume, 1RM Epley, Progressi Esercizio) per lettura esatta dei valori.

### Changed
- **UX Timer Recupero**: Aggiunto un effetto *glow* e un'animazione pulsante durante gli ultimi 5 secondi del countdown per preparare l'atleta.
- **Colori Dinamici Scheda**: Utilizzo di una palette ciclica di 8 colori associata ad un hash dell'ID dinamico dei giorni, per non avere più il limite di `d1-d4`.
- **Tech Debt e Ottimizzazione**: 
  - Pattern retry per il token JWT centralizzato via helper generico `_authenticatedRequest` per evitare fallimenti nei salvataggi su token 401.
  - Implementato un caching dei permessi HealthService per non richiederli due volte nella stessa sessione.
  - Track dei Personal Record ottimizzato a passaggio singolo (*single-pass*).
  - Backend SQLAlchemy aggiornato a v2.0 (`DeclarativeBase`) e migrazioni SQLite raw rimosse.

### Fixed
- **Parsing URL Shorts**: Il parser video ora riconosce anche il link nel formato `youtube.com/shorts/VIDEO_ID`.
- Evitato il fallback forzato al logout (401-retry gap) durante la sincronizzazione attiva del workout.

## [1.9.8] — 2026-06-15

### Changed
- Sostituito il player in linea di YouTube con una thumbnail che apre il video in pop-up per migliorare performance e stabilità.
- Aggiunti controlli Stop e Pausa/Riprendi nella barra superiore durante gli esercizi e rimosso FloatingActionButton avvia tutto a sessione in corso.

### Fixed
- Risolto bug UI di sovrapposizione del video YouTube durante lo scroll in day_detail_screen.

## [1.9.7] — 2026-06-12
### Fixed
- **Mobile Keyboard Autocorrect:** Aggiunto il supporto ai trattini lunghi (En Dash `–` ed Em Dash `—`) generati automaticamente dai correttori delle tastiere iOS e Android, per garantire il corretto split del titolo dei giorni.

## [1.9.6] — 2026-06-12
### Changed
- **Robust Title Parsing:** Riscritto il motore di parsing in Dart per i titoli delle schede d'allenamento. Ora utilizza un normalizzatore universale in grado di sdoppiare retroattivamente anche le vecchie sintassi (es. "DAY 1 - Petto + Tricipiti"), garantendo sempre un titolo pulito "DAY X" e un elenco puntato dei muscoli.

## [1.9.5] — 2026-06-12
### Added
- **Centralized Versioning:** Creato lo script automatizzato `execution/bump_version.py` per sincronizzare in un solo colpo il numero di build in `pubspec.yaml`, la costante hardcoded nel frontend e la variabile backend, prevenendo disallineamenti di versione in cache.
## [1.9.4] — 2026-06-12
### Added & Changed
- **UI Card Split:** Sdoppiamento visivo automatico del titolo del giorno di allenamento (es. `DAY 1` e `Petto + Tricipiti`) nella Home Screen senza impatto sul backend o sui modelli dati, per risolvere problemi di troncamento testo su mobile.
- **AI Prompt:** Aggiunta regola ferrea al prompt AI nel backend per garantire che il nome giorno sia generato sempre col formato stringente `DAY X - Descrizione muscoli`, ottimizzando il parsing visivo frontend su schede future.

## [1.9.3] — 2026-06-12
### Added & Changed
- **Icon App & Build:** Aggiornate le icone dell'app (launcher icons) per Android e iOS.
- **APK Optimization:** Ottimizzazione e generazione di un APK compatto.

## [1.9.2] â€” 2026-06-12
### Fixed
- **Training Indicators:** Risolto un bug per cui gli indicatori di completamento della Home perdevano il conteggio cambiando versione della scheda. Ora il calcolo è diventato completamente *cross-scheda*: il sistema raggruppa gli allenamenti per "numero di giorno" e per ID strutturale, mantenendo lo storico intatto indipendentemente dal nome generato dall'IA.

## [1.9.1] â€” 2026-06-12
### Changed
- **UX Layout:** Spostata l'icona di stato di sincronizzazione e connessione dalla riga del titolo principale alla riga "Sinc", migliorando l'equilibrio visivo.
- **Bug Fix:** Risolto un bug per cui interrompere un esercizio dal tasto indietro generava un caricamento infinito (spinner bloccato) nella schermata di Workout Session.

## [1.9.0] â€” 2026-06-11
### Changed
- **UX YouTube Player:** Sostituito YoutubeThumbnail con l'embed nativo youtube_player_iframe per riprodurre i video di istruzioni tecniche direttamente in-app senza rimbalzare su app esterne.


## [1.8.8] â€” 2026-06-11
### Added
- **Active Session Persistence:** Implementato il salvataggio automatico progressivo dell'allenamento in corso. Chiudendo l'app o uscendo dalla schermata, la sessione viene salvata in locale e ricaricata alla riapertura, permettendo di non perdere i progressi (e mantenendo in pausa il timer) anche in caso di disconnessioni, crash o logout per token scaduto.
- **Sospensione Sessione:** Aggiunta la possibilitÃ  di sospendere volontariamente la sessione ("Sospendi per dopo") premendo il tasto "Indietro" del dispositivo durante un allenamento.

## [1.8.7] â€” 2026-06-11
### Changed
- **UX Form Registrazione:** Rimossa la legenda a chip dei punti di misurazione sottostante l'immagine della guida visiva nella schermata di registrazione, snellendo l'interfaccia visiva.

## [1.8.6] â€” 2026-06-11
### Changed
- **UX Fine Allenamento:** Migliorata l'interfaccia del popup di fine allenamento. Il pulsante "Termina Sessione e Salva" Ã¨ stato riposizionato in alto al centro (colore rosso) per evitare tocchi accidentali con il tasto "Continua Allenamento" e vi Ã¨ stato aggiunto un dialog di conferma.

## [1.8.5] â€” 2026-06-11
### Added
- **Registrazione â€” Guida Visiva Misurazioni**: Aggiunto accordion expandable (aperto di default) nella sezione "Misurazioni Iniziali" della schermata di registrazione. Mostra l'immagine `rilievo.jpg` con overlay gradient premium, badge "Guida Visiva", caption con istruzioni d'uso e chip informativi per ogni punto di rilievo (Vita, Fianchi, Petto, Bicipite, Coscia, Collo). Il pannello si apre/chiude con animazione fluida (`AnimatedCrossFade` + rotazione freccia).

## [1.8.4] â€” 2026-06-10
### Added
- **AI Models:** Integrazione completa del supporto per i modelli DeepSeek (DeepSeek V3 Chat e R1 Reasoner) come alternativa a Gemini, accessibili tramite un wrapper unificato compatibile con OpenAI SDK.
- **System Settings:** Aggiunta la chiave `deepseek_api_key_override` nel database per configurare dinamicamente le credenziali di DeepSeek.
### Fixed
- **Frontend Build:** Creata cartella mancante `assets/images` per risolvere i warning di compilazione di Flutter in `pubspec.yaml`.

## [1.8.3] â€” 2026-06-10
### Changed
- **AI Models:** Aggiunto `gemini-2.5-flash` alla whitelist dei modelli e impostato come default globale per evitare addebiti extra previsti dai futuri tier di Gemini 3.x.

## [1.8.2] â€” 2026-06-10
### Fixed
- **AI timeout:** Risolto errore 524 Cloudflare durante la generazione di schede. Il backend ora sfrutta `StreamingResponse` per inviare i frammenti in tempo reale (keep-alive) bypassando il timeout di inattivitÃ  dei load balancer.
- **Wakelock:** Implementato fallback globale nativo tramite JS nel web `index.html` per assicurare che il display non si spenga durante il workout su iOS e Android.

## [1.8.1] â€” 2026-06-10
### Fixed
- **SyncService:** Risolto bug che azzerava gli esercizi scaricati dal server sovrascrivendo la cronologia locale con array vuoti.
- **Wakelock (PWA):** Spostata l'abilitazione del blocco schermo direttamente negli handler dei bottoni (Avvia Tutto / Start) per bypassare i blocchi energetici di Safari iOS e Android Chrome, risolvendo il problema dello schermo che si spegneva durante il workout.
- **Backend:** Fix import mancante (`models` invece di `UserProfile`) in `backend/routers/admin.py` che mandava in crash il backend.


## [1.8.0] â€” 2026-06-10
### Changed
- Upgrade dell'intelligenza artificiale: i modelli selezionabili passano ufficialmente alla nuova famiglia Gemini 3.5 (Flash, Pro, e Flash-Lite), offrendo maggiore velocitÃ  e ragionamento.
- Rimozione del vecchio endpoint `/api/register` obsoleto (e dei dati biometrici superflui durante la registrazione) dal `main.py` per una totale pulizia e coerenza architetturale.


## [1.7.9] â€” 2026-06-10
### Changed
- Rimossi i tasti obsoleti e fuorvianti di "Importa/Esporta Backup" locale dalla schermata `SetupScreen` per evitare conflitti con la sincronizzazione in tempo reale.
- Spostata la logica di esportazione del database a livello server: creato nuovo endpoint `/api/admin/backup` per scaricare direttamente l'intero database di produzione SQLite.

## [1.7.8] â€” 2026-06-10
### Added
- Integrazione del pacchetto `wakelock_plus` per mantenere lo schermo sempre acceso durante la sessione di allenamento (impedendo lo standby del dispositivo sia su Web PWA che su app mobile).

## [1.7.7] â€” 2026-06-10
### Fixed
- Corretto un artefatto visivo in `SetupScreen` per cui veniva renderizzata una versione del backend cablata fissa (1.7.4) nell'istante di caricamento prima che `SyncService` finisse. Ora usa un `ValueNotifier` per aggiornarsi reattivamente.

## [1.7.6] â€” 2026-06-10
### Added
- Implementato il 2-way sync completo (pull): se un utente cancella un allenamento tramite API/FitConsole, il prossimo avvio dell'app riconoscerÃ  che l'ID non Ã¨ piÃ¹ presente sul server e cancellerÃ  silenziosamente la sessione "orfana" anche dal database locale Hive del telefono/browser.

## [1.7.5] â€” 2026-06-10
### Fixed
- Eliminata l'ultima chiamata ridondante a `/api/auth/me` proveniente da `SetupScreen`. Ora l'app all'avvio effettua esattamente 1 singola chiamata per ogni risorsa necessaria.

## [1.7.4] â€” 2026-06-10
### Fixed
- Ottimizzazione chiamate API ridondanti all'avvio: il profilo utente Ã¨ ora sincronizzato in maniera centralizzata per evitare etÃ  fallaci in `AnalysisScreen` e sono state eliminate chiamate duplicate a `workouts` e `auth/me` dalle singole schede per alleggerire il carico di avvio.
- Fix in backend `auth.py`: utilizzo della variabile `APP_VERSION` dinamica al posto della stringa "1.7.2" hardcoded in `TokenResponse`.

## [1.7.3] â€” 2026-06-10
### Fixed
- Risolto un bug critico di duplicazione degli allenamenti in storico. Il frontend ora aggiorna il proprio UUID locale con l'ID autoincrementale assegnato dal backend, prevenendo salvataggi multipli durante i successivi cicli di sincronizzazione offline.

## [1.7.2] â€” 2026-06-10
### Added
- Aggiunto endpoint `DELETE /api/workouts/{log_id}` per permettere l'eliminazione remota degli allenamenti dallo storico.
### Fixed
- L'eliminazione locale di un allenamento sul client mobile ora notifica il backend affinchÃ© l'allenamento venga rimosso anche in FitConsole (la dashboard web).
- I dati dell'utente (etÃ  e altezza) risultavano "0" in `AnalysisScreen` perchÃ© l'account Admin non prevede questi dati nella configurazione. Ora il fallback Ã¨ noto come un comportamento atteso e sicuro per l'amministratore.

Tutte le modifiche rilevanti vengono documentate in questo file.  
Formato: `[versione] â€” YYYY-MM-DD` â†’ sezioni **Added / Changed / Fixed / Removed**.

---

## [1.7.1] â€” 2026-06-10

### Fixed
- **Sincronizzazione Storico Allenamenti**: Aggiunto il salvataggio e recupero del campo `title` nel backend per gli allenamenti completati. Questo risolve il bug per cui il badge mensile ("cerchietto") non si aggiornava sui dispositivi remoti a causa del titolo nullo.

---

## [1.7.0] â€” 2026-06-10

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

## [1.6.4] â€” 2026-06-10

### Fixed
- **App PWA Android**: Risolto il bug che mostrava la barra di sistema rossa su Chrome/Android (impostato il theme-color corretto a `#141419`).
- **Pannello Admin**: Aggiunta la voce mancante `Core` nel menu a tendina "Gruppo Muscolare" durante la creazione di un nuovo esercizio.
- **Pannello Admin**: Copiata l'iconcina `favicon.ico` per eliminare l'errore 404 sui browser web.
- **Autenticazione**: Risolto il conflitto di account (Errore 404 Schede) quando il Personal Trainer accedeva con il proprio account sull'app mobile.

---

## [1.6.3] â€” 2026-06-10

### Added
- **Storico Schede**: Aggiunta la possibilitÃ  di navigare nello storico delle schede di allenamento sia dal Pannello Admin (nel Builder) sia dall'app per il Cliente (nella schermata principale).

---

## [1.6.2] â€” 2026-06-10

### Added
- **Pannello Admin**: Aggiunta la possibilitÃ  di modificare i dati anagrafici (nome, cognome, email) e la password degli utenti direttamente dalla tabella "Clienti Registrati".

---

## [1.6.1] â€” 2026-06-10

### Removed & Changed
- **Passkeys (WebAuthn)**: Rimozione totale di tutto il sistema Passkey dall'intero applicativo (Frontend e Backend).
- **Sessione JWT**: Estesa la durata del token di sessione da 7 a 14 giorni.

---

## [1.6.0] â€” 2026-06-10

### Fixed & Changed
- **Passkeys (WebAuthn)**: Spostata la registrazione della Passkey nella schermata "Setup & Sicurezza" ("Sicurezza account") rimuovendola dal menu Analisi IA.
- **Passkeys (WebAuthn)**: Risolto errore server `400 Bad Request` in fase di registrazione/login. Aggiornata la libreria `python-webauthn` v2 per usare `parse_registration_credential_json` invece di `parse_raw`.

---

## [1.5.1] â€” 2026-06-09

### Fixed
- **Version Number**: Sincronizzata la versione dell'app a `1.5.1` globalmente (frontend e backend).

---

## [1.5.0] â€” 2026-06-09

### Added
- **Passkeys (WebAuthn)**: Implementata l'autenticazione biometrica senza password tramite Passkeys. Gli utenti possono ora registrare il proprio dispositivo (FaceID/TouchID/Windows Hello) e accedere istantaneamente con l'impronta digitale o il volto, anche se l'app non Ã¨ installata nativamente ma gira nel browser come PWA.
- **SyncService Resiliente (Two-Way Sync)**: Implementata una sincronizzazione a due vie (Push/Pull) per Workouts e Misure Biometriche. I dati creati offline vengono ritentati in background ogni 5 minuti. Inoltre, facendo login su un nuovo dispositivo o premendo "Sincronizza ora", l'app popola il database locale (Hive) scaricando interamente lo storico dal server (nuove API backend `/history/{user_id}`).

### Fixed
- **CORS Login Errore (Server non raggiungibile)**: Aggiunta la direttiva `allow_origin_regex=".*"` in `main.py` per garantire che il middleware CORS di FastAPI permetta le richieste da qualsiasi URL e porta, risolvendo il problema del "Server non raggiungibile" quando il client e il server sono su reti locali diverse ma non proxate o elencate tra le origin hardcoded.

---

## [1.4.0] â€” 2026-06-09

### Added
- **Video Splash Screen**: Sostituita l'immagine statica di caricamento con un video animato in loop (`splash_video.mp4`), migliorando l'impatto visivo all'avvio.

### Fixed
- **Frontend Hive Fallback**: Aggiunto recovery automatico (`Hive.deleteBoxFromDisk`) in caso di corruzione dei dati locali (`RangeError`), per prevenire crash su web e app mobile.
- **Frontend Logout Pulito**: Implementata la cancellazione globale e sicura dei dati in cache (`DatabaseService.clearAllData()`) ad ogni logout.
- **Frontend Interceptor 401**: Intercettazione proattiva degli errori di token scaduto (HTTP 401) via `navigatorKey` per forzare il logout sicuro dell'utente in tempo reale.
- **Backend Rate Limiter (`slowapi`)**: Corretta la firma del parametro `request` in `auth_login` per prevenire errori 500 Bad Gateway in fase di autenticazione.
- **Backend AI Schemas**: Aggiunto lo schema `AIAnalyzeResponse` precedentemente omesso e corretto il mapping attributi (`context_data`, `prompt_text`) nel passthrough AI.

---

## [1.3.0] â€” 2026-06-08

### Changed / Fixed
- **Architettura Backend Modulare**: Refactoring totale di main.py in moduli dedicati dentro ackend/routers/ (i.py, uth.py, catalog.py, measurements.py, plans.py, system.py, users.py, workouts.py).
- **Supporto Offline (PWA)**: Implementato lutter_service_worker.js custom con policy Network-First per consentire l'utilizzo dell'app anche senza connessione internet in palestra.
- **Sicurezza & UX**: Aggiunto modulo slowapi in FastAPI per rate limiting.
- **Pulizia Bundle**: Rimosso definitivamente youtube_player_iframe da Flutter e shared_preferences, alleggerendo il pacchetto e risolvendo dipendenze obsolete.
- Risoluzione finale punti audit: Confirmation dialogs per cancellazione account e storico, Splash Screen logic async, BottomBar Gradient corretto, timer globale unificato in day_detail_screen.dart, e feedback ultima sincronizzazione UI.

---

## [1.2.0] â€” 2026-06-08

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

## [1.1.8] â€” 2026-06-08

### Fixed
- **Installazione App (PWA) / CORS**: Risolto il blocco di Cloudflare Access sul file `manifest.json`. Ãˆ stato aggiunto l'attributo `crossorigin="use-credentials"` al tag link HTML. Ora il browser invia i cookie di sessione di Cloudflare anche per il caricamento del manifest, permettendo al prompt PWA di apparire correttamente.

---

## [1.1.7] â€” 2026-06-08

### Fixed
- **Installazione App (PWA)**: Corretto un errore di sintassi nel file `manifest.json` (parentesi mancante) che impediva ai browser di riconoscere l'app come installabile e di mostrare il popup di installazione su Android e desktop.

---

## [1.1.6] â€” 2026-06-08

### Added
- **YouTube Embed Nativo**: Aggiunto il pacchetto `youtube_player_iframe` per incorporare nativamente i video YouTube (se disponibili per l'esercizio) all'interno dell'app. I video si riproducono senza problemi CORS direttamente nella schermata dell'allenamento. Sostituisce il vecchio pulsante "Guarda Tutorial".

---

## [1.1.5] â€” 2026-06-08

### Fixed
- **Ordinamento giorni scheda**: I giorni di allenamento ora vengono ordinati numericamente (Giorno 1, 2, 3â€¦) dopo il parsing del JSON, indipendentemente dall'ordine in cui il backend li restituisce.

---

## [1.1.4] â€” 2026-06-08

### Fixed
- **CORS eliminato alla radice**: Il frontend Nginx ora fa da reverse-proxy per tutte le chiamate `/api/` verso il container backend. Browser e API sono serviti dalla stessa origin (`forgefit.ghome.it`), eliminando completamente la necessitÃ  di header CORS.

### Changed
- **`frontend/nginx.conf`**: Aggiunto blocco `location /api/` con `proxy_pass` verso `http://backend:8000`.
- **`frontend/Dockerfile`**: Build web con `--dart-define=API_BASE_URL=` (URL relative) per instradare le chiamate API attraverso il proxy Nginx locale anzichÃ© cross-origin verso `fitconsole.ghome.it`.

---

## [1.1.3] â€” 2026-06-08

### Fixed
- **CORS Empty Env Handling**: Gestione migliorata del fallback per le origini CORS nel backend. Se la variabile d'ambiente `ALLOWED_ORIGINS` Ã¨ presente ma vuota o contiene solo spazi (ad esempio, impostata vuota in Portainer), il backend ora applica correttamente l'elenco di fallback predefinito, risolvendo gli errori di CORS.

## [1.1.2] â€” 2026-06-08

### Fixed
- **CORS Fallback**: Aggiunti i domini di produzione `forgefit.ghome.it`, `fitconsole.ghome.it` e l'IP locale `10.0.0.105:8083` come fallback predefiniti nelle origini CORS consentite dal backend nel caso in cui la variabile d'ambiente `ALLOWED_ORIGINS` sia assente.
- **Portainer Deploy Script**: Corretto il bug nello script PowerShell che azzerava le variabili d'ambiente dello stack Portainer durante i redeploy. Ora le variabili preesistenti vengono conservate correttamente.

## [1.1.1] â€” 2026-06-08

### Fixed
- **Database robusto**: Aggiunta gestione degli errori (try-catch) durante l'apertura delle box Hive con pulizia automatica/ricreazione in caso di box corrotta o schema mismatch, prevenendo crash all'avvio su web.
- **BiometricRecord JSON mapping**: Corretto il mapping della chiave `hips` (in italiano `fianchi`), `calf` (`polpaccio`), `neck` (`collo`) e `wrist` (`polso`) nel parser `fromJson` per garantire compatibilitÃ  bidirezionale con i dati esportati.

## [1.1.0] â€” 2026-06-08

### Added
- **Rest timer â€” prossima serie visibile**: durante il periodo di recupero viene mostrata una card con il numero di serie, il peso (kg) e le ripetizioni previste per la serie successiva, cosÃ¬ l'atleta puÃ² preparare l'attrezzatura in anticipo.
- **Bottone GO! a fine countdown**: al termine del conto alla rovescia il timer non avvia piÃ¹ automaticamente la serie successiva. Appare invece un pulsante **GO!** (con animazione elastica) che l'utente deve premere esplicitamente per iniziare la serie. Il flusso garantisce piena consapevolezza prima di riprendere il carico.

### Changed
- `RestTimerWidget`: aggiunto parametro opzionale `nextSet: NextSetInfo?`; la callback `onFinish` Ã¨ ora invocata solo alla pressione del bottone GO! (non allo scadere del timer).
- `ActiveSessionScreen`: calcola e passa `NextSetInfo` al `RestTimerWidget` alla conferma di ogni serie.

---

## [1.0.0] â€” 2026-06-01

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
