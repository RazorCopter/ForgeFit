# ForgeFit — Piano di fix e sviluppo

**Data:** 21 luglio 2026

**Stato:** release 2.4.0 premium UI in sviluppo e validazione

**Ambito:** backend FastAPI, app Flutter, dashboard amministrativa, sincronizzazione, AI e release mobile

## Stato di sviluppo — release 2.4.0

- [x] Branch `feat/2.4.0-premium-ui` creato dalla baseline 2.3.0
- [x] Design system ForgeFit Obsidian e component theme Material 3
- [x] Navigazione semplificata a cinque destinazioni senza perdita di funzionalità
- [x] Nuovo hub Profilo con metriche, Traguardi e Impostazioni
- [x] Home premium con saluto, data e gerarchia informativa più chiara
- [x] Sessione attiva con avanzamento, CTA premium e Semantics per timer/countdown
- [x] Versioni sorgente allineate a `2.4.0+76`
- [x] Test automatici UI aggiunti
- [x] Gate backend, Flutter, Docker e build web completati
- [x] Commit, push, merge su `main` e tag `v2.4.0`
- [ ] Backup dati di produzione pre-deploy verificato
- [ ] Deploy backend/frontend e verifica dati post-deploy
- [ ] APK Lite ARM64 `2.4.0+76` generato e verificato

### Compatibilità dati 2.4.0

La release non modifica schema SQLite, adapter Hive o chiavi di persistenza. Lo storico già raccolto e le credenziali utente restano invariati. Il deploy deve comunque creare un backup online SQLite e un archivio del volume prima di aggiornare i container.

## Stato di sviluppo — release 2.3.0

Ultimo aggiornamento: 21 luglio 2026. La checklist viene aggiornata insieme al codice e costituisce lo stato operativo della release.

- [x] Baseline: compilazione Python e validazione Docker Compose
- [x] SEC-01: credenziali rimosse dalla working tree e sostituite con variabili d'ambiente
- [x] SEC-01 esterno: rotazione credenziali confermata dal proprietario
- [ ] SEC-01 storico: bonificare in modo coordinato la cronologia Git
- [x] SEC-02: eliminare stored XSS e secret restituiti dalla dashboard
- [x] AUTH-01: registrazione con token e sessione completa
- [x] SYNC-01: pull paginato senza perdita oltre 100 allenamenti
- [x] DATA-00: logout/401 non cancellano i dati Hive; reset distruttivo solo esplicito
- [ ] SYNC-02: idempotency key, outbox e tombstone
- [x] UX-01/05: state machine preview/countdown/esecuzione e test
- [ ] DATA-01/02: metriche e timestamp Health coerenti
- [ ] AI-01: SDK supportato, entitlement, whitelist e quote
- [ ] PRIV-01/REL-01: privacy, secure storage e firma release
- [x] OPS-01 backup/restore: SQLite Online Backup API, limite upload, integrità, schema e rollback
- [ ] OPS-01 migrazioni / OPS-02: Alembic e hardening Docker ancora aperti
- [ ] QA-01: test backend/Flutter presenti; CI ancora da configurare

Le attività non completate non vengono dichiarate risolte nel changelog. Le azioni esterne restano aperte finché non sono confermate dal proprietario.

### Gate release 2.3.0

- [x] 8 test backend superati
- [x] 5 test Flutter superati
- [x] Flutter analyze senza errori bloccanti
- [x] Build web release completata
- [x] Compilazione Python completata
- [x] Docker Compose validato
- [x] Versione `2.3.0+75` allineata tra frontend, backend e web
- [x] Rotazione credenziali precedentemente esposte confermata dal proprietario
- [x] Backup reale 2.2.4 verificato e compatibile con lo schema 2.3.0
- [x] Backup completo pre-deploy del volume `/app/data` creato e verificato
- [x] Produzione verificata: versione 2.3.0, database integro e conteggi invariati
- [ ] Bonifica coordinata della cronologia Git
- [x] Merge su `main`, tag `v2.3.0`, push e deploy Portainer completati

## 1. Obiettivi

