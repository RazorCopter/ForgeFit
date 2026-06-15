import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import '../core/achievement_service.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final unlocked = AchievementService.getUnlocked();
    final unlockedIds = {for (final u in unlocked) u.achievement.id: u.unlockedAt};

    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Traguardi', style: TextStyle(color: AppTheme.textPrimary)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'I tuoi Successi',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ).animate().fade().slideY(),
            const SizedBox(height: 4),
            Text(
              'Hai sbloccato ${unlocked.length} su ${AchievementService.all.length} traguardi',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ).animate().fade(delay: 100.ms).slideY(),
            const SizedBox(height: 32),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 24,
                crossAxisSpacing: 16,
                childAspectRatio: 0.65,
              ),
              itemCount: AchievementService.all.length,
              itemBuilder: (context, i) {
                final a = AchievementService.all[i];
                final isUnlocked = unlockedIds.containsKey(a.id);
                final unlockedAt = unlockedIds[a.id];
                return _PennantBadge(achievement: a, isUnlocked: isUnlocked, unlockedAt: unlockedAt)
                    .animate().fade(delay: (150 + i * 30).ms).scale(curve: Curves.easeOutBack);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PennantBadge extends StatelessWidget {
  final Achievement achievement;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const _PennantBadge({required this.achievement, required this.isUnlocked, this.unlockedAt});

  @override
  Widget build(BuildContext context) {
    final color = isUnlocked ? achievement.color : AppTheme.textSecondary.withValues(alpha: 0.15);
    
    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _PennantPainter(color: color, isUnlocked: isUnlocked),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                isUnlocked ? achievement.name.substring(0, 1).toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? Colors.white : AppTheme.textSecondary.withValues(alpha: 0.5),
                  shadows: isUnlocked ? [
                    Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 4, offset: const Offset(1, 2))
                  ] : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          achievement.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isUnlocked ? Colors.white : AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _PennantPainter extends CustomPainter {
  final Color color;
  final bool isUnlocked;

  _PennantPainter({required this.color, required this.isUnlocked});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();
    // Gagliardetto: rettangolo superiore e punta inferiore
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - 20);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, size.height - 20);
    path.close();

    if (isUnlocked) {
      final rect = Offset.zero & size;
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.8),
          color,
          color.withValues(alpha: 0.9),
        ],
      ).createShader(rect);

      // Effetto Glow (neon vivido)
      canvas.drawShadow(path, color, 8, true);
    } else {
      paint.color = color;
    }

    canvas.drawPath(path, paint);
    
    final borderPaint = Paint()
      ..color = isUnlocked ? Colors.white.withValues(alpha: 0.4) : Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawPath(path, borderPaint);
    
    // Disegna una riga decorativa in alto se sbloccato
    if (isUnlocked) {
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(
        const Offset(10, 8), 
        Offset(size.width - 10, 8), 
        linePaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PennantPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isUnlocked != isUnlocked;
  }
}
