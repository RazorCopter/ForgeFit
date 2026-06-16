import 'package:flutter/material.dart';
import '../models/training_data.dart';
import '../models/completed_workout.dart';
import '../core/theme.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
    WakelockPlus.enable();
    _startTime = DateTime.now();
    _startCurrentExercise();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
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
    } else {
      // L'utente ha interrotto l'esercizio dal tasto back (result == null)
      if (_completedExercises.isEmpty) {
        // Se non ha completato niente, annulliamo la sessione tornando a null
        Navigator.pop(context, null);
      } else {
        // Se ha completato qualcosa, salviamo la sessione finora
        _finishWorkout();
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
    // Questa schermata è visibile solo brevemente tra un esercizio e l'altro,
    // mentre Navigator.push è in attesa del risultato di ActiveSessionScreen.
    // Mostriamo il riepilogo dell'esercizio corrente per dare contesto.
    final exercise = _currentIndex < widget.exercises.length
        ? widget.exercises[_currentIndex]
        : null;

    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center, size: 56, color: widget.accentColor),
                  const SizedBox(height: 24),
                  Text(
                    'Esercizio ${_currentIndex + 1} di ${widget.exercises.length}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (exercise != null) ...[
                    Text(
                      exercise.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: widget.accentColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${exercise.sets.length} serie × ${exercise.sets.isNotEmpty ? exercise.sets.first.targetReps : 0} reps',
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                    ),
                    if (exercise.loadNote.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(exercise.loadNote, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.accentColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
