import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/completed_workout.dart';
import '../models/user_profile.dart';
import '../models/biometric_record.dart';
import '../models/training_data.dart'; // Necessario per parseTrainingDaysFromJson

class DatabaseService {
  static const String _workoutBoxName = 'completed_workouts';
  static const String _userProfileBoxName = 'user_profile';
  static const String _biometricBoxName = 'biometric_records';
  static const String _settingsBoxName = 'settings';

  static Future<void> openBox() async {
    await Hive.openBox<CompletedWorkout>(_workoutBoxName);
    await Hive.openBox<UserProfile>(_userProfileBoxName);
    await Hive.openBox<BiometricRecord>(_biometricBoxName);
    await Hive.openBox(_settingsBoxName);
  }

  static Box<CompletedWorkout> get _workoutBox => Hive.box<CompletedWorkout>(_workoutBoxName);
  static Box<UserProfile> get _userProfileBox => Hive.box<UserProfile>(_userProfileBoxName);
  static Box<BiometricRecord> get _biometricBox => Hive.box<BiometricRecord>(_biometricBoxName);
  static Box get _settingsBox => Hive.box(_settingsBoxName);

  static ValueListenable<Box<CompletedWorkout>> workoutBoxListenable() => _workoutBox.listenable();
  static ValueListenable<Box<BiometricRecord>> biometricBoxListenable() => _biometricBox.listenable();

  // --- SETTINGS ---
  static Future<void> saveAIActivationDate(DateTime date) async {
    await _settingsBox.put('ai_activation_date', date.toIso8601String());
  }

