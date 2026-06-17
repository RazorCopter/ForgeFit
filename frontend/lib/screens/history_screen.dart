import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import '../models/completed_workout.dart';
import '../data/database_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  Color _getColorForWorkout(CompletedWorkout w) {
    final title = w.title.toLowerCase();
    if (title.contains('push')) return AppTheme.pushAccent;
    if (title.contains('pull')) return AppTheme.pullAccent;
    if (title.contains('legs') || title.contains('gambe')) return AppTheme.legsAccent;
    return AppTheme.cyan;
  }

  // Cache: ricalcolata solo quando il box Hive notifica un cambiamento
  Map<DateTime, List<CompletedWorkout>>? _workoutsByDayCache;
  List<CompletedWorkout>? _lastWorkoutList;

  Map<DateTime, List<CompletedWorkout>> _getWorkoutsByDay(List<CompletedWorkout> allWorkouts) {
    if (identical(allWorkouts, _lastWorkoutList) && _workoutsByDayCache != null) {
      return _workoutsByDayCache!;
    }
    final Map<DateTime, List<CompletedWorkout>> map = {};
    for (final w in allWorkouts) {
      final date = DateTime(w.date.year, w.date.month, w.date.day);
      (map[date] ??= []).add(w);
    }
    _lastWorkoutList = allWorkouts;
    _workoutsByDayCache = map;
    return map;
  }

  List<CompletedWorkout> _getWorkoutsForDay(DateTime date, Map<DateTime, List<CompletedWorkout>> workoutsByDay) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return workoutsByDay[normalizedDate] ?? [];
  }

  Future<void> _deleteWorkout(CompletedWorkout workout) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: const Text('Eliminare allenamento?', style: TextStyle(color: Colors.white)),
        content: const Text('Questa azione è irreversibile e rimuoverà la sessione dallo storico.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla', style: TextStyle(color: AppTheme.cyan))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Elimina', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.deleteWorkout(workout);
      // Best effort per eliminare anche dal server se sincronizzato
      if (workout.id.isNotEmpty && int.tryParse(workout.id) != null) {
        try {
          await ApiService.deleteWorkout(int.parse(workout.id));
        } catch (e) {
          debugPrint('Errore eliminazione remota allenamento: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Storico'),
          backgroundColor: Colors.transparent,
        ),
      body: ValueListenableBuilder(
        valueListenable: DatabaseService.workoutBoxListenable(),
        builder: (context, box, _) {
          final allWorkouts = box.values.toList().cast<CompletedWorkout>();
          final workoutsByDay = _getWorkoutsByDay(allWorkouts);
          final workoutsForSelectedDay = _getWorkoutsForDay(_selectedDay ?? _focusedDay, workoutsByDay);

          return Column(
            children: [
              AppTheme.glassContainer(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(8),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(color: AppTheme.textPrimary),
                weekendTextStyle: const TextStyle(color: AppTheme.textSecondary),
                outsideTextStyle: const TextStyle(color: Colors.grey),
                selectedDecoration: const BoxDecoration(
                  color: AppTheme.pushAccent,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.pushAccent, width: 2),
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return const SizedBox();
                  return Positioned(
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: events.cast<CompletedWorkout>().map((w) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getColorForWorkout(w),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.textPrimary),
              ),
              eventLoader: (day) {
                final normalizedDate = DateTime(day.year, day.month, day.day);
                return workoutsByDay[normalizedDate] ?? [];
              },
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: -0.1),
          
          Expanded(
            child: workoutsForSelectedDay.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Lottie.asset('assets/lottie/empty_workout.json', width: 130, repeat: true),
                        const SizedBox(height: 8),
                        const Text(
                          'Nessun allenamento in questo giorno',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ).animate().fade(delay: 200.ms),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: workoutsForSelectedDay.length,
                    itemBuilder: (context, index) {
                      final w = workoutsForSelectedDay[index];
                      int totalVolume = 0;
                      int totalSets = 0;
                      for (var ex in w.exercises) {
                        for (var set in ex.sets) {
                          totalSets++;
                          totalVolume += (set.reps * set.weight).toInt();
                        }
                      }
                      
                      return AppTheme.glassContainer(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.zero,
                        borderColor: AppTheme.homeAccent.withValues(alpha: 0.5),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    w.title,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.homeAccent,
                                    ),
                                  ),
                                ),
                                if (!w.isSynced)
                                  Tooltip(
                                    message: 'In attesa di sincronizzazione',
                                    child: const Icon(
                                      Icons.cloud_off_rounded,
                                      size: 18,
                                      color: Colors.orangeAccent,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _StatBadge(icon: Icons.timer, label: '${w.durationSeconds ~/ 60} min'),
                                  _StatBadge(icon: Icons.fitness_center, label: '$totalVolume kg'),
                                  _StatBadge(icon: Icons.format_list_numbered, label: '$totalSets sets'),
                                ],
                              ),
                            ),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ...w.exercises.map((ex) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(ex.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: ex.sets.map((s) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.pullAccent.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text('${s.weight}kg x ${s.reps}', style: const TextStyle(color: AppTheme.pullAccent, fontSize: 12)),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 20),
                                    const Divider(color: Colors.white12, height: 1),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () => _deleteWorkout(w),
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                      label: const Text('Elimina Allenamento', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                        backgroundColor: Colors.redAccent.withValues(alpha: 0.08),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fade(delay: (100 * index).ms).slideX(begin: 0.1);
                    },
                  ),
          ),
        ],
      );
      }),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
