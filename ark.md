# ForgeFit — Analisi Tecnica e Funzionale

> Documento aggiornato il 2026-06-16. Riferimento: branch `main`.
> **v2.0.0 — Wearable Health, Gamification, and UX Enhancements**.
> Introdotto sistema di traguardi (Achievements), salvataggio su Google Fit / Apple Health, e major upgrade visivo con animazioni Lottie, statistiche interattive e offline-first cloud badge.

---

## 1. Panoramica del Progetto

**ForgeFit** è un sistema completo per la gestione del fitness personale, composto da:

- **App mobile Flutter** (Android, iOS, Web) — il "coach tascabile" del cliente
- **Backend FastAPI** (Python) — il cervello e il database centrale
- **Dashboard web** (HTML statico servita dal backend) — pannello di controllo per il Personal Trainer

Il sistema permette di:
- Autenticarsi con un account personale (JWT + refresh token)
- Scaricare la scheda di allenamento personalizzata assegnata dal trainer
- Eseguire sessioni con timer, tracciamento serie, peso e reps
- Consultare lo storico su calendario
- Visualizzare statistiche di volume e stime 1RM (formula Epley)
- Ricevere suggerimenti di progressive overload automatici basati sullo storico
- Inviare report all'AI (Gemini via backend) per feedback personalizzati
- Tracciare le misurazioni biometriche nel tempo con grafici di tendenza
- Sbloccare le funzionalità AI tramite codice HMAC-SHA256 verificato server-side

| Voce | Dettaglio |
|---|---|
| Framework frontend | Flutter 3.x / Dart ≥ 3.2 |
| Target | Android (minSdk 21), iOS, Web |
| Package name | `it.nexusitsolutions.forgefit` |
| Framework backend | FastAPI 0.x / Python 3.11 |
| DB backend | SQLite (via SQLAlchemy ORM) |
| DB locale (app) | Hive (NoSQL binary, 5 box) |
| Auth | JWT Bearer HS256, access 7gg + refresh 30gg |
| AI | Google Gemini (gemini-3.5-flash default) |
| Deployment | Docker + docker-compose su Portainer |

---

## 2. Struttura del Monorepo

```
ForgeFit/                        ← radice del monorepo (git)
├── docker-compose.yml           ← orchestrazione frontend:8083 + backend:8100
├── .gitignore                   ← regole per Flutter, Python, Docker, OS
├── ark.md                       ← questo documento
│
├── frontend/                    ← Flutter app
│   ├── pubspec.yaml             # name: forgefit
│   ├── Dockerfile               # multi-stage: Flutter build → Nginx serve
│   ├── nginx.conf               # serve dist web su porta 80
│   ├── lib/
│   │   ├── main.dart            # Entry point — init Hive, interceptor 401
│   │   ├── core/
│   │   │   ├── api_config.dart  # URL endpoint centralizzati
│   │   │   ├── api_service.dart # Client HTTP REST (singleton statico + retry 401)
│   │   │   ├── auth_service.dart# Gestione JWT/refresh + decodifica exp
│   │   │   └── theme.dart       # Design system Cyber-Glassmorphism
│   │   ├── data/
│   │   │   └── database_service.dart  # CRUD Hive + parser JSON scheda
│   │   ├── models/
│   │   │   ├── training_data.dart     # ExerciseSet, Exercise, TrainingDay
│   │   │   ├── completed_workout.dart # CompletedWorkout + Hive adapters
│   │   │   ├── user_profile.dart      # Profilo utente + Hive adapter (typeId=3)
│   │   │   └── biometric_record.dart  # Misurazioni + Hive adapter (typeId=4)
│   │   ├── screens/
│   │   │   ├── splash_screen.dart          # Splash + auto-login + check JWT exp
│   │   │   ├── auth_screen.dart            # Login + Registrazione
│   │   │   ├── main_screen.dart            # Shell BottomNavigationBar (5 tab)
│   │   │   ├── home_screen.dart            # Dashboard — lista giorni scheda
│   │   │   ├── day_detail_screen.dart      # Dettaglio giorno — lista esercizi
│   │   │   ├── active_session_screen.dart  # Sessione attiva — timer + serie + overload hint
│   │   │   ├── history_screen.dart         # Calendario storico allenamenti
│   │   │   ├── statistics_screen.dart      # Grafici volume + 1RM Epley
│   │   │   ├── analysis_screen.dart        # Misurazioni + sblocco AI + report + trend button
│   │   │   ├── biometric_trends_screen.dart# Grafici fl_chart per 9 misure corporee
│   │   │   └── setup_screen.dart           # Sync + export/import backup + sicurezza
│   │   └── widgets/
│   │       └── rest_timer_widget.dart # Timer countdown recupero circolare
│   ├── android/                 # Kotlin MainActivity (package: it.nexusitsolutions.forgefit)
│   ├── ios/                     # Swift Runner
│   ├── web/                     # PWA (index.html, manifest, icons)
│   ├── assets/
│   │   ├── images/splash.png
│   │   └── icona.png
│   └── test/
│
└── backend/                     ← FastAPI server
    ├── main.py                  # Entry point: CORS, endpoint, seeding DB
    ├── auth.py                  # JWT utilities + bcrypt + get_current_user
    ├── models.py                # SQLAlchemy ORM models
    ├── schemas.py               # Pydantic request/response schemas
    ├── database.py              # SQLite engine + session factory
    ├── ai_service.py            # Gemini API client + prompt builder
    ├── config_manager.py        # admin_config.json (credenziali PT)
    ├── requirements.txt         # Python dependencies (versioni pinnate)
    ├── Dockerfile               # python:3.11-slim + uvicorn
    ├── data/                    # fitness.db (SQLite, montato come volume Docker)
    └── static/                  # Dashboard HTML del Personal Trainer
        ├── index.html
        ├── policy.html
        └── ai-loader.png
```

