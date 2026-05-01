import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import '../core/auth_service.dart';
import 'main_screen.dart';
import 'auth_screen.dart';
import '../data/database_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      final loggedIn = await AuthService.isLoggedIn();
      if (loggedIn) {
        // Sincronizzazione di sicurezza: se AuthService ha l'email ma DatabaseService no, la ripristiniamo.
        final email = await AuthService.getEmail();
        if (email != null && (DatabaseService.getUserEmail() == null)) {
          await DatabaseService.saveUserEmail(email);
        }
      }
      if (!mounted) return;
      final Widget next = loggedIn ? const MainScreen() : const AuthScreen();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => next,
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Image.asset(
          'assets/images/splash.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Text(
              'FORGE FIT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ).animate().fade(duration: 800.ms);
          },
        ).animate()
            .fadeIn(duration: 800.ms)
            .fadeOut(delay: 2.seconds, duration: 800.ms),
      ),
    );
  }
}