1. Eliminare i rischi immediati di sicurezza e perdita dati rilevati nell'audit.
2. Rendere affidabili registrazione, sincronizzazione e metriche sanitarie.
3. Introdurre un flusso di esecuzione che non conteggi preparazione e posizionamento nel tempo effettivo della serie.
4. Rendere il progetto verificabile con test automatici, CI, migrazioni e build riproducibili.
5. Arrivare a una release mobile firmata e conforme ai requisiti privacy/Health Connect.

## 2. Decisione UX: preview, countdown ed esecuzione

### Problema attuale

`ActiveSessionScreen` imposta `_startTime` e avvia `_startStopwatch()` in `initState`. Il tempo necessario a leggere la scheda, caricare i pesi e posizionarsi viene quindi registrato come tempo sotto tensione. Anche dopo la serie il cronometro continua fino alla conferma di peso e ripetizioni.

### Flusso target

La sessione deve essere governata da una macchina a stati esplicita:

```text
preparazione
    -> countdown (5 s)
    -> esecuzione
    -> conferma dati a timer fermo
    -> recupero
    -> preparazione serie successiva
    -> countdown
    -> ...
    -> riepilogo esercizio
```

#### A. Preparazione esercizio/serie

All'apertura di ogni esercizio non deve partire alcun cronometro di esecuzione.

La preview mostra:

- nome esercizio e numero nell'allenamento;
- elenco completo delle serie programmate, con serie corrente evidenziata;
- peso e ripetizioni previste per ogni serie;
- ultimo peso/ripetizioni registrati;
- eventuale suggerimento di sovraccarico;
- recupero previsto, RIR/nota di carico e istruzioni di setup;
- miniatura/video tecnica, quando disponibile;
- pulsante primario `SONO PRONTO`;
- modifica rapida di peso e ripetizioni prima della partenza.

Se il peso non è noto, mostrare `Peso da impostare` invece di presentare `0 kg` come valore valido.

#### B. Countdown

Il tap su `SONO PRONTO` avvia un countdown a schermo intero di 5 secondi:

- numeri `5, 4, 3, 2, 1` ben visibili;
- feedback aptico negli ultimi tre secondi;
- segnale sonoro e/o coach vocale a zero, rispettando le preferenze esistenti;
- possibilità di annullare il countdown e tornare alla preview;
- nessun tempo salvato se il countdown viene annullato.

Il valore predefinito è 5 secondi. Nelle impostazioni si potrà scegliere `3 / 5 / 10 secondi` oppure disattivarlo; il default resta 5.

#### C. Esecuzione

Il cronometro della serie parte esattamente quando il countdown raggiunge zero. Durante l'esecuzione la schermata privilegia:

- cronometro grande;
- serie corrente, peso e target ripetizioni;
- pulsante molto grande `TERMINA SERIE`;
- protezione dai doppi tap.

Il tap su `TERMINA SERIE` ferma immediatamente il cronometro. Solo dopo l'arresto viene mostrata la conferma di peso effettivo, ripetizioni e, se abilitato, RIR/RPE. Il tempo impiegato a riporre l'attrezzatura o correggere i dati non deve alterare `timeUnderTension`.

#### D. Recupero e serie successive

Il recupero continua a mostrare la serie successiva, come già avviene in `RestTimerWidget`. Alla fine del recupero non deve partire automaticamente il cronometro della serie:

1. si apre la preview della prossima serie;
2. l'utente può sistemare il peso;
3. il tap su `SONO PRONTO` avvia il nuovo countdown;
4. il cronometro parte a zero.

### Semantica dei tempi

- `CompletedSet.timeUnderTension`: solo tempo compreso tra zero del countdown e tap su `TERMINA SERIE`.
- `CompletedWorkout.durationSeconds`: durata complessiva della sessione, inclusi preparazione e recuperi, per compatibilità con lo storico.
- `activeSeconds`: somma dei tempi delle serie; inizialmente calcolabile dai set senza modificare il backend.
- In una fase successiva si potranno salvare separatamente `preparationSeconds` e `restSeconds` per analisi più precise.