---

## 3. Architettura Applicativa

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter App (frontend/)                  │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │ Screens  │  │ Widgets  │  │  Models  │  │   Theme    │  │
│  └────┬─────┘  └──────────┘  └────┬─────┘  └────────────┘  │
│       │                           │                         │
│  ┌────▼───────────────────────────▼─────┐                   │
│  │          core/api_service.dart       │                   │
│  │  HTTP client + auth headers          │                   │
│  │  retry trasparente su 401 via        │                   │
│  │  refresh token (_RetryWithNewToken)  │                   │
│  └─────────────────┬────────────────────┘                   │
│                    │                                        │
│  ┌─────────────────▼────────────────────┐                   │
│  │        core/auth_service.dart        │                   │
│  │  access_token + refresh_token        │                   │
│  │  SharedPreferences — decodifica exp  │                   │
│  └──────────────────────────────────────┘                   │
│                                                             │
│  ┌───────────────────────────────────────┐                  │
│  │       data/database_service.dart      │                  │
│  │  Hive CRUD + parser JSON scheda       │                  │
│  │  5 box: workouts, profile, biometrics,│                  │
│  │         settings, training_plan       │                  │
│  └───────────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
                 │ HTTP REST (JWT Bearer)
                 ▼
┌─────────────────────────────────────┐
│   Backend FastAPI (backend/)        │
│   fitconsole.ghome.it               │
│   (o localhost:8100 in locale)      │
│                                     │
│  POST /api/auth/login               │
│  POST /api/auth/register            │
│  POST /api/auth/refresh             │
│  POST /api/auth/setup               │
│  GET  /api/auth/me                  │
│  PUT  /api/auth/change-password     │
│  POST /api/auth/unlock-ai           │
│  GET  /api/auth/ai-unlock-code      │
│  GET  /api/plans/{user_id}          │
│  POST /api/plans/{user_id}          │
│  GET  /api/plans/{user_id}/history  │
│  POST /api/plans/generate-ai        │
│  GET  /api/workouts/suggestions/… │
│  POST /api/workouts/save            │
│  POST /api/measurements             │
│  POST /api/analysis/generate        │
│  POST /api/ai/analyze               │
│  GET  /api/users                    │
│  GET  /api/catalog                  │
│  GET  /api/system/backup            │
│  GET  /api/system/settings          │
└─────────────────────┬───────────────┘
                      │
              ┌───────▼──────────┐
              │  SQLite / Hive   │
              │  + Google Gemini │
              └──────────────────┘
```

### 3.1 Docker Compose

```yaml
# docker-compose.yml (root)
frontend:8083  ← Flutter web build servita da Nginx
backend:8100   ← FastAPI + SQLite (volume backend_data)
               (interno container: 8000 → host: 8100)
