import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/database_service.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../models/completed_workout.dart';
import '../models/biometric_record.dart';
import '../models/user_profile.dart';

class SyncService {
  static bool _isSyncing = false;

  static Future<void> syncAllPendingData() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) return; // Non autenticato

      // ==========================================
      // FASE 1: PUSH (Upload dati locali pendenti)
      // ==========================================

      // 1A. Sincronizza Workouts
      final pendingWorkouts = DatabaseService.getUnsyncedWorkouts();
      for (final workout in pendingWorkouts) {
        try {
          final backendId = await ApiService.saveWorkout(workout);
          await DatabaseService.updateWorkoutId(workout.id, backendId);
          await DatabaseService.markWorkoutSynced(backendId);
          if (kDebugMode) debugPrint('✅ Push Workout $backendId completato');
        } catch (e) {
          debugPrint('❌ Push fallito per Workout ${workout.id}: $e');
        }
      }

      // 1B. Sincronizza Biometric Records
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
          if (kDebugMode) debugPrint('✅ Push BiometricRecord completato per data ${record.date}');
        } catch (e) {
          debugPrint('❌ Push fallito per BiometricRecord in data ${record.date}: $e');
        }
      }

      // ==========================================
      // FASE 2: PULL (Download storico remoto)
      // ==========================================

      // 2A. Download Storico Workouts
      try {
        final remoteWorkouts = await ApiService.getWorkoutHistory(userId);
        final localWorkouts = DatabaseService.getAllWorkouts();
        final localIds = localWorkouts.map((w) => w.id).toSet();

        for (final rw in remoteWorkouts) {
          // parse exercises correctly
          // WorkoutLogResponse JSON
          final exercisesJson = rw['exercises_json'] as String? ?? '[]';
          final exercisesList = jsonDecode(exercisesJson) as List<dynamic>;
          rw['exercises'] = exercisesList;
          
          final cw = CompletedWorkout.fromJson(rw);
          cw.isSynced = true; 
          
          if (!localIds.contains(cw.id)) {
            await DatabaseService.saveWorkout(cw);
            if (kDebugMode) debugPrint('✅ Pull nuovo Workout: ${cw.id}');
          }
        }
      } catch (e) {
        debugPrint('❌ Pull fallito per Storico Workouts: $e');
      }

      // 2B. Download Storico Biometrics
      try {
        final remoteBio = await ApiService.getBiometricHistory(userId);
        final localBio = DatabaseService.getAllBiometricRecords();
        // Le misure locali sono identificate dalla data
        final localDates = localBio.map((b) => b.date.toIso8601String().substring(0, 10)).toSet();

        for (final rb in remoteBio) {
          final record = BiometricRecord.fromJson(rb);
          record.isSynced = true;
          
          final dateStr = record.date.toIso8601String().substring(0, 10);
          if (!localDates.contains(dateStr)) {
            await DatabaseService.saveBiometricRecord(record);
            if (kDebugMode) debugPrint('✅ Pull nuovo BiometricRecord: $dateStr');
          }
        }
      } catch (e) {
        debugPrint('❌ Pull fallito per Storico Biometrics: $e');
      }

      // 2C. Download User Profile
      try {
        final userData = await ApiService.getMe();
        final int eta = userData['age'] ?? 0;
        final int birthYear = DateTime.now().year - eta;
        final newProfile = UserProfile(
          name: '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'.trim(),
          dateOfBirth: DateTime(birthYear > 1900 ? birthYear : 1990, 7, 1),
          height: (userData['height'] as num?)?.toDouble() ?? 0.0,
          sesso: userData['gender'] ?? '',
          bmi: (userData['bmi'] as num?)?.toDouble(),
          bmr: userData['bmr'] as int?,
          whr: (userData['whr'] as num?)?.toDouble(),
          acquaLitri: (userData['acqua_litri'] as num?)?.toDouble(),
          proteineMin: userData['proteine_min'] as int?,
          proteineMax: userData['proteine_max'] as int?,
          bodyFatPerc: (userData['body_fat_perc'] as num?)?.toDouble(),
        );
        await DatabaseService.saveUserProfile(newProfile);
        if (kDebugMode) debugPrint('✅ Pull UserProfile completato');
      } catch (e) {
        debugPrint('❌ Pull fallito per UserProfile: $e');
      }
    } finally {
      _isSyncing = false;
    }
  }
}
