import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'statistics_screen.dart';
import 'analysis_screen.dart';
import 'setup_screen.dart';
import '../core/theme.dart';
import '../data/database_service.dart';
import '../core/sync_service.dart';
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
    // Esegui la prima sync immediata
    SyncService.syncAllPendingData();
    // Imposta una sync periodica (es. ogni 5 minuti)
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      SyncService.syncAllPendingData();
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
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
      ),
    );
  }
}
