🔍 Audit Completo — ForgeFit v1.9.8
Indice
Criticità (da risolvere)
Miglioramenti Grafici / UX
Nuove Funzionalità Proposte
🔴 1. Criticità
1.1 🔒 CORS Wildcard in Produzione
File: 
main.py

python

allow_origin_regex=".*",  # ⚠️ Accetta QUALSIASI origin
Hai configurato una lista di allowed_origins (riga 380), ma poi aggiungi allow_origin_regex=".*" che bypassa completamente la whitelist. Qualsiasi sito web può fare richieste autenticate al tuo backend.

CAUTION

Impatto: Un attaccante potrebbe creare una pagina malevola che, se visitata da un utente loggato, esegue operazioni sul suo account (CSRF via CORS). Fix: Rimuovere allow_origin_regex=".*" dalla configurazione CORS.

1.2 🔑 Credenziali Hardcoded nello Script di Deploy
File: 
deploy - forgefit.ps1

powershell

$Username = "admin"
$Password = "gianvitobleve"
La password di Portainer è scritta in chiaro nello script. Chiunque abbia accesso al file (o al repo se viene committato) può accedere alla dashboard Docker.

WARNING

Fix: Leggere le credenziali da variabili d'ambiente o da un file .env separato e gitignored.

1.3 ⚠️ Migrazione DB Manuale con sqlite3 Diretto
File: 
main.py

python

import sqlite3
conn = sqlite3.connect("./data/fitness.db")
conn.execute("ALTER TABLE workout_logs ADD COLUMN title VARCHAR")
conn.commit()
conn.close()
Stai aprendo una connessione SQLite raw bypassando SQLAlchemy per aggiungere una colonna. Questo:

Non è idempotente in modo pulito (l'errore viene silentemente ignorato)
Potrebbe creare conflitti con il pool di connessioni di SQLAlchemy
Non scala se aggiungi altre migrazioni
IMPORTANT

Fix: Usare Alembic per le migrazioni, oppure almeno fare l'ALTER TABLE via il motore SQLAlchemy (engine.execute()).

1.4 🧹 Import Inutilizzato youtube_player_iframe nel Build Tree
File: 
day_detail_screen.dart

dart

import 'package:youtube_player_iframe/youtube_player_iframe.dart';
Questo import è usato solo nel dialog _VideoPlayerDialog, ma il widget _YoutubeThumbnailWidget è stato già refactored per usare le thumbnail. L'import è comunque necessario per il dialog, ma il pacchetto youtube_player_iframe potrebbe essere rimosso dal pubspec.yaml se si usasse url_launcher per aprire YouTube direttamente nel browser, risparmiando ~5MB di dimensione APK.

1.5 🎨 getAccentForDay() Non Funziona con ID Dinamici
File: 
theme.dart

dart

static Color getAccentForDay(String dayId) {
    switch (dayId) {
      case 'd1': return pushAccent;
      case 'd2': return pullAccent;
      case 'd3': return legsAccent;
      case 'd4': return homeAccent;
      default: return vividPurple;  // ⚠️ Tutti i giorni oltre d4 hanno lo stesso colore
    }
}
Quando il backend genera schede con ID dinamici (es. petto_spalle, gambe_glutei), tutti i giorni ricevono lo stesso colore viola. Non c'è differenziazione visiva.

WARNING

Fix: Generare colori con un hash dell'ID del giorno, oppure usare una palette ciclica basata sull'indice del giorno nella lista.

1.6 📺 YouTube Shorts Non Parsati Correttamente
File: 
day_detail_screen.dart

dart

String? _getVideoId(String url) {
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'];  // Non matcha /shorts/VIDEO_ID
    }
}
Nel catalogo esercizi hai URL come https://www.youtube.com/shorts/U5Fi0VQpzmc (es. "Estensioni dietro nuca"). Il parser non gestisce il path /shorts/, quindi il video non viene mostrato per questi esercizi.

IMPORTANT