I timer devono essere calcolati da timestamp monotoni/assoluti, non incrementando soltanto un contatore ogni secondo: questo riduce la deriva e gestisce meglio background, notifiche e rallentamenti del dispositivo.

## 3. Capability aggiuntive suggerite

### MVP — da includere con preview e countdown

- modifica rapida del carico prima della serie;
- copia dei valori dell'ultima sessione;
- annullamento e riavvio del countdown;
- feedback aptico, beep e voce configurabili;
- conferma post-serie a timer già fermo;
- test di ripresa dopo rotazione schermo/background e protezione dai doppi tap;
- accessibilità: pulsanti grandi, contrasto, Semantics e countdown non affidato soltanto al colore.

### Iterazione successiva

- **Calcolatore dischi:** dato il peso totale e il bilanciere, indica i dischi da caricare per lato.
- **Checklist attrezzatura:** bilanciere, manubri, panca, elastici o macchina necessari per l'esercizio successivo.
- **Serie di riscaldamento/ramp-up:** distinte dalle serie allenanti e non incluse nel volume di lavoro.
- **RIR/RPE post-serie:** raccolto nella conferma senza falsare il cronometro.
- **Tempo/ritmo target:** metronomo opzionale per eccentrica, pausa e concentrica.
- **Modalità unilaterale:** lato destro/sinistro e completamento separato.
- **Session recovery:** ripristino della serie attiva dopo chiusura o crash dell'app.
- **Statistiche tempo:** confronto tra tempo attivo, recupero e durata totale.

### Da validare con utenti prima dello sviluppo

- comandi vocali hands-free `avvia/termina serie`;
- avvio automatico da smartwatch o sensori di movimento;
- adattamento automatico del recupero in base a frequenza cardiaca;
- suggerimento AI del carico in tempo reale.

Queste capability richiedono più permessi, affidabilità o responsabilità sul dato e non devono bloccare l'MVP.

## 4. Roadmap prioritaria

| Priorità | Workstream | Risultato necessario | Dipendenze |
|---|---|---|---|
| P0 | Sicurezza immediata | Nessun secret esposto e nessuna stored XSS amministrativa | Azioni manuali del proprietario per la rotazione |
| P0 | Contratto registrazione | Nuovo utente autenticato correttamente | Decisione backend: token alla registrazione o login automatico |
| P0 | Sincronizzazione | Nessuna cancellazione oltre 100 record e push idempotente | Identificatori client e strategia tombstone/cursore |
| P1 | Preview/countdown/timer | Tempo serie misurato solo durante l'esecuzione | Test della macchina a stati |
| P1 | AI | SDK/modelli supportati, entitlement e quote server-side | Secret AI validi e budget |
| P1 | Dati sanitari/privacy | Metriche coerenti e permessi minimi | Revisione prodotto/privacy |
| P1 | Release mobile | Firma release, secure storage e manifest corretti | Keystore e account store |
| P2 | Operabilità | Backup affidabile, migrazioni e Docker riproducibile | Finestra di manutenzione DB |
| P2 | Qualità | Test backend/Flutter e CI bloccante | Toolchain Flutter disponibile |

## 5. Piano di implementazione

### Fase 0 — Contenimento sicurezza

#### SEC-01 — Rotazione e rimozione credenziali

- Ruotare le credenziali presenti in `get_logs.ps1`.
- Sostituirle con variabili d'ambiente o secret manager.
- Rimuovere il valore dalla cronologia Git con una procedura coordinata.
- Verificare log di accesso e sessioni ancora valide.

**Criterio di accettazione:** una scansione della working tree e dell'intera storia non trova più il secret revocato.

#### SEC-02 — Eliminare la stored XSS

- Sostituire l'interpolazione di dati utente in `innerHTML` con nodi DOM e `textContent`.
- Rimuovere gli `onclick` costruiti con dati dinamici.
- Applicare limiti e normalizzazione ai campi di registrazione.
- Aggiungere Content-Security-Policy, `nosniff`, frame policy e referrer policy.
- Non restituire mai chiavi AI complete nella risposta delle impostazioni.
- Valutare cookie `HttpOnly`, `Secure`, `SameSite` per la sessione dashboard al posto di `localStorage`.

