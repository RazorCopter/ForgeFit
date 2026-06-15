import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../core/achievement_service.dart';
import '../core/theme.dart';

class AchievementPopup extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback? onDismiss;

  const AchievementPopup({super.key, required this.achievement, this.onDismiss});

  /// Mostra una sequenza di popup (uno per volta, auto-dismiss 4s).
  static Future<void> showSequence(
    BuildContext context,
    List<Achievement> achievements,
  ) async {
    for (final a in achievements) {
      if (!context.mounted) return;
      final completer = Completer<void>();
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        builder: (_) => AchievementPopup(
          achievement: a,
          onDismiss: () => completer.complete(),
        ),
      ).then((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
      // Piccolo delay tra popup successivi
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  State<AchievementPopup> createState() => _AchievementPopupState();
}

class _AchievementPopupState extends State<AchievementPopup> {
  Timer? _autoDismiss;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _confettiController.play();
    _autoDismiss = Timer(const Duration(seconds: 4), _dismiss);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _autoDismiss?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      widget.onDismiss?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    return GestureDetector(
      onTap: _dismiss,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F1A),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: a.color.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: a.color.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 4),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TRAGUARDO SBLOCCATO!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                        color: a.color,
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                    const SizedBox(height: 20),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: a.color.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2),
                        ],
                      ),
                      child: Image.asset('assets/achievements/${a.id}.png', fit: BoxFit.contain),
                    )
                        .animate()
                        .scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), duration: 450.ms, curve: Curves.elasticOut)
                        .fadeIn(duration: 250.ms),
                    const SizedBox(height: 20),
                    Text(
                      a.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                    const SizedBox(height: 8),
                    Text(
                      a.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 24),
                    Text(
                      'Tocca per chiudere',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 800.ms),
                  ],
                ),
              ),
            )
                .animate()
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 300.ms, curve: Curves.easeOut)
                .fadeIn(duration: 250.ms),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: [a.color, Colors.white, AppTheme.cyan],
              emissionFrequency: 0.05,
              numberOfParticles: 25,
              maxBlastForce: 20,
              minBlastForce: 10,
            ),
          ),
        ],
      ),
    );
  }
}