```

Avvio locale: `docker-compose up -d --build`
Stop: `docker-compose down`

---

## 4. Backend — Architettura Python

### 4.1 File principali

| File                | Responsabilità                                                                                                                                         |
| ---------------------| --------------------------------------------------------------------------------------------------------------------------------------------------------|
| `main.py`           | FastAPI app, tutti gli endpoint REST, seeding catalogo esercizi                                                                                        |
| `auth.py`           | `hash_password`, `verify_password`, `create_access_token`, `create_refresh_token`, `decode_token`, `decode_refresh_token`, `get_current_user`          |
| `models.py`         | SQLAlchemy ORM: `User`, `WorkoutPlan` (con versioning), `WorkoutLog`, `Measurement`, `ExerciseCatalog`, `SystemSettings`                               |
| `schemas.py`        | Pydantic request/response: `UserCreate`, `TokenResponse`, `RefreshTokenRequest`, `WorkoutPlanCreate`, `WorkoutPlanHistoryItem`, `AIGenerateRequest`, … |
| `database.py`       | `engine` SQLite + `SessionLocal` + `get_db` dependency                                                                                                 |
| `ai_service.py`     | `get_model(db)` — carica chiave Gemini e modello configurato; `generate_athlete_analysis_prompt()`                                                     |
| `config_manager.py` | Lettura/scrittura `admin_config.json` (credenziali Personal Trainer)                                                                                   |

### 4.2 Autenticazione backend

Il backend ha due tipi di utente:
- **Admin (Personal Trainer)**: credenziali in `admin_config.json`, ruolo `admin`, ID fittizio `0`
- **Cliente**: in SQLite (`User`), ruolo `client`

La dipendenza `get_current_user` gestisce entrambi: controlla prima il file admin, poi il DB.

Il JWT ha:
- Algoritmo: HS256
- `sub`: email dell'utente
- `type`: `"access"` o `"refresh"`
- `exp`: access = +7 giorni, refresh = +30 giorni
- Chiave: `JWT_SECRET_KEY` da env var — **fail-fast all'avvio se non impostata**

### 4.3 Database SQLite (ORM)

| Tabella | Campi principali |
|---|---|
| `users` | id, email, first_name, last_name, age, weight, height, biceps, chest, hips, waist, thigh, calf, neck, wrist, gender, hashed_password, role |
| `workout_plans` | id, user_id (FK), plan_json, **version** (int), **label** (str, nullable), **created_at** |
| `workout_logs` | id, user_id (FK), date, duration_seconds, exercises_json |
| `measurements` | id, user_id (FK), created_at, weight, chest, waist, hips, biceps, thigh, calf, neck, wrist, goal |
| `exercise_catalog` | id, nome, gruppo_muscolare, default_serie, default_ripetizioni, default_recupero_secondi, default_note, video_url |
| `system_settings` | key, value (es. `ai_model`, `ai_api_key_override`) |

---

## 5. Hive Box Map (Frontend)

| Box Name | TypeAdapter | TypeId | Contenuto |
|---|---|---|---|
| `completed_workouts` | `CompletedWorkoutAdapter` | 0 | Allenamenti completati |
| — | `CompletedExerciseAdapter` | 1 | Esercizi per allenamento |
| — | `CompletedSetAdapter` | 2 | Serie per esercizio |
| `user_profile` | `UserProfileAdapter` | 3 | Profilo utente |
| `biometric_records` | `BiometricRecordAdapter` | 4 | Misurazioni fisiche (key = data ISO) |
| `settings` | — | — | `user_email`, `user_id`, `ai_activation_date`, `jwt_refresh_token` |
| `training_plan` | — | — | `current` → JSON raw della scheda (persistenza offline) |

---

## 6. Flussi Funzionali

### 6.1 Flusso di Autenticazione (con Refresh Token)

```
App Start
    │
    ▼
SplashScreen
    │
    ├─── AuthService.isLoggedIn()?
    │      ├── token null/empty → FALSE
    │      └── JWT exp decodificato (base64url):
    │           exp < now → auto-logout → FALSE
    │           exp >= now → TRUE
    │
    ├─── NO ──► AuthScreen (Login / Register)
    │             POST /api/auth/login
    │               → access_token (7gg) + refresh_token (30gg)
    │               → saveToken(), saveRefreshToken(), saveUserId(), saveEmail()
    │
    └── YES ──► MainScreen (BottomNavBar 5 tab)

