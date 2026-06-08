import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';

class RestTimerWidget extends StatefulWidget {
  final int durationSeconds;
  final Color accentColor;
  final VoidCallback onFinish;

  const RestTimerWidget({
    super.key,
    required this.durationSeconds,
    required this.accentColor,
    required this.onFinish,
  });

  @override
  State<RestTimerWidget> createState() => _RestTimerWidgetState();
}

class _RestTimerWidgetState extends State<RestTimerWidget> {
  late int _remainingSeconds;
  Timer? _timer;

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
        // Qui invokeremmo anche la vibrazione: HapticFeedback.vibrate();
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _stopTimer() {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                  width: 250,
                  height: 250,
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formattedTime,
                      style: TextStyle(
                        fontSize: 56,
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
          const SizedBox(height: 48),
          AppTheme.glassContainer(
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.all(4),
            child: ElevatedButton.icon(
              onPressed: _stopTimer,
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
    );
  }
}
