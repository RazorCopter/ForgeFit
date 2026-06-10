import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'statistics_screen.dart';
import 'analysis_screen.dart';
import 'setup_screen.dart';
import '../core/theme.dart';
import '../data/database_service.dart';
import '../core/sync_service.dart';
import '../core/connectivity_service.dart';
import 'dart:async';

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
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: AppTheme.pushAccent,
              unselectedItemColor: AppTheme.textSecondary,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Routines',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month),
                  label: 'Storico',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart),
                  label: 'Statistiche',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.auto_awesome),
                  label: 'AI Analysis',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Setup',
                ),
              ],
            ),
          );
        },
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
