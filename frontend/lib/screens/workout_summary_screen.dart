import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import '../core/theme.dart';
import '../models/completed_workout.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  final CompletedWorkout workout;

  const WorkoutSummaryScreen({super.key, required this.workout});

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  double get _totalVolume {
    double v = 0;
    for (final ex in widget.workout.exercises) {
      for (final s in ex.sets) {
        v += s.weight * s.reps;
      }
    }
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                Center(
                  child: Text(
                    'OTTIMO LAVORO!',
                    style: GoogleFonts.orbitron(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.cyan,
                      letterSpacing: 2,
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),

                const SizedBox(height: 8),

                Center(
                  child: Text(
                    widget.workout.title,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 40),

                Row(
                  children: [
                    Expanded(child: _AnimatedKPICard(
                      label: 'Volume',
                      value: _totalVolume,
                      unit: 'kg',
                      color: AppTheme.vividPurple,
                      icon: Icons.fitness_center,
                      delay: 300,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _AnimatedKPICard(
                      label: 'Durata',
                      value: widget.workout.durationSeconds / 60,
                      unit: 'min',
                      color: AppTheme.cyan,
                      icon: Icons.timer_outlined,
                      delay: 450,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _AnimatedKPICard(
                      label: 'Esercizi',
                      value: widget.workout.exercises.length.toDouble(),
                      unit: '',
                      color: AppTheme.legsAccent,
                      icon: Icons.list_alt,
                      delay: 600,
                    )),
                  ],
                ),

                const SizedBox(height: 40),

                const Text(
                  'Riepilogo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ).animate().fadeIn(delay: 700.ms),

                const SizedBox(height: 16),

                ...widget.workout.exercises.asMap().entries.map((entry) {
                  final i = entry.key;
                  final ex = entry.value;
                  return _ExerciseSummaryCard(exercise: ex)
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: 800 + i * 100))
                      .slideX(begin: 0.1);
                }),

                const SizedBox(height: 40),

                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  icon: const Icon(Icons.home),
                  label: const Text(
                    'TORNA ALLA HOME',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: AppTheme.cyan.withOpacity(0.4),
                  ),
                ).animate().fadeIn(delay: 1200.ms).slideY(begin: 0.2),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [AppTheme.cyan, AppTheme.vividPurple, AppTheme.legsAccent, Colors.white],
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            maxBlastForce: 20,
            minBlastForce: 10,
          ),
        ),
      ],
    ),
  ),
);
}
}

class _AnimatedKPICard extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;
  final IconData icon;
  final int delay;

  const _AnimatedKPICard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return AppTheme.glassContainer(
      padding: const EdgeInsets.all(16),
      borderColor: color.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: Duration(milliseconds: 1200 + delay),
            curve: Curves.easeOut,
            builder: (_, v, __) => Text(
              '${v.toStringAsFixed(value > 10 ? 0 : 1)}${unit.isNotEmpty ? ' $unit' : ''}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _ExerciseSummaryCard extends StatelessWidget {
  final CompletedExercise exercise;

  const _ExerciseSummaryCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppTheme.glassContainer(
        padding: const EdgeInsets.all(16),
        borderColor: AppTheme.vividPurple.withOpacity(0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: exercise.sets.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.vividPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.vividPurple.withOpacity(0.3)),
                ),
                child: Text(
                  '${s.weight.toStringAsFixed(s.weight == s.weight.roundToDouble() ? 0 : 1)}kg × ${s.reps}',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
