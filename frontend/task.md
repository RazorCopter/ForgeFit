# ForgeFit — Task List per Agente Autonomo

Questo file contiene tutti i task da eseguire sul codebase Flutter di ForgeFit.
Ogni task è auto-contenuto: include file coinvolti, problema esatto con riferimento a riga/funzione,
codice da modificare, e criteri di verifica. Un agente può eseguire ogni task senza consultare
altri file se non quelli indicati.

---

## Sezione 1 — BUG CRITICI

---

### TASK-001 — Protezione cancellazione dati Hive su errore apertura box

**Categoria:** Bug critico — perdita dati  
**File:** `lib/data/database_service.dart`  
**Funzione:** `openBox()`, linee 16–56

**Problema:**
Ogni blocco `try/catch` nella funzione `openBox()` esegue `Hive.deleteBoxFromDisk(boxName)` se
l'apertura fallisce, **cancellando silenziosamente tutti i dati dell'utente** senza alcun avviso.
Questo avviene ad esempio dopo un aggiornamento dell'app che modifica i TypeAdapter Hive (schema
migration) o se un file Hive viene corrotto.

Codice attuale (stesso pattern ripetuto 5 volte):
```dart
try {
  await Hive.openBox<CompletedWorkout>(_workoutBoxName);
} catch (e) {
  debugPrint('Error opening $_workoutBoxName: $e. Recreating...');
  await Hive.deleteBoxFromDisk(_workoutBoxName);         // ← DISTRUGGE I DATI
  await Hive.openBox<CompletedWorkout>(_workoutBoxName);
}
```

**Fix da applicare:**
Sostituire ogni blocco catch con una versione che:
1. Salva l'errore in una lista
2. Non cancella nulla durante `openBox()`
3. Restituisce i box con errore come lista da gestire in `main.dart`

Modifica alla firma di `openBox()`:
```dart
/// Restituisce la lista di nomi di box che hanno fallito l'apertura.
/// Il chiamante decide se cancellare i dati.
static Future<List<String>> openBox() async {
  final List<String> failedBoxes = [];

  Future<void> tryOpen<T>(String name, Future<Box> Function() opener) async {
    try {
      await opener();
    } catch (e) {
      debugPrint('Error opening $name: $e');
      failedBoxes.add(name);
    }
  }

  await tryOpen(_workoutBoxName,      () => Hive.openBox<CompletedWorkout>(_workoutBoxName));
  await tryOpen(_userProfileBoxName,  () => Hive.openBox<UserProfile>(_userProfileBoxName));
  await tryOpen(_biometricBoxName,    () => Hive.openBox<BiometricRecord>(_biometricBoxName));
  await tryOpen(_settingsBoxName,     () => Hive.openBox(_settingsBoxName));
  await tryOpen(_planBoxName,         () => Hive.openBox(_planBoxName));

  return failedBoxes;
}
```

In `lib/main.dart`, dentro `main()`, dopo `await DatabaseService.openBox()`:
```dart
final failedBoxes = await DatabaseService.openBox();
if (failedBoxes.isNotEmpty) {
  // Mostra un dialog PRIMA di cancellare qualsiasi dato
  final shouldReset = await showDialog<bool>(
    context: navigatorKey.currentContext!,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: const Text('Errore dati locali', style: TextStyle(color: Colors.white)),
      content: Text(
        'I seguenti archivi locali non sono leggibili e devono essere reimpostati:\n\n'
        '${failedBoxes.join(', ')}\n\n'
        'Questa operazione eliminerà i dati non recuperabili. '
        'Verifica prima di avere un backup esportato.',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => SystemNavigator.pop(), // Chiude l'app senza cancellare
          child: const Text('Annulla', style: TextStyle(color: Colors.cyanAccent)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(_, true),
          child: const Text('Reimposta', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  ) ?? false;

  if (shouldReset) {
    for (final boxName in failedBoxes) {
      await Hive.deleteBoxFromDisk(boxName);
    }
    await DatabaseService.openBox(); // Riapre le box reimpostate
  }
}
```

**Criteri di verifica:**
- Simulare un'apertura fallita rinominando temporaneamente un file `.hive`
- Verificare che appaia il dialog invece di un crash silenzioso
- Scegliendo "Annulla" l'app si chiude senza modificare i file
- Scegliendo "Reimposta" solo i box elencati vengono ricreati vuoti

---

### TASK-002 — JWT in SharedPreferences → flutter_secure_storage

**Categoria:** Bug critico — sicurezza  
**File:** `lib/core/auth_service.dart` (intero file), `pubspec.yaml`

**Problema:**
I token JWT (access + refresh) sono salvati in `SharedPreferences`, che su Android **non cifra
i dati** e li scrive in plain XML leggibile da qualsiasi app con accesso root o da backup ADB
non cifrati. I token permettono l'accesso completo all'account dell'utente.

**Fix — Step 1: aggiungere dipendenza in `pubspec.yaml`**

Nella sezione `dependencies:`, dopo `shared_preferences: ^2.2.3`, aggiungere:
```yaml
flutter_secure_storage: ^9.0.0
```

