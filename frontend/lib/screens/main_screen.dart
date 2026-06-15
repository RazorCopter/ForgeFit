import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'statistics_screen.dart';
import 'analysis_screen.dart';
import 'achievements_screen.dart';
import 'setup_screen.dart';
import '../core/theme.dart';
import '../data/database_service.dart';
import '../core/sync_service.dart';
import '../core/connectivity_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    // Esegui la prima sync immediata (solo se online)
    if (ConnectivityService.isOnline.value) {
      SyncService.syncAllPendingData();
    }
    // Sync periodica ogni 15 minuti come fallback (il trigger principale è ConnectivityService)
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (ConnectivityService.isOnline.value) {
        SyncService.syncAllPendingData();
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const StatisticsScreen(),
    const AnalysisScreen(),
    const AchievementsScreen(),
    const SetupScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildBackground(
      child: ValueListenableBuilder<bool>(
        valueListenable: ConnectivityService.isOnline,
        builder: (context, online, child) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  child: online
                      ? const SizedBox.shrink()
                      : _OfflineBanner(),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _AnimatedBottomNav(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom navigation bar custom con indicatore animato e glow
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AnimatedBottomNav({required this.currentIndex, required this.onTap});

  @override
  State<_AnimatedBottomNav> createState() => _AnimatedBottomNavState();
}

class _AnimatedBottomNavState extends State<_AnimatedBottomNav>
    with SingleTickerProviderStateMixin {
  static const _items = [
    (icon: Icons.home_rounded, label: 'Routines'),
    (icon: Icons.calendar_month_rounded, label: 'Storico'),
    (icon: Icons.bar_chart_rounded, label: 'Stats'),
    (icon: Icons.auto_awesome_rounded, label: 'AI'),
    (icon: Icons.emoji_events_rounded, label: 'Traguardi'),
    (icon: Icons.settings_rounded, label: 'Setup'),
  ];

  late AnimationController _indicatorCtrl;
  late Animation<double> _indicatorAnim;
  int _prevIndex = 0;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex;
    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _indicatorAnim = CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(_AnimatedBottomNav old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _prevIndex = old.currentIndex;
      _indicatorCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 64 + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A).withValues(alpha: 0.85),
            border: const Border(top: BorderSide(color: Color(0xFF00E5FF), width: 0.5)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _items.length;
              return Stack(
                children: [
                  // Indicatore scorrevole
                  AnimatedBuilder(
                    animation: _indicatorAnim,
                    builder: (context, _) {
                      final from = _prevIndex * itemWidth + itemWidth / 2;
                      final to = widget.currentIndex * itemWidth + itemWidth / 2;
                      final x = lerpDouble(from, to, _indicatorAnim.value)!;
                      return Positioned(
                        top: 6,
                        left: x - 24,
                        child: Container(
                          width: 48,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppTheme.cyan,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.cyan.withValues(alpha: 0.7),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Icone e label
                  Row(
                    children: List.generate(_items.length, (i) {
                      final selected = widget.currentIndex == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onTap(i),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 10),
                              AnimatedScale(
                                scale: selected ? 1.25 : 1.0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                child: AnimatedOpacity(
                                  opacity: selected ? 1.0 : 0.45,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    _items[i].icon,
                                    color: selected ? AppTheme.cyan : AppTheme.textSecondary,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                  color: selected ? AppTheme.cyan : AppTheme.textSecondary,
                                ),
                                child: Text(_items[i].label),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pendingCount = DatabaseService.getUnsyncedWorkouts().length;
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A1A2E),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        bottom: 8,
        left: 16,
        right: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 14, color: Colors.orangeAccent),
          const SizedBox(width: 8),
          Text(
            pendingCount > 0
                ? 'Offline — $pendingCount allenament${pendingCount == 1 ? 'o' : 'i'} in attesa di sync'
                : 'Offline — gli allenamenti vengono salvati localmente',
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