Su 401 in qualsiasi richiesta protetta:
    ApiService._checkUnauthorizedAsync()
    ├─ ha refresh_token? → POST /api/auth/refresh → nuovo access_token
    │    └─ ok → salva e riprova la richiesta originale (_RetryWithNewToken)
    └─ no / refresh scaduto → logout forzato → AuthScreen
```

### 6.2 Flusso Sincronizzazione Scheda

```
HomeScreen (o SetupScreen) → initState
    │
    ├─ DatabaseService.loadCachedPlan()  ← Hive training_plan box
    │    └─ plan trovato? → _days = cached (no rete, immediato)
    │
    ▼ [Pulsante cloud_sync]
    │
ApiService.getPlans(userId)  ← GET /api/plans/{user_id}
    │                           (ritorna versione più recente)
    ├─ DatabaseService.saveRawPlan(planMap)   ← persiste su Hive
    └─ parseTrainingDaysFromJson(planMap) → setState(_days)
```

### 6.3 Flusso Sessione di Allenamento (con Progressive Overload)

```
DayDetailScreen → [INIZIA ESERCIZIO]
    │
    ▼
ActiveSessionScreen(exercise)
    │
    ├─ Carica storico da Hive (pre-popola kg/reps)
    ├─ ApiService.getOverloadSuggestions(userId)
    │    └─ GET /api/workouts/suggestions/{user_id}
    │         analizza ultime 3 sessioni per esercizio
    │         → suggestedWeight (+2.5kg se 2+ sessioni on-target)
    │         → mostrato sotto "Record precedente" in card
    ├─ Stopwatch 1s (Time Under Tension)
    │
    ▼ LOOP SERIE:
    │  _completeActiveSet() → RestTimerWidget (countdown recupero_secondi)
    │  Ultima serie → _showNerdStats()
    │    kcal = MET(5.0) × peso_kg × durata_ore  (ACSM)
    │
    ▼ [TERMINA SESSIONE]
    │
DayDetailScreen._finishWorkout()
    ├─ DatabaseService.saveWorkout()        ← Hive (offline)
    └─ ApiService.saveWorkout()             ← backend POST /api/workouts/save
         └─ errore? → solo offline + warning snackbar
```

### 6.4 Flusso Sblocco AI (HMAC-SHA256 — server-side)

```
AnalysisScreen → [AI bloccata]
    │
    ▼ _unlockAI(code):
    │
    ApiService.unlockAI(code: input_utente)
    │  POST /api/auth/unlock-ai
    │
    ▼ Backend verifica:
    │  expected = HMAC-SHA256(JWT_SECRET_KEY, "{year}-W{week}")[:8]
    │  compare_digest(code, expected)  ← timing-safe
    │  code errato → { "valid": false }
    │  code ok     → { "valid": true, "expires_at": "domenica 23:59:59 UTC" }
    │
    ├─ valid=false → SnackBar errore
    └─ valid=true  → DatabaseService.saveAIActivationDate(now) → sblocco UI

Admin può ottenere il codice corrente:
    GET /api/auth/ai-unlock-code  (solo ruolo admin)
```

### 6.5 Flusso Grafici Trend Misure Corporee

```
AnalysisScreen → [Vedi Trend Misure Corporee]
    │
    ▼
BiometricTrendsScreen
    │
    DatabaseService.getAllBiometricRecords()  ← Hive biometric_records box
    │
    ├─ Ordina per data crescente
    ├─ Per ciascuna delle 9 misure (peso, fianchi, petto, bicipite,
    │   vita, coscia, polpaccio, collo, polso):
    │     → FlSpot list (indice → valore)
    │     → se < 2 punti: card saltata
    │     → LineChart fl_chart con:
    │          curva smussata, gradiente sotto, dot sui punti
    │          tooltip interattivo (valore + data)
    │          delta prima↔ultima misurazione (verde/rosso)
    └─ Animazione in cascata (flutter_animate)