**Fix — Step 2: riscrivere `lib/core/auth_service.dart` intero**

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  AuthService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyToken        = 'jwt_token';
  static const String _keyRefreshToken = 'jwt_refresh_token';
  static const String _keyEmail        = 'auth_email';
  static const String _keyUserId       = 'auth_user_id';

  static Future<void> saveToken(String token) =>
      _storage.write(key: _keyToken, value: token);

  static Future<String?> getToken() =>
      _storage.read(key: _keyToken);

  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _keyRefreshToken, value: token);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: _keyRefreshToken);

  static Future<void> saveEmail(String email) =>
      _storage.write(key: _keyEmail, value: email);

  static Future<String?> getEmail() =>
      _storage.read(key: _keyEmail);

  // userId serializzato come stringa (FlutterSecureStorage non ha setInt)
  static Future<void> saveUserId(int userId) =>
      _storage.write(key: _keyUserId, value: userId.toString());

  static Future<int?> getUserId() async {
    final raw = await _storage.read(key: _keyUserId);
    return raw != null ? int.tryParse(raw) : null;
  }

  static bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final exp = data['exp'] as int?;
      if (exp == null) return false;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    if (_isTokenExpired(token)) {
      await logout();
      return false;
    }
    return true;
  }

  static Future<void> logout() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyUserId);
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    if (kDebugMode) {
      debugPrint('🔑 [AuthService] authHeaders() -> Token: ${token != null ? "presente" : "assente"}');
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}
```

**Note:**
- Rimuovere l'import `package:shared_preferences/shared_preferences.dart` da questo file
- Non rimuovere `shared_preferences` da `pubspec.yaml` perché potrebbe ancora essere usato
  altrove (es. `database_service.dart` usa `Hive`, non `SharedPreferences`)
- Su iOS usa automaticamente Keychain; su Android usa `EncryptedSharedPreferences` (API 23+)

**Criteri di verifica:**
- `flutter pub get` deve completare senza errori
- Login → verifica che il token non appaia in chiaro in `/data/data/<package>/shared_prefs/`
- Logout → verifica che tutte le chiavi vengano cancellate

---

### TASK-003 — Wrappare debugPrint sensibili con kDebugMode

**Categoria:** Bug critico — sicurezza  
**File:** `lib/core/auth_service.dart:104`, `lib/core/api_service.dart`

**Problema:**
Varie chiamate `debugPrint` stampano dati sensibili (token JWT, body delle risposte di login)
in produzione. In Flutter, `debugPrint` viene compilato anche in release mode.

**Fix in `lib/core/auth_service.dart`:**

Nota: se TASK-002 è già stato eseguito, questo è già risolto nel nuovo file. Altrimenti:

Riga 104, sostituire:
```dart
debugPrint('🔑 [AuthService] authHeaders() -> Token found: ${token != null ? "SI" : "NO"}');
```
con:
```dart
if (kDebugMode) {
  debugPrint('🔑 [AuthService] authHeaders() -> Token found: ${token != null ? "SI" : "NO"}');
}
```

**Fix in `lib/core/api_service.dart`:**

Aprire il file e cercare tutte le occorrenze di `debugPrint` che stampano:
- Il body della risposta di login/register (contiene il JWT)
- Qualsiasi campo `password`
- I token nelle chiamate di refresh

Per ciascuna, wrappare con:
```dart
if (kDebugMode) {
  debugPrint('...');
}
```

Aggiungere in cima al file (se non già presente):
```dart
import 'package:flutter/foundation.dart';
```

Le `debugPrint` di rete generiche (errori HTTP, status code) possono restare fuori dal guard
perché non contengono dati sensibili.

**Criteri di verifica:**
- `flutter build apk --release` → verificare che i log JWT non appaiano su logcat
- In debug mode i log devono ancora essere visibili normalmente

---

### TASK-004 — Colore delta biometrico semanticamente corretto

**Categoria:** Bug critico — UX fuorviante  
**File:** `lib/screens/biometric_trends_screen.dart`  
**Riga:** 114 (dentro `_MetricCard.build`)

**Problema:**
Il colore del delta (variazione prima/ultima misurazione) usa:
- Verde = diminuzione
- Rosso = aumento

Questo è corretto per **Peso, Vita, Fianchi, Collo** (dove calare è positivo), ma è **sbagliato**
per **Bicipite, Petto, Coscia, Polpaccio** (dove crescere è l'obiettivo dell'allenamento).

Codice attuale (riga 114):
```dart
final deltaColor = delta < 0 ? Colors.greenAccent : (delta > 0 ? Colors.redAccent : Colors.white54);
```

**Fix:**

Step 1 — Aggiungere una costante top-level nel file (prima della classe `BiometricTrendsScreen`):
```dart
/// Metriche per cui un aumento è un risultato positivo (massa muscolare).
const _positiveGrowthMetrics = {'Bicipite', 'Petto', 'Coscia', 'Polpaccio'};
```

Step 2 — In `_MetricCard.build`, sostituire la riga 114:
```dart
final deltaColor = delta < 0 ? Colors.greenAccent : (delta > 0 ? Colors.redAccent : Colors.white54);
```
con:
```dart
final isPositiveGrowth = _positiveGrowthMetrics.contains(metric.label);
final Color deltaColor;
if (delta == 0) {
  deltaColor = Colors.white54;
} else if (isPositiveGrowth) {
  deltaColor = delta > 0 ? Colors.greenAccent : Colors.redAccent;
} else {
  deltaColor = delta < 0 ? Colors.greenAccent : Colors.redAccent;
}
```

**Criteri di verifica:**
- Per "Bicipite +2cm" → deve apparire in verde
- Per "Peso +2kg" → deve apparire in rosso
- Per "Vita -3cm" → deve apparire in verde

---

### TASK-005 — Rimuovere dead code in _exportBackup

**Categoria:** Bug — dead code  
**File:** `lib/screens/setup_screen.dart`  
**Funzione:** `_exportBackup()`, linee 117–129

**Problema:**
I due branch `if (kIsWeb)` e `else` sono **identici** — stesso codice, nessuna differenza.
Il branch `kIsWeb` non ha alcun effetto.

Codice attuale:
```dart
if (kIsWeb) {
  await FileSaver.instance.saveFile(
    name: fileName,
    bytes: bytes,
    mimeType: MimeType.json,
  );
} else {
  await FileSaver.instance.saveFile(
    name: fileName,
    bytes: bytes,
    mimeType: MimeType.json,
  );
}
```

**Fix — sostituire l'intera funzione `_exportBackup`:**
```dart
Future<void> _exportBackup() async {
  try {
    final jsonString = DatabaseService.exportDatabaseJson();
    final bytes = utf8.encode(jsonString);
    final fileName = 'forgefit_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      mimeType: MimeType.json,
    );
    _showSnackBar('Backup esportato con successo!', Colors.green.shade700);
  } catch (e) {
    _showSnackBar('Errore durante l\'export: $e', Colors.red.shade700);
  }
}
```

Rimuovere anche l'import `import 'dart:io';` se non usato altrove nel file (verificare).

**Criteri di verifica:**
- `flutter analyze` non deve mostrare warning sul file
- L'export backup funziona su Android

---

### TASK-006 — Deduplicare logica _syncScheda in un PlanService

**Categoria:** Bug — duplicazione codice  
**File da creare:** `lib/services/plan_service.dart`  
**File da modificare:** `lib/screens/home_screen.dart`, `lib/screens/setup_screen.dart`

**Problema:**
La logica di sync della scheda (GET /api/plans/{userId} → parse → salva su Hive) è **identica**
in `home_screen.dart` (linee 66–148) e `setup_screen.dart` (linee 27–59). Qualsiasi fix o
miglioramento alla logica va applicato manualmente in entrambi i posti.

**Fix — Step 1: creare `lib/services/plan_service.dart`:**
```dart
import 'dart:convert';
import '../core/api_service.dart';
import '../data/database_service.dart';
import '../models/training_data.dart';

