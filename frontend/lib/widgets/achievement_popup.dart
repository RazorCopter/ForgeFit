import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  @override
  void initState() {
    super.initState();
    _autoDismiss = Timer(const Duration(seconds: 4), _dismiss);
  }

  @override
  void dispose() {
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
      child: Center(
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
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: a.color.withValues(alpha: 0.15),
                    border: Border.all(color: a.color.withValues(alpha: 0.5), width: 2),
                    boxShadow: [
                      BoxShadow(color: a.color.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2),
                    ],
                  ),
                  child: Icon(a.icon, size: 44, color: a.color),
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
    );
  }
}
