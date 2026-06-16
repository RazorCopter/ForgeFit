# 🔍 Audit Completo del Software — ForgeFit v2.0.4

Questo documento contiene l'analisi tecnica e funzionale dell'intero ecosistema ForgeFit (Backend FastAPI e Frontend Flutter) aggiornato alla versione **v2.0.4**. L'audit evidenzia le criticità di sicurezza, architetturali e funzionali rilevate ed elenca una serie di nuove funzionalità avanzate ad alto impatto emotivo e visivo (stile cyber-neon / premium).

---

## 🔴 1. Criticità ad Alta Priorità (Bug e Sicurezza)

### 1.1 🔒 CORS Wildcard Regex ancora Attivo in Produzione
* **File:** [main.py](file:///c:/Users/gianv/Documents/Progetti/ForgeFit/backend/main.py#L388-L395)
* **Descrizione:** Nonostante sia stata definita una lista di origini autorizzate (`allowed_origins`) tramite la variabile d'ambiente `ALLOWED_ORIGINS`, la configurazione del middleware CORS include ancora `allow_origin_regex=".*"`:
  ```python
  app.add_middleware(
      CORSMiddleware,
      allow_origins=allowed_origins,
      allow_origin_regex=".*",  # ⚠️ Bypassa completamente la whitelist!
      allow_credentials=True,
      allow_methods=["*"],
      allow_headers=["*"],
  )
  ```
  Questo regex dice al browser che **qualsiasi** sito web (anche malevolo) può effettuare chiamate autenticate verso questo backend.
* **Impatto:** Rischio di attacchi CSRF (Cross-Site Request Forgery) in browser in cui l'utente ha una sessione attiva.
* **Soluzione:** Rimuovere la riga `allow_origin_regex=".*"`. La configurazione corretta deve affidarsi unicamente ad `allow_origins=allowed_origins`.

---

### 1.2 🧩 Criticità Funzionale: Mancanza Endpoint `POST /api/measurements` nel Backend
* **File Frontend:** [api_service.dart](file:///c:/Users/gianv/Documents/Progetti/ForgeFit/frontend/lib/core/api_service.dart#L330-L341) e [sync_service.dart](file:///c:/Users/gianv/Documents/Progetti/ForgeFit/frontend/lib/core/sync_service.dart#L44-L55)
* **File Backend:** [routers/measurements.py](file:///c:/Users/gianv/Documents/Progetti/ForgeFit/backend/routers/measurements.py)
* **Descrizione:** Nel frontend, l'inserimento manuale in [analysis_screen.dart](file:///c:/Users/gianv/Documents/Progetti/ForgeFit/frontend/lib/screens/analysis_screen.dart#L174) e la sincronizzazione automatica in `SyncService` tentano di inviare i nuovi record biometrici inviando un `POST` su `/api/measurements`.
  Tuttavia, esaminando il backend, nel router `measurements.py` **non è definito alcun endpoint `@router.post("")`**. Sono presenti solo `GET /history/{user_id}`, `PUT /{measurement_id}` e `DELETE /{measurement_id}`.
* **Impatto:** Qualsiasi tentativo di salvare una nuova misurazione biometrica dall'app fallisce silenziosamente o restituisce un errore HTTP `405 Method Not Allowed`, bloccando il tracciamento dei progressi fisici dell'utente sul cloud.
* **Soluzione:** Implementare l'endpoint `POST` nel backend (`routers/measurements.py`) per la creazione di nuovi record.

---

### 1.3 🔑 Credenziali Portainer Hardcoded nello Script di Deploy
* **File:** [deploy - forgefit.ps1](file:///c:/Users/gianv/Documents/Progetti/deploy%20-%20forgefit.ps1#L19-L21)
* **Descrizione:** Lo script di deploy locale contiene in chiaro la password dell'amministratore Portainer:
  ```powershell
  $Username     = "admin"
  $Password     = "gianvitobleve"
  ```
* **Impatto:** Se questo script viene per errore incluso in un commit Git ed inviato al repository pubblico, le credenziali di accesso al server Portainer/Docker vengono esposte.
* **Soluzione:** Spostare la password in una variabile d'ambiente locale del sistema oppure caricarla dinamicamente leggendola da un file `.env` escluso dal controllo di versione.

---

### 1.4 📅 Offline-Sync: Data di Registrazione Disallineata per le Misure Sincronizzate
* **File Frontend:** [sync_service.dart](file:///c:/Users/gianv/Documents/Progetti/ForgeFit/frontend/lib/core/sync_service.dart#L44-L54)
* **Descrizione:** Durante la sincronizzazione dei dati biometrici pendenti (`pendingBiometrics`), l'app invia le misure numeriche al backend ma **non include la data reale del record** (`record.date`).
  Il backend, non ricevendo una data specifica, assegna il valore di default `created_at = datetime.now()`.
* **Impatto:** Se l'utente registra il peso offline lunedì e apre l'app connesso a internet mercoledì, la misurazione verrà salvata sul server con la data di mercoledì. Inoltre, nella successiva fase di pull dei dati remoti, l'app vedrà la data di mercoledì come nuova e scaricherà un record duplicato, sballando i grafici temporali.
* **Soluzione:** 
  1. Estendere lo schema `MeasurementCreate` nel backend per accettare un campo `created_at` facoltativo.
  2. Inviare `record.date.toIso8601String()` dal frontend durante il sync delle misurazioni.

---

## 🟡 2. Criticità a Media Priorità (Architettura e Performance)

### 2.1 🚀 Modello Gemini Default: Rischio Deprecazione
* **File:** [ai_service.py](file:///c:/Users/gianv/Documents/Progetti/ForgeFit/backend/ai_service.py#L89)
* **Descrizione:** In caso di mancata configurazione del database, il fallback predefinito per il modello AI è impostato a `"gemini-2.5-flash"`. Tuttavia, in molte altre parti della documentazione si fa riferimento a `gemini-3.5-flash` (un modello non ufficiale) o a modelli diversi.
* **Soluzione:** Assicurarsi che i fallback nel codice puntino a modelli di produzione stabili e attivi nell'SDK di Google (come `gemini-1.5-flash` o `gemini-2.0-flash`), prevenendo errori improvvisi di chiamata API.

---

### 2.2 🔒 Mancanza di Flussi per Reset Password e Gestione Credenziali PT
* **Descrizione:** Attualmente, non esiste un meccanismo di recupero password tramite link email per gli utenti. Inoltre, le credenziali del Personal Trainer sono salvate nel file `admin_config.json` sul server. Se il file viene rimosso, non montato in un volume docker persistente o corrotto, l'amministratore perde l'accesso al pannello di controllo.
* **Soluzione:** Aggiungere un comando CLI o un endpoint amministrativo per generare codici di reset, oppure salvare in sicurezza una password di emergenza crittografata nelle variabili d'ambiente.

---

## 🚀 3. Nuove Features "Cool" Proposte (Wow-Effect & Gamification)

Per portare l'app ad un livello estetico e funzionale ultra-premium (in sintonia con la Cyber-Glass UI neon), si propongono le seguenti funzionalità:

### 3.1 🏋️‍♂️ AI Form Checker (Analisi Video Esecuzione)
* **Come funziona:** L'utente può registrare un breve video di una serie (es. Squat, Stacco da terra, Panca) o caricarlo. Sfruttando le capacità multimodali di Gemini Flash, il video (o fotogrammi chiave estratti) viene inviato al backend. L'AI analizza la postura (inclinazione schiena, profondità squat, traiettoria barra) e restituisce consigli immediati sulla tecnica.
* **Impatto:** Altissimo wow-effect. ForgeFit diventa un vero e proprio assistente tecnico intelligente.

---

### 3.2 📊 Heatmap Interattiva Gruppi Muscolari (Body Map 3D/SVG)
* **Come funziona:** Nella scheda statistiche, inserire una sagoma stilizzata del corpo umano (fronte/retro) in stile wireframe neon. I vari distretti muscolari (petto, quadricipiti, dorsali) cambiano gradiente da scuro a ciano/viola elettrico in base al volume di allenamento cumulato negli ultimi 7/30 giorni.
* **Impatto:** Ottimo feedback visivo per capire subito quali muscoli sono stati stimolati maggiormente.

---

### 3.3 🏆 AI Social Share Card Generator
* **Come funziona:** Al termine dell'allenamento, oltre al popup di celebrazione con i coriandoli, un pulsante "Condividi Progresso" genera un'immagine in formato verticale (adatta a Instagram Stories) in stile glassmorphism, contenente:
  - Il nome del workout e la data.
  - Statistiche chiave (es. "Tonnellaggio totale: 5400 kg", "Tempo di tensione: 42 min").
  - Record Personali battuti evidenziati con icone neon.
  - Una frase motivazionale epica e personalizzata generata sul momento da Gemini.
* **Impatto:** Aumenta l'engagement dell'utente e funge da marketing organico.

---

### 3.4 🎙️ Coach Vocale AI in Palestra (Hands-Free Assist)
* **Come funziona:** Durante la sessione di allenamento attiva, l'app guida l'utente tramite sintesi vocale (es. "Inizio recupero di 90 secondi", "Mancano 5 secondi alla prossima serie di Panca Piana"). Inoltre, implementando comandi vocali basilari (Speech-to-Text in-app), l'atleta può pronunciare "Serie completata" o "Pausa" senza dover toccare lo schermo dello smartphone con le mani sudate o i guanti da allenamento.
* **Impatto:** Rivoluzionario dal punto di vista dell'usabilità pratica durante le sessioni intense.

---

### 3.5 🎮 Sfide e Quest Settimanali (AI-Generated Quests)
* **Come funziona:** Ogni lunedì, Gemini analizza lo storico dell'utente e genera 3 "Quest" personalizzate della settimana (es. *"La sfida del volume: solleva un totale di 12.000 kg"*, *"Costanza di ferro: allenati 4 volte questa settimana con almeno 90 secondi di recupero"*, *"PR Hunter: stabilisci un nuovo record personale nel Curl Bicipiti"*). Completando le sfide l'utente guadagna XP (Punti Esperienza) scalando i livelli dell'atleta (es. Livello 1: Novizio, Livello 10: Bestia d'Acciaio, Livello 20: Divinità del Ferro).
* **Impatto:** Incrementa drasticamente la gamification e la fidelizzazione all'uso quotidiano dell'app.