class PlanService {
  PlanService._();

  /// Scarica il piano dal backend, lo salva su Hive e lo restituisce parsato.
  /// Lancia [Exception('no_plan')] se il server risponde senza scheda.
  /// Propaga [ApiException] per errori HTTP.
  static Future<List<TrainingDay>> syncPlan(int userId) async {
    final response = await ApiService.getPlans(userId);
    final rawPlan = response['plan'];

    if (rawPlan == null) throw Exception('no_plan');

    final Map<String, dynamic> planMap;
    if (rawPlan is Map<String, dynamic>) {
      planMap = rawPlan;
    } else if (rawPlan is String) {
      planMap = jsonDecode(rawPlan) as Map<String, dynamic>;
    } else {
      throw Exception('unexpected_plan_format');
    }

    await DatabaseService.saveRawPlan(planMap);
    return DatabaseService.parseTrainingDaysFromJson(planMap);
  }
}
```

**Fix — Step 2: aggiornare `lib/screens/home_screen.dart`**

Aggiungere import:
```dart
import '../services/plan_service.dart';
```

Sostituire il body del blocco `try` in `_syncScheda()` (linee 82–133) con:
```dart
try {
  final List<TrainingDay> parsedDays = await PlanService.syncPlan(userId);
  await DatabaseService.saveLastSyncTimestamp(); // Vedi TASK-012
  setState(() => _days = parsedDays);
  _showSuccessSnackBar('Scheda sincronizzata! ${parsedDays.length} giorni caricati.');
} on ApiException catch (e) {
  _showErrorSnackBar('Errore Server (${e.statusCode}): ${e.message}');
} catch (e) {
  if (e.toString().contains('no_plan')) {
    _showInfoSnackBar('Nessuna scheda disponibile. Contatta il tuo trainer.');
  } else {
    _showErrorSnackBar('Errore di sistema: $e');
  }
}
```

**Fix — Step 3: aggiornare `lib/screens/setup_screen.dart`**

Aggiungere import:
```dart
import '../services/plan_service.dart';
```

Sostituire il body del blocco `try` in `_syncScheda()` (linee 35–50) con:
```dart
try {
  final days = await PlanService.syncPlan(userId);
  _showSnackBar('Scheda aggiornata! ${days.length} giorni caricati.', Colors.green.shade700);
} on ApiException catch (e) {
  _showSnackBar('Errore dal server: ${e.message}', Colors.red.shade700);
} catch (e) {
  if (e.toString().contains('no_plan')) {
    _showSnackBar('Nessuna scheda disponibile. Contatta il trainer.', Colors.orange);
  } else {
    _showSnackBar('Server non raggiungibile.', Colors.red.shade700);
  }
}
```

**Criteri di verifica:**
- `flutter analyze` senza errori
- La sincronizzazione funziona da entrambe le schermate
- Un singolo breakpoint in `PlanService.syncPlan` viene raggiunto da entrambe le schermate

---

### TASK-007 — Mostrare note esercizio durante la sessione attiva

**Categoria:** Bug — informazione critica nascosta  
**File:** `lib/screens/active_session_screen.dart`  
**Funzione:** `_buildActiveFocusCard(int si)`, linea ~374

**Problema:**
Durante la sessione attiva, l'utente non vede:
- `exercise.loadNote` — il range di ripetizioni prescritto (es. "8-10 RIR 2")
- `exercise.externalNote` — le note tecniche del trainer sull'esercizio

Queste informazioni sono disponibili nell'oggetto `widget.exercise` ma non vengono mostrate.

**Fix:**

Nella funzione `_buildActiveFocusCard(int si)`, dopo il blocco con il testo
`'Serie ${si + 1} di ${widget.exercise.sets.length}'` e prima del blocco
`if (lastSet != null)` (circa riga 385), inserire:

```dart
if (widget.exercise.loadNote.isNotEmpty) ...[
  const SizedBox(height: 10),
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: widget.accentColor.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: widget.accentColor.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.bar_chart, size: 14, color: widget.accentColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            widget.exercise.loadNote,
            style: TextStyle(
              fontSize: 13,
              color: widget.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  ),
],
if (widget.exercise.externalNote != null &&
    widget.exercise.externalNote!.isNotEmpty) ...[
  const SizedBox(height: 6),
  Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.notes, size: 13, color: Colors.white38),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          widget.exercise.externalNote!,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white54,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    ],
  ),
],
```

**Criteri di verifica:**
- Aprire un esercizio con loadNote "8-10 RIR 2" → deve apparire nella card con icona
- Aprire un esercizio con externalNote → deve apparire in corsivo sotto
- Se entrambi sono vuoti/null → nessun widget aggiuntivo

---

## Sezione 2 — MIGLIORAMENTI UX

---

### TASK-008 — Etichette date sull'asse X del grafico Volume

**Categoria:** Miglioramento UX — leggibilità grafici  
**File:** `lib/screens/statistics_screen.dart`  
**Sezione:** grafico "Tonnellaggio Totale", linea ~228

**Problema:**
L'asse X del grafico volume mostra i dati delle ultime 7 sessioni ma senza etichette di data,
rendendo impossibile capire a quale giorno corrisponde ogni punto.

**Fix — Step 1: aggiungere helper `_getVolumeLabels`**

Nella classe `_StatisticsScreenState`, dopo `_getVolumeSpots`, aggiungere:
```dart
List<String> _getVolumeLabels(List<CompletedWorkout> workouts) {
  if (workouts.isEmpty) return [];
  final sorted = List<CompletedWorkout>.from(workouts)
    ..sort((a, b) => a.date.compareTo(b.date));
  final recent = sorted.reversed.take(7).toList().reversed.toList();
  return recent.map((w) =>
    '${w.date.day.toString().padLeft(2, '0')}/${w.date.month.toString().padLeft(2, '0')}'
  ).toList();
}
```

**Fix — Step 2: usare le etichette nel grafico**

Nel metodo `build`, dentro il `ValueListenableBuilder`, aggiungere:
```dart
final volumeLabels = _getVolumeLabels(workouts);
```

Nel `LineChartData` del grafico "Tonnellaggio Totale", sostituire:
```dart
bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
```
con:
```dart
bottomTitles: AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 20,
    getTitlesWidget: (val, meta) {
      final idx = val.toInt();
      if (idx >= 0 && idx < volumeLabels.length) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            volumeLabels[idx],
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
          ),
        );
      }
      return const SizedBox.shrink();
    },
  ),
),
```

**Criteri di verifica:**
- Il grafico volume mostra date in formato `dd/MM` sotto ogni punto
- Con meno di 7 sessioni, le etichette coprono solo i punti presenti

---

### TASK-009 — Haptic feedback su conferma serie e scadenza timer

**Categoria:** Miglioramento UX — feedback fisico  
**File:** `lib/screens/active_session_screen.dart:138`, `lib/widgets/rest_timer_widget.dart:51-63`

**Problema:**
Nessuna vibrazione avviene quando:
- L'utente conferma una serie
- Il timer di recupero raggiunge lo zero

**Fix in `lib/screens/active_session_screen.dart`:**

`HapticFeedback` è già importato via `package:flutter/services.dart` (linea 3).

Aggiungere come **prima riga** della funzione `_completeActiveSet()` (linea 138):
```dart
HapticFeedback.mediumImpact();
```

**Fix in `lib/widgets/rest_timer_widget.dart`:**

Aggiungere import (in cima al file, dopo gli altri import):
```dart
import 'package:flutter/services.dart';
```

Nella funzione `_startTimer()`, nel branch `else` (quando il timer raggiunge 0, linee 57-62),
aggiungere `HapticFeedback.heavyImpact()`:
```dart
} else {
  _timer?.cancel();
  HapticFeedback.heavyImpact();      // ← aggiungere questa riga
  setState(() {
    _countdownFinished = true;
  });
}
```

**Criteri di verifica:**
- Su device fisico Android: vibrazione media alla conferma serie
- Su device fisico Android: vibrazione forte a fine timer recupero
- Su emulatore: nessun crash (HapticFeedback è no-op su emulatori)

---

### TASK-010 — Fix tracking esercizi completati per indice invece che per nome

**Categoria:** Miglioramento UX — bug con esercizi duplicati  
**File:** `lib/screens/day_detail_screen.dart`  
**Righe:** 24, 26-51, 163

**Problema:**
Lo stato `_completedExercises` traccia gli esercizi completati per **nome** (riga 163):
```dart
final isCompleted = _completedExercises.any((e) => e.name == exercise.name);
```
Se una scheda contiene lo stesso esercizio due volte (es. Curl bilanciere al mattino e alla sera),
completare il primo segna automaticamente anche il secondo come completato.

**Fix:**

Step 1 — Cambiare la dichiarazione a riga 24:
```dart
// Prima:
final List<CompletedExercise> _completedExercises = [];
// Dopo:
final List<CompletedExercise> _completedExercises = [];
final Set<int> _completedIndexes = {};
```

Step 2 — In `_startExercise`, aggiungere il parametro `index` e usarlo:
```dart
// Prima:
void _startExercise(Exercise exercise, Color accentColor) async {
// Dopo:
void _startExercise(Exercise exercise, Color accentColor, int index) async {
```

Nel blocco `if (result != null && result is Map<String, dynamic>)` (riga 42), aggiungere:
```dart
_completedExercises.add(completed);
_completedIndexes.add(index);     // ← aggiungere
setState(() {});
```

Step 3 — Nel `ListView.builder` (riga 163), sostituire:
```dart
final isCompleted = _completedExercises.any((e) => e.name == exercise.name);
```
con:
```dart
final isCompleted = _completedIndexes.contains(index);
```

Step 4 — Nel callback `onStart` (riga 176), passare `index`:
```dart
// Prima:
onStart: () => _startExercise(exercise, accentColor),
// Dopo:
onStart: () => _startExercise(exercise, accentColor, index),
```

**Criteri di verifica:**
- Con scheda che ha lo stesso esercizio due volte: completare il primo non segna il secondo
- Con esercizi con nomi diversi: il comportamento è identico a prima

---

### TASK-011 — BiometricTrendsScreen reattiva a nuove misurazioni

**Categoria:** Miglioramento UX — reattività dati  
**File:** `lib/screens/biometric_trends_screen.dart`

**Problema:**
`BiometricTrendsScreen` è un `StatelessWidget` e legge i dati Hive una sola volta in `build()`.
Se l'utente aggiunge una nuova misurazione nella `AnalysisScreen` e poi naviga ai trends,
la schermata mostra i dati vecchi finché non viene ricostruita (es. cold restart).

**Fix — convertire in StatefulWidget con ValueListenableBuilder:**

Step 1 — Cambiare la dichiarazione della classe:
```dart
// Prima:
class BiometricTrendsScreen extends StatelessWidget {
  const BiometricTrendsScreen({super.key});
// Dopo:
class BiometricTrendsScreen extends StatefulWidget {
  const BiometricTrendsScreen({super.key});

  @override
  State<BiometricTrendsScreen> createState() => _BiometricTrendsScreenState();
}

class _BiometricTrendsScreenState extends State<BiometricTrendsScreen> {
```

Step 2 — Il metodo `_sortedRecords()` e la lista `_metrics` con i metodi statici rimangono
invariati ma devono essere spostati nella classe `_BiometricTrendsScreenState`.

Step 3 — Nel metodo `build`, wrappare il body con `ValueListenableBuilder`:
```dart
@override
Widget build(BuildContext context) {
  return AppTheme.buildBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Trend Misure Corporee', style: TextStyle(color: AppTheme.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: DatabaseService.biometricBoxListenable(),
        builder: (context, box, _) {
          final records = _sortedRecords(); // ora rilegge sempre i dati aggiornati
          return records.isEmpty
              ? const Center(
                  child: Text(
                    'Nessuna misurazione registrata.\nAggiungi le tue misure dalla schermata Analisi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _metrics.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 20),
                  itemBuilder: (context, i) {
                    final m = _metrics[i];
                    final spots = _buildSpots(records, m.extractor);
                    if (spots.length < 2) return const SizedBox.shrink();
                    return _MetricCard(metric: m, spots: spots, records: records)
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: i * 80))
                        .slideY(begin: 0.1);
                  },
                );
        },
      ),
    ),
  );
}
```

`DatabaseService.biometricBoxListenable()` è già definito in `database_service.dart:65`.

**Criteri di verifica:**
- Aggiungere una misurazione in `AnalysisScreen`
- Senza ricaricare l'app, navigare ai trends → i dati devono essere aggiornati

---

### TASK-012 — Auto-sync scheda all'avvio con rate limiting

**Categoria:** Miglioramento UX — frizione manuale  
**File:** `lib/screens/home_screen.dart`, `lib/data/database_service.dart`

**Problema:**
Al primo avvio dopo l'aggiornamento della scheda da parte del trainer, l'utente deve
**premere manualmente** il pulsante sync. Se dimentica, si allena con la scheda vecchia.

**Fix — Step 1: aggiungere due helper in `DatabaseService`:**

Alla fine della sezione `// --- SETTINGS ---` (dopo `getAIActivationDate`, riga ~96):
```dart
static Future<void> saveLastSyncTimestamp() async {
  await _settingsBox.put('last_plan_sync', DateTime.now().toIso8601String());
}

static DateTime? getLastSyncTimestamp() {
  final raw = _settingsBox.get('last_plan_sync') as String?;
  return raw != null ? DateTime.tryParse(raw) : null;
}
```

