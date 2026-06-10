import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme.dart';
import 'core/api_service.dart';
import 'core/auth_service.dart';
import 'core/connectivity_service.dart';
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

  final failedBoxes = await DatabaseService.openBox();

  await ConnectivityService.initialize();

  // ── Interceptor 401: logout forzato da qualsiasi punto dell'app ──
  onUnauthorized = () async {
    await AuthService.logout();
    
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
    // SnackBar globale — guard contro context null o smontato
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Sessione scaduta. Effettua nuovamente il login.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  };

  runApp(MyTrainingLogApp(failedBoxes: failedBoxes));
}

class MyTrainingLogApp extends StatelessWidget {
  final List<String> failedBoxes;
  
  const MyTrainingLogApp({super.key, required this.failedBoxes});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forge Fit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorKey: navigatorKey,
      home: SplashScreen(failedBoxes: failedBoxes),
    );
  }
}
