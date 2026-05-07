/// ============================================================
/// auth_service.dart
/// Gestione persistenza token JWT e stato di autenticazione.
/// Usa shared_preferences (compatibile web + mobile).
/// ============================================================
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class AuthService {
  AuthService._();

  static const String _keyToken   = 'jwt_token';
  static const String _keyEmail   = 'auth_email';
  static const String _keyUserId  = 'auth_user_id';

  // ── Salva token dopo login/register ────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  // ── Legge token salvato (null se non loggato) ──────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  // ── Salva email corrente ───────────────────────────────────────────────────
  static Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  // ── Salva ID utente ────────────────────────────────────────────────────────
  static Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  // ── Controlla se l'utente è autenticato ───────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── Logout: cancella token e email ────────────────────────────────────────
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyUserId);
  }

  // ── Header Authorization da iniettare nelle richieste ─────────────────────
  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    debugPrint('🔑 [AuthService] authHeaders() -> Token found: ${token != null ? "SI" : "NO"}');
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}