Fix: Aggiungere il parsing di /shorts/VIDEO_ID nel metodo _getVideoId().

1.7 🔁 Pattern Retry Duplicato in api_service.dart
File: 
api_service.dart

Il pattern doRequest → _checkUnauthorizedAsync → catch _RetryWithNewToken → doRequest → _checkUnauthorized è ripetuto identico in 5 metodi (getPlans, getPlanHistory, getWorkoutHistory, getBiometricHistory, deleteWorkout). Questo viola il principio DRY e rende le modifiche future error-prone.

TIP

Fix: Estrarre un metodo generico _authenticatedRequest<T>(Future<http.Response> Function(Map<String, String>) requestFn).

1.8 💾 declarative_base() è Deprecato
File: 
database.py

python

from sqlalchemy.ext.declarative import declarative_base
Base = declarative_base()
declarative_base() è deprecato da SQLAlchemy 2.0. Il modo moderno è:

python

from sqlalchemy.orm import DeclarativeBase
class Base(DeclarativeBase):
    pass
🎨 2. Miglioramenti Grafici / UX
2.1 🌈 Colori Dinamici per i Giorni di Allenamento
Attualmente tutti i giorni oltre d4 hanno lo stesso colore. Propongo di generare una palette ciclica con 8-10 colori vibranti che si assegnano automaticamente in base all'indice del giorno nella lista. Ogni giorno avrà un'identità visiva unica.

2.2 📊 Grafici Interattivi con Touch
I grafici fl_chart attualmente non hanno touchData configurato. Aggiungendo LineTouchData con tooltip, l'utente potrebbe toccare un punto del grafico e vedere il valore esatto (es. "12 Giugno: 4500kg volume").

2.3 🎭 Animazione Lottie per Stati Vuoti
Sostituire le icone statiche degli stati vuoti (es. "Nessun allenamento registrato") con animazioni Lottie leggere (~30KB ciascuna). Un bilanciere che oscilla, un grafico che cresce. Effetto "wow" garantito.

2.4 🏋️ Card Esercizio con Indicatore di Gruppo Muscolare
Aggiungere un chip colorato con il nome del gruppo muscolare (es. "Petto", "Schiena") nella card dell'esercizio in DayDetailScreen. Rende la scansione visiva molto più rapida.

2.5 ⏱️ Timer di Recupero con Animazione Circolare Migliorata
Il timer di recupero potrebbe avere un effetto "glow" pulsante quando mancano gli ultimi 5 secondi, con cambio colore progressivo da cyan a rosso. Aumenta l'urgenza visiva.

2.6 📱 Bottom Navigation Bar con Indicatore Animato
La bottom nav bar attuale usa l'indicatore standard di Material. Propongo un indicatore custom con un dot animato che scorre sotto l'icona selezionata, con effetto glow nel colore accent.

2.7 🎉 Celebrazione Fine Allenamento Migliorata
Il dialog di "Ottimo Lavoro!" è funzionale ma statico. Propongo di aggiungere:

Confetti (il pacchetto è già nel pubspec.yaml!) — attualmente non usato da nessuna parte nel codice
Animazione contatore per volume/tempo/kcal che conta da 0 al valore finale
2.8 📈 Heatmap Calendario Allenamenti
Nella sezione statistiche, aggiungere una heatmap in stile GitHub che mostra i giorni in cui l'utente si è allenato negli ultimi 3 mesi. Verde più intenso = più volume. Dà un colpo d'occhio immediato sulla costanza.

🚀 3. Nuove Funzionalità Proposte
3.1 📸 Foto Progresso (Before/After)
Permettere all'utente di scattare foto del proprio fisico ad intervalli regolari (es. ogni 4 settimane). Le foto vengono salvate localmente con data e misurazioni associate. Una vista "slider" permette di sovrapporre il prima/dopo.

Complessità: Media | Impatto UX: Alto

