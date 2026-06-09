import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/database_service.dart';

class AuthService {
  AuthService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyToken        = 'jwt_token';
  static const String _keyRefreshToken = 'jwt_refresh_token';
  static const String _keyEmail        = 'auth_email';
  static const String _keyUserId       = 'auth_user_id';

  static Future<void> saveToken(String token) =>
      _storage.write(key: _keyToken, value: token);

  static Future<String?> getToken() =>
      _storage.read(key: _keyToken);

  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _keyRefreshToken, value: token);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: _keyRefreshToken);

  static Future<void> saveEmail(String email) =>
      _storage.write(key: _keyEmail, value: email);

  static Future<String?> getEmail() =>
      _storage.read(key: _keyEmail);

  // userId serializzato come stringa (FlutterSecureStorage non ha setInt)
  static Future<void> saveUserId(int userId) =>
      _storage.write(key: _keyUserId, value: userId.toString());

  static Future<int?> getUserId() async {
    final raw = await _storage.read(key: _keyUserId);
    return raw != null ? int.tryParse(raw) : null;
  }

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
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyUserId);
    
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