**Test obbligatorio:** registrare un utente con payload HTML/JavaScript e verificare che venga visualizzato come testo inerte.

#### SEC-03 — Hardening autenticazione

- Rate limit su registrazione, login, refresh, AI e TTS.
- Password con policy ragionevole e limite massimo prima di bcrypt.
- Refresh token ruotabili e revocabili, con `jti`, issuer e audience.
- Invalidazione delle sessioni al cambio password.
- Configurazione corretta dell'IP reale dietro proxy fidato.

### Fase 1 — Correttezza di registrazione e sincronizzazione

#### AUTH-01 — Contratto di registrazione unico

Scelta consigliata: il backend restituisce la stessa `TokenResponse` del login dopo aver creato l'utente. Il frontend salva token e `userId` soltanto dopo una risposta valida; in caso contrario non apre `MainScreen`.

**Test di integrazione:** `register -> /me -> sync` deve funzionare senza login manuale.

#### SYNC-01 — Eliminare la perdita oltre 100 allenamenti

- Non dedurre cancellazioni da una pagina parziale.
- Introdurre paginazione a cursore oppure endpoint incrementale `updated_since`.
- Rappresentare le cancellazioni con tombstone server-side.
- Ordinare esplicitamente le risposte.

**Test obbligatori:** account con 99, 100, 101 e almeno 250 allenamenti; nessun record locale deve sparire.

#### SYNC-02 — Idempotenza e outbox

- Aggiungere `client_uuid` univoco a workout e misurazioni.
- Accettare un'idempotency key nei `POST`.
- Salvare localmente le operazioni pendenti in una outbox.
- Marcare l'operazione conclusa soltanto dopo riconciliazione ID/versione.
- Usare tombstone anche per le cancellazioni offline.
- Definire una policy esplicita per più misurazioni nello stesso giorno.

**Test obbligatorio:** simulare timeout dopo commit server e ripetere il push; deve esistere un solo record.

### Fase 2 — Preview e timer corretto

#### UX-01 — Macchina a stati della serie

- Sostituire `_isResting` e gli avvii impliciti con un enum, ad esempio:
  `preparing`, `countingDown`, `executing`, `confirming`, `resting`, `completed`.
- Rendere impossibili transizioni non valide e doppi avvii.
- Non inizializzare `_startTime` o lo stopwatch in `initState`.
- Avviare il timestamp della serie solo alla fine del countdown.
- Congelare il tempo prima di aprire la conferma post-serie.

#### UX-02 — Componenti UI

- Estrarre `SetPreparationView` per preview e modifica rapida.
- Estrarre `SetCountdownView` con durata configurabile.
- Estrarre `ActiveSetView` con grande pulsante di arresto.
- Estrarre `SetConfirmationSheet` per kg, reps e RIR/RPE opzionale.
- Riutilizzare un modello comune `NextSetInfo` tra preparazione e recupero.

#### UX-03 — Integrazione con i due punti di ingresso

Il comportamento deve essere identico quando l'esercizio parte da:

- `DayDetailScreen`, con scelta manuale dell'esercizio;
- `WorkoutSessionScreen`, con avanzamento automatico dell'intero allenamento.

Il wrapper può avviare il timer globale della sessione al primo ingresso, ma non deve avviare il cronometro della serie.

#### UX-04 — Persistenza preferenze

In `DatabaseService` aggiungere impostazioni versionate per:

- durata countdown, default `5`;
- countdown abilitato/disabilitato;
- aptica, suono e voce;
- eventuale RIR/RPE post-serie.

Valori non validi devono ricadere sui default senza bloccare l'avvio.

#### UX-05 — Test della macchina a stati

- apertura esercizio: tempo serie a zero e fermo;
- countdown completo: parte una sola volta a zero;
- countdown annullato: ritorno a preview senza tempo salvato;
- stop serie: il tempo non cambia durante la conferma;
- recupero terminato: la serie successiva resta in preview;
- background/foreground: nessuna deriva significativa;
- doppio tap: nessuna doppia conferma o doppia navigazione;
- back durante ogni stato: comportamento esplicito e dati coerenti;
- ultima serie: riepilogo prodotto una sola volta.

