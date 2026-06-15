import 'package:health/health.dart';
import '../models/completed_workout.dart';

class HealthService {
  static final Health _health = Health();

  // Cached per-session permission result — avoids a platform round-trip on every write.
  // Reset to null on hot-restart only; null means "not yet checked this session".
  static bool? _permissionsGranted;

  static const _writeTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  static Future<bool> requestPermissions() async {
    if (_permissionsGranted != null) return _permissionsGranted!;
    try {
      final permissions = _writeTypes.map((_) => HealthDataAccess.WRITE).toList();
      _permissionsGranted = await _health.requestAuthorization(_writeTypes, permissions: permissions);
      return _permissionsGranted!;
    } catch (_) {
      return false;
    }
  }

  /// Scrive il workout completato su Google Fit / Apple Health.
  /// Silenzioso in caso di errore: non blocca mai la UI.
  static Future<void> writeWorkout(CompletedWorkout workout) async {
    try {
      final granted = await requestPermissions();
      if (!granted) return;

      final start = workout.date;
      final end = start.add(Duration(seconds: workout.durationSeconds));

      // Stima calorie: volume_kg * 0.05 kcal (approssimazione strength training)
      double totalVolume = 0;
      for (final ex in workout.exercises) {
        for (final s in ex.sets) {
          totalVolume += s.weight * s.reps;
        }
      }
      final estimatedKcal = totalVolume * 0.05;

      await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
        start: start,
        end: end,
        totalEnergyBurned: estimatedKcal.round(),
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      );
    } catch (_) {
      // Fallimento silenzioso — Health non è disponibile o permessi negati
    }
  }
}
