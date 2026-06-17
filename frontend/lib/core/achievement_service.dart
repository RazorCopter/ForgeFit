import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/completed_workout.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class UnlockedAchievement {
  final Achievement achievement;
  final DateTime unlockedAt;

  const UnlockedAchievement({required this.achievement, required this.unlockedAt});
}

class AchievementService {
  static const String _hiveKey = 'achievements_v1';

  static const List<Achievement> all = [
    Achievement(
      id: 'first_workout',
      name: 'Prima Volta',
      description: 'Hai completato il tuo primo allenamento!',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFF00E5FF),
    ),
    Achievement(
      id: 'streak_7',
      name: 'Settimana di Fuoco',
      description: '7 giorni consecutivi di allenamento',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFFFD700),
    ),
    Achievement(
      id: 'streak_30',
      name: 'Leggendario',
      description: '30 giorni consecutivi di allenamento',
      icon: Icons.bolt_rounded,
      color: Color(0xFFBB86FC),
    ),
    Achievement(
      id: 'total_50',
      name: 'Veterano',
      description: '50 sessioni completate',
      icon: Icons.military_tech_rounded,
      color: Color(0xFFFF6D00),
    ),
    Achievement(
      id: 'volume_100k',
      name: 'Tonnellate',
      description: '100.000 kg di volume totale cumulato',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFF00E676),
    ),
    Achievement(
      id: 'biometric',
      name: 'Data Nerd',
      description: 'Prima misurazione biometrica inserita',
      icon: Icons.monitor_heart_rounded,
      color: Color(0xFFFF4081),
    ),
    Achievement(
      id: 'pr_hunter',
      name: 'PR Hunter',
      description: '10 personal record battuti',
      icon: Icons.trending_up_rounded,
      color: Color(0xFFFFD740),
    ),
    Achievement(
      id: 'marathon',
      name: 'Maratoneta',
      description: '50 ore totali di allenamento',
      icon: Icons.timer_rounded,
      color: Color(0xFF7C4DFF),
    ),
    Achievement(
      id: 'early_bird',
      name: 'Early Bird',
      description: 'Allenamento iniziato prima delle 7:00',
      icon: Icons.wb_sunny_rounded,
      color: Color(0xFFFF9800),
    ),
    Achievement(
      id: 'night_owl',
      name: 'Creatura della Notte',
      description: 'Allenamento iniziato dopo le 22:00',
      icon: Icons.nights_stay_rounded,
      color: Color(0xFF00B0FF),
    ),
    Achievement(
      id: 'weekend_warrior',
      name: 'Guerriero del Weekend',
      description: 'Allenamento sia Sabato che Domenica',
      icon: Icons.shield_rounded,
      color: Color(0xFFFFC107),
    ),
    Achievement(
      id: 'legs_50k',
      name: 'Gambe d\'Acciaio',
      description: '50.000 kg di volume per le Gambe',
      icon: Icons.directions_run_rounded,
      color: Color(0xFFF44336),
    ),
    Achievement(
      id: 'chest_50k',
      name: 'Petto di Bronzo',
      description: '50.000 kg di volume per il Petto',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFF00E5FF),
    ),
    Achievement(
      id: 'back_50k',
      name: 'Schiena a V',
      description: '50.000 kg di volume per il Dorso',
      icon: Icons.accessibility_new_rounded,
      color: Color(0xFF00E676),
    ),
    Achievement(
      id: 'spartan_300',
      name: 'Spartano (300)',
      description: '300 ripetizioni in un singolo allenamento',
      icon: Icons.sports_martial_arts_rounded,
      color: Color(0xFFBCAAA4),
    ),
    Achievement(
      id: 'tut_master',
      name: 'Maestro del Tempo',
      description: '20 minuti di TUT in un allenamento',
      icon: Icons.hourglass_bottom_rounded,
      color: Color(0xFF9C27B0),
    ),
    Achievement(
      id: 'beast_mode',
      name: 'Bestia da Soma',
      description: '10.000 kg sollevati in un allenamento',
      icon: Icons.pets_rounded,
      color: Color(0xFFD50000),
    ),
    Achievement(
      id: 'versatile',
      name: 'Versatile',
      description: 'Allenati 4 gruppi muscolari diversi',
      icon: Icons.category_rounded,
      color: Color(0xFFFFEB3B),
    ),
  ];

  static Box get _settingsBox => Hive.box('settings');

  /// Restituisce la mappa {id: DateTime} degli achievement già sbloccati.
  static Map<String, DateTime> _loadUnlocked() {
    final raw = _settingsBox.get(_hiveKey) as String?;
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, DateTime.parse(v as String)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveUnlocked(Map<String, DateTime> unlocked) async {
    final map = unlocked.map((k, v) => MapEntry(k, v.toIso8601String()));
    await _settingsBox.put(_hiveKey, jsonEncode(map));
  }

  /// Ritorna la lista degli [UnlockedAchievement] già salvati.
  static List<UnlockedAchievement> getUnlocked() {
    final map = _loadUnlocked();
    return all
        .where((a) => map.containsKey(a.id))
        .map((a) => UnlockedAchievement(achievement: a, unlockedAt: map[a.id]!))
        .toList();
  }

  /// Controlla tutti gli achievement, salva i nuovi, e restituisce solo quelli
  /// appena sbloccati in questa chiamata (da mostrare come popup).
  static Future<List<Achievement>> checkAll(
    List<CompletedWorkout> workouts, {
    bool hasBiometric = false,
    int currentStreak = 0,
  }) async {
    final unlocked = _loadUnlocked();
    if (unlocked.length >= all.length) return const [];
    final now = DateTime.now();
    final newlyUnlocked = <Achievement>[];

    void check(String id, bool condition) {
      if (condition && !unlocked.containsKey(id)) {
        unlocked[id] = now;
        newlyUnlocked.add(all.firstWhere((a) => a.id == id));
      }
    }

    // Single pass (sorted by date) for volume, duration, and PR counting.
    // Sorting is only done once; PR counting early-exits at 10 when already unlocked.
    final sorted = List<CompletedWorkout>.from(workouts)
      ..sort((a, b) => a.date.compareTo(b.date));

    double totalVolume = 0;
    int totalSeconds = 0;
    final bests = <String, double>{};
    int prs = 0;
    final prAlreadyUnlocked = unlocked.containsKey('pr_hunter');

    double legsVolume = 0;
    double chestVolume = 0;
    double backVolume = 0;

    // weekend_warrior: controlla stesso weekend ISO (anno + numero settimana)
    final weekendDates = <String>{};
    bool weekendSameWeek = false;

    bool hasEarlyBird = false;
    bool hasNightOwl = false;

    for (final w in sorted) {
      totalSeconds += w.durationSeconds;

      if (!hasEarlyBird && w.date.hour < 7)  hasEarlyBird = true;
      if (!hasNightOwl  && w.date.hour >= 22) hasNightOwl  = true;

      if (w.date.weekday == DateTime.saturday || w.date.weekday == DateTime.sunday) {
        // chiave univoca per settimana ISO: "anno-settimana"
        final weekKey = '${w.date.year}-${_isoWeek(w.date)}';
        weekendDates.add('$weekKey-${w.date.weekday}');
        if (!weekendSameWeek) {
          final satKey = '$weekKey-${DateTime.saturday}';
          final sunKey = '$weekKey-${DateTime.sunday}';
          if (weekendDates.contains(satKey) && weekendDates.contains(sunKey)) {
            weekendSameWeek = true;
          }
        }
      }

      int workoutReps = 0;
      double workoutVolume = 0;
      int workoutTUT = 0;
      Set<String> muscleGroups = {};

      for (final ex in w.exercises) {
        if (ex.gruppoMuscolare != null && ex.gruppoMuscolare!.isNotEmpty) {
          muscleGroups.add(ex.gruppoMuscolare!);
        }

        for (final s in ex.sets) {
          final setVolume = s.weight * s.reps;
          totalVolume += setVolume;
          workoutVolume += setVolume;
          workoutReps += s.reps;
          workoutTUT += s.timeUnderTension;

          if (ex.gruppoMuscolare?.toLowerCase() == 'gambe') {
            legsVolume += setVolume;
          } else if (ex.gruppoMuscolare?.toLowerCase() == 'petto') {
            chestVolume += setVolume;
          } else if (ex.gruppoMuscolare?.toLowerCase() == 'dorso') {
            backVolume += setVolume;
          }
        }
        // PR counting — skip once threshold reached and achievement already persisted
        if (!prAlreadyUnlocked && prs < 10) {
          final prev = bests[ex.name] ?? 0;
          double maxWeight = prev;
          for (final s in ex.sets) {
            if (s.weight > maxWeight) maxWeight = s.weight;
          }
          if (maxWeight > prev) {
            if (prev > 0) prs++; // il primo record non conta come PR battuto
            bests[ex.name] = maxWeight;
          }
        }
      }
      
      check('spartan_300', workoutReps >= 300);
      check('tut_master', workoutTUT >= 1200);
      check('beast_mode', workoutVolume >= 10000);
      check('versatile', muscleGroups.length >= 4);
    }

    check('first_workout', workouts.isNotEmpty);
    check('streak_7', currentStreak >= 7);
    check('streak_30', currentStreak >= 30);
    check('total_50', workouts.length >= 50);
    check('volume_100k', totalVolume >= 100000);
    check('biometric', hasBiometric);         // hasBiometric = records >= 1
    check('pr_hunter', prAlreadyUnlocked || prs >= 10);
    check('marathon', totalSeconds >= 50 * 3600);
    check('weekend_warrior', weekendSameWeek);
    check('legs_50k', legsVolume >= 50000);
    check('chest_50k', chestVolume >= 50000);
    check('back_50k', backVolume >= 50000);
    check('early_bird', hasEarlyBird);
    check('night_owl', hasNightOwl);

    if (newlyUnlocked.isNotEmpty) {
      await _saveUnlocked(unlocked);
    }
    return newlyUnlocked;
  }

  // Numero settimana ISO 8601 (settimana 1 = quella con il primo giovedì dell'anno).
  static int _isoWeek(DateTime d) {
    final thursday = d.add(Duration(days: 4 - (d.weekday == 7 ? 0 : d.weekday)));
    final firstThursday = DateTime(thursday.year, 1, 1).add(
      Duration(days: (4 - (DateTime(thursday.year, 1, 1).weekday == 7 ? 0 : DateTime(thursday.year, 1, 1).weekday)) % 7),
    );
    return ((thursday.difference(firstThursday).inDays) ~/ 7) + 1;
  }
}
