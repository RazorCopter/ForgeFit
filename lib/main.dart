import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme.dart';
import 'core/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'models/completed_workout.dart';
import 'models/user_profile.dart';
import 'models/biometric_record.dart';
import 'data/database_service.dart';

/// Chiave globale del Navigator — usata dall'interceptor 401
/// per forzare il logout senza dipendere dal BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(CompletedWorkoutAdapter());
  Hive.registerAdapter(CompletedExerciseAdapter());
  Hive.registerAdapter(CompletedSetAdapter());
  Hive.registerAdapter(UserProfileAdapter());
  Hive.registerAdapter(BiometricRecordAdapter());

  await DatabaseService.openBox();

  // ── Interceptor 401: logout forzato da qualsiasi punto dell'app ──
  onUnauthorized = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
    // SnackBar globale
    ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
      const SnackBar(
        content: Text('Sessione scaduta. Effettua nuovamente il login.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  };

  runApp(const MyTrainingLogApp());
}

class MyTrainingLogApp extends StatelessWidget {
  const MyTrainingLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forge Fit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
    );
  }
}