```

### 6.6 Flusso Statistiche

```
StatisticsScreen
    │
    ValueListenableBuilder(workoutBoxListenable())
    │
    ├─ Best Set (max peso assoluto)
    ├─ Volume Medio per sessione
    ├─ Ore Totali allenamento
    ├─ LineChart "Tonnellaggio Totale" (ultimi 7 allenamenti)
    ├─ LineChart "Stima 1RM — {esercizio più frequente}"
    │    formula Epley: weight * (1 + reps/30)
    └─ Volume per Distretto Muscolare (gruppoMuscolare)
```

---

## 7. Modello Dati (Frontend)

```
TrainingDay
├── id: String            (es. 'd1', 'd2' — generato lato client)
├── title: String         (es. "Lunedì", "PUSH")
├── subtitle: String      (es. "Petto e Spalle")
├── priority: String      (sempre vuoto — il server non lo invia)
└── exercises: List<Exercise>

Exercise
├── id: String            (es. 'ex_0' — generato lato client)
├── name: String
├── loadNote: String      (stringa ripetizioni: "8-10", "AMRAP")
├── videoUrl: String
├── externalNote: String? (note_esecuzione dal trainer)
├── gruppoMuscolare: String?
└── sets: List<ExerciseSet>

ExerciseSet
├── number: int           (1-based)
├── targetReps: int       (primo numero da ripetizioni)
├── actualReps: int       (compilato durante la sessione)
├── weight: double
├── targetRestSeconds: int  (chiave JSON: recupero_secondi, fallback: recupero)
├── isCompleted: bool
└── timeUnderTension: int (secondi da stopwatch)

CompletedWorkout
├── id: String            (UUID v4)
├── title: String
├── date: DateTime
├── durationSeconds: int
└── exercises: List<CompletedExercise>

