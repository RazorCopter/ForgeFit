import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/database_service.dart';
import 'api_service.dart';

class SyncService {
  static bool _isSyncing = false;

  /// Tenta la sincronizzazione di tutti i dati pendenti.
  static Future<void> syncAllPendingData() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    try {
      // 1. Sincronizza Workouts
      final pendingWorkouts = DatabaseService.getUnsyncedWorkouts();
      for (final workout in pendingWorkouts) {
        try {
          await ApiService.saveWorkout(workout);
          await DatabaseService.markWorkoutSynced(workout.id);
          if (kDebugMode) debugPrint('✅ Sync Workout ${workout.id} completato');
        } catch (e) {
          debugPrint('❌ Sync fallito per Workout ${workout.id}: $e');
        }
      }

      // 2. Sincronizza Biometric Records
      final pendingBiometrics = DatabaseService.getAllBiometricRecords().where((r) => !r.isSynced).toList();
      for (final record in pendingBiometrics) {
        try {
          await ApiService.postMeasurements({
            'weight': record.weight,
            'hips': record.hips,
            'calf': record.calf,
            'chest': record.chest,
            'biceps': record.biceps,
            'waist': record.waist,
            'thigh': record.thigh,
            'neck': record.neck,
            'wrist': record.wrist,
            'goal': 'Sync automatico',
          });
          record.isSynced = true;
          await DatabaseService.saveBiometricRecord(record);
          if (kDebugMode) debugPrint('✅ Sync BiometricRecord completato per data ${record.date}');
        } catch (e) {
          debugPrint('❌ Sync fallito per BiometricRecord in data ${record.date}: $e');
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}
