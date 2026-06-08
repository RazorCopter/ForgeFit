import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';

class NextSetInfo {
  final int setNumber;
  final int totalSets;
  final double kg;
  final int reps;

  const NextSetInfo({
    required this.setNumber,
    required this.totalSets,
    required this.kg,
    required this.reps,
  });
}

class RestTimerWidget extends StatefulWidget {
  final int durationSeconds;
  final Color accentColor;
  final VoidCallback onFinish;
  final NextSetInfo? nextSet;

  const RestTimerWidget({
    super.key,
    required this.durationSeconds,
    required this.accentColor,
    required this.onFinish,
    this.nextSet,
  });

  @override
  State<RestTimerWidget> createState() => _RestTimerWidgetState();
}

class _RestTimerWidgetState extends State<RestTimerWidget> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _countdownFinished = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.durationSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        HapticFeedback.heavyImpact();
        setState(() {
          _countdownFinished = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _skipRest() {
    _timer?.cancel();
    widget.onFinish();
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.durationSeconds == 0
        ? 1.0
        : 1 - (_remainingSeconds / widget.durationSeconds);

    final isZero = _remainingSeconds == 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cerchio countdown
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(isZero ? 0.6 : 0.2),
                    blurRadius: isZero ? 40 : 20,
                    spreadRadius: isZero ? 10 : 2,
                  )
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: widget.accentColor.withOpacity(0.1),
                      color: widget.accentColor,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'RECUPERO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formattedTime,
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: isZero ? Colors.white : widget.accentColor,
                          shadows: [
                            if (isZero)
                              Shadow(
                                color: widget.accentColor,
                                blurRadius: 10,
                              )
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate(target: isZero ? 1 : 0).shimmer(duration: 500.ms, color: Colors.white).scaleXY(end: 1.05, duration: 200.ms),

            const SizedBox(height: 32),

            // Card prossima serie
            if (widget.nextSet != null) _buildNextSetCard(widget.nextSet!),

            const SizedBox(height: 32),

            // Bottone GO! oppure SALTA RECUPERO
            if (_countdownFinished)
              _buildGoButton()
            else
              AppTheme.glassContainer(
                borderRadius: BorderRadius.circular(30),
                padding: const EdgeInsets.all(4),
                child: ElevatedButton.icon(
                  onPressed: _skipRest,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('SALTA RECUPERO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor.withOpacity(0.1),
                    foregroundColor: widget.accentColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextSetCard(NextSetInfo next) {
    return AppTheme.glassContainer(
      borderRadius: BorderRadius.circular(20),
      borderColor: widget.accentColor.withOpacity(0.4),
      opacity: 0.10,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center, size: 18, color: widget.accentColor.withOpacity(0.8)),
              const SizedBox(width: 8),
              Text(
                'PROSSIMA SERIE ${next.setNumber} / ${next.totalSets}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: widget.accentColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNextSetStat(
                icon: Icons.monitor_weight_outlined,
                value: next.kg > 0
                    ? '${next.kg == next.kg.roundToDouble() ? next.kg.toInt() : next.kg} kg'
                    : '— kg',
                label: 'Peso',
              ),
              Container(width: 1, height: 48, color: widget.accentColor.withOpacity(0.2)),
              _buildNextSetStat(
                icon: Icons.repeat,
                value: '${next.reps} reps',
                label: 'Ripetizioni',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextSetStat({required IconData icon, required String value, required String label}) {
    return Column(
      children: [
        Icon(icon, size: 22, color: widget.accentColor.withOpacity(0.7)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildGoButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.onFinish,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.accentColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 12,
          shadowColor: widget.accentColor.withOpacity(0.6),
        ),
        child: const Text(
          'GO!',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
      ),
    ).animate().scaleXY(begin: 0.8, end: 1.0, duration: 300.ms, curve: Curves.elasticOut).fadeIn(duration: 200.ms);
  }
}