**Fix — Step 2: modificare `initState` in `home_screen.dart`:**

Sostituire il metodo `initState` (attuale linee 33-39):
```dart
@override
void initState() {
  super.initState();
  final cached = DatabaseService.loadCachedPlan();
  if (cached != null && cached.isNotEmpty) {
    _days = cached;
  }
  _autoSyncIfStale(); // ← aggiungere
}

Future<void> _autoSyncIfStale() async {
  final userId = DatabaseService.getUserId();
  if (userId == null) return;
  final lastSync = DatabaseService.getLastSyncTimestamp();
  final isStale = lastSync == null ||
      DateTime.now().difference(lastSync).inHours >= 4;
  if (isStale) {
    await _syncScheda(silent: true);
  }
}
```

**Fix — Step 3: modificare la firma di `_syncScheda`:**

```dart
// Prima:
Future<void> _syncScheda() async {
// Dopo:
Future<void> _syncScheda({bool silent = false}) async {
```

Dopo la riga `final List<TrainingDay> parsedDays = await PlanService.syncPlan(userId);` aggiungere:
```dart
await DatabaseService.saveLastSyncTimestamp();
```

Nelle chiamate `_showSuccessSnackBar(...)` e `_showInfoSnackBar(...)` aggiungere il guard:
```dart
if (!silent) _showSuccessSnackBar('Scheda sincronizzata! ${parsedDays.length} giorni caricati.');
```

