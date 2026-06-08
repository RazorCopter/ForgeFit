import 'package:flutter/material.dart';
import '../models/training_data.dart';
import '../models/completed_workout.dart';
import '../core/theme.dart';
import 'active_session_screen.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final List<Exercise> exercises;
  final Color accentColor;
  final String dayTitle;

  const WorkoutSessionScreen({
    super.key,
    required this.exercises,
    required this.accentColor,
    required this.dayTitle,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  int _currentIndex = 0;
  final List<CompletedExercise> _completedExercises = [];
  late final DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startCurrentExercise();
  }

  void _startCurrentExercise() async {
    if (_currentIndex >= widget.exercises.length) {
      _finishWorkout();
      return;
    }

    final exercise = widget.exercises[_currentIndex];
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => ActiveSessionScreen(
          exercise: exercise,
          accentColor: widget.accentColor,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      final CompletedExercise completed = result['data'];
      _completedExercises.add(completed);

      if (result['action'] == 'finish' || _currentIndex == widget.exercises.length - 1) {
        _finishWorkout();
      } else {
        setState(() => _currentIndex++);
        _startCurrentExercise();
      }
    }
  }

  void _finishWorkout() {
    final duration = DateTime.now().difference(_startTime).inSeconds;
    Navigator.pop(context, {
      'completed': _completedExercises,
      'duration': duration,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: widget.accentColor),
              const SizedBox(height: 16),
              Text(
                'Esercizio ${_currentIndex + 1} / ${widget.exercises.length}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
