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

    for (final w in sorted) {
      totalSeconds += w.durationSeconds;
      for (final ex in w.exercises) {
        for (final s in ex.sets) {
          totalVolume += s.weight * s.reps;
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
    }

    check('first_workout', workouts.isNotEmpty);
    check('streak_7', currentStreak >= 7);
    check('streak_30', currentStreak >= 30);
    check('total_50', workouts.length >= 50);
    check('volume_100k', totalVolume >= 100000);
    check('biometric', hasBiometric);
    check('pr_hunter', prAlreadyUnlocked || prs >= 10);
    check('marathon', totalSeconds >= 50 * 3600);

    if (newlyUnlocked.isNotEmpty) {
      await _saveUnlocked(unlocked);
    }
    return newlyUnlocked;
  }
}
