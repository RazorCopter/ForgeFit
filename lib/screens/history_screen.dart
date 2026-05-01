import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
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

  Map<DateTime, List<CompletedWorkout>> _getWorkoutsByDay(List<CompletedWorkout> allWorkouts) {
    Map<DateTime, List<CompletedWorkout>> map = {};
    for (var w in allWorkouts) {
      final date = DateTime(w.date.year, w.date.month, w.date.day);
      if (map[date] == null) {
        map[date] = [];
      }
      map[date]!.add(w);
    }
    return map;
  }

  List<CompletedWorkout> _getWorkoutsForDay(DateTime date, Map<DateTime, List<CompletedWorkout>> workoutsByDay) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return workoutsByDay[normalizedDate] ?? [];
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
                markerDecoration: const BoxDecoration(
                  color: AppTheme.pullAccent,
                  shape: BoxShape.circle,
                ),
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
                    child: const Text(
                      'Nessun allenamento in questo giorno',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ).animate().fade(delay: 200.ms),
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
                        borderColor: AppTheme.homeAccent.withOpacity(0.5),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              w.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.homeAccent,
                              ),
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
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: w.exercises.map((ex) {
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
                                                  color: AppTheme.pullAccent.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text('${s.weight}kg x ${s.reps}', style: const TextStyle(color: AppTheme.pullAccent, fontSize: 12)),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
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
