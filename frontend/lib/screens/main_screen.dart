import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/connectivity_service.dart';
import '../core/sync_service.dart';
import '../core/theme.dart';
import '../data/database_service.dart';
import 'analysis_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'profile_hub_screen.dart';
import 'statistics_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Timer? _syncTimer;

  static const _screenBuilders = <Widget Function()>[
    HomeScreen.new,
    HistoryScreen.new,
    StatisticsScreen.new,
    AnalysisScreen.new,
    ProfileHubScreen.new,
  ];

  final Map<int, Widget> _screenCache = {};

  @override
  void initState() {
    super.initState();
    if (ConnectivityService.isOnline.value) {
      SyncService.syncAllPendingData();
    }
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

  Widget _getScreen(int index) =>
      _screenCache.putIfAbsent(index, () => _screenBuilders[index]());

  @override
  Widget build(BuildContext context) {
    _getScreen(_currentIndex);

    return AppTheme.buildBackground(
      child: ValueListenableBuilder<bool>(
        valueListenable: ConnectivityService.isOnline,
        builder: (context, online, child) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                AnimatedSize(
                  duration: AppMotion.standard,
                  curve: AppMotion.curve,
                  child: online
                      ? const SizedBox.shrink()
                      : _OfflineBanner(
                          pendingCount:
                              DatabaseService.getUnsyncedWorkouts().length,
                        ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: List.generate(
                      _screenBuilders.length,
                      (i) => _screenCache[i] ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF26313D))),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  HapticFeedback.selectionClick();
                  setState(() => _currentIndex = index);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Oggi',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: 'Storico',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights_rounded),
                    label: 'Progressi',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome_rounded),
                    label: 'Coach',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Profilo',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Connessione assente',
      child: Container(
        width: double.infinity,
        color: AppTheme.warning.withValues(alpha: 0.12),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          bottom: 8,
          left: 16,
          right: 16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 14,
              color: AppTheme.warning,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                pendingCount > 0
                    ? 'Offline — $pendingCount allenament${pendingCount == 1 ? 'o' : 'i'} in attesa di sync'
                    : 'Offline — gli allenamenti vengono salvati localmente',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.warning,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