### Fase 3 — Dati sanitari e tempi

#### DATA-01 — Metriche aggiornate

- Calcolare profilo e target dalla misurazione più recente, oppure aggiornare atomicamente lo snapshot `User`.
- Evitare di combinare peso recente con BMI/BMR obsoleti nei prompt AI.
- Non ricostruire e sovrascrivere la data di nascita partendo dall'età.
- Validare formule, unità e gestione del sesso con un referente competente.

#### DATA-02 — Durata e Health Connect

- Salvare l'orario reale di inizio della sessione.
- Non trattare l'orario di completamento come inizio del workout Health.
- Conservare separatamente durata totale e somma dei tempi attivi.
- Documentare la stima calorie e renderla distinguibile da un dato misurato.

### Fase 4 — AI, privacy e release

#### AI-01 — Migrazione e controllo costi

- Migrare da `google-generativeai` al client `google-genai` supportato.
- Rimuovere modelli dismessi e mantenere una whitelist server-side.
- Salvare entitlement/sblocco sul server: nessun codice settimanale prevedibile o controllo soltanto locale.
- Aggiungere quote per utente, rate limit, timeout e limiti ai payload.
- Non accettare un `model_name` arbitrario dal client.
- Tracciare costo, modello, latenza ed errori senza registrare dati sanitari sensibili nei log.

#### PRIV-01 — Privacy e permessi

- Riscrivere la privacy policy senza placeholder.
- Dichiarare categorie di dati, finalità, retention, cancellazione, diritti e subprocessori AI/TTS.
- Richiedere soltanto permessi Health effettivamente usati.
- Rimuovere entitlement iOS non necessari.
- Inserire flusso di consenso e link alla gestione permessi.
- Spostare token mobile in Keychain/Keystore e controllare i backup dell'app.

#### REL-01 — Release Android/iOS

- Creare keystore release esterno al repository.
- Rimuovere la firma debug dalla variante release.
- Allineare manifest, versioni PWA/mobile, icone e configurazioni store.
- Produrre build release verificabile e testarla su dispositivo reale.

### Fase 5 — Operabilità e qualità

#### OPS-01 — Database

- Introdurre Alembic e una baseline dello schema corrente.
- Eliminare gradualmente gli `ALTER TABLE` eseguiti allo startup.
- Usare la SQLite Backup API per backup consistenti.
- Limitare upload restore, verificare che `integrity_check` restituisca `ok`, validare schema e usare una modalità manutenzione.

#### OPS-02 — Docker

- Aggiungere `.dockerignore` a backend e frontend.
- Evitare di inviare `build`, `.dart_tool`, `.git`, database, `.env` e file locali al daemon.
- Fissare versioni/digest delle immagini base.
- Eseguire i container come utente non-root e aggiungere healthcheck.
- Migliorare la cache Flutter copiando prima i manifest delle dipendenze.

#### QA-01 — Test e CI

- Backend: pytest per auth, autorizzazione, XSS, pagination, idempotenza, AI entitlement, backup e restore.
- Flutter: unit test della state machine, widget test di preview/countdown, integration test registrazione e sessione completa.
- Contract test tra JSON Flutter e schemi FastAPI.
- CI con lint, format check, test, build e scansione secret/dipendenze.
- Impedire il merge se test o scansioni falliscono.

#### MAINT-01 — Riduzione complessità

- Suddividere `active_session_screen.dart`, `auth_screen.dart`, `home_screen.dart`, `database_service.dart` e la dashboard monolitica.
- Rimuovere script temporanei, dipendenze non usate, certificati scaduti e asset duplicati.
- Correggere mojibake e documentazione non allineata al codice.
- Invalidare la cache catalogo dopo ogni modifica CRUD.
- Ordinare esplicitamente query di piano e storico.

## 6. File principalmente coinvolti nella feature timer

