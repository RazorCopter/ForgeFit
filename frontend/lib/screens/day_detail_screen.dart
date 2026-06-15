import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:uuid/uuid.dart';
import '../models/training_data.dart';
import '../models/completed_workout.dart';
import '../data/database_service.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import 'active_session_screen.dart';
import 'workout_session_screen.dart';
import 'workout_summary_screen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  bool _isPaused = false;
  final List<CompletedExercise> _completedExercises = [];
  final Set<int> _completedIndexes = {};

  @override
  void initState() {
    super.initState();
    _loadActiveSession();
  }

  void _loadActiveSession() {
    final session = DatabaseService.getActiveSession(widget.day.id);
    if (session != null) {
      setState(() {
        _completedExercises.addAll(session['completed'] as List<CompletedExercise>);
        _completedIndexes.addAll(session['indexes'] as Set<int>);
        _elapsedSeconds = session['elapsedSeconds'] as int;
        _workoutStartTime = session['startTime'] as DateTime;
      });
      // Riprendi il timer dal tempo salvato
      _isPaused = false;
      _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isPaused) {
          setState(() {
            _elapsedSeconds++;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _globalTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _startExercise(Exercise exercise, Color accentColor, int index) async {
    // Abilitiamo il wakelock al tap (serve per iOS Safari / Web)
    WakelockPlus.enable();
    
    if (_workoutStartTime == null) {
      _workoutStartTime = DateTime.now();
      _isPaused = false;
      _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isPaused) {
          setState(() {
            _elapsedSeconds++;
          });
        }
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
      
      // Salva progressivamente la sessione in corso
      DatabaseService.saveActiveSession(
        widget.day.id,
        _workoutStartTime ?? DateTime.now(),
        _elapsedSeconds,
        _completedExercises,
        _completedIndexes,
      );
      
      setState(() {});

      if (result['action'] == 'finish' || _completedIndexes.length == widget.day.exercises.length) {
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
      dayId: widget.day.id,
    );

    try {
      // 1. Salvataggio locale
      await DatabaseService.saveWorkout(completedWorkout);
      await DatabaseService.clearActiveSession(widget.day.id);

      // 2. Sincronizzazione con il Cloud (FastAPI Backend)
      try {
        final backendId = await ApiService.saveWorkout(completedWorkout);
        await DatabaseService.updateWorkoutId(completedWorkout.id, backendId);
        await DatabaseService.markWorkoutSynced(backendId);
      } catch (_) {
        // Sync fallita — workout salvato offline, retry al prossimo avvio
      }

      if (mounted) {
        WakelockPlus.disable();
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
        WakelockPlus.disable();
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_workoutStartTime != null && _completedExercises.isNotEmpty) {
          final choice = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surfaceVariant,
              title: const Text('Sessione in corso', style: TextStyle(color: Colors.white)),
              content: const Text(
                'Hai esercizi completati. Cosa vuoi fare?',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'continue'),
                  child: const Text('Resta qui', style: TextStyle(color: AppTheme.cyan)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'suspend'),
                  child: const Text('Sospendi per dopo', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'abandon'),
                  child: const Text('Annulla allenamento', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          );
          if (!context.mounted) return;
          if (choice == 'suspend') {
            Navigator.pop(context); // esce ma la sessione rimane salvata
          } else if (choice == 'abandon') {
            await DatabaseService.clearActiveSession(widget.day.id);
            Navigator.pop(context);
          }
          // 'continue' o dismiss: non fa nulla, resta sulla schermata
        } else {
          await DatabaseService.clearActiveSession(widget.day.id);
          Navigator.pop(context);
        }
      },
      child: AppTheme.buildBackground(
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
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _isPaused ? Icons.play_arrow : Icons.pause,
                            color: Colors.amber,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPaused = !_isPaused;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop, color: Colors.redAccent),
                          onPressed: _finishWorkout,
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
        floatingActionButton: _workoutStartTime == null
            ? FloatingActionButton.extended(
                heroTag: 'guided',
                onPressed: () async {
                  WakelockPlus.enable();
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
                    for (int i = 0; i < widget.day.exercises.length; i++) {
                      _completedIndexes.add(i);
                    }
                    _workoutStartTime ??= DateTime.now();
                    _elapsedSeconds += (result['duration'] as int?) ?? 0;
                    await _finishWorkout();
                  }
                },
                backgroundColor: AppTheme.getAccentForDay(widget.day.id),
                foregroundColor: Colors.black,
                icon: const Icon(Icons.play_arrow),
                label: const Text('AVVIA TUTTO', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            : null,
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
                          if (widget.exercise.gruppoMuscolare case final gruppo?) ...[
                            const SizedBox(height: 6),
                            _MuscleChip(group: gruppo),
                          ],
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

// Chip colorato per il gruppo muscolare — stateless, dipende solo dal valore del dato
class _MuscleChip extends StatelessWidget {
  final String group;
  const _MuscleChip({required this.group});

  @override
  Widget build(BuildContext context) {
    final chipColor = AppTheme.getMuscleGroupColor(group);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        group,
        style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _YoutubeThumbnailWidget extends StatefulWidget {
  final String videoUrl;

  const _YoutubeThumbnailWidget({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<_YoutubeThumbnailWidget> createState() => _YoutubeThumbnailWidgetState();
}

class _YoutubeThumbnailWidgetState extends State<_YoutubeThumbnailWidget> {
  String? _videoId;

  @override
  void initState() {
    super.initState();
    _videoId = _getVideoId(widget.videoUrl);
  }

  String? _getVideoId(String url) {
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtube.com')) {
      // Formato standard: youtube.com/watch?v=VIDEO_ID
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }
      // Formato Shorts: youtube.com/shorts/VIDEO_ID
      final segments = uri.pathSegments;
      final shortsIdx = segments.indexOf('shorts');
      if (shortsIdx != -1 && shortsIdx + 1 < segments.length) {
        return segments[shortsIdx + 1];
      }
    } else if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return null;
  }

  void _playVideo() {
    if (_videoId == null) return;
    showDialog(
      context: context,
      builder: (context) => _VideoPlayerDialog(videoId: _videoId!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_videoId == null) {
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

    return GestureDetector(
      onTap: _playVideo,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                'https://img.youtube.com/vi/$_videoId/hqdefault.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.black12,
                  child: const Icon(Icons.video_library, color: Colors.white54, size: 48),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  final String videoId;
  const _VideoPlayerDialog({required this.videoId});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: YoutubePlayer(
          controller: _controller,
          aspectRatio: 16 / 9,
        ),
      ),
    );
  }
}
