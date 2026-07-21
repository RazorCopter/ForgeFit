import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/training_data.dart';
import '../models/completed_workout.dart';
import '../data/database_service.dart';
import '../core/api_service.dart';
import '../core/auth_service.dart';
import '../core/set_session_flow.dart';
import '../core/sound_service.dart';
import '../core/theme.dart';
import '../widgets/rest_timer_widget.dart';
import '../core/voice_service.dart';

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
  late final SetSessionFlow _flow;

  Timer? _stopwatchTimer;
  Timer? _countdownTimer;
  final _stopwatchNotifier = ValueNotifier<int>(0);
  int _countdownRemaining = 5;
  DateTime? _setStartedAt;

  int _restSeconds = 0;
  bool _soundEnabled = true;
  bool _voiceEnabled = true;

  DateTime? _exerciseStartedAt;
  CompletedExercise? _historyCache;
  late final List<Map<String, TextEditingController>> _controllers;
  double? _suggestedWeight;
  String? _suggestionReason;
  double? _currentPR;

  @override
  void initState() {
    super.initState();
    _flow = SetSessionFlow(
      totalSets: widget.exercise.sets.length,
      initialSetIndex: widget.initialSetIndex,
    );
    _soundEnabled = DatabaseService.getSoundEnabled();
    _voiceEnabled = DatabaseService.getVoiceCoachEnabled();

    _historyCache =
        DatabaseService.getLastExerciseHistory(widget.exercise.name);
    _currentPR = DatabaseService.getPersonalRecord(widget.exercise.name);
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
        'kg': TextEditingController(
            text: live.kg > 0
                ? live.kg
                    .toStringAsFixed(live.kg == live.kg.roundToDouble() ? 0 : 1)
                : ''),
        'reps': TextEditingController(text: live.reps.toString()),
      };
    });

    // La schermata parte in preparazione: nessun tempo di esecuzione è attivo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final setsCount = widget.exercise.sets.length;
      VoiceService.speak(
          "Prepara ${widget.exercise.name}. Sono previste $setsCount serie.");
    });
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    _countdownTimer?.cancel();
    _stopwatchNotifier.dispose();
    for (final ctrlMap in _controllers) {
      ctrlMap['kg']!.dispose();
      ctrlMap['reps']!.dispose();
    }
    super.dispose();
  }

  static String _formatSeconds(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _loadOverloadSuggestion() async {
    // Fast-path: skip network call entirely when userId is not available locally
    final localId = DatabaseService.getUserId();
    if (localId == null) return;
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

  int get _activeSetIndex => _flow.activeSetIndex;

  void _startStopwatch() {
    _stopwatchTimer?.cancel();
    _stopwatchNotifier.value = 0;
    _setStartedAt = DateTime.now();
    _exerciseStartedAt ??= _setStartedAt;
    _stopwatchTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final startedAt = _setStartedAt;
      if (startedAt != null) {
        _stopwatchNotifier.value =
            DateTime.now().difference(startedAt).inSeconds;
      }
    });
  }

  void _stopStopwatch() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = null;
  }

  void _startCountdown() {
    FocusScope.of(context).unfocus();
    final reps = int.tryParse(_controllers[_activeSetIndex]['reps']!.text);
    if (reps == null || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Inserisci un numero di ripetizioni valido.')),
      );
      return;
    }
    _countdownTimer?.cancel();
    _flow.startCountdown();
    final duration = DatabaseService.getSetCountdownSeconds();
    _countdownRemaining = duration;
    setState(() {});

    if (duration == 0) {
      _startExecution();
      return;
    }

    VoiceService.speak("Preparati");
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownRemaining <= 1) {
        timer.cancel();
        _startExecution();
      } else {
        setState(() => _countdownRemaining--);
        if (_countdownRemaining <= 3) HapticFeedback.selectionClick();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _flow.cancelCountdown();
    setState(() {});
  }

  void _startExecution() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _flow.startExecution();
    _startStopwatch();
    HapticFeedback.heavyImpact();
    if (_soundEnabled) SoundService.playBeep();
    VoiceService.speak("Via!");
    setState(() {});
  }

  void _stopActiveSet() {
    if (_flow.phase != SetSessionPhase.executing) return;
    final startedAt = _setStartedAt;
    if (startedAt != null) {
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      _stopwatchNotifier.value = elapsedMs <= 0 ? 0 : (elapsedMs + 999) ~/ 1000;
    }
    _stopStopwatch();
    _flow.stopExecution();
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _confirmActiveSet() {
    HapticFeedback.mediumImpact();

    final si = _activeSetIndex;
    final kgVal =
        double.tryParse(_controllers[si]['kg']!.text) ?? _liveSets[si].kg;
    final repsVal =
        int.tryParse(_controllers[si]['reps']!.text) ?? _liveSets[si].reps;

    final isNewPR = kgVal > 0 && (_currentPR == null || kgVal > _currentPR!);
    if (isNewPR) {
      _currentPR = kgVal;
      _showPRCelebration(kgVal);
      VoiceService.speak("Nuovo record personale! Complimenti!");
    }

    setState(() {
      _liveSets[si]
        ..isDone = true
        ..kg = kgVal
        ..reps = repsVal
        ..timeUnderTension = _stopwatchNotifier.value;
    });

    final isLastSet = _flow.isLastSet;
    _flow.confirmSet();

    if (isLastSet) {
      VoiceService.speak("Esercizio completato! Ottimo lavoro.");
      _showNerdStats();
    } else {
      final restSec = widget.exercise.sets[si].targetRestSeconds;
      if (!isNewPR) {
        VoiceService.speak("Ottimo! Ora ripòsati per $restSec secondi.");
      } else {
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted && _flow.phase == SetSessionPhase.resting) {
            VoiceService.speak("Ora ripòsati per $restSec secondi.");
          }
        });
      }
      setState(() {
        _restSeconds = restSec;
      });
    }
  }

  void _endRest() {
    _flow.finishRest();
    setState(() {
      _stopwatchNotifier.value = 0;
    });
    VoiceService.speak("Prepara la serie ${_activeSetIndex + 1}.");
  }

  void _showNerdStats() {
    final endTime = DateTime.now();
    final durationSeconds = _exerciseStartedAt == null
        ? _liveSets.fold<int>(0, (sum, set) => sum + set.timeUnderTension)
        : endTime.difference(_exerciseStartedAt!).inSeconds;

    double volume = 0;
    for (final s in _liveSets) {
      if (s.isDone) {
        volume += s.kg * s.reps;
      }
    }

    // kcal = MET × peso_kg × durata_ore  (ACSM). Fallback 70 kg se no biometrics.
    final double userWeightKg =
        DatabaseService.getLatestBiometricRecord()?.weight ?? 70.0;
    final int kcal =
        (_kMET * userWeightKg * (durationSeconds / 3600.0)).round();
    final String timeStr =
        '${durationSeconds ~/ 60}:${(durationSeconds % 60).toString().padLeft(2, '0')}';

    final setsData = _liveSets
        .where((s) => s.isDone)
        .map((s) => CompletedSet(
              weight: s.kg,
              reps: s.reps,
              timeUnderTension: s.timeUnderTension,
            ))
        .toList();

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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surfaceVariant,
                        title: const Text('Termina Sessione',
                            style: TextStyle(color: Colors.white)),
                        content: const Text(
                            'Sei sicuro di voler terminare e salvare l\'allenamento corrente?',
                            style: TextStyle(color: AppTheme.textSecondary)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annulla',
                                style: TextStyle(color: AppTheme.cyan)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Termina e Salva',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      Navigator.pop(context);
                      Navigator.pop(context,
                          {'action': 'finish', 'data': completedExercise});
                    }
                  },
                  icon: const Icon(Icons.stop_circle_outlined, size: 20),
                  label: const Text('TERMINA SESSIONE E SALVA',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                const SizedBox(height: 32),
                const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                const SizedBox(height: 16),
                const Text('Ottimo Lavoro!',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatBox(
                        title: 'Volume',
                        value: '${volume.toStringAsFixed(1)} kg',
                        color: widget.accentColor),
                    _StatBox(
                        title: 'Tempo',
                        value: timeStr,
                        color: Colors.blueAccent),
                    _StatBox(
                        title: 'Kcal',
                        value: '$kcal',
                        color: Colors.orangeAccent),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context,
                          {'action': 'continue', 'data': completedExercise});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      foregroundColor: AppTheme.bgTop,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('CONTINUA ALLENAMENTO',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPRCelebration(double weight) {
    HapticFeedback.heavyImpact();

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    bool isRemoved = false;

    void removeEntry() {
      if (!isRemoved) {
        isRemoved = true;
        entry.remove();
      }
    }

    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).size.height * 0.25,
        left: 32,
        right: 32,
        child: GestureDetector(
          onTap: removeEntry,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.9),
                    Colors.orange.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  const Text(
                    'NUOVO RECORD!',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    '${weight.toStringAsFixed(weight == weight.roundToDouble() ? 0 : 1)} kg',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1.0, 1.0),
                    duration: 400.ms,
                    curve: Curves.elasticOut)
                .fadeIn(duration: 200.ms),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2500), removeEntry);
  }

  Future<bool> _onWillPop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: const Text('Interrompi esercizio?',
            style: TextStyle(color: Colors.white)),
        content: const Text('I dati di questo esercizio non verranno salvati.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla',
                  style: TextStyle(color: AppTheme.cyan))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Interrompi',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_flow.phase == SetSessionPhase.resting) {
      final nextIdx = _activeSetIndex + 1;
      NextSetInfo? nextSetInfo;
      if (nextIdx < _liveSets.length) {
        final nextLive = _liveSets[nextIdx];
        nextSetInfo = NextSetInfo(
          setNumber: nextIdx + 1,
          totalSets: widget.exercise.sets.length,
          kg: nextLive.kg,
          reps: nextLive.reps,
        );
      }
      return AppTheme.buildBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: RestTimerWidget(
              durationSeconds: _restSeconds,
              accentColor: widget.accentColor,
              onFinish: _endRest,
              nextSet: nextSetInfo,
              soundEnabled: _soundEnabled,
              onSoundToggle: (value) {
                setState(() => _soundEnabled = value);
                DatabaseService.setSoundEnabled(value);
              },
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
            actions: [
              IconButton(
                tooltip: _voiceEnabled
                    ? 'Disattiva Coach Vocale'
                    : 'Attiva Coach Vocale',
                icon: Icon(
                  _voiceEnabled ? Icons.headset : Icons.headset_off,
                  color: _voiceEnabled
                      ? widget.accentColor
                      : AppTheme.textSecondary,
                ),
                onPressed: () {
                  final next = !_voiceEnabled;
                  setState(() => _voiceEnabled = next);
                  DatabaseService.setVoiceCoachEnabled(next);
                  if (next) {
                    VoiceService.speak("Coach vocale attivo");
                  } else {
                    VoiceService.stop();
                  }
                },
              ),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0.05, 0), end: Offset.zero)
                      .animate(animation),
                  child: child,
                ),
              );
            },
            child: _buildBodyForPhase(),
          ),
          bottomNavigationBar: _buildBottomAction(),
        ),
      ),
    );
  }

  Widget _buildBodyForPhase() {
    switch (_flow.phase) {
      case SetSessionPhase.preparing:
        return _buildPreparationCard();
      case SetSessionPhase.countdown:
        return _buildCountdownView();
      case SetSessionPhase.executing:
        return _buildActiveFocusCard(_activeSetIndex, editable: false);
      case SetSessionPhase.confirming:
        return _buildActiveFocusCard(_activeSetIndex, editable: true);
      case SetSessionPhase.completed:
        return const Center(child: CircularProgressIndicator());
      case SetSessionPhase.resting:
        return const SizedBox.shrink();
    }
  }

  Widget? _buildBottomAction() {
    late final VoidCallback action;
    late final IconData icon;
    late final String label;
    Color background = widget.accentColor;
    Color foreground = AppTheme.bgTop;

    switch (_flow.phase) {
      case SetSessionPhase.preparing:
        action = _startCountdown;
        icon = Icons.play_circle_fill;
        label = 'SONO PRONTO';
        break;
      case SetSessionPhase.executing:
        action = _stopActiveSet;
        icon = Icons.stop_circle_outlined;
        label = 'TERMINA SERIE';
        background = Colors.redAccent;
        foreground = Colors.white;
        break;
      case SetSessionPhase.confirming:
        action = _confirmActiveSet;
        icon = Icons.check_circle_outline;
        label = 'CONFERMA SERIE ${_activeSetIndex + 1}';
        break;
      case SetSessionPhase.countdown:
      case SetSessionPhase.resting:
      case SetSessionPhase.completed:
        return null;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: action,
          icon: Icon(icon, size: 28),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
          ),
        ),
      ),
    );
  }

  Widget _buildPreparationCard() {
    final si = _activeSetIndex;
    final lastSet = (_historyCache != null && si < _historyCache!.sets.length)
        ? _historyCache!.sets[si]
        : null;

    return SingleChildScrollView(
      key: ValueKey('preparing-$si'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PREPARA LA SERIE ${si + 1}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.exercise.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (widget.exercise.setup.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.exercise.setup,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 20),
          AppTheme.glassContainer(
            borderColor: widget.accentColor.withValues(alpha: 0.5),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(_liveSets.length, (index) {
                final active = index == si;
                final kgText = _controllers[index]['kg']!.text.trim();
                final repsText = _controllers[index]['reps']!.text.trim();
                return Container(
                  margin: EdgeInsets.only(
                      bottom: index == _liveSets.length - 1 ? 0 : 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: active
                        ? widget.accentColor.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active
                          ? widget.accentColor.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            active ? widget.accentColor : Colors.white12,
                        foregroundColor:
                            active ? AppTheme.bgTop : Colors.white70,
                        child: Text('${index + 1}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          kgText.isEmpty ? 'Peso da impostare' : '$kgText kg',
                          style: TextStyle(
                            color: active ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '$repsText reps',
                        style: TextStyle(
                            color:
                                active ? widget.accentColor : Colors.white54),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          if (widget.exercise.loadNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              widget.exercise.loadNote,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: widget.accentColor, fontWeight: FontWeight.w600),
            ),
          ],
          if (lastSet != null) ...[
            const SizedBox(height: 8),
            Text(
              'Ultima volta: ${lastSet.weight} kg × ${lastSet.reps}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
          if (_suggestedWeight != null) ...[
            const SizedBox(height: 6),
            Text(
              'Carico suggerito: $_suggestedWeight kg',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.greenAccent, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                  child: _buildInput(
                      label: 'Kg previsti',
                      controller: _controllers[si]['kg']!,
                      enabled: true,
                      color: widget.accentColor)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildInput(
                      label: 'Reps previste',
                      controller: _controllers[si]['reps']!,
                      enabled: true,
                      isInt: true,
                      color: widget.accentColor)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Recupero dopo la serie: ${widget.exercise.sets[si].targetRestSeconds}s',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownView() {
    return Center(
      key: ValueKey('countdown-$_activeSetIndex'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'POSIZIONATI',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text(
              '$_countdownRemaining',
              style: TextStyle(
                color: widget.accentColor,
                fontSize: 128,
                height: 1,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                      color: widget.accentColor.withValues(alpha: 0.6),
                      blurRadius: 30)
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${_controllers[_activeSetIndex]['kg']!.text.isEmpty ? 'Peso libero' : '${_controllers[_activeSetIndex]['kg']!.text} kg'} × ${_controllers[_activeSetIndex]['reps']!.text} reps',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: _cancelCountdown,
              icon: const Icon(Icons.close),
              label: const Text('ANNULLA COUNTDOWN'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFocusCard(int si, {required bool editable}) {
    final CompletedSet? lastSet =
        (_historyCache != null && si < _historyCache!.sets.length)
            ? _historyCache!.sets[si]
            : null;

    return SingleChildScrollView(
      key: ValueKey('${editable ? 'confirming' : 'executing'}-$si'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: AppTheme.glassContainer(
        borderColor: widget.accentColor.withValues(alpha: 0.8),
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
            if (widget.exercise.loadNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bar_chart, size: 14, color: widget.accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.exercise.loadNote,
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (widget.exercise.externalNote != null &&
                widget.exercise.externalNote!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 13, color: Colors.white38),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.exercise.externalNote!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (lastSet != null)
              Text('Record precedente: ${lastSet.weight}kg × ${lastSet.reps}',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                      fontStyle: FontStyle.italic)),
            if (_suggestedWeight != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    _suggestionReason == 'target_reached'
                        ? Icons.trending_up
                        : Icons.trending_flat,
                    size: 14,
                    color: _suggestionReason == 'target_reached'
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _suggestionReason == 'target_reached'
                        ? 'Suggerimento: ${_suggestedWeight}kg (+2.5kg)'
                        : 'Suggerimento: mantieni ${_suggestedWeight}kg',
                    style: TextStyle(
                      fontSize: 12,
                      color: _suggestionReason == 'target_reached'
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
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
                  Icon(Icons.timer_outlined,
                      size: 36,
                      color: widget.accentColor.withValues(alpha: 0.7)),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: _stopwatchNotifier,
                    builder: (_, secs, __) => Text(
                      _formatSeconds(secs),
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        color: widget.accentColor,
                        height: 1.0,
                        shadows: [
                          Shadow(
                              color: widget.accentColor.withValues(alpha: 0.4),
                              blurRadius: 20)
                        ],
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    editable ? 'TEMPO REGISTRATO' : 'TEMPO SOTTO TENSIONE',
                    style: TextStyle(
                        fontSize: 13,
                        color: widget.accentColor.withValues(alpha: 0.6),
                        letterSpacing: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            if (editable)
              Row(
                children: [
                  Expanded(
                      child: _buildInput(
                          label: 'Kg effettivi',
                          controller: _controllers[si]['kg']!,
                          enabled: true,
                          color: widget.accentColor)),
                  const SizedBox(width: 12),
                  if (lastSet != null) ...[
                    _buildPlusThreeBtn(si, lastSet.weight),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                      child: _buildInput(
                          label: 'Reps effettive',
                          controller: _controllers[si]['reps']!,
                          enabled: true,
                          isInt: true,
                          color: widget.accentColor)),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                      child: _buildExecutionValue(
                          'CARICO',
                          _controllers[si]['kg']!.text.isEmpty
                              ? 'Corpo libero'
                              : '${_controllers[si]['kg']!.text} kg')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildExecutionValue(
                          'TARGET', '${_controllers[si]['reps']!.text} reps')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutionValue(String label, String value) {
    return AppTheme.glassContainer(
      borderColor: widget.accentColor.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInput(
      {required String label,
      required TextEditingController controller,
      required bool enabled,
      bool isInt = false,
      required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        AppTheme.glassContainer(
          borderRadius: BorderRadius.circular(12),
          borderColor: color.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: controller,
            enabled: enabled,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
            inputFormatters: isInt
                ? [FilteringTextInputFormatter.digitsOnly]
                : [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: enabled ? Colors.white : Colors.white54),
            decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8)),
          ),
        ),
      ],
    );
  }

  Widget _buildPlusThreeBtn(int si, double lastKg) {
    return Semantics(
      label: 'Aumenta peso del 3% rispetto all\'ultima sessione',
      button: true,
      child: GestureDetector(
        onTap: () {
          setState(() {
            final newKg = (lastKg * 1.03 * 2).round() / 2;
            _controllers[si]['kg']!.text = newKg == newKg.roundToDouble()
                ? newKg.toInt().toString()
                : newKg.toStringAsFixed(1);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: widget.accentColor.withValues(alpha: 0.4))),
          child: Text('+3%',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: widget.accentColor)),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatBox(
      {required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