BiometricRecord                     ← sentinel -1.0 per nullable
├── date: DateTime                  (chiave Hive)
├── weight: double
├── hips, biceps, chest: double
└── waist, thigh, calf, neck, wrist: double?  (-1.0 = non misurato)
```

---

## 8. Fix e Feature Applicati (v3)

### Bug fix (18 totali)

| # | Tipo | Fix |
|---|---|---|
| 1 | 🔴 Critico | `ai_analyze_passthrough`: aggiunto `db: Session = Depends(get_db)` mancante |
| 2 | 🔴 Critico | `docker-compose`: `GEMINI_API_KEY` (host) → `GOOGLE_API_KEY` (container) |
| 3 | 🔴 Critico | Chiave `recupero_secondi` allineata tra prompt AI e parser Flutter (con fallback `recupero`) |
| 4 | 🔴 Critico | `export_users_csv`: gate admin con 403 se ruolo ≠ admin |
| 5 | 🟠 Sicurezza | `JWT_SECRET_KEY`: fail-fast all'avvio se env var non impostata |
| 6 | 🟠 Sicurezza | CORS: rimosso wildcard `*`, configurabile via `ALLOWED_ORIGINS` env var |
| 7 | 🟠 Sicurezza | AI unlock: sostituito `forza{week}` con HMAC-SHA256 (timing-safe) |
| 8 | 🟡 UX | `dateOfBirth`: corretto da 1° gennaio a 1° luglio (errore medio da 6→3 mesi) |
| 9 | 🟡 Data | `list_users`: evitata mutazione di oggetti ORM attivi (usa Pydantic `model_validate`) |
| 10 | 🟡 UX | Stima kcal: formula MET × peso_kg × durata_ore (ACSM, MET=5.0) |
| 11 | 🟡 API | `WorkoutLogResponse.exercises`: da stringa grezza JSON a campo `Any` deserializzato |
| 12 | 🟡 Debito | Rimosso `onboarding_screen.dart` (codice morto con type error) |
| 13 | 🟡 Debito | `requirements.txt`: tutte le versioni pinnate |
| 14 | 🔴 Critico | **Frontend Hive Fallback**: Gestione e recovery automatico `RangeError` per box corrotti (`Hive.deleteBoxFromDisk`) |
| 15 | 🟠 Importante | **Frontend Logout Clean**: Implementato `DatabaseService.clearAllData()` per svuotare interamente i box locali al logout |
| 16 | 🟠 Importante | **Frontend Interceptor 401**: Intercettazione globale 401 via `navigatorKey` per forzare il logout sicuro |
| 17 | 🔴 Critico | **Backend Rate Limiter**: Corretta firma parametro `request` in `auth_login` per prevenire crash `slowapi` in produzione |
| 18 | 🔴 Critico | **Backend AI Schemas**: Aggiunto `AIAnalyzeResponse` mancante e corretto mapping Pydantic in `/api/ai/analyze-passthrough` |

### Feature (4 totali)

| # | Feature | Descrizione |
|---|---|---|
| F1 | **Refresh Token** | `POST /api/auth/refresh`, retry 401 trasparente in Flutter, sessione valida 30gg |
| F2 | **Versioning Piani** | Ogni assegnazione crea nuova riga con `version++`; storico via `GET /api/plans/{id}/history` |
| F3 | **Progressive Overload** | `GET /api/workouts/suggestions/{user_id}`: +2.5kg se 2+ sessioni on-target; hint in sessione attiva |
| F5 | **Trend Misure** | `BiometricTrendsScreen`: grafici `fl_chart` per 9 misure, delta primo↔ultimo, tooltip interattivo |

---

## 9. Endpoint API — Riepilogo Completo

| Metodo | Endpoint | Auth | Tag | Descrizione |
|---|---|---|---|---|
| `POST` | `/api/auth/login` | NO | Auth | Login → access_token + refresh_token + userId + role |
| `POST` | `/api/auth/register` | JWT (admin) | Auth | Crea utente con password (PT) |
| `POST` | `/api/auth/refresh` | NO | Auth | Rinnova access_token tramite refresh_token |
| `POST` | `/api/auth/setup` | NO | Auth | Configura primo avvio PT |
| `GET` | `/api/auth/setup-status` | NO | Auth | PT già configurato? |
| `GET` | `/api/auth/me` | JWT | Auth | Profilo + metriche calcolate |
| `PUT` | `/api/auth/change-password` | JWT | Auth | Cambio password |
| `POST` | `/api/auth/unlock-ai` | JWT | Auth | Verifica codice AI HMAC-SHA256 |
| `GET` | `/api/auth/ai-unlock-code` | JWT (admin) | Auth | Restituisce codice corrente all'admin |
| `GET` | `/api/plans/{user_id}` | JWT | Schede | Scarica versione più recente della scheda |
| `POST` | `/api/plans/{user_id}` | JWT (admin) | Schede | Salva nuova versione scheda (version++) |
| `GET` | `/api/plans/{user_id}/history` | JWT (admin) | Schede | Storico tutte le versioni assegnate |
| `POST` | `/api/plans/generate-ai` | JWT | AI | Genera scheda con Gemini |
| `GET` | `/api/workouts/suggestions/{user_id}` | JWT | Allenamento | Suggerimenti progressive overload |
| `POST` | `/api/workouts/save` | JWT | Allenamento | Salva sessione completata |
| `POST` | `/api/measurements` | JWT | Misure | Aggiunge misurazione biometrica |
| `PUT` | `/api/measurements/{id}` | JWT | Misure | Aggiorna misurazione |
| `DELETE` | `/api/measurements/{id}` | JWT | Misure | Elimina misurazione |
| `POST` | `/api/analysis/generate` | JWT | AI | Report AI progressi |
| `POST` | `/api/ai/analyze` | JWT | AI | Passthrough Gemini generico |
| `GET` | `/api/users` | JWT (admin) | Utenti | Lista tutti i clienti |
| `DELETE` | `/api/users/{email}` | JWT (admin) | Utenti | Elimina utente + scheda |
| `GET` | `/api/users/export` | JWT (admin) | Utenti | Export CSV clienti |
| `POST` | `/api/users/import` | JWT (admin) | Utenti | Import CSV clienti (upsert) |
| `GET` | `/api/admin/clients/{id}/progress` | JWT | Utenti | Progressi completi cliente |
| `GET` | `/api/catalog` | NO | Catalogo | Lista esercizi |
| `GET` | `/api/catalog/{id}` | NO | Catalogo | Dettaglio esercizio |
| `POST` | `/api/catalog` | JWT (admin) | Catalogo | Aggiunge esercizio |
| `PUT` | `/api/catalog/{id}` | JWT (admin) | Catalogo | Aggiorna esercizio |
| `DELETE` | `/api/catalog/{id}` | JWT (admin) | Catalogo | Rimuove esercizio |
| `GET` | `/api/system/backup` | JWT (admin) | Sistema | Download database SQLite |
| `POST` | `/api/system/restore` | JWT (admin) | Sistema | Upload restore database |
| `GET` | `/api/system/models` | JWT (admin) | Sistema | Whitelist modelli AI |
| `GET` | `/api/system/settings` | JWT (admin) | Sistema | Impostazioni correnti |
| `PUT` | `/api/system/settings` | JWT (admin) | Sistema | Aggiorna modello AI / API key |

---

## 10. Design System — AppTheme

| Token | Valore | Uso |
|---|---|---|
| `bgTop` | `#090909` | Sfondo gradiente top |
| `bgBottom` | `#1A1A1A` | Sfondo gradiente bottom |
| `surface` | `#0F0F1A` | BottomNavBar |
| `surfaceVariant` | `#1A1A24` | Dialog, card |
| `cyan` | `#00E5FF` | Accento primario (PUSH, pulsanti) |
| `vividPurple` | `#BB86FC` | Accento secondario (PULL, AI) |
| `legsAccent` | `#00B8D4` | Accento gambe |
| `homeAccent` | `#E0B0FF` | Accento home/rest |
| Font body | Outfit (Google Fonts) | Tutto il testo |
| Font titoli | Orbitron (Google Fonts) | "FORGE FIT" banner |

