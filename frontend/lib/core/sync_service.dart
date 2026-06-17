import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/database_service.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../models/completed_workout.dart';
import '../models/biometric_record.dart';
import '../models/user_profile.dart';
import 'achievement_service.dart';

class SyncService {
  // Completer usato come mutex: se non-null c'è già una sync in corso
  static Completer<void>? _syncCompleter;
  static final ValueNotifier<String?> backendVersionNotifier = ValueNotifier(null);

  static Future<void> syncAllPendingData() async {
    // Se c'è già una sync attiva, aspetta che finisca invece di abortire silenziosamente
    if (_syncCompleter != null) {
      return _syncCompleter!.future;
    }
    _syncCompleter = Completer<void>();

    try {
      final userId = await AuthService.getUserId();
      if (userId == null) return;

      // ==========================================
      // FASE 1: PUSH parallelo (workout + biometrics simultanei)
      // ==========================================
      final pendingWorkouts = DatabaseService.getUnsyncedWorkouts();
      final pendingBiometrics =
          DatabaseService.getAllBiometricRecords().where((r) => !r.isSynced).toList();

      await Future.wait([
        // 1A. Workout push — sequenziale internamente (ordine ID importante)
        Future(() async {
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
        }),
        // 1B. Biometrics push — indipendente dai workout, eseguito in parallelo
        Future(() async {
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
                'created_at': record.date.toIso8601String(),
              });
              record.isSynced = true;
              await DatabaseService.saveBiometricRecord(record);
              if (kDebugMode) debugPrint('✅ Push BiometricRecord completato per data ${record.date}');
            } catch (e) {
              debugPrint('❌ Push fallito per BiometricRecord in data ${record.date}: $e');
            }
          }
        }),
      ]);

      // ==========================================
      // FASE 2: PULL (Download storico remoto)
      // ==========================================

      // 2A. Download Storico Workouts
      try {
        final remoteWorkouts = await ApiService.getWorkoutHistory(userId);
        final localWorkouts = DatabaseService.getAllWorkouts();
        final localIds = localWorkouts.map((w) => w.id).toSet();

        for (final rw in remoteWorkouts) {
          final cw = CompletedWorkout.fromJson(rw);
          cw.isSynced = true; 
          
          if (!localIds.contains(cw.id)) {
            await DatabaseService.saveWorkout(cw);
            if (kDebugMode) debugPrint('✅ Pull nuovo Workout: ${cw.id}');
          } else {
            // Se esiste già, aggiorniamolo per assicurarci che i dati non siano corrotti
            final existing = localWorkouts.firstWhere((w) => w.id == cw.id);
            if (existing.exercises.isEmpty && cw.exercises.isNotEmpty) {
              await DatabaseService.saveWorkout(cw);
              if (kDebugMode) debugPrint('✅ Ripristinato Workout corrotto: ${cw.id}');
            }
          }
        }

        // Eliminiamo localmente gli allenamenti che sono stati cancellati sul server
        final remoteIds = remoteWorkouts.map((rw) => rw['id'].toString()).toSet();
        for (final lw in localWorkouts) {
          // Se un allenamento è marcato come sincronizzato (quindi esiste/esisteva sul server)
          // e ha un ID numerico (assegnato dal server), ma non è più presente nella lista remota,
          // significa che è stato eliminato da un altro client o dal web. Lo rimuoviamo.
          if (lw.isSynced && int.tryParse(lw.id) != null) {
            if (!remoteIds.contains(lw.id)) {
              await DatabaseService.deleteWorkout(lw);
              if (kDebugMode) debugPrint('🗑️ Allenamento ${lw.id} eliminato in remoto, rimosso localmente');
            }
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
        backendVersionNotifier.value = userData['version']?.toString();
        final int eta = userData['age'] ?? 0;
        final int birthYear = DateTime.now().year - eta;
        final newProfile = UserProfile(
          name: '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'.trim(),
          dateOfBirth: DateTime(birthYear > 1900 ? birthYear : 1990, 7, 1),
          height: (userData['height'] as num?)?.toDouble() ?? 0.0,
          sesso: userData['gender'] ?? '',
          bmi: (userData['bmi'] as num?)?.toDouble(),
          bmr: (userData['bmr'] as num?)?.toInt(),
          whr: (userData['whr'] as num?)?.toDouble(),
          acquaLitri: (userData['acqua_litri'] as num?)?.toDouble(),
          proteineMin: (userData['proteine_min'] as num?)?.toInt(),
          proteineMax: (userData['proteine_max'] as num?)?.toInt(),
          bodyFatPerc: (userData['body_fat_perc'] as num?)?.toDouble(),
        );
        await DatabaseService.saveUserProfile(newProfile);
        if (kDebugMode) debugPrint('✅ Pull UserProfile completato');
      } catch (e) {
        debugPrint('❌ Pull fallito per UserProfile: $e');
      }

      // Ricalcolo achievements post-sync
      try {
        final workouts = DatabaseService.getAllWorkouts();
        final streak = DatabaseService.getCurrentStreak();
        final hasBiometric = DatabaseService.getAllBiometricRecords().isNotEmpty;
        await AchievementService.checkAll(
          workouts,
          hasBiometric: hasBiometric,
          currentStreak: streak,
        );
        if (kDebugMode) debugPrint('✅ Ricalcolo Achievements post-sync completato');
      } catch (e) {
        debugPrint('❌ Errore ricalcolo Achievements post-sync: $e');
      }
    } finally {
      final c = _syncCompleter;
      _syncCompleter = null;
      c?.complete();
    }
  }
}
