import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/training_data.dart';
import '../models/completed_workout.dart';
import '../data/database_service.dart';
import '../core/theme.dart';
import '../widgets/rest_timer_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stato di una singola serie durante la sessione live
// ─────────────────────────────────────────────────────────────────────────────
class _LiveSet {
  double kg;
  int reps;
  bool isDone;
  int timeUnderTension; // secondi cronometro

  _LiveSet({required this.kg, required this.reps})
      : isDone = false,
        timeUnderTension = 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget principale
// ─────────────────────────────────────────────────────────────────────────────
class ActiveSessionScreen extends StatefulWidget {
  final TrainingDay day;
  final Color accentColor;

  const ActiveSessionScreen({
    super.key,
    required this.day,
    required this.accentColor,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  // ── Dati live (struttura parallela agli esercizi della scheda) ────────────
  // _liveSets[exIndex][setIndex]
  late final List<List<_LiveSet>> _liveSets;

  // ── Stato corrente ────────────────────────────────────────────────────────
  int? _activeEx;   // indice esercizio con serie in corso
  int? _activeSet;  // indice serie in corso

  // ── Timer cronometro (conta a salire durante la serie) ────────────────────
  Timer? _stopwatchTimer;
  int _stopwatchSeconds = 0;

  // ── Riposo ────────────────────────────────────────────────────────────────
  bool _isResting = false;
  int _restSeconds = 0;

  // ── Cronometro allenamento totale ─────────────────────────────────────────
  late final DateTime _startTime;

  // ── Storico ultima sessione (pre-caricato) ─────────────────────────────────
  final Map<String, CompletedExercise?> _historyCache = {};

  // ── GlobalKey per auto-scroll ──────────────────────────────────────────────
  final Map<String, GlobalKey> _rowKeys = {};

  // ── TextEditingController pool (evita rebuild con ValueKey) ───────────────
  // controllers[exIndex][setIndex] = {kg: ctrl, reps: ctrl}
  late final List<List<Map<String, TextEditingController>>> _controllers;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    // Carica storico
    for (final ex in widget.day.exercises) {
      _historyCache[ex.id] = DatabaseService.getLastExerciseHistory(ex.name);
    }

    // Inizializza strutture live con valori target della scheda
    _liveSets = widget.day.exercises.map((ex) {
      return ex.sets.map((s) => _LiveSet(
        kg:   s.weight > 0 ? s.weight : 0,
        reps: s.targetReps,
      )).toList();
    }).toList();

    // Inizializza controller pre-compilati
    _controllers = List.generate(widget.day.exercises.length, (ei) {
      return List.generate(widget.day.exercises[ei].sets.length, (si) {
        final live = _liveSets[ei][si];
        return {
          'kg':   TextEditingController(text: live.kg > 0 ? live.kg.toStringAsFixed(live.kg == live.kg.roundToDouble() ? 0 : 1) : ''),
          'reps': TextEditingController(text: live.reps.toString()),
        };
      });
    });
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    for (final exCtrl in _controllers) {
      for (final ctrlMap in exCtrl) {
        ctrlMap['kg']!.dispose();
        ctrlMap['reps']!.dispose();
      }
    }
    super.dispose();
  }

  // ── GlobalKey per riga ─────────────────────────────────────────────────────
  GlobalKey _rowKey(int ei, int si) {
    final k = '${ei}_$si';
    return _rowKeys.putIfAbsent(k, () => GlobalKey());
  }

  // ── Cronometro ─────────────────────────────────────────────────────────────
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

  // ── Avvia serie ────────────────────────────────────────────────────────────
  void _startSet(int ei, int si) {
    setState(() {
      _activeEx  = ei;
      _activeSet = si;
    });
    _startStopwatch();
    // Auto-scroll alla serie attiva
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _rowKey(ei, si).currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.15);
      }
    });
  }

  // ── Termina serie ──────────────────────────────────────────────────────────
  void _completeSet(int ei, int si) {
    _stopStopwatch();

    // Leggi valori reali dai controller
    final kgVal   = double.tryParse(_controllers[ei][si]['kg']!.text)   ?? _liveSets[ei][si].kg;
    final repsVal = int.tryParse(_controllers[ei][si]['reps']!.text)    ?? _liveSets[ei][si].reps;

    setState(() {
      _liveSets[ei][si]
        ..isDone          = true
        ..kg              = kgVal
        ..reps            = repsVal
        ..timeUnderTension = _stopwatchSeconds;
      _activeEx  = null;
      _activeSet = null;
    });

    // Logica riposo intelligente
    final exercise  = widget.day.exercises[ei];
    final isLastSet = si == exercise.sets.length - 1;

    if (isLastSet) {
      // Ultima serie dell'esercizio → nessun riposo, avanza direttamente
      _scrollToNextPending();
    } else {
      // Serie intermedia → avvia riposo
      final restSec = exercise.sets[si].targetRestSeconds;
      setState(() {
        _isResting  = true;
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
      for (int e = 0; e < _liveSets.length; e++) {
        for (int s = 0; s < _liveSets[e].length; s++) {
          if (!_liveSets[e][s].isDone) {
            final ctx = _rowKey(e, s).currentContext;
            if (ctx != null) {
              Scrollable.ensureVisible(ctx,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  alignment: 0.15);
            }
            return;
          }
        }
      }
    });
  }

  // ── Salva allenamento ──────────────────────────────────────────────────────
  Future<void> _finishWorkout() async {
    _stopStopwatch();
    final duration = DateTime.now().difference(_startTime).inSeconds;

    final List<CompletedExercise> completedExercises = [];

    for (int ei = 0; ei < widget.day.exercises.length; ei++) {
      final ex   = widget.day.exercises[ei];
      final sets = <CompletedSet>[];

      for (int si = 0; si < _liveSets[ei].length; si++) {
        final live = _liveSets[ei][si];
        if (live.isDone) {
          sets.add(CompletedSet(
            weight:          live.kg,
            reps:            live.reps,
            timeUnderTension: live.timeUnderTension,
          ));
        }
      }

      if (sets.isNotEmpty) {
        completedExercises.add(CompletedExercise(
          name:            ex.name,
          gruppoMuscolare: ex.gruppoMuscolare,
          sets:            sets,
        ));
      }
    }

    if (completedExercises.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nessun set completato. Allenamento annullato.'),
          backgroundColor: Colors.redAccent,
        ));
        Navigator.pop(context);
      }
      return;
    }

    await DatabaseService.saveWorkout(CompletedWorkout(
      id:              const Uuid().v4(),
      title:           widget.day.title,
      date:            DateTime.now(),
      durationSeconds: duration,
      exercises:       completedExercises,
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Allenamento salvato! Durata: ${duration ~/ 60}m'),
        backgroundColor: AppTheme.vividPurple,
      ));
      Navigator.pop(context);
      Navigator.pop(context);
    }
  }

  // ── Conferma abbandono ─────────────────────────────────────────────────────
  Future<bool> _onWillPop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: const Text('Abbandona allenamento?', style: TextStyle(color: Colors.white)),
        content: const Text('I progressi non salvati andranno persi.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Continua', style: TextStyle(color: AppTheme.cyan))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Abbandona', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    return confirm ?? false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Overlay riposo (fullscreen)
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
            title: Text(widget.day.title),
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
                onPressed: _finishWorkout,
                tooltip: 'Termina e Salva',
              ),
            ],
          ),
          body: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120, top: 8),
            itemCount: widget.day.exercises.length,
            itemBuilder: (context, ei) {
              final exercise = widget.day.exercises[ei];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildExerciseHeader(exercise, ei),
                  ...List.generate(exercise.sets.length, (si) {
                    return Container(
                      key: _rowKey(ei, si),
                      child: _buildSetCard(ei, si),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
          floatingActionButton: AppTheme.glassContainer(
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.all(4),
            child: FloatingActionButton.extended(
              onPressed: _finishWorkout,
              backgroundColor: widget.accentColor.withOpacity(0.2),
              foregroundColor: widget.accentColor,
              elevation: 0,
              icon: const Icon(Icons.check_circle),
              label: const Text('CONCLUDI', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header esercizio ───────────────────────────────────────────────────────
  Widget _buildExerciseHeader(Exercise exercise, int ei) {
    final allDone = _liveSets[ei].every((s) => s.isDone);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(Icons.fitness_center,
              color: allDone ? Colors.green : widget.accentColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(exercise.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: allDone ? Colors.green : Colors.white,
                )),
          ),
          if (exercise.videoUrl.isNotEmpty)
            IconButton(
              icon: Icon(Icons.play_circle_outline, color: widget.accentColor),
              onPressed: () async {
                final uri = Uri.parse(exercise.videoUrl);
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
            ),
        ],
      ),
    );
  }

  // ── Card serie ─────────────────────────────────────────────────────────────
  Widget _buildSetCard(int ei, int si) {
    final live     = _liveSets[ei][si];
    final isActive = _activeEx == ei && _activeSet == si;
    final isDone   = live.isDone;

    Color border = Colors.white.withOpacity(0.05);
    double bgOpacity = 0.02;
    if (isDone)   { border = Colors.green.withOpacity(0.3);       bgOpacity = 0.05; }
    if (isActive) { border = widget.accentColor.withOpacity(0.8); bgOpacity = 0.10; }

    final hist = _historyCache[widget.day.exercises[ei].id];
    final CompletedSet? lastSet =
        (hist != null && si < hist.sets.length) ? hist.sets[si] : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: AppTheme.glassContainer(
        borderColor: border,
        opacity: bgOpacity,
        padding: isActive
            ? const EdgeInsets.all(20)
            : const EdgeInsets.all(14),
        child: isActive
            ? _buildActiveCardContent(ei, si, lastSet)
            : _buildCompactCardContent(ei, si, isDone, lastSet),
      ),
    );
  }

  // ── Layout ESPANSO — serie in corso ────────────────────────────────────────
  Widget _buildActiveCardContent(int ei, int si, CompletedSet? lastSet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Intestazione: numero serie + label
        Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accentColor.withOpacity(0.2),
              ),
              child: Center(
                child: Text(
                  '${si + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'SERIE IN CORSO',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: widget.accentColor,
              ),
            ),
            if (lastSet != null) ...[
              const Spacer(),
              Text(
                'Last: ${lastSet.weight}kg × ${lastSet.reps}',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white30,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),

        const SizedBox(height: 20),

        // ── CRONOMETRO GIGANTE ──────────────────────────────────────
        Center(
          child: Column(
            children: [
              Icon(Icons.timer_outlined,
                  size: 28, color: widget.accentColor.withOpacity(0.7)),
              const SizedBox(height: 4),
              Text(
                _swFormatted,
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: widget.accentColor,
                  height: 1.0,
                  shadows: [
                    Shadow(
                      color: widget.accentColor.withOpacity(0.4),
                      blurRadius: 20,
                    ),
                  ],
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'Tempo Sotto Tensione',
                style: TextStyle(
                    fontSize: 11,
                    color: widget.accentColor.withOpacity(0.6),
                    letterSpacing: 1),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Input Kg / Reps ─────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _buildInput(
                label: 'Kg effettivi',
                controller: _controllers[ei][si]['kg']!,
                enabled: true,
                color: widget.accentColor,
              ),
            ),
            const SizedBox(width: 8),
            if (lastSet != null) _buildPlusThreeBtn(ei, si, lastSet.weight),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInput(
                label: 'Reps effettive',
                controller: _controllers[ei][si]['reps']!,
                enabled: true,
                isInt: true,
                color: widget.accentColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Pulsante TERMINA — piena larghezza ──────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _completeSet(ei, si),
            icon: const Icon(Icons.stop_circle_outlined, size: 22),
            label: const Text(
              'TERMINA SERIE',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // ── Layout COMPATTO — serie in attesa o completata ─────────────────────────
  Widget _buildCompactCardContent(
      int ei, int si, bool isDone, CompletedSet? lastSet) {
    final live = _liveSets[ei][si];
    return Row(
      children: [
        // Numero / check
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? Colors.green.withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.green, size: 18)
                : Text(
                    '${si + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDone
                    ? '${live.kg}kg × ${live.reps} reps  •  ${live.timeUnderTension}s'
                    : 'Target: ${widget.day.exercises[ei].sets[si].targetReps} reps'
                        ' @ ${_controllers[ei][si]['kg']!.text.isNotEmpty ? _controllers[ei][si]['kg']!.text : "—"}kg',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                  color: isDone ? Colors.green : Colors.white70,
                ),
              ),
              if (lastSet != null && !isDone)
                Text(
                  'Last: ${lastSet.weight}kg × ${lastSet.reps}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white30,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        // Pulsante
        if (!isDone)
          ElevatedButton.icon(
            onPressed: () => _startSet(ei, si),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Via!',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: AppTheme.bgTop,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          )
        else
          ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: Colors.green.withOpacity(0.4),
              disabledForegroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Icon(Icons.check, size: 20),
          ),
      ],
    );
  }

  // ── Input field ────────────────────────────────────────────────────────────
  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    bool isInt = false,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        AppTheme.glassContainer(
          borderRadius: BorderRadius.circular(10),
          borderColor: color.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
            inputFormatters: isInt
                ? [FilteringTextInputFormatter.digitsOnly]
                : [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: enabled ? Colors.white : Colors.white54,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
      ],
    );
  }

  // ── Pulsante +3% ──────────────────────────────────────────────────────────
  Widget _buildPlusThreeBtn(int ei, int si, double lastKg) {
    return GestureDetector(
      onTap: () {
        setState(() {
          final newKg = (lastKg * 1.03 * 2).round() / 2; // arrotonda a 0.5kg
          _controllers[ei][si]['kg']!.text =
              newKg == newKg.roundToDouble() ? newKg.toInt().toString() : newKg.toStringAsFixed(1);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: widget.accentColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: widget.accentColor.withOpacity(0.4)),
        ),
        child: Text('+3%',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: widget.accentColor)),
      ),
    );
  }

}