**Criteri di verifica:**
- Al primo avvio del giorno (o dopo 4h): sync silenziosa avviene in background
- Entro le 4 ore: nessuna sync automatica
- Il pulsante manuale funziona sempre indipendentemente dal rate limiting

---

### TASK-013 — Flag isSynced su CompletedWorkout per retry offline

**Categoria:** Miglioramento UX — resilienza offline  
**File:** `lib/models/completed_workout.dart`, `lib/data/database_service.dart`,
`lib/screens/day_detail_screen.dart`, `lib/screens/main_screen.dart`

**Problema:**
Se `ApiService.saveWorkout()` fallisce (rete assente), il workout viene salvato localmente
ma non viene mai ritentato il sync con il server. I dati rimangono offline a tempo indefinito.

**Fix — Step 1: aprire `lib/models/completed_workout.dart` e trovare il `typeId` massimo**

Trovare l'ultimo `@HiveField(N)` nel `CompletedWorkoutAdapter` (typeId 0).
In base all'analisi il `CompletedWorkout` ha i campi: id, title, date, durationSeconds, exercises.
L'indice massimo usato è 4. Quindi il nuovo campo userà `@HiveField(5)`.

Nella classe `CompletedWorkout`, aggiungere il campo:
```dart
@HiveField(5)
bool isSynced;
```

Nel costruttore, aggiungere `this.isSynced = false`:
```dart
CompletedWorkout({
  required this.id,
  required this.title,
  required this.date,
  required this.durationSeconds,
  required this.exercises,
  this.isSynced = false,     // ← aggiungere con default false
});
```

Nel `CompletedWorkoutAdapter.write`, aggiungere dopo l'ultimo campo scritto:
```dart
writer.write(obj.isSynced);
```

Nel `CompletedWorkoutAdapter.read`, aggiungere:
```dart
final isSynced = reader.read() as bool? ?? false;
```
E passarlo al costruttore nel return:
```dart
return CompletedWorkout(
  ...,
  isSynced: isSynced,
);
```

**Fix — Step 2: aggiornare `DatabaseService`:**

Aggiungere dopo `saveWorkout`:
```dart
static List<CompletedWorkout> getUnsyncedWorkouts() =>
    _workoutBox.values.where((w) => !w.isSynced).toList();

static Future<void> markWorkoutSynced(String workoutId) async {
  final key = _workoutBox.keys.firstWhere(
    (k) => _workoutBox.get(k)?.id == workoutId,
    orElse: () => null,
  );
  if (key != null) {
    final w = _workoutBox.get(key)!;
    w.isSynced = true;
    await w.save();
  }
}
```

**Fix — Step 3: in `day_detail_screen.dart._finishWorkout()`:**

Dopo `await ApiService.saveWorkout(completedWorkout)` success:
```dart
await DatabaseService.markWorkoutSynced(completedWorkout.id);
```

**Fix — Step 4: aggiungere retry in `main_screen.dart` (o `home_screen.dart`):**

In `initState` di `_MainScreenState` (o `_HomeScreenState`):
```dart
_retryUnsyncedWorkouts();

Future<void> _retryUnsyncedWorkouts() async {
  final unsynced = DatabaseService.getUnsyncedWorkouts();
  for (final workout in unsynced) {
    try {
      await ApiService.saveWorkout(workout);
      await DatabaseService.markWorkoutSynced(workout.id);
    } catch (_) {
      // Riproverà al prossimo avvio
    }
  }
}
```

**Criteri di verifica:**
- Salvare un allenamento in modalità aereo → `isSynced = false`
- Riattivare la rete e riavviare l'app → il workout viene sincronizzato automaticamente
- Dopo il sync `isSynced = true`

---

## Sezione 3 — NUOVE FEATURE

---

### TASK-014 — Flow sessione sequenziale (Workout Mode guidato)

**Categoria:** Nuova feature — core UX  
**File da creare:** `lib/screens/workout_session_screen.dart`  
**File da modificare:** `lib/screens/day_detail_screen.dart`

