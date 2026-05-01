import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/training_data.dart';
import '../core/theme.dart';
import 'active_session_screen.dart';


class DayDetailScreen extends StatefulWidget {
  final TrainingDay day;

  const DayDetailScreen({super.key, required this.day});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  int? _expandedIndex;

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
                  
                  return _ExpandableExerciseCard(
                    exercise: exercise,
                    index: index,
                    accentColor: accentColor,
                    isExpanded: isExpanded,
                    onToggle: () {
                      setState(() {
                        _expandedIndex = isExpanded ? null : index;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: AppTheme.glassContainer(
          borderRadius: BorderRadius.circular(30),
          padding: const EdgeInsets.all(4),
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ActiveSessionScreen(
                    day: widget.day,
                    accentColor: accentColor,
                  ),
                ),
              );
            },
            backgroundColor: accentColor,
            foregroundColor: AppTheme.bgTop,
            elevation: 0,
            icon: const Icon(Icons.play_arrow),
            label: const Text('INIZIA WORKOUT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
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
  final VoidCallback onToggle;

  const _ExpandableExerciseCard({
    required this.exercise,
    required this.index,
    required this.accentColor,
    required this.isExpanded,
    required this.onToggle,
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
            borderColor: widget.isExpanded ? widget.accentColor : widget.accentColor.withOpacity(0.3),
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
                        color: widget.accentColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.textPrimary,
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
                      color: widget.accentColor,
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
                            if (widget.exercise.videoUrl.isNotEmpty)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _launchUrl(widget.exercise.videoUrl),
                                  icon: const Icon(Icons.play_circle_fill, size: 24),
                                  label: const Text(
                                    'GUARDA TUTORIAL',
                                    style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w900),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.cyan,
                                    foregroundColor: AppTheme.bgTop,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 8,
                                    shadowColor: AppTheme.cyan.withOpacity(0.5),
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
