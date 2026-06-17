import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../data/database_service.dart';

/// Servizio di autenticazione unificato per tutte le piattaforme.
///
/// Usa Hive come storage: su web Hive usa localStorage internamente,
/// su native Hive usa file system (crittografia eventualmente gestibile
/// tramite HiveCipher). Questo evita la dipendenza da
/// `flutter_secure_storage` che su web HTTP crasha perché
/// `window.crypto.subtle` non è disponibile.
class AuthService {
  AuthService._();

  static const String _keyToken        = 'jwt_token';
  static const String _keyRefreshToken = 'jwt_refresh_token';
  static const String _keyEmail        = 'auth_email';
  static const String _keyUserId       = 'auth_user_id';

  /// Nome del box Hive da usare per i dati di autenticazione.
  /// Riutilizza il box `settings` già aperto da [DatabaseService.openBox].
  static Box? _getSettingsBox() {
    try {
      return Hive.box('settings');
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(String key, String value) async {
    final box = _getSettingsBox();
    if (box != null && box.isOpen) {
      await box.put('auth_$key', value);
    }
  }

  static Future<String?> _read(String key) async {
    final box = _getSettingsBox();
    if (box != null && box.isOpen) {
      return box.get('auth_$key') as String?;
    }
    return null;
  }

  static Future<void> _delete(String key) async {
    final box = _getSettingsBox();
    if (box != null && box.isOpen) {
      await box.delete('auth_$key');
    }
  }

  static Future<void> saveToken(String token) =>
      _write(_keyToken, token);

  static Future<String?> getToken() =>
      _read(_keyToken);

  static Future<void> saveRefreshToken(String token) =>
      _write(_keyRefreshToken, token);

  static Future<String?> getRefreshToken() =>
      _read(_keyRefreshToken);

  static Future<void> saveEmail(String email) =>
      _write(_keyEmail, email);

  static Future<String?> getEmail() =>
      _read(_keyEmail);

  static Future<void> saveUserId(int userId) =>
      _write(_keyUserId, userId.toString());

  static Future<int?> getUserId() async {
    final raw = await _read(_keyUserId);
    return raw != null ? int.tryParse(raw) : null;
  }

  /// Synchronous userId lookup backed by DatabaseService (Hive, already open).
  /// Use this in hot paths where await is undesirable.
  static int? getUserIdSync() => DatabaseService.getUserId();

  static bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final exp = data['exp'] as int?;
      if (exp == null) return false;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    if (_isTokenExpired(token)) {
      await logout();
      return false;
    }
    return true;
  }

  static Future<void> logout() async {
    await _delete(_keyToken);
    await _delete(_keyRefreshToken);
    await _delete(_keyEmail);
    await _delete(_keyUserId);

    // Cancella anche tutti i dati applicativi su Hive
    await DatabaseService.clearAllData();
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    if (kDebugMode) {
      debugPrint('🔑 [AuthService] authHeaders() -> Token: ${token != null ? "presente" : "assente"}');
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}