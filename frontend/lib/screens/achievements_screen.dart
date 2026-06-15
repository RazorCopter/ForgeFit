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
    Widget image = Image.asset(
      'assets/achievements/${achievement.id}.png',
      fit: BoxFit.contain,
    );

    if (!isUnlocked) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]), // Scala di grigi
        child: Opacity(
          opacity: 0.25,
          child: image,
        ),
      );
    }

    Widget badgeContent = Column(
      children: [
        Expanded(
          child: isUnlocked
              ? Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: achievement.color.withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: image,
                )
              : image,
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

    if (isUnlocked) {
      final dateStr = unlockedAt != null 
          ? '\nSbloccato il ${unlockedAt!.day.toString().padLeft(2, '0')}/${unlockedAt!.month.toString().padLeft(2, '0')}/${unlockedAt!.year}'
          : '';
      return Tooltip(
        message: '${achievement.description}$dateStr',
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 3),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: achievement.color.withValues(alpha: 0.5)),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        child: badgeContent,
      );
    }

    return badgeContent;
  }
}
