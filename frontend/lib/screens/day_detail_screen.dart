import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/training_data.dart';
import '../models/completed_workout.dart';
import '../data/database_service.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import 'active_session_screen.dart';
import 'workout_session_screen.dart';
import 'workout_summary_screen.dart';

class DayDetailScreen extends StatefulWidget {
  final TrainingDay day;

  const DayDetailScreen({super.key, required this.day});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  int? _expandedIndex;
  DateTime? _workoutStartTime;
  Timer? _globalTimer;
  int _elapsedSeconds = 0;
  final List<CompletedExercise> _completedExercises = [];
  final Set<int> _completedIndexes = {};

  @override
  void dispose() {
    _globalTimer?.cancel();
    super.dispose();
  }

  void _startExercise(Exercise exercise, Color accentColor, int index) async {
    if (_workoutStartTime == null) {
      _workoutStartTime = DateTime.now();
      _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _elapsedSeconds++;
        });
      });
      setState(() {});
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveSessionScreen(
          exercise: exercise,
          accentColor: accentColor,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final CompletedExercise completed = result['data'];
      _completedExercises.add(completed);
      _completedIndexes.add(index);
      setState(() {});

      if (result['action'] == 'finish') {
        _finishWorkout();
      }
    }
  }

  Future<void> _finishWorkout() async {
    if (_completedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nessun esercizio completato. Allenamento annullato.'),
        backgroundColor: Colors.redAccent,
      ));
      Navigator.pop(context);
      return;
    }

    // Mostra il loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.vividPurple)),
    );

    _globalTimer?.cancel();
    final duration = _elapsedSeconds;
    
    final completedWorkout = CompletedWorkout(
      id: const Uuid().v4(),
      title: widget.day.title,
      date: DateTime.now(),
      durationSeconds: duration,
      exercises: _completedExercises,
    );

    try {
      // 1. Salvataggio locale
      await DatabaseService.saveWorkout(completedWorkout);

      // 2. Sincronizzazione con il Cloud (FastAPI Backend)
      try {
        await ApiService.saveWorkout(completedWorkout);
        await DatabaseService.markWorkoutSynced(completedWorkout.id);
      } catch (_) {
        // Sync fallita — workout salvato offline, retry al prossimo avvio
      }

      if (mounted) {
        Navigator.pop(context); // chiude lo spinner
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WorkoutSummaryScreen(workout: completedWorkout),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // chiude lo spinner
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore salvataggio: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.getAccentForDay(widget.day.id);

    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(widget.day.title, style: const TextStyle(color: AppTheme.textPrimary)),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: accentColor.withOpacity(0.5),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.day.subtitle,
                    style: const TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.day.priority,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  if (_workoutStartTime != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.timer, color: AppTheme.cyan, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: AppTheme.cyan,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 16, bottom: 80),
                itemCount: widget.day.exercises.length,
                itemBuilder: (context, index) {
                  final exercise = widget.day.exercises[index];
                  final isExpanded = _expandedIndex == index;
                  final isCompleted = _completedIndexes.contains(index);
                  
                  return _ExpandableExerciseCard(
                    exercise: exercise,
                    index: index,
                    accentColor: accentColor,
                    isExpanded: isExpanded,
                    isCompleted: isCompleted,
                    onToggle: () {
                      setState(() {
                        _expandedIndex = isExpanded ? null : index;
                      });
                    },
                    onStart: () => _startExercise(exercise, accentColor, index),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              heroTag: 'guided',
              onPressed: () async {
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkoutSessionScreen(
                      exercises: widget.day.exercises,
                      accentColor: AppTheme.getAccentForDay(widget.day.id),
                      dayTitle: widget.day.title,
                    ),
                  ),
                );
                if (result != null) {
                  final exercises = result['completed'] as List<CompletedExercise>;
                  _completedExercises.addAll(exercises);
                  _workoutStartTime ??= DateTime.now();
                  _elapsedSeconds += (result['duration'] as int?) ?? 0;
                  await _finishWorkout();
                }
              },
              backgroundColor: AppTheme.getAccentForDay(widget.day.id),
              foregroundColor: Colors.black,
              icon: const Icon(Icons.play_arrow),
              label: const Text('AVVIA TUTTO', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (_workoutStartTime != null) ...[
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'stop',
                onPressed: _finishWorkout,
                backgroundColor: Colors.redAccent,
                child: const Icon(Icons.stop, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpandableExerciseCard extends StatefulWidget {
  final Exercise exercise;
  final int index;
  final Color accentColor;
  final bool isExpanded;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback onStart;

  const _ExpandableExerciseCard({
    required this.exercise,
    required this.index,
    required this.accentColor,
    required this.isExpanded,
    required this.isCompleted,
    required this.onToggle,
    required this.onStart,
  });

  @override
  State<_ExpandableExerciseCard> createState() => _ExpandableExerciseCardState();
}

class _ExpandableExerciseCardState extends State<_ExpandableExerciseCard> {
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: AppTheme.glassContainer(
            padding: const EdgeInsets.all(16),
            borderColor: widget.isCompleted ? Colors.green : (widget.isExpanded ? widget.accentColor : widget.accentColor.withOpacity(0.3)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Intestazione Card
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.isCompleted ? Colors.green.withOpacity(0.2) : widget.accentColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: widget.isCompleted
                            ? const Icon(Icons.check, color: Colors.green)
                            : Text(
                                '${widget.index + 1}',
                                style: TextStyle(
                                  color: widget.accentColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.exercise.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: widget.isCompleted ? Colors.green : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.exercise.sets.length} Serie | Recupero: ${widget.exercise.sets.first.targetRestSeconds}s',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      widget.isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: widget.isCompleted ? Colors.green : widget.accentColor,
                    ),
                  ],
                ),
                // Sezione Espansa
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: widget.isExpanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            const Divider(color: AppTheme.surfaceVariant),
                            const SizedBox(height: 16),
                            Text(
                              'Setup: ${widget.exercise.setup}',
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Note: ${widget.exercise.loadNote}',
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            if (widget.exercise.videoUrl.isNotEmpty) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: _YoutubeThumbnailWidget(videoUrl: widget.exercise.videoUrl),
                                ),
                              const SizedBox(height: 16),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: widget.isCompleted ? null : widget.onStart,
                                icon: const Icon(Icons.play_arrow, size: 24),
                                label: Text(
                                  widget.isCompleted ? 'COMPLETATO' : 'INIZIA ESERCIZIO',
                                  style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w900),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.accentColor,
                                  foregroundColor: AppTheme.bgTop,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 8,
                                  shadowColor: widget.accentColor.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YoutubeThumbnailWidget extends StatelessWidget {
  final String videoUrl;

  const _YoutubeThumbnailWidget({Key? key, required this.videoUrl}) : super(key: key);

  String? _getVideoId(String url) {
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    } else if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return null;
  }

  Future<void> _launchVideo() async {
    final uri = Uri.parse(videoUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $videoUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoId = _getVideoId(videoUrl);

    if (videoId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
        ),
        child: const Text(
          'URL video non valido.',
          style: TextStyle(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      );
    }

    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/0.jpg';

    return GestureDetector(
      onTap: _launchVideo,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              thumbnailUrl,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                  ),
                );
              },
            ),
          ),
          Container(
            width: 60,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }
}
