import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/training_data.dart';
import '../models/completed_workout.dart';
import '../data/database_service.dart';
import '../core/api_service.dart';
import '../core/auth_service.dart';
import '../core/theme.dart';
import '../widgets/rest_timer_widget.dart';

// MET per allenamento con pesi (intensità moderata, ACSM)
const double _kMET = 5.0;

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
  final int initialSetIndex;

  const ActiveSessionScreen({
    super.key,
    required this.exercise,
    required this.accentColor,
    this.initialSetIndex = 0,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  late final List<_LiveSet> _liveSets;
  late int _activeSetIndex;

  Timer? _stopwatchTimer;
  int _stopwatchSeconds = 0;
  
  bool _isResting = false;
  int _restSeconds = 0;
  
  late final DateTime _startTime;
  CompletedExercise? _historyCache;
  late final List<Map<String, TextEditingController>> _controllers;
  double? _suggestedWeight;
  String? _suggestionReason;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _activeSetIndex = widget.initialSetIndex;

    _historyCache = DatabaseService.getLastExerciseHistory(widget.exercise.name);
    _loadOverloadSuggestion();

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

    _startStopwatch();
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

  String get _swFormatted {
    final m = _stopwatchSeconds ~/ 60;
    final s = _stopwatchSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _loadOverloadSuggestion() async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) return;
      final data = await ApiService.getOverloadSuggestions(userId);
      final suggestions = data['suggestions'] as Map<String, dynamic>?;
      final s = suggestions?[widget.exercise.name] as Map<String, dynamic>?;
      if (s != null && mounted) {
        setState(() {
          _suggestedWeight = (s['suggested_weight'] as num?)?.toDouble();
          _suggestionReason = s['reason'] as String?;
        });
      }
    } catch (_) {
      // Suggerimento non critico — ignora errori di rete
    }
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

  void _completeActiveSet() {
    _stopStopwatch();

    final si = _activeSetIndex;
    final kgVal = double.tryParse(_controllers[si]['kg']!.text) ?? _liveSets[si].kg;
    final repsVal = int.tryParse(_controllers[si]['reps']!.text) ?? _liveSets[si].reps;

    setState(() {
      _liveSets[si]
        ..isDone = true
        ..kg = kgVal
        ..reps = repsVal
        ..timeUnderTension = _stopwatchSeconds;
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
    setState(() {
      _isResting = false;
      _activeSetIndex++;
    });
    _startStopwatch();
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
    
    // kcal = MET × peso_kg × durata_ore  (ACSM). Fallback 70 kg se no biometrics.
    final double userWeightKg = DatabaseService.getLatestBiometricRecord()?.weight ?? 70.0;
    final int kcal = (_kMET * userWeightKg * (durationSeconds / 3600.0)).round();
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          backgroundColor: AppTheme.surfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
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
                      Navigator.pop(context); // chiudi dialog
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
                      Navigator.pop(context); // chiudi dialog
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
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
                  child: child,
                ),
              );
            },
            child: _buildActiveFocusCard(_activeSetIndex),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _completeActiveSet,
                icon: const Icon(Icons.check_circle_outline, size: 28),
                label: Text('CONFERMA SERIE ${_activeSetIndex + 1}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor, 
                  foregroundColor: AppTheme.bgTop,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                  elevation: 8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFocusCard(int si) {
    final CompletedSet? lastSet = (_historyCache != null && si < _historyCache!.sets.length) ? _historyCache!.sets[si] : null;

    return SingleChildScrollView(
      key: ValueKey<int>(si),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: AppTheme.glassContainer(
        borderColor: widget.accentColor.withOpacity(0.8),
        opacity: 0.10,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'Serie ${si + 1} di ${widget.exercise.sets.length}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (lastSet != null)
              Text('Record precedente: ${lastSet.weight}kg × ${lastSet.reps}', style: const TextStyle(fontSize: 13, color: Colors.white54, fontStyle: FontStyle.italic)),
            if (_suggestedWeight != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    _suggestionReason == 'target_reached' ? Icons.trending_up : Icons.trending_flat,
                    size: 14,
                    color: _suggestionReason == 'target_reached' ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _suggestionReason == 'target_reached'
                        ? 'Suggerimento: ${_suggestedWeight}kg (+2.5kg)'
                        : 'Suggerimento: mantieni ${_suggestedWeight}kg',
                    style: TextStyle(
                      fontSize: 12,
                      color: _suggestionReason == 'target_reached' ? Colors.greenAccent : Colors.orangeAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Icon(Icons.timer_outlined, size: 36, color: widget.accentColor.withOpacity(0.7)),
                  const SizedBox(height: 8),
                  Text(
                    _swFormatted,
                    style: TextStyle(
                      fontSize: 80, fontWeight: FontWeight.w900, color: widget.accentColor, height: 1.0,
                      shadows: [Shadow(color: widget.accentColor.withOpacity(0.4), blurRadius: 20)],
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Tempo Sotto Tensione', style: TextStyle(fontSize: 13, color: widget.accentColor.withOpacity(0.6), letterSpacing: 1)),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(child: _buildInput(label: 'Kg effettivi', controller: _controllers[si]['kg']!, enabled: true, color: widget.accentColor)),
                const SizedBox(width: 12),
                if (lastSet != null) _buildPlusThreeBtn(si, lastSet.weight),
                const SizedBox(width: 12),
                Expanded(child: _buildInput(label: 'Reps effettive', controller: _controllers[si]['reps']!, enabled: true, isInt: true, color: widget.accentColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({required String label, required TextEditingController controller, required bool enabled, bool isInt = false, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        AppTheme.glassContainer(
          borderRadius: BorderRadius.circular(12), borderColor: color.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: controller, enabled: enabled,
            keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
            inputFormatters: isInt ? [FilteringTextInputFormatter.digitsOnly] : [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: enabled ? Colors.white : Colors.white54),
            decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8)),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: widget.accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.accentColor.withOpacity(0.4))),
        child: Text('+3%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.accentColor)),
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
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