  static DateTime? getAIActivationDate() {
    final dateStr = _settingsBox.get('ai_activation_date') as String?;
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  // --- EMAIL UTENTE ---
  // L'email è la chiave univoca usata per tutte le chiamate REST
  // (es. GET /api/plans/{email}). Viene salvata al completamento
  // dell'onboarding e letta ogni volta che serve contattare il backend.

  /// Persiste l'[email] dell'utente nella box settings di Hive.
  static Future<void> saveUserEmail(String email) async {
    await _settingsBox.put('user_email', email);
  }

  /// Legge l'email dell'utente dalla box settings.
  /// Restituisce `null` se l'utente non ha ancora completato l'onboarding.
  static String? getUserEmail() {
    return _settingsBox.get('user_email') as String?;
  }

  // --- PARSING SCHEDA DA JSON SERVER ---

  // Struttura reale del campo plan_json restituito da /api/plans/{email}:
  //
  // {
  //   "titolo": "Scheda Gianvito",
  //   "giorni": [
  //     {
  //       "nome_giorno": "Lunedì",
  //       "tipo_allenamento": "PUSH – Petto e Spalle",
  //       "esercizi": [
  //         {
  //           "nome": "Panca Piana",
  //           "serie": 4,               ← numero intero di serie da generare
  //           "ripetizioni": "8-10",    ← stringa (può essere "10", "8-12", "AMRAP")
  //           "recupero_secondi": 150,
  //           "note_esecuzione": "RIR 1-2, bilanciere"
  //         }
  //       ]
  //     }
  //   ]
  // }

  /// Parsa il campo `plan_json` della risposta REST in oggetti [TrainingDay].
  ///
  /// [planJson] è la [Map] corrispondente all'intero oggetto `plan_json`,
  /// che contiene le chiavi `titolo` e `giorni`.
  ///
  /// Il parser è **robusto**: usa `?? defaultValue` su ogni campo per non
  /// crashare in caso di struttura parziale o aggiornamenti futuri del backend.
  ///
  /// Mapping chiavi server → modello Dart:
  /// | JSON server          | Modello Dart                    |
  /// |----------------------|---------------------------------|
  /// | `giorni`             | `List<TrainingDay>`             |
  /// | `nome_giorno`        | `TrainingDay.title`             |
  /// | `tipo_allenamento`   | `TrainingDay.subtitle`          |
  /// | `esercizi`           | `List<Exercise>`                |
  /// | `nome`               | `Exercise.name`                 |
  /// | `serie` (int)        | N copie di `ExerciseSet`        |
  /// | `ripetizioni` (String)| `ExerciseSet.targetReps` (int parsed) + `Exercise.loadNote` |
  /// | `recupero_secondi`   | `ExerciseSet.targetRestSeconds` |
  /// | `note_esecuzione`    | `Exercise.externalNote`         |
  static List<TrainingDay> parseTrainingDaysFromJson(Map<String, dynamic> planJson) {
    final List<TrainingDay> days = [];

    // Estrae la lista dei giorni dalla chiave "giorni"
    final rawGiorni = planJson['giorni'] as List<dynamic>? ?? [];

    for (final dayMap in rawGiorni) {
      if (dayMap is! Map<String, dynamic>) continue; // Salta elementi malformati

      // --- Parsing esercizi del giorno ---
      final rawEsercizi = dayMap['esercizi'] as List<dynamic>? ?? [];
      final List<Exercise> exercises = [];

      for (final exMap in rawEsercizi) {
        if (exMap is! Map<String, dynamic>) continue;

        // "serie" è il numero di serie da generare (int), non un array
        final int numSerie = (exMap['serie'] as int?) ?? 3;

        // "ripetizioni" è una stringa descrittiva (es. "8-10", "12", "AMRAP")
        // → conserviamo la stringa intera come loadNote per la visualizzazione
        // → estraiamo il primo numero intero come targetReps per il contatore
        final String ripetizioniStr = (exMap['ripetizioni'] as String?) ?? '10';
        final int targetReps = _parseRepsFromString(ripetizioniStr);

        // "recupero_secondi" è già un int
        final int recupero = (exMap['recupero_secondi'] as int?) ?? 90;

        // Genera le [numSerie] serie partendo da 1
        final List<ExerciseSet> sets = List.generate(
          numSerie,
          (i) => ExerciseSet(
            number: i + 1,
            targetReps: targetReps,        // primo numero estratto da ripetizioni
            minTargetReps: 0,
            targetRestSeconds: recupero,
            weight: 0.0,                   // peso da inserire durante la sessione
            actualReps: 0,
            isCompleted: false,
          ),
        );

        exercises.add(Exercise(
          // ID generato automaticamente (il server non lo invia)
          id:              'ex_${exercises.length}',
          // "nome" → nome dell'esercizio
          name:            (exMap['nome']               as String?) ?? 'Esercizio senza nome',
          // Il server non invia "setup" (tipo attrezzatura) → stringa vuota
          setup:           '',
          // Usiamo "ripetizioni" come nota di carico (es. "8-10 reps")
          // così viene visualizzato nell'UI del dettaglio esercizio
          loadNote:        ripetizioniStr,
          // Video tutorial dal backend
          videoUrl:        (exMap['video_url']           as String?) ?? '',
          // "note_esecuzione" → nota tecnica del trainer
          externalNote:    exMap['note_esecuzione']      as String?,
          // "gruppo_muscolare" → Petto | Schiena | Gambe | Spalle | Braccia | Altro
          gruppoMuscolare: exMap['gruppo_muscolare']     as String?,
          sets:            sets,
        ));
      }

      days.add(TrainingDay(
        // ID basato sull'indice (il server usa nomi, non ID numerici)
        id:       'd${days.length + 1}',
        // "nome_giorno" → titolo del giorno (es. "Lunedì", "PUSH")
        title:    (dayMap['nome_giorno']      as String?) ?? 'Giorno ${days.length + 1}',
        // "tipo_allenamento" → sottotitolo con muscoli bersaglio
        subtitle: (dayMap['tipo_allenamento'] as String?) ?? '',
        // Il server non ha un campo "priority" separato
        priority: '',
        exercises: exercises,
      ));
    }

    return days;
  }

  /// Estrae il primo numero intero da una stringa di ripetizioni.
  ///
  /// Esempi:
  /// - `"8-10"` → `8`
  /// - `"12"`   → `12`
  /// - `"AMRAP"` → `10` (default)
  /// - `"15+"`  → `15`
  static int _parseRepsFromString(String repsStr) {
    // Cerca la prima sequenza di cifre nella stringa
    final match = RegExp(r'\d+').firstMatch(repsStr);
    if (match == null) return 10; // Fallback sicuro se non ci sono numeri
    return int.tryParse(match.group(0)!) ?? 10;
  }

  // --- USER PROFILE ---
  static Future<void> saveUserProfile(UserProfile profile) async {
    await _userProfileBox.put('profile', profile);
  }

  static UserProfile? getUserProfile() {
    return _userProfileBox.get('profile');
  }

  // --- BIOMETRIC RECORDS ---
  static Future<void> saveBiometricRecord(BiometricRecord record) async {
    final dateKey = '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}';
    await _biometricBox.put(dateKey, record);
  }

  static BiometricRecord? getLatestBiometricRecord() {
    if (_biometricBox.isEmpty) return null;
    final records = _biometricBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return records.first;
  }

  static String getBiometricHistoryForAI() {
    if (_biometricBox.isEmpty) return 'Nessun dato biometrico registrato.';
    final records = _biometricBox.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    StringBuffer buffer = StringBuffer();
    for (var r in records) {
      final dateStr = '${r.date.day.toString().padLeft(2, '0')}/${r.date.month.toString().padLeft(2, '0')}/${r.date.year}';
      buffer.writeln('- $dateStr: Peso ${r.weight}kg, Addome ${r.abdomen}cm, Petto ${r.chest}cm, Bicipite ${r.biceps}cm, Vita ${r.waist ?? '—'}cm, Coscia ${r.thigh ?? '—'}cm');
    }
    return buffer.toString().trim();
  }

  // --- WORKOUTS ---
  static Future<void> saveWorkout(CompletedWorkout workout) async {
    await _workoutBox.add(workout);
  }

  static List<CompletedWorkout> getAllWorkouts() {
    return _workoutBox.values.toList();
  }

  static List<CompletedWorkout> getWorkoutsForMonth(DateTime month) {
    return _workoutBox.values.where((workout) {
      return workout.date.year == month.year && workout.date.month == month.month;
    }).toList();
  }

  static CompletedExercise? getLastExerciseHistory(String exerciseName) {
    final workouts = _workoutBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (var w in workouts) {
      for (var e in w.exercises) {
        if (e.name == exerciseName) {
          return e;
        }
      }
    }
    return null;
  }

  static double getVolumeLast3Weeks() {
    final threeWeeksAgo = DateTime.now().subtract(const Duration(days: 21));
    double totalVolume = 0;
    for (var w in _workoutBox.values) {
      if (w.date.isAfter(threeWeeksAgo)) {
        for (var e in w.exercises) {
          for (var s in e.sets) {
            totalVolume += (s.weight * s.reps);
          }
        }
      }
    }
    return totalVolume;
  }

  static String getWorkoutHistoryForAI(int weeks) {
    final now = DateTime.now();
    final recentWorkouts = _workoutBox.values.where((w) => now.difference(w.date).inDays <= (weeks * 7)).toList();
    recentWorkouts.sort((a, b) => a.date.compareTo(b.date));
    
    if (recentWorkouts.isEmpty) return 'Nessun allenamento registrato.';

    Map<int, List<CompletedWorkout>> weeksMap = {};
    for (var w in recentWorkouts) {
      final daysAgo = now.difference(w.date).inDays;
      final weekFromNow = (daysAgo / 7).floor(); 
      final weekIndex = weeks - weekFromNow;
      
      if (weeksMap[weekIndex] == null) {
        weeksMap[weekIndex] = [];
      }
      weeksMap[weekIndex]!.add(w);
    }

    StringBuffer buffer = StringBuffer();
    final sortedWeeks = weeksMap.keys.toList()..sort();

    for (var wIdx in sortedWeeks) {
      buffer.writeln('week$wIdx:');
      for (var w in weeksMap[wIdx]!) {
        final dateStr = '${w.date.day.toString().padLeft(2, '0')}/${w.date.month.toString().padLeft(2, '0')}/${w.date.year}';
        buffer.writeln('- $dateStr ${w.title}');
        for (var ex in w.exercises) {
          final setsStr = ex.sets.map((s) => '${s.weight}kg x ${s.reps}').join(', ');
          buffer.writeln('  ${ex.name}: $setsStr');
        }
      }
      buffer.writeln('###');
    }

    return buffer.toString().trim();
  }

  static String exportDatabaseJson() {
    final workouts = getAllWorkouts().map((w) => w.toJson()).toList();
    final profile = getUserProfile()?.toJson();
    final biometrics = _biometricBox.values.map((b) => b.toJson()).toList();

    final exportData = {
      'workouts': workouts,
      'profile': profile,
      'biometrics': biometrics,
    };

    return jsonEncode(exportData);
  }

  static Future<void> importDatabaseJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);

