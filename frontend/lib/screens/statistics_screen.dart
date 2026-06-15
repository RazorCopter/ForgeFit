import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../core/theme.dart';
import '../models/completed_workout.dart';
import '../data/database_service.dart';
import '../core/api_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String? _selectedExercise;
  @override
  void initState() {
    super.initState();
  }

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

  List<String> _getVolumeLabels(List<CompletedWorkout> workouts) {
    if (workouts.isEmpty) return [];
    final sorted = List<CompletedWorkout>.from(workouts)
      ..sort((a, b) => a.date.compareTo(b.date));
    final recent = sorted.reversed.take(7).toList().reversed.toList();
    return recent.map((w) =>
      '${w.date.day.toString().padLeft(2, '0')}/${w.date.month.toString().padLeft(2, '0')}'
    ).toList();
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

            if (workouts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Lottie.asset('assets/lottie/empty_workout.json', width: 160, repeat: true),
                    const SizedBox(height: 8),
                    const Text(
                      'Nessun allenamento registrato',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Completa il tuo primo workout per\nvedere le statistiche qui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            final muscleVolumes = _getMuscleGroupVolumes(workouts);
            final volumeLabels = _getVolumeLabels(workouts);

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
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                            final idx = s.x.toInt();
                            final label = idx >= 0 && idx < volumeLabels.length ? volumeLabels[idx] : '';
                            return LineTooltipItem(
                              '${s.y.toInt()} kg\n$label',
                              TextStyle(color: AppTheme.vividPurple, fontSize: 11, fontWeight: FontWeight.bold),
                            );
                          }).toList(),
                        ),
                      ),
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
                                  lineTouchData: LineTouchData(
                                    touchTooltipData: LineTouchTooltipData(
                                      getTooltipItems: (touchedSpots) => touchedSpots.map((s) => LineTooltipItem(
                                        '1RM est.\n${s.y.toStringAsFixed(1)} kg',
                                        const TextStyle(color: AppTheme.cyan, fontSize: 11, fontWeight: FontWeight.bold),
                                      )).toList(),
                                    ),
                                  ),
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
                _MuscleRadarChart(muscleVolumes: muscleVolumes)
                    .animate()
                    .fade(delay: 600.ms)
                    .scale(),

              const SizedBox(height: 32),
              const Text(
                'Progressione per Esercizio',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ).animate().fade(delay: 700.ms),
              const SizedBox(height: 12),

              Builder(builder: (context) {
                final exerciseNames = _getAllExerciseNames(workouts);
                if (exerciseNames.isEmpty) {
                  return const Text('Nessun esercizio registrato.',
                      style: TextStyle(color: AppTheme.textSecondary));
                }
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
                                  lineTouchData: LineTouchData(
                                    touchTooltipData: LineTouchTooltipData(
                                      getTooltipItems: (touchedSpots) => touchedSpots.map((s) => LineTooltipItem(
                                        '${s.y.toStringAsFixed(1)} kg',
                                        const TextStyle(color: AppTheme.legsAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                      )).toList(),
                                    ),
                                  ),
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

              const SizedBox(height: 60),
            ],
          ),
        );
      }),
      ),
    );
  }

  Widget _buildNerdStat(String title, String value, IconData icon, Color color) {
    // Estrai il primo numero dalla stringa per animarlo (es. "3500 kg" → 3500.0)
    final numMatch = RegExp(r'[\d]+(?:[.,]\d+)?').firstMatch(value);
    final numericPart = numMatch != null ? double.tryParse(numMatch.group(0)!.replaceAll(',', '.')) : null;
    final prefix = numMatch != null ? value.substring(0, numMatch.start) : '';
    final suffix = numMatch != null ? value.substring(numMatch.end) : value;

    return AppTheme.glassContainer(
      padding: const EdgeInsets.all(16),
      borderColor: color.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          numericPart != null
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: numericPart),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOut,
                  builder: (_, v, __) {
                    final formatted = numericPart >= 100
                        ? v.toInt().toString()
                        : v.toStringAsFixed(1);
                    return Text(
                      '$prefix$formatted$suffix',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                )
              : Text(
                  value,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _MuscleRadarChart extends StatelessWidget {
  final Map<String, double> muscleVolumes;

  const _MuscleRadarChart({required this.muscleVolumes});

  @override
  Widget build(BuildContext context) {
    final entries = muscleVolumes.entries
        .where((e) => e.value > 0 || true) // mostra tutti i distretti
        .toList();
    final maxVal = muscleVolumes.values.fold(0.0, (m, v) => v > m ? v : m);
    if (maxVal == 0) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Completa qualche allenamento\nper vedere il radar muscolare.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return AppTheme.glassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            height: 260,
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    dataEntries: entries
                        .map((e) => RadarEntry(value: e.value))
                        .toList(),
                    fillColor: AppTheme.vividPurple.withOpacity(0.2),
                    borderColor: AppTheme.vividPurple,
                    borderWidth: 2,
                    entryRadius: 4,
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                tickBorderData: BorderSide(
                    color: AppTheme.textSecondary.withOpacity(0.2), width: 1),
                gridBorderData: BorderSide(
                    color: AppTheme.textSecondary.withOpacity(0.15), width: 1),
                tickCount: 4,
                ticksTextStyle: const TextStyle(fontSize: 0, color: Colors.transparent),
                getTitle: (index, angle) {
                  if (index >= entries.length) return RadarChartTitle(text: '');
                  final label = entries[index].key;
                  final pct = maxVal > 0
                      ? (entries[index].value / maxVal * 100).toStringAsFixed(0)
                      : '0';
                  return RadarChartTitle(
                    text: '$label\n$pct%',
                    angle: 0,
                  );
                },
                titleTextStyle: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legenda sintetica
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: entries.map((e) {
              final isEmpty = e.value == 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isEmpty
                          ? AppTheme.textSecondary.withOpacity(0.3)
                          : AppTheme.vividPurple,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    e.key,
                    style: TextStyle(
                      fontSize: 11,
                      color: isEmpty
                          ? AppTheme.textSecondary.withOpacity(0.5)
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