**Descrizione:**
Al momento per fare una sessione completa, l'utente deve: espandere ogni esercizio → premere
"Inizia Esercizio" → completare le serie → tornare alla lista → espandere il prossimo → repeat.
Questa feature introduce un flow guidato che propone automaticamente l'esercizio successivo.

**Creare `lib/screens/workout_session_screen.dart`:**
```dart
import 'package:flutter/material.dart';
import '../models/training_data.dart';
import '../models/completed_workout.dart';
import '../core/theme.dart';
import 'active_session_screen.dart';
import 'workout_summary_screen.dart'; // Vedi TASK-016

class WorkoutSessionScreen extends StatefulWidget {
  final List<Exercise> exercises;
  final Color accentColor;
  final String dayTitle;

  const WorkoutSessionScreen({
    super.key,
    required this.exercises,
    required this.accentColor,
    required this.dayTitle,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  int _currentIndex = 0;
  final List<CompletedExercise> _completedExercises = [];
  late final DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startCurrentExercise();
  }

  void _startCurrentExercise() async {
    if (_currentIndex >= widget.exercises.length) {
      _finishWorkout();
      return;
    }

    final exercise = widget.exercises[_currentIndex];
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => ActiveSessionScreen(
          exercise: exercise,
          accentColor: widget.accentColor,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      final CompletedExercise completed = result['data'];
      _completedExercises.add(completed);

      if (result['action'] == 'finish' || _currentIndex == widget.exercises.length - 1) {
        _finishWorkout();
      } else {
        setState(() => _currentIndex++);
        _startCurrentExercise();
      }
    }
  }

  void _finishWorkout() {
    final duration = DateTime.now().difference(_startTime).inSeconds;
    // Il salvataggio e sync avvengono in WorkoutSummaryScreen o DayDetailScreen
    // Per ora torna alla DayDetailScreen con i dati
    Navigator.pop(context, {
      'completed': _completedExercises,
      'duration': duration,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Questa schermata è solo un coordinatore di navigazione.
    // Mentre non naviga, mostra un indicatore di progresso.
    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: widget.accentColor),
              const SizedBox(height: 16),
              Text(
                'Esercizio ${_currentIndex + 1} / ${widget.exercises.length}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Modifiche a `lib/screens/day_detail_screen.dart`:**

Nel `floatingActionButton`, sostituire l'attuale FAB con due pulsanti:
```dart
floatingActionButton: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    // FAB principale: avvia la sessione guidata completa
    FloatingActionButton.extended(
      heroTag: 'guided',
      onPressed: () async {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => WorkoutSessionScreen(
              exercises: widget.day.exercises,
              accentColor: accentColor,
              dayTitle: widget.day.title,
            ),
          ),
        );
        if (result != null) {
          // Popola _completedExercises e chiama _finishWorkout
          final exercises = result['completed'] as List<CompletedExercise>;
          _completedExercises.addAll(exercises);
          await _finishWorkout();
        }
      },
      backgroundColor: accentColor,
      foregroundColor: Colors.black,
      icon: const Icon(Icons.play_arrow),
      label: const Text('AVVIA TUTTO', style: TextStyle(fontWeight: FontWeight.bold)),
    ),
    if (_workoutStartTime != null) ...[
      const SizedBox(height: 8),
      // FAB secondario: termina e salva gli esercizi già completati
      FloatingActionButton.small(
        heroTag: 'stop',
        onPressed: _finishWorkout,
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.stop, color: Colors.white),
      ),
    ],
  ],
),
```

**Criteri di verifica:**
- "AVVIA TUTTO" apre l'esercizio 1; al termine propone l'esercizio 2 automaticamente
- Al termine dell'ultimo esercizio, salva e torna alla home
- Il vecchio flow (esercizio singolo) continua a funzionare

---

### TASK-015 — PR Detection con celebrazione

**Categoria:** Nuova feature — engagement  
**File:** `lib/data/database_service.dart`, `lib/screens/active_session_screen.dart`

**Fix — Step 1: aggiungere `getPersonalRecord` in `DatabaseService`:**

Dopo `getLastExerciseHistory`, aggiungere:
```dart
/// Restituisce il massimo peso mai sollevato per un dato esercizio.
/// Restituisce null se non esistono sessioni precedenti.
static double? getPersonalRecord(String exerciseName) {
  double? maxWeight;
  for (final w in _workoutBox.values) {
    for (final ex in w.exercises) {
      if (ex.name != exerciseName) continue;
      for (final s in ex.sets) {
        if (s.weight > 0 && (maxWeight == null || s.weight > maxWeight)) {
          maxWeight = s.weight;
        }
      }
    }
  }
  return maxWeight;
}
```

**Fix — Step 2: modificare `ActiveSessionScreen`:**

In `_ActiveSessionScreenState`, aggiungere la variabile:
```dart
double? _currentPR;
```

In `initState()`, dopo `_loadOverloadSuggestion()`:
```dart
_currentPR = DatabaseService.getPersonalRecord(widget.exercise.name);
```

In `_completeActiveSet()`, dopo aver letto `kgVal` (riga ~143), aggiungere:
```dart
final isNewPR = kgVal > 0 && (_currentPR == null || kgVal > _currentPR!);
if (isNewPR) {
  _currentPR = kgVal;
  _showPRCelebration(kgVal);
}
```

**Aggiungere il metodo `_showPRCelebration`:**
```dart
void _showPRCelebration(double weight) {
  HapticFeedback.heavyImpact();
  
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: MediaQuery.of(context).size.height * 0.25,
      left: 32,
      right: 32,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.amber.withOpacity(0.9),
                Colors.orange.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text(
                'NUOVO RECORD!',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '${weight.toStringAsFixed(weight == weight.roundToDouble() ? 0 : 1)} kg',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ).animate()
          .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0),
                 duration: 400.ms, curve: Curves.elasticOut)
          .fadeIn(duration: 200.ms),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 2500), () {
    entry.remove();
  });
}
```

Aggiungere import se non presente: `import 'package:flutter_animate/flutter_animate.dart';`

**Criteri di verifica:**
- Inserire un peso maggiore del record → appare overlay dorato con il nuovo valore
- Il widget sparisce dopo 2.5 secondi senza bloccare l'interazione
- Un peso uguale o inferiore al record → nessun overlay

---

### TASK-016 — Animated Workout Summary Screen

**Categoria:** Nuova feature — premium UX  
**File da creare:** `lib/screens/workout_summary_screen.dart`  
**File da modificare:** `lib/screens/day_detail_screen.dart:87-106`

**Problema:**
Al termine di un allenamento, viene mostrato solo un `SnackBar` verde con il testo
"Allenamento salvato!". Non c'è alcuna soddisfazione visiva o riepilogo dei dati.

**Creare `lib/screens/workout_summary_screen.dart`:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../models/completed_workout.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  final CompletedWorkout workout;

  const WorkoutSummaryScreen({super.key, required this.workout});

  double get _totalVolume {
    double v = 0;
    for (final ex in workout.exercises) {
      for (final s in ex.sets) {
        v += s.weight * s.reps;
      }
    }
    return v;
  }

  String get _durationFormatted {
    final m = workout.durationSeconds ~/ 60;
    final s = workout.durationSeconds % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // Titolo
                Center(
                  child: Text(
                    'OTTIMO LAVORO!',
                    style: GoogleFonts.orbitron(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.cyan,
                      letterSpacing: 2,
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),

                const SizedBox(height: 8),

                Center(
                  child: Text(
                    workout.title,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 40),

                // KPI Cards con TweenAnimationBuilder
                Row(
                  children: [
                    Expanded(child: _AnimatedKPICard(
                      label: 'Volume',
                      value: _totalVolume,
                      unit: 'kg',
                      color: AppTheme.vividPurple,
                      icon: Icons.fitness_center,
                      delay: 300,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _AnimatedKPICard(
                      label: 'Durata',
                      value: workout.durationSeconds / 60,
                      unit: 'min',
                      color: AppTheme.cyan,
                      icon: Icons.timer_outlined,
                      delay: 450,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _AnimatedKPICard(
                      label: 'Esercizi',
                      value: workout.exercises.length.toDouble(),
                      unit: '',
                      color: AppTheme.legsAccent,
                      icon: Icons.list_alt,
                      delay: 600,
                    )),
                  ],
                ),

                const SizedBox(height: 40),

                // Lista esercizi
                const Text(
                  'Riepilogo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ).animate().fadeIn(delay: 700.ms),

                const SizedBox(height: 16),

                ...workout.exercises.asMap().entries.map((entry) {
                  final i = entry.key;
                  final ex = entry.value;
                  return _ExerciseSummaryCard(exercise: ex, delay: 800 + i * 100)
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: 800 + i * 100))
                      .slideX(begin: 0.1);
                }),

                const SizedBox(height: 40),

                // Pulsante torna home
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  icon: const Icon(Icons.home),
                  label: const Text(
                    'TORNA ALLA HOME',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: AppTheme.cyan.withOpacity(0.4),
                  ),
                ).animate().fadeIn(delay: 1200.ms).slideY(begin: 0.2),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedKPICard extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;
  final IconData icon;
  final int delay;

  const _AnimatedKPICard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return AppTheme.glassContainer(
      padding: const EdgeInsets.all(16),
      borderColor: color.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: Duration(milliseconds: 1200 + delay),
            curve: Curves.easeOut,
            builder: (_, v, __) => Text(
              '${v.toStringAsFixed(value > 10 ? 0 : 1)}${unit.isNotEmpty ? ' $unit' : ''}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _ExerciseSummaryCard extends StatelessWidget {
  final CompletedExercise exercise;
  final int delay;

  const _ExerciseSummaryCard({required this.exercise, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppTheme.glassContainer(
        padding: const EdgeInsets.all(16),
        borderColor: AppTheme.vividPurple.withOpacity(0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: exercise.sets.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.vividPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.vividPurple.withOpacity(0.3)),
                ),
                child: Text(
                  '${s.weight.toStringAsFixed(s.weight == s.weight.roundToDouble() ? 0 : 1)}kg × ${s.reps}',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Modificare `lib/screens/day_detail_screen.dart._finishWorkout()`:**

Sostituire il blocco `try` (linee 80-107) con:
```dart
try {
  await DatabaseService.saveWorkout(completedWorkout);
  try {
    await ApiService.saveWorkout(completedWorkout);
    await DatabaseService.markWorkoutSynced(completedWorkout.id); // TASK-013
  } catch (_) {
    // Sync fallita — workout salvato offline, retry al prossimo avvio (TASK-013)
  }

  if (mounted) {
    Navigator.pop(context); // chiude spinner
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(workout: completedWorkout),
      ),
    );
  }
} catch (e) {
  if (mounted) {
    Navigator.pop(context); // chiude spinner
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Errore salvataggio: $e'),
      backgroundColor: Colors.redAccent,
    ));
  }
}
```

Aggiungere import in cima:
```dart
import 'workout_summary_screen.dart';
```

**Criteri di verifica:**
- Al termine allenamento si apre `WorkoutSummaryScreen` invece del SnackBar
- I KPI si animano incrementalmente da 0 al valore finale
- "TORNA ALLA HOME" fa `popUntil(isFirst)` tornando alla tab principale

---

### TASK-017 — Grafico progressione per esercizio specifico

**Categoria:** Nuova feature — analytics  
**File:** `lib/screens/statistics_screen.dart`

**Descrizione:**
Aggiungere una nuova sezione alla schermata Statistiche con un dropdown per selezionare
qualsiasi esercizio mai eseguito, e visualizzare il peso massimo per sessione nel tempo.

**Fix — aggiungere helper e stato in `_StatisticsScreenState`:**

Aggiungere la variabile di stato:
```dart
String? _selectedExercise;
```

Aggiungere i metodi helper:
```dart
List<String> _getAllExerciseNames(List<CompletedWorkout> workouts) {
  final names = <String>{};
  for (final w in workouts) {
    for (final ex in w.exercises) {
      names.add(ex.name);
    }
  }
  final sorted = names.toList()..sort();
  return sorted;
}

