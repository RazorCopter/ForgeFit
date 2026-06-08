🔍 Audit Completo — ForgeFit v1.2.0
Analisi approfondita di tutta la codebase (frontend Flutter + backend FastAPI), organizzata per gravità.

🔴 Criticità (Bug / Sicurezza)
1. @app.on_event("startup") è deprecato
File: 
main.py

FastAPI ha deprecato @app.on_event("startup") in favore dei lifespan events. Potrebbe smettere di funzionare in un aggiornamento futuro di FastAPI/Starlette.

diff

-@app.on_event("startup")
-def on_startup():
+from contextlib import asynccontextmanager
+
+@asynccontextmanager
+async def lifespan(app):
+    # startup
     ...
+    yield
+    # shutdown (se necessario)
+
+app = FastAPI(..., lifespan=lifespan)
2. debugPrint non-protetto in produzione (API Service)
File: 
api_service.dart

In saveWorkout(), ci sono 4 debugPrint senza il guard kDebugMode — stampano payload, status e body di errore anche in build release.

dart

// Linee 220, 231, 233, 241
debugPrint('🚀 [ApiService] POST ${ApiConfig.saveWorkout}');
WARNING

Potenziale leak di dati sensibili nei log di produzione (pesi, ripetizioni, token nell'header).

3. _checkUnauthorized sincrona chiama AuthService.logout() senza await
File: 
api_service.dart

_checkUnauthorized è sincrono (void) ma chiama AuthService.logout() che è async. Il logout potrebbe non completarsi prima del throw, lasciando token residui nello storage.

4. main.py è un monolite da 1873 righe
File: 
main.py
 — 81 KB
Ogni endpoint (auth, plans, workouts, AI, catalog, measurements, dashboard) è nello stesso file. Rende il codice difficile da mantenere e aumenta il rischio di conflitti.

IMPORTANT

Consigliato split in routers/ con APIRouter di FastAPI:

routers/auth.py
routers/plans.py
routers/workouts.py
routers/measurements.py
routers/ai.py
routers/catalog.py
5. Nessun rate-limiting sugli endpoint pubblici
File: 
main.py

L'endpoint /api/auth/login non ha rate-limiting. Un attaccante può fare brute-force senza limiti.

6. Service Worker mancante per PWA completa
File: 
web/

L'app ha manifest.json e il popup di installazione, ma non è presente un file flutter_service_worker.js personalizzato per la cache offline. Flutter genera un service worker di default durante il build, ma senza configurazione esplicita la PWA potrebbe non funzionare offline.

🟡 Problemi Importanti (UX / Funzionali)
7. Splash screen con timer fisso di 3 secondi
File: 
splash_screen.dart

Lo splash attende sempre 3 secondi, anche se AuthService.isLoggedIn() risponde in 50ms. Su connessioni veloci è tempo morto inutile.

Suggerimento: Usa Future.wait con un delay minimo di ~1.5s e il check auth in parallelo.

8. Bottom Navigation Bar senza il background gradient dell'app
File: 
main_screen.dart

Il Scaffold in MainScreen non usa AppTheme.buildBackground(), quindi lo sfondo della bottom bar è AppTheme.surface piatto senza il gradiente. Crea un taglio visivo netto rispetto al resto dell'app.

9. Nessun feedback visivo di "ultima sincronizzazione"
File: 
home_screen.dart

L'utente non sa quando è stata l'ultima volta che la scheda è stata aggiornata. getLastSyncTimestamp() esiste ma non viene mai mostrato in UI.

Suggerimento: Aggiungere sotto il titolo "La tua Settimana" un piccolo testo tipo:
Ultimo aggiornamento: 2h fa in grigio chiaro.

10. PR Celebration overlay non è dismissibile
File: 
active_session_screen.dart

Il popup "NUOVO RECORD!" è un OverlayEntry che si auto-rimuove dopo 2.5 secondi. Se l'utente tocca lo schermo, non succede nulla. Potrebbe risultare fastidioso se sta per premere un pulsante sottostante.

Suggerimento: Wrappare con un GestureDetector per permettere dismiss al tap.

11. Nessuna conferma di eliminazione dati
File: 
setup_screen.dart

C'è la conferma per l'import (sovrascrittura) ma manca un pulsante per cancellare i dati locali o resettare l'app. Se l'utente ha problemi, non può fare "reset" senza reinstallare.

12. shared_preferences dichiarato ma inutilizzato
File: 
pubspec.yaml

Il pacchetto shared_preferences: ^2.2.3 è ancora nelle dipendenze, ma la v1.2.0 ha migrato tutto a flutter_secure_storage. È peso morto nel bundle.

13. History screen: nessuna possibilità di cancellare un allenamento
File: 
history_screen.dart

Se l'utente registra per errore un allenamento (o un test), non può eliminarlo dallo storico. Serve un long-press → "Elimina" con conferma.

🟢 Miglioramenti Grafici / Estetici
14. Aggiungere animazione shimmer/skeleton durante il loading della scheda
Quando l'utente preme "Sincronizza" e la lista giorni è vuota, c'è solo un CircularProgressIndicator nell'AppBar. Uno skeleton shimmer (placeholder delle card) darebbe un effetto molto più premium.

15. Aggiungere "Pull-to-Refresh" sulla Home
L'utente potrebbe voler aggiornare la scheda con uno swipe verso il basso, invece di cercare l'icona cloud sync nell'AppBar. Un RefreshIndicator wrappato attorno alla ListView sarebbe molto naturale.

16. Statistiche: grafico volume per distretto muscolare solo come lista
File: 
statistics_screen.dart

Il volume per distretto muscolare è una semplice lista di righe testo. Un radar chart (spider chart) o un bar chart orizzontale con barre colorate sarebbe molto più impattante visivamente e d'immediata lettura.

17. Calendar: giorni con allenamento hanno solo un pallino
File: 
history_screen.dart

I marker del calendario sono un semplice cerchio viola. Si potrebbe usare marker multipli colorati per tipo di allenamento (Push = cyan, Pull = purple, ecc.) o mostrare un badge numerico se ci sono più sessioni in un giorno.

18. Workout Summary: nessuna animazione confetti/particelle
File: 
workout_summary_screen.dart

La schermata di riepilogo post-allenamento è graficamente buona, ma manca un effetto "wow" finale. Un'animazione confetti (pacchetto confetti) renderebbe il momento di completamento più celebrativo.

19. YouTube embed: aggiungere un placeholder/thumbnail prima del caricamento
File: 
day_detail_screen.dart

Il player YouTube mostra un iframe vuoto finché non si carica. Un thumbnail dell'esercizio con un'icona play centrata (clickable per avviare il caricamento) sarebbe più leggero e reattivo.

🔵 Miglioramenti Funzionali
20. Notifiche push / reminder allenamento
L'app non ha alcun sistema di notifiche. Un reminder giornaliero ("Hai un allenamento oggi!") aumenterebbe significativamente l'engagement. Utilizzabile tramite flutter_local_notifications + scheduling.

21. Dark/Light mode toggle
L'app è solo dark mode. Anche se il design cyber-dark è molto bello, alcuni utenti preferiscono il light mode, specialmente in palestra con luce forte.

22. Internazionalizzazione (i18n)
Tutto il testo è hardcoded in italiano. Se in futuro l'app verrà usata da clienti non italiani, servirebbero i file .arb di Flutter per la localizzazione.

23. Backup automatico cloud (non solo export manuale)
Attualmente il backup è un file JSON manuale. Un sync automatico periodico su backend (o Google Drive/iCloud) proteggerebbe meglio i dati dell'utente.

24. Aggiungere un timer globale di sessione nella DayDetailScreen
Quando l'utente naviga tra gli esercizi di un giorno, non c'è un timer complessivo della sessione di allenamento. Un timer visibile in alto (simile a quello di Apple Fitness) darebbe la percezione del tempo totale speso.

📊 Riepilogo Priorità
Priorità	# Issue	Categoria
🔴 Critico	1, 2, 3, 4, 5, 6	Bug / Sicurezza / Architettura
🟡 Importante	7, 8, 9, 10, 11, 12, 13	UX / Funzionalità mancanti
🟢 Grafico	14, 15, 16, 17, 18, 19	Polish visivo
🔵 Feature	20, 21, 22, 23, 24	Nuove funzionalità
TIP

Se vuoi procedere con le correzioni, posso iniziare dai punti critici (🔴) e poi passare ai miglioramenti. Fammi sapere su quali vuoi concentrarti o se vuoi un piano di implementazione dettagliato per un sottoinsieme specifico.