import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';
import '../data/database_service.dart';

/// Servizio per la gestione della sintesi vocale (TTS) del Coach AI.
/// Utilizza Microsoft Edge TTS (voci neurali cloud) con cache locale
/// e fallback offline su flutter_tts (sintesi vocale locale).
class VoiceService {
  VoiceService._(); // Singleton

  static final FlutterTts _flutterTts = FlutterTts();
  static final AudioPlayer _audioPlayer = AudioPlayer();
  
  static bool _isTtsInitialized = false;
  static bool _isInitialized = false;

  // In-memory TTS cache for web (hash → audio bytes). Bounded to 30 entries.
  static final Map<int, Uint8List> _webCache = {};
  static const int _webCacheMax = 30;

  // LRU eviction: track insertion order for web cache
  static final List<int> _webCacheKeys = [];

  /// Inizializza il motore TTS con impostazioni di fallback.
  static Future<void> init() async {
    if (_isInitialized) return;
    await _initLocalTts();
    _isInitialized = true;
  }

  static Future<void> _initLocalTts() async {
    try {
      await _flutterTts.setLanguage("it-IT");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      if (!kIsWeb) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setEngine("com.google.android.tts");
      }
      _isTtsInitialized = true;
      debugPrint('🎙️ [VoiceService] Fallback Local TTS inizializzato in italiano');
    } catch (e) {
      debugPrint('❌ [VoiceService] Errore inizializzazione Local TTS: $e');
    }
  }

  /// Calcola un nome file univoco e sicuro basato sull'hash del testo.
  static String _getSafeFilename(String text) {
    final clean = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final prefix = clean.substring(0, math.min(15, clean.length));
    return 'tts_${text.hashCode}_$prefix.mp3';
  }

  /// Pronuncia un testo in italiano. Tenta la chiamata cloud Edge TTS,
  /// salva in cache locale (su mobile) o riproduce via byte in memoria (su web),
  /// e in caso di errore/offline effettua il fallback su Local TTS.
  static Future<void> speak(String text) async {
    final isEnabled = DatabaseService.getVoiceCoachEnabled();
    if (!isEnabled) {
      debugPrint('🎙️ [VoiceService] Parlato ignorato: Coach Vocale disabilitato');
      return;
    }

    if (text.trim().isEmpty) return;

    try {
      // Web: use in-memory cache (no filesystem access available).
      if (kIsWeb) {
        final cacheKey = text.hashCode;
        if (_webCache.containsKey(cacheKey)) {
          debugPrint('🎙️ [VoiceService] Web Mode: cache hit per hashCode $cacheKey');
          await stop();
          await _audioPlayer.play(BytesSource(_webCache[cacheKey]!));
          return;
        }

        debugPrint('🎙️ [VoiceService] Web Mode: Scaricamento audio Edge TTS...');
        final headers = await AuthService.authHeaders();
        final encodedText = Uri.encodeComponent(text);
        final url = Uri.parse('${ApiConfig.baseUrl}/api/system/tts?text=$encodedText');

        final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          // Store in cache with LRU eviction
          if (_webCacheKeys.length >= _webCacheMax) {
            final evicted = _webCacheKeys.removeAt(0);
            _webCache.remove(evicted);
          }
          _webCache[cacheKey] = response.bodyBytes;
          _webCacheKeys.add(cacheKey);

          await stop();
          await _audioPlayer.play(BytesSource(response.bodyBytes));
          return;
        } else {
          throw Exception('Web TTS fallito con status ${response.statusCode}');
        }
      }

      // Su dispositivi mobile (Android/iOS), usiamo la cache su filesystem
      final filename = _getSafeFilename(text);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');

      // 1. Controlla cache locale
      if (await file.exists()) {
        debugPrint('🎙️ [VoiceService] Riproduzione da cache locale: $filename');
        await stop();
        await _audioPlayer.play(DeviceFileSource(file.path));
        return;
      }

      // 2. Chiamata a Edge TTS su backend
      debugPrint('🎙️ [VoiceService] Richiesta Edge TTS in corso per: "$text"');
      final headers = await AuthService.authHeaders();
      final encodedText = Uri.encodeComponent(text);
      final url = Uri.parse('${ApiConfig.baseUrl}/api/system/tts?text=$encodedText');

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('🎙️ [VoiceService] Salvato in cache: $filename');
        
        await stop();
        await _audioPlayer.play(DeviceFileSource(file.path));
      } else {
        throw Exception('Server risponde con status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🎙️ [VoiceService] Errore Edge TTS o offline, fallback su Local TTS: $e');
      await _speakLocal(text);
    }
  }

  /// Pronuncia tramite motore di sintesi locale
  static Future<void> _speakLocal(String text) async {
    if (!_isTtsInitialized) {
      await _initLocalTts();
    }
    try {
      await stop();
      await _flutterTts.speak(text);
      debugPrint('🎙️ [VoiceService] Speaking (Local Fallback): "$text"');
    } catch (e) {
      debugPrint('❌ [VoiceService] Errore riproduzione Local TTS: $e');
    }
  }

  /// Interrompe immediatamente qualsiasi parlato in corso (sia locale che cloud).
  static Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      await _flutterTts.stop();
    } catch (_) {}
  }
}
