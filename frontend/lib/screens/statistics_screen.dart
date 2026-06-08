import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import '../models/completed_workout.dart';
import '../data/database_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _bestSet(List<CompletedWorkout> workouts) {
    if (workouts.isEmpty) return 'N/A';
    double maxLoad = 0;
    String exName = '';
    for (var w in workouts) {
      for (var ex in w.exercises) {
        for (var set in ex.sets) {
          if (set.weight > maxLoad) {
            maxLoad = set.weight;
            exName = ex.name;
          }
        }
      }
    }
    return maxLoad > 0 ? '${maxLoad}kg ($exName)' : 'N/A';
  }

  String _avgVolume(List<CompletedWorkout> workouts) {
    if (workouts.isEmpty) return '0 kg';
    double total = 0;
    for (var w in workouts) {
      for (var ex in w.exercises) {
        for (var set in ex.sets) {
          total += set.weight * set.reps;
        }
      }
    }
    return '${(total / workouts.length).toStringAsFixed(0)} kg';
  }

  /// Tempo complessivo trascorso ad allenarsi, formattato come "Xh Ym".
  String _totalTrainingTime(List<CompletedWorkout> workouts) {
    if (workouts.isEmpty) return '0h 0m';
    final totalSec = workouts.fold<int>(0, (sum, w) => sum + w.durationSeconds);
    final hours   = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  List<FlSpot> _getVolumeSpots(List<CompletedWorkout> workouts) {
    if (workouts.isEmpty) return [const FlSpot(0, 0)];
    
    final List<CompletedWorkout> sortedWorkouts = List.from(workouts)
      ..sort((a, b) => a.date.compareTo(b.date));
      
    final recent = sortedWorkouts.reversed.take(7).toList().reversed.toList();
    
    List<FlSpot> spots = [];
    for (int i = 0; i < recent.length; i++) {
      double volume = 0;
      for (var ex in recent[i].exercises) {
        for (var set in ex.sets) {
          volume += set.reps * set.weight;
        }
      }
      spots.add(FlSpot(i.toDouble(), volume));
    }
    return spots.isEmpty ? [const FlSpot(0, 0)] : spots;
  }

  /// Calcola la stima dell'1RM con la formula di Epley: weight * (1 + reps/30).
  /// Trova l'esercizio compound più frequente negli ultimi 60 giorni e ne
  /// traccia il massimo 1RM stimato per sessione (ultimi 6 allenamenti).
  List<FlSpot> _get1RMSpots(List<CompletedWorkout> workouts) {
    if (workouts.isEmpty) return [];

    // Conta le occorrenze di ogni esercizio per trovare il più frequente
    final Map<String, int> frequency = {};
    for (final w in workouts) {
      for (final ex in w.exercises) {
        frequency[ex.name] = (frequency[ex.name] ?? 0) + 1;
      }
    }
    if (frequency.isEmpty) return [];

    final topExercise = frequency.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    // Raggruppa il miglior 1RM stimato per sessione
    final Map<DateTime, double> best1rmByDay = {};
    for (final w in workouts) {
      for (final ex in w.exercises) {
        if (ex.name != topExercise) continue;
        double sessionBest = 0;
        for (final s in ex.sets) {
          if (s.reps > 0 && s.weight > 0) {
            final estimated = s.weight * (1 + s.reps / 30);
            if (estimated > sessionBest) sessionBest = estimated;
          }
        }
        if (sessionBest > 0) {
          final day = DateTime(w.date.year, w.date.month, w.date.day);
          if ((best1rmByDay[day] ?? 0) < sessionBest) {
            best1rmByDay[day] = sessionBest;
          }
        }
      }
    }

    if (best1rmByDay.isEmpty) return [];

    final sorted = best1rmByDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final recent = sorted.length > 6 ? sorted.sublist(sorted.length - 6) : sorted;

    return recent
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), double.parse(e.value.value.toStringAsFixed(1))))
        .toList();
  }

  String _top1RMExerciseName(List<CompletedWorkout> workouts) {
    final Map<String, int> frequency = {};
    for (final w in workouts) {
      for (final ex in w.exercises) {
        frequency[ex.name] = (frequency[ex.name] ?? 0) + 1;
      }
    }
    if (frequency.isEmpty) return 'Esercizio principale';
    return frequency.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Map<String, double> _getMuscleGroupVolumes(List<CompletedWorkout> workouts) {
    // Chiavi allineate esattamente ai valori che arrivano dall'API
    Map<String, double> volumes = {
      'Petto': 0,
      'Schiena': 0,
      'Gambe': 0,
      'Glutei': 0,
      'Spalle': 0,
      'Braccia': 0,
      'Altro': 0,
    };

    for (var w in workouts) {
      for (var ex in w.exercises) {
        // Legge il gruppo direttamente dal campo salvato — nessuna euristica sul nome
        final group = (ex.gruppoMuscolare != null && ex.gruppoMuscolare!.isNotEmpty)
            ? ex.gruppoMuscolare!
            : 'Altro';
        double exVolume = 0;
        for (var set in ex.sets) {
          exVolume += set.weight * set.reps;
        }
        // Se il backend invia un gruppo non in lista, lo accumula in 'Altro'
        if (volumes.containsKey(group)) {
          volumes[group] = volumes[group]! + exVolume;
        } else {
          volumes['Altro'] = volumes['Altro']! + exVolume;
        }
      }
    }

    return volumes;
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Nerd Analytics', style: TextStyle(color: AppTheme.textPrimary)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ValueListenableBuilder(
          valueListenable: DatabaseService.workoutBoxListenable(),
          builder: (context, box, _) {
            final workouts = box.values.toList().cast<CompletedWorkout>();
            final muscleVolumes = _getMuscleGroupVolumes(workouts);
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildNerdStat('Best Set', _bestSet(workouts), Icons.emoji_events, AppTheme.vividPurple)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNerdStat('Vol. Medio', _avgVolume(workouts), Icons.fitness_center, AppTheme.cyan)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNerdStat('Ore Tot.', _totalTrainingTime(workouts), Icons.timer_outlined, AppTheme.legsAccent)),
                    ],
                  ).animate().fade().slideY(),
              const SizedBox(height: 32),
              
              const Text(
                'Tonnellaggio Totale',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ).animate().fade(delay: 200.ms),
              const SizedBox(height: 16),
              
              AppTheme.glassContainer(
                padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 24),
                child: SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppTheme.textSecondary.withOpacity(0.1),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)))),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _getVolumeSpots(workouts),
                          isCurved: true,
                          color: AppTheme.vividPurple,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.vividPurple.withOpacity(0.4),
                                AppTheme.vividPurple.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fade(delay: 300.ms).scale(),

              const SizedBox(height: 32),
              Builder(builder: (_) {
                final spots = _get1RMSpots(workouts);
                final exerciseName = _top1RMExerciseName(workouts);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stima 1RM — $exerciseName',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ).animate().fade(delay: 400.ms),
                    const SizedBox(height: 16),
                    AppTheme.glassContainer(
                      padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 24),
                      child: SizedBox(
                        height: 200,
                        child: spots.isEmpty
                            ? const Center(
                                child: Text(
                                  'Completa almeno una sessione\nper vedere la progressione 1RM.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              )
                            : LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) => FlLine(
                                      color: AppTheme.textSecondary.withOpacity(0.1),
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)))),
                                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: spots,
                                      isCurved: true,
                                      color: AppTheme.cyan,
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: FlDotData(show: true),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ).animate().fade(delay: 500.ms).scale(),
                  ],
                );
              }),

              const SizedBox(height: 32),
              const Text(
                'Volume per Distretto Muscolare',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ).animate().fade(delay: 600.ms),
              const SizedBox(height: 16),

              if (muscleVolumes.isEmpty)
                const Text(
                  'Nessun dato registrato.',
                  style: TextStyle(color: AppTheme.textSecondary),
                )
              else
                ...muscleVolumes.entries.map((entry) {
                  return AppTheme.glassContainer(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    borderColor: AppTheme.vividPurple.withOpacity(0.3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${entry.value.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                            color: AppTheme.cyan,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ).animate().slideX(begin: 0.1);
                }).toList(),

              const SizedBox(height: 60),
            ],
          ),
        );
      }),
      ),
    );
  }

  Widget _buildNerdStat(String title, String value, IconData icon, Color color) {
    return AppTheme.glassContainer(
      padding: const EdgeInsets.all(16),
      borderColor: color.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