- `frontend/lib/screens/active_session_screen.dart`
- `frontend/lib/screens/workout_session_screen.dart`
- `frontend/lib/screens/day_detail_screen.dart`
- `frontend/lib/widgets/rest_timer_widget.dart`
- nuovi widget sotto `frontend/lib/widgets/session/`
- `frontend/lib/data/database_service.dart`
- `frontend/lib/models/training_data.dart`
- `frontend/lib/models/completed_workout.dart`, solo se vengono aggiunti nuovi campi persistenti
- nuovi test sotto `frontend/test/session/` e `frontend/integration_test/`

## 7. Strategia di consegna

Evitare una singola modifica molto grande. Sequenza consigliata di change set/PR:

1. rotazione secret e correzione XSS;
2. contratto registrazione e relativi test;
3. paginazione sicura e idempotenza sync;
4. state machine pura e test unitari;
5. UI preview/countdown/conferma e test widget;
6. integrazione nei due flussi di allenamento;
7. migrazione AI e quote;
8. metriche sanitarie, privacy e release signing;
9. Alembic, backup, Docker e CI;
10. refactoring e rimozione del debito tecnico.

Ogni change set deve mantenere compatibilità con i dati Hive e SQLite già esistenti oppure includere una migrazione esplicita e reversibile.

## 8. Definition of Done complessiva

Il piano può considerarsi completato quando:

- nessun secret operativo è presente nel repository o nella storia distribuita;
- i payload utente non possono eseguire script nella dashboard;
- registrazione e login funzionano end-to-end;
- la sincronizzazione non perde né duplica dati durante paginazione, retry o uso offline;
- preparazione e countdown non aumentano `timeUnderTension`;
- il timer si ferma prima della conferma dei dati;
- AI e TTS sono autorizzati, limitati e osservabili;
- metriche e record Health usano tempi e misurazioni coerenti;
- la build release è firmata correttamente e usa storage sicuro;
- test backend, Flutter e contract test passano in CI;
- backup e restore sono stati provati su una copia reale del database.

## 9. Tipo di agente consigliato

### Agente principale

Usare un **agente coding full-stack senior, orientato all'esecuzione sul repository, con reasoning alto**. Se disponibile in Codex, la scelta consigliata è **`gpt-5.6-sol` con reasoning `high`**.

Motivazione:

- la modifica attraversa Flutter, FastAPI, persistenza locale, contratti JSON e sicurezza;
- la macchina a stati del timer richiede ragionamento su lifecycle e concorrenza asincrona;
- i fix di sincronizzazione richiedono migrazioni compatibili e test di failure/retry;
- è preferibile un unico owner tecnico per state machine e protocollo sync, evitando modifiche parallele conflittuali.

Prompt operativo suggerito:

> Implementa il prossimo change set di `plan.md`. Prima verifica il codice corrente e i test. Mantieni compatibilità con i dati esistenti, aggiungi i test indicati, non includere fix non correlati nello stesso change set e fermati solo quando i criteri di accettazione della fase sono verificati.

### Revisione indipendente

Dopo ogni workstream P0/P1 è utile un secondo passaggio con un **agente reviewer security/QA in sola lettura**, focalizzato su:

- XSS, sessioni, secret e autorizzazione AI;
- perdita/duplicazione dati e casi di retry;
- transizioni invalide della state machine;
- regressioni privacy e Health Connect;
- copertura dei criteri di accettazione.

Non è necessario un agente di image generation per questa attività: la UI può essere realizzata con il design system Flutter esistente. Un agente visual/UX diventa utile soltanto se si vogliono produrre mockup grafici prima dell'implementazione.

## 10. Azioni che richiedono il proprietario del progetto

Un agente può modificare e testare il codice, ma non deve autonomamente:

- ruotare credenziali su servizi reali senza autorizzazione;
- creare o distribuire il keystore di produzione;
- scegliere basi giuridiche o approvare la privacy policy;
- pubblicare sugli store;
- impostare budget AI o cancellare dati di produzione.

Queste attività devono essere approvate ed eseguite con gli account e le policy del proprietario.
