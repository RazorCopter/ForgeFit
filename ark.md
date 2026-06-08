# ForgeFit — Analisi Tecnica e Funzionale

> Documento aggiornato il 2026-06-08. Riferimento: branch `main`.
> **v2 — Struttura Monorepo** (frontend/ + backend/).
> I 13 bug critici identificati in v1 sono stati tutti risolti.

---

## 1. Panoramica del Progetto

**ForgeFit** è un sistema completo per la gestione del fitness personale, composto da:

- **App mobile Flutter** (Android, iOS, Web) — il "coach tascabile" del cliente
- **Backend FastAPI** (Python) — il cervello e il database centrale
- **Dashboard web** (HTML statico servita dal backend) — pannello di controllo per il Personal Trainer

Il sistema permette di:
- Autenticarsi con un account personale (JWT 7gg)
- Scaricare la scheda di allenamento personalizzata assegnata dal trainer
- Eseguire sessioni con timer, tracciamento serie, peso e reps
- Consultare lo storico su calendario
- Visualizzare statistiche di volume e stime 1RM (formula Epley)
- Inviare report all'AI (Gemini via backend) per feedback personalizzati
- Tracciare le misurazioni biometriche nel tempo
- Sbloccare le funzionalità AI tramite codice settimanale verificato server-side

| Voce | Dettaglio |
|---|---|
| Framework frontend | Flutter 3.x / Dart ≥ 3.2 |
| Target | Android (minSdk 21), iOS, Web |
| Package name | `it.nexusitsolutions.forgefit` |
| Framework backend | FastAPI 0.x / Python 3.11 |
| DB backend | SQLite (via SQLAlchemy ORM) |
| DB locale (app) | Hive (NoSQL binary, 5 box) |
| Auth | JWT Bearer HS256, scadenza 7gg |
| AI | Google Gemini (gemini-2.5-flash default) |
| Deployment | Docker + docker-compose |

---

## 2. Struttura del Monorepo

```
ForgeFit/                        ← radice del monorepo (git)
├── docker-compose.yaml          ← orchestrazione frontend:8083 + backend:8000
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
│   │   │   ├── api_service.dart # Client HTTP REST (singleton statico)
│   │   │   ├── auth_service.dart# Gestione JWT + decodifica exp
│   │   │   └── theme.dart       # Design system Cyber-Glassmorphism
│   │   ├── data/
│   │   │   └── database_service.dart  # CRUD Hive + parser JSON scheda
│   │   ├── models/
│   │   │   ├── training_data.dart     # ExerciseSet, Exercise, TrainingDay
│   │   │   ├── completed_workout.dart # CompletedWorkout + Hive adapters
│   │   │   ├── user_profile.dart      # Profilo utente + Hive adapter (typeId=3)
│   │   │   └── biometric_record.dart  # Misurazioni + Hive adapter (typeId=4)
│   │   ├── screens/
│   │   │   ├── splash_screen.dart     # Splash + auto-login + check JWT exp
│   │   │   ├── auth_screen.dart       # Login + Registrazione
│   │   │   ├── main_screen.dart       # Shell BottomNavigationBar (5 tab)
│   │   │   ├── home_screen.dart       # Dashboard — lista giorni scheda
│   │   │   ├── day_detail_screen.dart # Dettaglio giorno — lista esercizi
│   │   │   ├── active_session_screen.dart # Sessione attiva — timer + serie
│   │   │   ├── history_screen.dart    # Calendario storico allenamenti
│   │   │   ├── statistics_screen.dart # Grafici volume + 1RM Epley
│   │   │   ├── analysis_screen.dart   # Misurazioni + sblocco AI + report
│   │   │   ├── setup_screen.dart      # Sync + export/import backup + sicurezza
│   │   │   └── onboarding_screen.dart # Onboarding primo accesso
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
    ├── requirements.txt         # Python dependencies
    ├── Dockerfile               # python:3.11-slim + uvicorn
    ├── data/                    # fitness.db (SQLite, montato come volume)
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
│  │     (HTTP client + auth headers)     │                   │
│  └─────────────────┬────────────────────┘                   │
│                    │                                        │
│  ┌─────────────────▼────────────────────┐                   │
│  │        core/auth_service.dart        │                   │
│  │  JWT token — SharedPreferences       │                   │
│  │  + decodifica exp per auto-logout    │                   │
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
│   (o localhost:8000 in locale)      │
│                                     │
│  POST /api/auth/login               │
│  POST /api/auth/register            │
│  POST /api/auth/setup               │
│  GET  /api/auth/me                  │
│  PUT  /api/auth/change-password     │
│  POST /api/auth/unlock-ai   ← NEW   │
│  GET  /api/plans/{user_id}          │
│  POST /api/plans/{user_id}          │
│  POST /api/plans/generate-ai        │
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
# docker-compose.yaml (root)
frontend:8083  ← Flutter web build servita da Nginx
backend:8000   ← FastAPI + SQLite (volume backend_data)
```

