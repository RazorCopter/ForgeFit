import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/auth_service.dart';
import 'main_screen.dart';
import 'auth_screen.dart';
import '../data/database_service.dart';

import 'package:hive/hive.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  final List<String> failedBoxes;
  const SplashScreen({super.key, this.failedBoxes = const []});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/videos/splash_video.mp4')
      ..initialize().then((_) {
        _videoController.setVolume(0.0); // Muto per aggirare il blocco autoplay dei browser
        _videoController.play();
        _videoController.setLooping(true);
        if (mounted) setState(() {});
      }).catchError((e) {
        debugPrint("Errore inizializzazione video: $e");
      });
    _initApp();
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    // 1. Gestisci eventuali box corrotti PRIMA di procedere
    if (widget.failedBoxes.isNotEmpty) {
      final shouldReset = await _showCorruptedDataDialog(widget.failedBoxes);
      if (shouldReset && mounted) {
        for (final boxName in widget.failedBoxes) {
          await Hive.deleteBoxFromDisk(boxName);
        }
        await DatabaseService.openBox();
      }
    }

    // 2. Procedi con il controllo auth e il delay minimo
    final minimumDelay = Future.delayed(const Duration(milliseconds: 5000));
    final checkAuth = AuthService.isLoggedIn().then((loggedIn) async {
      if (loggedIn) {
        // Sincronizzazione di sicurezza: se AuthService ha l'email ma DatabaseService no, la ripristiniamo.
        final email = await AuthService.getEmail();
        if (email != null && (DatabaseService.getUserEmail() == null)) {
          await DatabaseService.saveUserEmail(email);
        }
      }
      return loggedIn;
    });

    final results = await Future.wait([minimumDelay, checkAuth]);
    if (!mounted) return;
    
    final loggedIn = results[1] as bool;
    final Widget next = loggedIn ? const MainScreen() : const AuthScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<bool> _showCorruptedDataDialog(List<String> failedBoxes) async {
    return await showDialog<bool>(
      context: context,
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reimposta', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: _videoController.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              )
            : const SizedBox(),
      ),
    );
  }
}
