import os

content = """import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/training_data.dart';
import '../models/completed_workout.dart';
import '../data/database_service.dart';
import '../core/theme.dart';
import '../widgets/rest_timer_widget.dart';

class _LiveSet {
  double kg;
  int reps;
  bool isDone;
  int timeUnderTension;

  _LiveSet({required this.kg, required this.reps})
      : isDone = false,
        timeUnderTension = 0;
}

class ActiveSessionScreen extends StatefulWidget {
  final Exercise exercise;
  final Color accentColor;

  const ActiveSessionScreen({
    super.key,
    required this.exercise,
    required this.accentColor,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  late final List<_LiveSet> _liveSets;
  int? _activeSet;
  Timer? _stopwatchTimer;
  int _stopwatchSeconds = 0;
  bool _isResting = false;
  int _restSeconds = 0;
  late final DateTime _startTime;
  CompletedExercise? _historyCache;
  final Map<String, GlobalKey> _rowKeys = {};
  late final List<Map<String, TextEditingController>> _controllers;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    _historyCache = DatabaseService.getLastExerciseHistory(widget.exercise.name);

    _liveSets = List.generate(widget.exercise.sets.length, (si) {
      final s = widget.exercise.sets[si];
      double initialKg = s.weight > 0 ? s.weight : 0;
      int initialReps = s.targetReps;
      
      if (_historyCache != null && si < _historyCache!.sets.length) {
        initialKg = _historyCache!.sets[si].weight;
        initialReps = _historyCache!.sets[si].reps;
      }
      
      return _LiveSet(kg: initialKg, reps: initialReps);
    });

    _controllers = List.generate(widget.exercise.sets.length, (si) {
      final live = _liveSets[si];
      return {
        'kg': TextEditingController(text: live.kg > 0 ? live.kg.toStringAsFixed(live.kg == live.kg.roundToDouble() ? 0 : 1) : ''),
        'reps': TextEditingController(text: live.reps.toString()),
      };
    });
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    for (final ctrlMap in _controllers) {
      ctrlMap['kg']!.dispose();
      ctrlMap['reps']!.dispose();
    }
    super.dispose();
  }

  GlobalKey _rowKey(int si) {
    final k = 'set_$si';
    return _rowKeys.putIfAbsent(k, () => GlobalKey());
  }

  String get _swFormatted {
    final m = _stopwatchSeconds ~/ 60;
    final s = _stopwatchSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startStopwatch() {
    _stopwatchTimer?.cancel();
    _stopwatchSeconds = 0;
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _stopwatchSeconds++);
    });
  }

  void _stopStopwatch() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = null;
  }

  void _startSet(int si) {
    setState(() {
      _activeSet = si;
    });
    _startStopwatch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _rowKey(si).currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut, alignment: 0.15);
      }
    });
  }

  void _completeSet(int si) {
    _stopStopwatch();

    final kgVal = double.tryParse(_controllers[si]['kg']!.text) ?? _liveSets[si].kg;
    final repsVal = int.tryParse(_controllers[si]['reps']!.text) ?? _liveSets[si].reps;

    setState(() {
      _liveSets[si]
        ..isDone = true
        ..kg = kgVal
        ..reps = repsVal
        ..timeUnderTension = _stopwatchSeconds;
      _activeSet = null;
    });

    final isLastSet = si == widget.exercise.sets.length - 1;

    if (isLastSet) {
      _showNerdStats();
    } else {
      final restSec = widget.exercise.sets[si].targetRestSeconds;
      setState(() {
        _isResting = true;
        _restSeconds = restSec;
      });
    }
  }

  void _endRest() {
    setState(() => _isResting = false);
    _scrollToNextPending();
  }

  void _scrollToNextPending() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (int s = 0; s < _liveSets.length; s++) {
        if (!_liveSets[s].isDone) {
          final ctx = _rowKey(s).currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut, alignment: 0.15);
          }
          return;
        }
      }
    });
  }

  void _showNerdStats() {
    final endTime = DateTime.now();
    final durationSeconds = endTime.difference(_startTime).inSeconds;
    
    double volume = 0;
    for (final s in _liveSets) {
      if (s.isDone) {
        volume += s.kg * s.reps;
      }
    }
    
    final int kcal = ((durationSeconds / 60.0) * 5 + (volume * 0.002)).round();
    final String timeStr = '${durationSeconds ~/ 60}:${(durationSeconds % 60).toString().padLeft(2, '0')}';

    final setsData = _liveSets.where((s) => s.isDone).map((s) => CompletedSet(
      weight: s.kg,
      reps: s.reps,
      timeUnderTension: s.timeUnderTension,
    )).toList();

    final completedExercise = CompletedExercise(
      name: widget.exercise.name,
      gruppoMuscolare: widget.exercise.gruppoMuscolare,
      sets: setsData,
    );

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surfaceVariant,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
              const SizedBox(height: 16),
              const Text('Ottimo Lavoro!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatBox(title: 'Volume', value: '${volume.toStringAsFixed(1)} kg', color: widget.accentColor),
                  _StatBox(title: 'Tempo', value: timeStr, color: Colors.blueAccent),
                  _StatBox(title: 'Kcal', value: '$kcal', color: Colors.orangeAccent),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // chiudi modal
                    Navigator.pop(context, {'action': 'continue', 'data': completedExercise});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: AppTheme.bgTop,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('CONTINUA ALLENAMENTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context); // chiudi modal
                    Navigator.pop(context, {'action': 'finish', 'data': completedExercise});
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('TERMINA SESSIONE E SALVA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: const Text('Interrompi esercizio?', style: TextStyle(color: Colors.white)),
        content: const Text('I dati di questo esercizio non verranno salvati.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla', style: TextStyle(color: AppTheme.cyan))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Interrompi', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isResting) {
      return AppTheme.buildBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: RestTimerWidget(
              durationSeconds: _restSeconds,
              accentColor: widget.accentColor,
              onFinish: _endRest,
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final leave = await _onWillPop();
          if (leave && mounted) Navigator.pop(context);
        }
      },
      child: AppTheme.buildBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(widget.exercise.name),
            backgroundColor: Colors.transparent,
          ),
          body: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120, top: 8),
            itemCount: widget.exercise.sets.length,
            itemBuilder: (context, si) {
              return Container(
                key: _rowKey(si),
                child: _buildSetCard(si),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSetCard(int si) {
    final live = _liveSets[si];
    final isActive = _activeSet == si;
    final isDone = live.isDone;

    Color border = Colors.white.withOpacity(0.05);
    double bgOpacity = 0.02;
    if (isDone) { border = Colors.green.withOpacity(0.3); bgOpacity = 0.05; }
    if (isActive) { border = widget.accentColor.withOpacity(0.8); bgOpacity = 0.10; }

    final CompletedSet? lastSet = (_historyCache != null && si < _historyCache!.sets.length) ? _historyCache!.sets[si] : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: AppTheme.glassContainer(
        borderColor: border,
        opacity: bgOpacity,
        padding: isActive ? const EdgeInsets.all(20) : const EdgeInsets.all(14),
        child: isActive ? _buildActiveCardContent(si, lastSet) : _buildCompactCardContent(si, isDone, lastSet),
      ),
    );
  }

  Widget _buildActiveCardContent(int si, CompletedSet? lastSet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.accentColor.withOpacity(0.2)),
              child: Center(child: Text('${si + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: widget.accentColor))),
            ),
            const SizedBox(width: 10),
            Text('SERIE IN CORSO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: widget.accentColor)),
            if (lastSet != null) ...[
              const Spacer(),
              Text('Last: ${lastSet.weight}kg × ${lastSet.reps}', style: const TextStyle(fontSize: 11, color: Colors.white30, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              Icon(Icons.timer_outlined, size: 28, color: widget.accentColor.withOpacity(0.7)),
              const SizedBox(height: 4),
              Text(
                _swFormatted,
                style: TextStyle(
                  fontSize: 72, fontWeight: FontWeight.w900, color: widget.accentColor, height: 1.0,
                  shadows: [Shadow(color: widget.accentColor.withOpacity(0.4), blurRadius: 20)],
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text('Tempo Sotto Tensione', style: TextStyle(fontSize: 11, color: widget.accentColor.withOpacity(0.6), letterSpacing: 1)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildInput(label: 'Kg effettivi', controller: _controllers[si]['kg']!, enabled: true, color: widget.accentColor)),
            const SizedBox(width: 8),
            if (lastSet != null) _buildPlusThreeBtn(si, lastSet.weight),
            const SizedBox(width: 8),
            Expanded(child: _buildInput(label: 'Reps effettive', controller: _controllers[si]['reps']!, enabled: true, isInt: true, color: widget.accentColor)),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _completeSet(si),
            icon: const Icon(Icons.stop_circle_outlined, size: 22),
            label: const Text('TERMINA SERIE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactCardContent(int si, bool isDone, CompletedSet? lastSet) {
    final live = _liveSets[si];
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle, color: isDone ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
          child: Center(child: isDone ? const Icon(Icons.check, color: Colors.green, size: 18) : Text('${si + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDone ? '${live.kg}kg × ${live.reps} reps  •  ${live.timeUnderTension}s' : 'Target: ${widget.exercise.sets[si].targetReps} reps @ ${_controllers[si]['kg']!.text.isNotEmpty ? _controllers[si]['kg']!.text : "—"}kg',
                style: TextStyle(fontSize: 13, fontWeight: isDone ? FontWeight.bold : FontWeight.normal, color: isDone ? Colors.green : Colors.white70),
              ),
              if (lastSet != null && !isDone)
                Text('Last: ${lastSet.weight}kg × ${lastSet.reps}', style: const TextStyle(fontSize: 11, color: Colors.white30, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        if (!isDone)
          ElevatedButton.icon(
            onPressed: () => _startSet(si),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Via!', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor, foregroundColor: AppTheme.bgTop,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )
        else
          ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: Colors.green.withOpacity(0.4), disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Icon(Icons.check, size: 20),
          ),
      ],
    );
  }

  Widget _buildInput({required String label, required TextEditingController controller, required bool enabled, bool isInt = false, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        AppTheme.glassContainer(
          borderRadius: BorderRadius.circular(10), borderColor: color.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: TextField(
            controller: controller, enabled: enabled,
            keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
            inputFormatters: isInt ? [FilteringTextInputFormatter.digitsOnly] : [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: enabled ? Colors.white : Colors.white54),
            decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 6)),
          ),
        ),
      ],
    );
  }

  Widget _buildPlusThreeBtn(int si, double lastKg) {
    return GestureDetector(
      onTap: () {
        setState(() {
          final newKg = (lastKg * 1.03 * 2).round() / 2;
          _controllers[si]['kg']!.text = newKg == newKg.roundToDouble() ? newKg.toInt().toString() : newKg.toStringAsFixed(1);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(color: widget.accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: widget.accentColor.withOpacity(0.4))),
        child: Text('+3%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.accentColor)),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatBox({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
"""

with open("lib/screens/active_session_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("Done")
