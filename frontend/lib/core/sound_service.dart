import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Suona un beep sintetico (sine wave 880 Hz, 0.4 s) generato in memoria.
/// Nessun asset file richiesto.
class SoundService {
  SoundService._();

  static final AudioPlayer _player = AudioPlayer();

  /// Genera e riproduce il beep. Fire-and-forget: non lancia eccezioni.
  static Future<void> playBeep() async {
    try {
      final bytes = _buildWav(frequency: 880, durationMs: 400);
      await _player.play(BytesSource(bytes));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // WAV PCM-16 stereo generato in memoria
  // ---------------------------------------------------------------------------
  static Uint8List _buildWav({
    required double frequency,
    required int durationMs,
    int sampleRate = 44100,
  }) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final dataSize = numSamples * 2; // 16-bit mono

    final buffer = ByteData(44 + dataSize);

    // RIFF header
    _writeChars(buffer, 0, 'RIFF');
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    _writeChars(buffer, 8, 'WAVE');

    // fmt chunk
    _writeChars(buffer, 12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little);        // chunk size
    buffer.setUint16(20, 1, Endian.little);         // PCM
    buffer.setUint16(22, 1, Endian.little);         // mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    buffer.setUint16(32, 2, Endian.little);         // block align
    buffer.setUint16(34, 16, Endian.little);        // bits/sample

    // data chunk header
    _writeChars(buffer, 36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    // PCM samples — sine wave with linear fade-out in last 20%
    const twoPi = 6.283185307179586;
    final fadeStart = (numSamples * 0.8).round();
    for (var i = 0; i < numSamples; i++) {
      var amplitude = 0.6;
      if (i >= fadeStart) {
        amplitude *= 1.0 - (i - fadeStart) / (numSamples - fadeStart);
      }
      final sample = (amplitude * 32767 * _sin(twoPi * frequency * i / sampleRate)).round().clamp(-32768, 32767);
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  static void _writeChars(ByteData buf, int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      buf.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  // Taylor-series sin (avoids dart:math import, sufficient precision here)
  static double _sin(double x) {
    // Reduce to [-π, π]
    const pi = 3.141592653589793;
    x = x % (2 * pi);
    if (x > pi) x -= 2 * pi;
    if (x < -pi) x += 2 * pi;
    // 7-term Taylor
    final x2 = x * x;
    return x * (1 - x2 / 6 * (1 - x2 / 20 * (1 - x2 / 42)));
  }
}