List<FlSpot> _getExerciseProgressSpots(String name, List<CompletedWorkout> workouts) {
  // Raggruppa per giorno, prendi il max weight
  final byDay = <DateTime, double>{};
  for (final w in workouts) {
    for (final ex in w.exercises) {
      if (ex.name != name) continue;
      double maxW = 0;
      for (final s in ex.sets) {
        if (s.weight > maxW) maxW = s.weight;
      }
      if (maxW > 0) {
        final day = DateTime(w.date.year, w.date.month, w.date.day);
        if ((byDay[day] ?? 0) < maxW) byDay[day] = maxW;
      }
    }
  }
  if (byDay.isEmpty) return [];
  final sorted = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  return sorted.asMap().entries
      .map((e) => FlSpot(e.key.toDouble(), e.value.value))
      .toList();
}
```

**Fix — aggiungere la sezione UI nel `build`:**

Dopo la sezione "Volume per Distretto Muscolare" (prima di `const SizedBox(height: 60)`),
aggiungere:
```dart
const SizedBox(height: 32),
const Text(
  'Progressione per Esercizio',
  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
).animate().fade(delay: 700.ms),
const SizedBox(height: 12),

// Dropdown selezione esercizio
Builder(builder: (context) {
  final exerciseNames = _getAllExerciseNames(workouts);
  if (exerciseNames.isEmpty) {
    return const Text('Nessun esercizio registrato.',
        style: TextStyle(color: AppTheme.textSecondary));
  }
  // Assicura che _selectedExercise sia valido
  if (_selectedExercise == null || !exerciseNames.contains(_selectedExercise)) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _selectedExercise = exerciseNames.first);
    });
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppTheme.glassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        borderColor: AppTheme.cyan.withOpacity(0.3),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedExercise,
            isExpanded: true,
            dropdownColor: AppTheme.surfaceVariant,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            items: exerciseNames
                .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                .toList(),
            onChanged: (val) => setState(() => _selectedExercise = val),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (_selectedExercise != null) Builder(builder: (_) {
        final spots = _getExerciseProgressSpots(_selectedExercise!, workouts);
        return AppTheme.glassContainer(
          padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 24),
          child: SizedBox(
            height: 200,
            child: spots.length < 2
                ? const Center(
                    child: Text('Servono almeno 2 sessioni per vedere la progressione.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  )
                : LineChart(LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: AppTheme.textSecondary.withOpacity(0.1), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}kg',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
                        ),
                      )),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppTheme.legsAccent,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.legsAccent.withOpacity(0.3),
                              AppTheme.legsAccent.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  )),
          ),
        ).animate().fade(delay: 800.ms).scale();
      }),
    ],
  );
}).animate().fade(delay: 750.ms),
```

**Criteri di verifica:**
- Il dropdown mostra tutti gli esercizi mai registrati in ordine alfabetico
- Selezionando un esercizio il grafico si aggiorna con il peso max per sessione
- Con meno di 2 sessioni appare il messaggio "Servono almeno 2 sessioni"

---

### TASK-018 — Streak allenamenti sulla HomeScreen

**Categoria:** Nuova feature — engagement  
**File:** `lib/data/database_service.dart`, `lib/screens/home_screen.dart`

**Descrizione:**
Mostrare un banner "🔥 N giorni di fila" sulla HomeScreen quando l'utente si allena
per più giorni consecutivi, per incentivare la costanza.

**Fix — Step 1: aggiungere `getCurrentStreak` in `DatabaseService`:**

Nella sezione `// --- WORKOUTS ---`, dopo `getAllWorkouts()`:
```dart
/// Calcola il numero di giorni consecutivi con almeno un allenamento fino a oggi.
/// Un giorno senza allenamento interrompe la streak (eccezione: oggi non conta
/// come interruzione se sono ancora le prime ore del giorno).
static int getCurrentStreak() {
  if (_workoutBox.isEmpty) return 0;

  final Set<String> daysWithWorkout = _workoutBox.values
      .map((w) => '${w.date.year}-${w.date.month.toString().padLeft(2,'0')}-${w.date.day.toString().padLeft(2,'0')}')
      .toSet();

  int streak = 0;
  final today = DateTime.now();

  for (int i = 0; i <= 365; i++) {
    final d = today.subtract(Duration(days: i));
    final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

    if (daysWithWorkout.contains(key)) {
      streak++;
    } else if (i == 0) {
      // Oggi senza allenamento non interrompe la streak (potrebbe ancora allenarsi)
      continue;
    } else {
      break;
    }
  }
  return streak;
}
```