Glassmorphism: `BackdropFilter` + `ImageFilter.blur` + bordo semitrasparente con gradiente lineare.

---

## 11. Dipendenze

### Frontend (pubspec.yaml)

| Package | Versione | Uso |
|---|---|---|
| `hive` / `hive_flutter` | ^2.2.3 | DB locale (5 box) |
| `shared_preferences` | ^2.2.3 | JWT token + email + refresh token |
| `http` | ^1.2.1 | Chiamate REST |
| `fl_chart` | ^0.68.0 | Grafici statistiche + trend misure corporee |
| `table_calendar` | ^3.1.2 | Calendario storico |
| `flutter_animate` | ^4.5.0 | Animazioni UI |
| `google_fonts` | ^6.1.0 | Font Outfit + Orbitron |
| `uuid` | ^4.3.3 | ID allenamenti |
| `url_launcher` | ^6.2.6 | Apertura video tutorial |
| `file_picker` | ^8.0.0 | Import backup |
| `file_saver` | ^0.3.1 | Export backup |

### Backend (requirements.txt — versioni pinnate)

| Package | Versione | Uso |
|---|---|---|
| `fastapi` | 0.115.5 | Framework HTTP |
| `uvicorn[standard]` | 0.32.1 | ASGI server |
| `sqlalchemy` | 2.0.36 | ORM SQLite |
| `pydantic` | 2.10.3 | Validazione dati |
| `PyJWT` | 2.10.1 | JWT encode/decode |
| `passlib[bcrypt]` | 1.7.4 | Hashing password |
| `bcrypt` | 3.2.2 | Backend bcrypt |
| `google-generativeai` | 0.8.3 | Gemini API |
| `python-dotenv` | 1.0.1 | .env loading |

---

## 12. Deployment

### Sviluppo locale

```bash
# Backend (porta 8000 interna, mappata 8100 in produzione)
cd backend
pip install -r requirements.txt
JWT_SECRET_KEY=dev_key uvicorn main:app --reload --port 8000

# Frontend
cd frontend
flutter pub get
flutter run -d chrome   # web
flutter run             # device connesso
```

### Produzione (Docker Compose)

```bash
# Dal root del monorepo
docker-compose up -d --build

# Logs
docker-compose logs -f backend
docker-compose logs -f frontend
```

Variabili d'ambiente da configurare (passate da Portainer o `.env`):

```env
JWT_SECRET_KEY=cambia_questa_chiave_in_produzione   # obbligatoria — fail-fast se assente
GEMINI_API_KEY=la_tua_api_key_google
ALLOWED_ORIGINS=https://forgefit.ghome.it,http://10.0.0.105:8083   # fallback, non più necessario con proxy
```

### Porte produzione

| Servizio | Porta host | Porta container | Note |
|---|---|---|---|
| Backend FastAPI | **8100** | 8000 | accesso diretto solo da rete interna Docker |
| Frontend Nginx | **8083** | 80 | reverse proxy su `forgefit.ghome.it`, include proxy `/api/` → backend |