      // Svuotiamo i vecchi dati prima di ripristinare il backup
      await _workoutBox.clear();
      await _biometricBox.clear();

      if (decoded is List) {
        final importedWorkouts = decoded.map((e) => CompletedWorkout.fromJson(e as Map<String, dynamic>)).toList();
        for (var w in importedWorkouts) {
          await _workoutBox.add(w);
        }
      } else if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('workouts') && decoded['workouts'] != null) {
          final importedWorkouts = (decoded['workouts'] as List)
              .map((e) => CompletedWorkout.fromJson(e as Map<String, dynamic>))
              .toList();
          for (var w in importedWorkouts) {
            await _workoutBox.add(w);
          }
        }

        if (decoded.containsKey('profile') && decoded['profile'] != null) {
          final p = UserProfile.fromJson(decoded['profile']);
          await saveUserProfile(p);
        }

        if (decoded.containsKey('biometrics') && decoded['biometrics'] != null) {
          final importedBiometrics = (decoded['biometrics'] as List)
              .map((e) => BiometricRecord.fromJson(e as Map<String, dynamic>))
              .toList();
          for (var b in importedBiometrics) {
            await saveBiometricRecord(b);
          }
        }
      }
    } catch (e) {
      throw Exception('Formato JSON non valido o dati corrotti.');
    }
  }

  static Future<void> _mergeWorkouts(List<CompletedWorkout> importedWorkouts) async {
    final existingIds = _workoutBox.values.map((w) => w.id).toSet();
    for (var w in importedWorkouts) {
      if (!existingIds.contains(w.id)) {
        await _workoutBox.add(w);
        existingIds.add(w.id);
      }
    }
  }
}