Avvio: `docker-compose up -d`
Stop: `docker-compose down`

---

## 4. Backend — Architettura Python

### 4.1 File principali

| File | Responsabilità |
|---|---|
| `main.py` | FastAPI app, tutti gli endpoint REST, seeding catalogo esercizi |
| `auth.py` | `hash_password`, `verify_password`, `create_access_token`, `decode_token`, `get_current_user` |
| `models.py` | SQLAlchemy ORM: `User`, `WorkoutPlan`, `WorkoutLog`, `Measurement`, `ExerciseCatalog`, `SystemSettings` |
| `schemas.py` | Pydantic request/response: `UserCreate`, `TokenResponse`, `WorkoutPlanCreate`, `AIGenerateRequest`, `UnlockAIRequest`, `UnlockAIResponse`, … |
| `database.py` | `engine` SQLite + `SessionLocal` + `get_db` dependency |
| `ai_service.py` | `get_model(db)` — carica chiave Gemini e modello configurato; `generate_athlete_analysis_prompt()` |
| `config_manager.py` | Lettura/scrittura `admin_config.json` (credenziali Personal Trainer) |

### 4.2 Autenticazione backend

Il backend ha due tipi di utente:
- **Admin (Personal Trainer)**: credenziali in `admin_config.json`, ruolo `admin`, ID fittizio `0`
- **Cliente**: in SQLite (`User`), ruolo `client`

La dipendenza `get_current_user` gestisce entrambi: controlla prima il file admin, poi il DB.

Il JWT ha:
- Algoritmo: HS256
- `sub`: email dell'utente
- `exp`: ora + 7 giorni
- Chiave: `JWT_SECRET_KEY` da `.env` (default `super_secret_cyberpunk_key` — **da cambiare in produzione**)

### 4.3 Database SQLite (ORM)

| Tabella | Campi principali |
|---|---|
| `users` | id, email, first_name, last_name, age, weight, height, biceps, chest, hips, waist, thigh, calf, neck, wrist, gender, hashed_password, role |
| `workout_plans` | id, user_id (FK), plan_json (TEXT JSON) |
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
| `settings` | — | — | `user_email`, `user_id`, `ai_activation_date` |
| `training_plan` | — | — | `current` → JSON raw della scheda (persistenza offline) |

---

## 6. Flussi Funzionali

### 6.1 Flusso di Autenticazione

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
    │             POST /api/auth/login  → JWT, userId, role
    │             POST /api/auth/register → JWT, userId
    │             → saveToken(), saveUserId(), saveEmail()
    │
    └── YES ──► MainScreen (BottomNavBar 5 tab)
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
DatabaseService.getUserId()
    │
ApiService.getPlans(userId)  ← GET /api/plans/{user_id}
    │
    ├─ risposta { "plan": { "giorni": [...] } }
    │
    ├─ DatabaseService.saveRawPlan(planMap)   ← persiste su Hive
    │
    └─ parseTrainingDaysFromJson(planMap) → setState(_days)
```

### 6.3 Flusso Sessione di Allenamento

```
DayDetailScreen → [INIZIA ESERCIZIO]
    │
    ▼
ActiveSessionScreen(exercise)
    │
    ├─ Carica storico da Hive (pre-popola kg/reps)
    ├─ Stopwatch 1s
    │
    ▼ LOOP SERIE:
    │  _completeActiveSet() → RestTimerWidget (countdown)
    │  Ultima serie → _showNerdStats()
    │
    ▼ [TERMINA SESSIONE]
    │
DayDetailScreen._finishWorkout()
    ├─ DatabaseService.saveWorkout()        ← Hive (offline)
    └─ ApiService.saveWorkout()             ← backend (POST /api/workouts/save)
         └─ errore? → solo offline + warning snackbar
```

### 6.4 Flusso Sblocco AI (sicuro — server-side)

```
AnalysisScreen → [AI bloccata]
    │
    ▼ _unlockAI(code):
    │
    ApiService.unlockAI(code: input_utente)
    │  POST /api/auth/unlock-ai
    │  Header: Authorization: Bearer {JWT}
    │  Body: { "code": "forza42" }
    │
    ▼ Backend verifica:
    │  expected = f"forza{iso_week_corrente}"  ← algoritmo non esposto al client
    │  code != expected → { "valid": false }
    │  code == expected → { "valid": true, "expires_at": "domenica 23:59:59 UTC" }
    │
    ├─ valid=false → SnackBar errore
    └─ valid=true  → DatabaseService.saveAIActivationDate(now) → sblocco UI