> **Architettura Same-Origin (v1.1.4+):** Il frontend Nginx fa da reverse-proxy
> per tutte le chiamate `/api/` verso il container backend sulla rete Docker interna.
> Il browser vede una sola origin (`forgefit.ghome.it`), eliminando i problemi CORS.
> Il build web Flutter usa `API_BASE_URL=` (vuoto) → URL relative (`/api/...`).

### Deploy su Portainer (produzione)

Il deploy in produzione avviene tramite lo script PowerShell:

```
C:\Users\gianvito.bleve\OneDrive - Banca Mediolanum SPA\Documenti\Progetti\deploy - forgefit.ps1
o
C:\Users\gianv\Documents\Progetti\deploy - forgefit.ps1
```

| Parametro | Valore |
|---|---|
| Portainer URL | `https://docker.ghome.it` |
| Stack ID | `151` |
| Endpoint ID | `2` |
| Repository | `https://github.com/RazorCopter/ForgeFit.git` |
| Branch | `main` |
| Compose file | `docker-compose.yml` |

Flusso dello script:
1. Autentica su Portainer e ottiene un JWT
2. Legge la configurazione dello stack — se Git è collegato:
   - Ferma lo stack (libera le porte)
   - Attende 5 secondi
   - `PUT /api/stacks/151/git/redeploy` con `prune=true` e `pullImage=true`
   - Portainer scarica l'ultimo commit da GitHub e ricostruisce le immagini
3. Se Git non è collegato: stop → start (senza rebuild — solo riavvio)

**Workflow di deploy standard:**
```
git push origin main
# poi:
powershell -ExecutionPolicy Bypass -File "deploy - forgefit.ps1"
```

> Le credenziali Portainer sono nel file `.ps1` locale — non versionare nel repo.

---

## 14. Release Workflow

Al termine di ogni sviluppo seguire questi passi **nell'ordine indicato**:

### Passo 1 — Aggiorna la versione in `pubspec.yaml`

```
version: MAJOR.MINOR.PATCH+BUILD
```

- **PATCH** (+0.0.1): bugfix, piccole correzioni UI
- **MINOR** (+0.1.0): nuova funzionalità backward-compatible
- **MAJOR** (+1.0.0): breaking change o rilascio significativo
- **BUILD** (`+N`): incrementa sempre di 1 ad ogni rilascio

Esempio: `1.0.0+1` → `1.1.0+2`

### Passo 2 — Aggiorna `CHANGELOG.md`

Aggiungi una nuova sezione in cima al file con il formato:

```markdown
## [X.Y.Z] — YYYY-MM-DD

### Added
- Descrizione delle nuove funzionalità.

### Changed
- Descrizione delle modifiche a funzionalità esistenti.

### Fixed
- Descrizione dei bug risolti.

### Removed
- Descrizione delle funzionalità rimosse.
```

Ometti le sezioni vuote.

### Passo 3 — Commit e push

```bash
# Dalla radice del monorepo (ForgeFit/)
git add -A
git commit -m "chore: release vX.Y.Z

- Riepilogo breve delle modifiche principali"
git push origin main
```

### Passo 4 — Deploy locale (script)

```bash
# Dal root del monorepo
docker-compose down
docker-compose up -d --build
```

Verifica che entrambi i container siano `Up`:

```bash
docker-compose ps
```

Controlla i log in caso di errori:

```bash
docker-compose logs -f backend
docker-compose logs -f frontend
```

### Checklist rilascio

- [ ] `pubspec.yaml` → versione aggiornata
- [ ] `CHANGELOG.md` → sezione nuova in cima
- [ ] `git commit` con messaggio `chore: release vX.Y.Z`
- [ ] `git push origin main`
- [ ] `docker-compose up -d --build` eseguito con successo
- [ ] `docker-compose ps` → entrambi i container `Up`

---

## 13. Roadmap Future

| # | Feature | Nota |
|---|---|---|
| F4 | Notifiche push promemoria | Firebase Cloud Messaging |
| F6 | Esportazione PDF piano di allenamento | `pdf` package Flutter |
| F7 | Migrazione SQLite → PostgreSQL | via `DATABASE_URL` env var |
| F8 | Statistiche comparative multi-misura | sovrapponi misure sullo stesso grafico |
| — | Dark/Light theme toggle | AppTheme è solo dark |
| — | Backup automatico su backend | attualmente solo export manuale locale |