**Fix — Step 2: aggiungere il banner in `home_screen.dart`:**

Nel metodo `build`, dentro la `Column` principale, **dopo** il `const SizedBox(height: 24)`
che precede la lista giorni e **prima** del `Expanded(child: _days.isEmpty ? ...)`:

```dart
// Banner streak (mostrato solo se streak >= 2)
ValueListenableBuilder(
  valueListenable: DatabaseService.workoutBoxListenable(),
  builder: (context, _, __) {
    final streak = DatabaseService.getCurrentStreak();
    if (streak < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppTheme.glassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderColor: Colors.orangeAccent.withOpacity(0.5),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streak giorni di fila!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    streak >= 7
                        ? 'Una settimana intera. Sei inarrestabile!'
                        : 'Continua così, stai andando alla grande!',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
    );
  },
),
```

**Criteri di verifica:**
- Dopo 2 allenamenti in giorni consecutivi: il banner appare
- Dopo un giorno senza allenamento: il banner sparisce
- A 7+ giorni consecutivi: il messaggio di testo cambia
- `streak = 1` (solo oggi): nessun banner (troppo presto per celebrare)

---

## Riepilogo dipendenze aggiuntive

Aggiungere in `pubspec.yaml` nella sezione `dependencies:`:
```yaml
flutter_secure_storage: ^9.0.0   # TASK-002
```

Tutti gli altri task usano package già presenti nel progetto.

---

## Ordine di esecuzione consigliato

1. TASK-002 (sicurezza JWT) — modifiche più rischiose, meglio prima
2. TASK-003 (log sensibili) — correlato a TASK-002
3. TASK-001 (protezione Hive) — fix critico standalone
4. TASK-006 (PlanService) — prerequisito per TASK-012
5. TASK-004 (colori delta) — fix semplice, zero rischi
6. TASK-005 (dead code export) — fix semplice, zero rischi
7. TASK-007 (note sessione) — aggiunta UI standalone
8. TASK-009 (haptic) — una riga per file
9. TASK-010 (tracking per indice) — piccola refactor
10. TASK-011 (biometrics reattivi) — refactor classe
11. TASK-008 (date asse X) — aggiunta helper
12. TASK-013 (isSynced) — modifica TypeAdapter Hive (rischio migration)
13. TASK-012 (auto-sync) — dipende da TASK-006
14. TASK-015 (PR detection) — feature standalone
15. TASK-018 (streak) — feature standalone
16. TASK-016 (summary screen) — nuova schermata
17. TASK-017 (grafico esercizio) — aggiunta statistica
18. TASK-014 (workout flow guidato) — feature più complessa, da fare per ultima