```

### 6.5 Flusso Statistiche

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
    │    ultimi 6 allenamenti, max per sessione
    │    empty state se nessun dato
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
├── targetRestSeconds: int
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

## 8. Fix Applicati (rispetto a v1)

Tutti i 13 bug identificati nell'analisi precedente sono stati risolti.

| # | Tipo | Fix |
|---|---|---|
| 1 | 🔴 Critico | `main.dart`: null-guard su `navigatorKey.currentContext` prima di `showSnackBar` |
| 2 | 🔴 Critico | Eliminato `android/.../nfcsniper/MainActivity.kt` (package residuo) |
| 3 | 🔴 Critico | Sblocco AI spostato su backend (`POST /api/auth/unlock-ai`) — algoritmo non esposto |
| 4 | 🔴 Critico | `BiometricRecordAdapter`: sentinel `-1.0` per campi nullable (coerente con `UserProfileAdapter`) |
| 5 | 🟠 Importante | Scheda persistita su Hive box `training_plan` — sopravvive ai riavvii |
| 6 | 🟠 Importante | `SetupScreen._syncScheda()` ora chiama `saveRawPlan()` — HomeScreen si aggiorna |
| 7 | 🟠 Importante | Grafico 1RM: dati mock rimossi, formula Epley su allenamenti reali |
| 8 | 🟠 Importante | Export/Import backup esposti in `SetupScreen` (FileSaver + FilePicker) |
| 9 | 🟡 Debito | `AuthService.isLoggedIn()` decodifica `exp` JWT — auto-logout se scaduto |
| 10 | 🟡 Debito | Tutti i `print()` sostituiti con `debugPrint()` |
| 11 | 🟡 Debito | `pubspec.yaml`: `name: my_training_log` → `name: forgefit` |
| 12 | 🟡 Debito | Rimosso sort alfabetico giorni — preserva ordine del trainer |
| 13 | 🟡 Debito | Eliminati `mock_data.dart`, `_mergeWorkouts()`, `youtube_player_iframe` |

---

## 9. Endpoint API — Riepilogo Completo

| Metodo | Endpoint | Auth | Tag | Descrizione |
|---|---|---|---|---|
| `POST` | `/api/auth/login` | NO | Auth | Login → JWT + userId + role |
| `POST` | `/api/auth/register` | JWT (admin) | Auth | Crea utente con password (PT) |
| `POST` | `/api/auth/setup` | NO | Auth | Configura primo avvio PT |
| `GET` | `/api/auth/setup-status` | NO | Auth | PT già configurato? |
| `GET` | `/api/auth/me` | JWT | Auth | Profilo + metriche calcolate |
| `PUT` | `/api/auth/change-password` | JWT | Auth | Cambio password |
| `POST` | `/api/auth/unlock-ai` | JWT | Auth | **Verifica codice AI (server-side)** |
| `GET` | `/api/plans/{user_id}` | JWT | Schede | Scarica scheda + arricchimento video |
| `POST` | `/api/plans/{user_id}` | JWT (admin) | Schede | Salva/aggiorna scheda |
| `POST` | `/api/plans/generate-ai` | JWT | AI | Genera scheda con Gemini |
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
| `shared_preferences` | ^2.2.3 | JWT token + email |
| `http` | ^1.2.1 | Chiamate REST |
| `fl_chart` | ^0.68.0 | Grafici statistiche (1RM Epley, volume) |
| `table_calendar` | ^3.1.2 | Calendario storico |
| `flutter_animate` | ^4.5.0 | Animazioni UI |
| `google_fonts` | ^6.1.0 | Font Outfit + Orbitron |
| `uuid` | ^4.3.3 | ID allenamenti |
| `url_launcher` | ^6.2.6 | Apertura video tutorial |
| `file_picker` | ^8.0.0 | Import backup |
| `file_saver` | ^0.3.1 | Export backup |

### Backend (requirements.txt)

| Package | Uso |
|---|---|
| `fastapi` | Framework HTTP |
| `uvicorn[standard]` | ASGI server |
| `sqlalchemy` | ORM SQLite |
| `pydantic[email]` | Validazione dati |
| `python-multipart` | Upload file |
| `PyJWT>=2.0.0` | JWT encode/decode |
| `passlib[bcrypt]` / `bcrypt==3.2.2` | Hashing password |
| `google-generativeai>=0.5.2` | Gemini API |
| `python-dotenv` | .env loading |

---

## 12. Deployment

### Sviluppo locale

```bash
# Backend
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000

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

Variabili d'ambiente da configurare in `.env`:
```env
JWT_SECRET_KEY=cambia_questa_chiave_in_produzione
GEMINI_API_KEY=la_tua_api_key_google
```

---

## 13. Roadmap Future

| # | Feature | Nota |
|---|---|---|
| 4.1 | Refresh token JWT | Evitare logout forzato su token scaduto |
| 4.2 | Notifiche push promemoria | Firebase Messaging |
| 4.3 | Grafico progressi biometrici | Linea peso nel tempo (fl_chart) |
| 4.4 | Onboarding interattivo | Completare `onboarding_screen.dart` |
| 4.5 | Generazione scheda AI in-app | Integrare `generateAIPlan()` già presente in ApiService |
| 4.6 | Dark/Light theme toggle | AppTheme è solo dark |
| 4.7 | Backup automatico su backend | Attualmente solo export manuale locale |
