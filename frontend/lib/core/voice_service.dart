import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../data/database_service.dart';

/// Servizio per la gestione della sintesi vocale (TTS) del Coach AI.
/// Gestisce l'inizializzazione del motore, la lingua, i canali audio (per le cuffie)
/// e il rispetto delle preferenze dell'utente.
class VoiceService {
  VoiceService._(); // Singleton

  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;

  /// Inizializza il motore TTS con impostazioni ottimali per la palestra.
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Imposta la lingua italiana
      await _flutterTts.setLanguage("it-IT");
      
      // Velocità del parlato bilanciata (0.5 è il default standard, comodo mentre ci si allena)
      await _flutterTts.setSpeechRate(0.5);
      
      // Tono naturale
      await _flutterTts.setPitch(1.0);
      
      // Volume massimo del canale audio
      await _flutterTts.setVolume(1.0);

      // Supporto per il ducking dell'audio in background (iOS)
      // La musica di altre app (Spotify, ecc.) si abbasserà durante il parlato.
      await _flutterTts.setSharedInstance(true);

      // Su Android, configura per usare il canale assistenza/navigazione o media.
      // Questo aiuta il routing verso cuffie Bluetooth con profilo A2DP/HFP.
      if (!kIsWeb) {
        // Impostiamo l'audio session appropriato
        await _flutterTts.setEngine("com.google.android.tts");
      }

      _isInitialized = true;
      debugPrint('🎙️ [VoiceService] Inizializzato con successo in lingua italiana');
    } catch (e) {
      debugPrint('❌ [VoiceService] Errore inizializzazione TTS: $e');
    }
  }

  /// Pronuncia un testo in italiano, a patto che il coach sia abilitato
  /// nelle impostazioni generali dell'app.
  static Future<void> speak(String text) async {
    // Verifica se abilitato in Hive settings
    final isEnabled = DatabaseService.getVoiceCoachEnabled();
    if (!isEnabled) {
      debugPrint('🎙️ [VoiceService] Parlato ignorato: Coach Vocale disabilitato');
      return;
    }

    if (!_isInitialized) {
      await init();
    }

    try {
      await _flutterTts.stop(); // Interrompi parlato precedente
      await _flutterTts.speak(text);
      debugPrint('🎙️ [VoiceService] Speaking: "$text"');
    } catch (e) {
      debugPrint('❌ [VoiceService] Errore riproduzione speak: $e');
    }
  }

  /// Interrompe immediatamente qualsiasi parlato in corso.
  static Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
