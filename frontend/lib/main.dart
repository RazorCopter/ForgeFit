import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final failedBoxes = await DatabaseService.openBox();

  // ── Interceptor 401: logout forzato da qualsiasi punto dell'app ──
  onUnauthorized = () {
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

  runApp(const MyTrainingLogApp());

  // Mostra il dialog di reset box corrotti dopo che il Navigator è montato
  if (failedBoxes.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      final shouldReset = await showDialog<bool>(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Errore dati locali', style: TextStyle(color: Colors.white)),
          content: Text(
            'I seguenti archivi locali non sono leggibili e devono essere reimpostati:\n\n'
            '${failedBoxes.join(', ')}\n\n'
            'Questa operazione eliminerà i dati non recuperabili. '
            'Verifica prima di avere un backup esportato.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('Annulla', style: TextStyle(color: Colors.cyanAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reimposta', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ) ?? false;

      if (shouldReset) {
        for (final boxName in failedBoxes) {
          await Hive.deleteBoxFromDisk(boxName);
        }
        await DatabaseService.openBox();
      }
    });
  }
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