3.2 🔔 Notifiche Push / Reminder Allenamento
Configurare notifiche locali che ricordano all'utente di allenarsi. Personalizzabili per giorno e orario. Se l'utente non si allena da 3+ giorni, inviare un messaggio motivazionale.

Complessità: Bassa | Impatto UX: Alto

3.3 ⚡ Superset / Dropset / Rest-Pause Tracking
Il modello attuale traccia solo serie lineari (peso × reps). Aggiungere il supporto per:

Superset: 2 esercizi consecutivi senza pausa
Dropset: riduzione peso senza pausa tra i set
Rest-Pause: pausa breve (10-15s) e ripresa
Questo richiede una modifica al modello CompletedSet e al backend exercises_json.

Complessità: Media-Alta | Impatto UX: Medio (utenti avanzati)

3.4 🌐 Modalità Offline-First Evoluta
Attualmente se la sync fallisce, il workout viene salvato localmente e riprovato al prossimo avvio. Propongo:

Indicatore visivo nell'history per i workout non sincronizzati (icona cloud barrata)
Retry automatico ogni volta che il dispositivo torna online (listener su ConnectivityService)
Conflict resolution se lo stesso workout viene salvato da due dispositivi
Complessità: Media | Impatto UX: Alto

3.5 ⏲️ Timer Tabata / EMOM / AMRAP
Per chi fa allenamenti funzionali o HIIT, aggiungere timer specializzati:

Tabata: 20s lavoro / 10s riposo × 8 round
EMOM: Every Minute On the Minute
AMRAP: As Many Reps As Possible in X minuti
Accessibile da un pulsante nella toolbar della sessione.

Complessità: Bassa | Impatto UX: Medio

3.6 📤 Export e Condivisione Workout
Permettere di esportare il riepilogo dell'allenamento come:

Immagine condivisibile (Instagram story format) con statistiche e brand ForgeFit
PDF con dettaglio completo per il personal trainer
CSV per analisi esterna
Complessità: Media | Impatto UX: Medio

3.7 ⌚ Integrazione Wearable (Google Fit / Apple Health)
Sincronizzare i dati dell'allenamento con le piattaforme salute del dispositivo:

Scrivere le sessioni come "Strength Training" su Google Fit / Apple Health
Leggere la frequenza cardiaca durante l'allenamento (se disponibile)
Calcolo kcal più preciso basato su FC reale
Complessità: Alta | Impatto UX: Alto

3.8 🏅 Gamification Avanzata (Achievement System)
Estendere il sistema di streak attuale con un sistema di achievement/badge:

🥉 "Prima Volta" — Primo allenamento completato
🥈 "Costanza" — 7 giorni di streak
🥇 "Bestia" — 30 giorni di streak
💪 "PR Hunter" — 10 personal record battuti
🏋️ "Tonnellaggio" — 100.000 kg di volume totale cumulato
📊 "Data Nerd" — Prima misurazione biometrica inserita
I badge vengono mostrati nel profilo e come notifica pop-up al raggiungimento.

Complessità: Media | Impatto UX: Alto

Riepilogo Priorità
Priorità	Intervento	Tipo
🔴 P0	Rimuovere CORS wildcard	Sicurezza
🔴 P0	Credenziali deploy in .env	Sicurezza
🟡 P1	Fix YouTube Shorts parser	Bug
🟡 P1	Colori dinamici per giorni	UX
🟡 P1	Fix declarative_base deprecato	Tech Debt
🟢 P2	Refactor pattern retry DRY	Tech Debt
🟢 P2	Migrazioni con Alembic	Tech Debt
🟢 P2	Grafici touch interattivi	UX
🟢 P2	Confetti a fine allenamento	UX
🔵 P3	Notifiche push	Feature
🔵 P3	Heatmap calendario	Feature
🔵 P3	Foto progresso	Feature
🔵 P3	Gamification	Feature
⚪ P4	Export/condivisione	Feature
⚪ P4	Timer Tabata/EMOM	Feature
⚪ P4	Integrazione wearable	Feature