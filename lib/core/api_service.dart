/// ============================================================
/// api_service.dart
/// Servizio centralizzato per tutte le chiamate HTTP al backend.
/// Inietta automaticamente il token JWT in ogni richiesta
/// (tranne login e register). Forza logout su 401.
/// ============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import '../data/database_service.dart';

/// Callback globale per il logout forzato su 401.
/// Viene impostata da main.dart con il navigatorKey.
/// Questo evita dipendenze circolari tra ApiService e il widget tree.
typedef UnauthorizedCallback = void Function();
UnauthorizedCallback? onUnauthorized;

/// Eccezione personalizzata lanciata quando il server risponde
/// con uno status code diverso da 2xx.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Servizio singleton per la comunicazione REST con il backend FastAPI.
class ApiService {
  ApiService._(); // Non istanziabile

  static const Duration _timeout = Duration(seconds: 15);

  // ── Header pubblici (login / register — senza token) ─────────────────────
  static const Map<String, String> _publicHeaders = {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };

  // ------------------------------------------------------------------
  // POST /api/login
  // ------------------------------------------------------------------

  /// Login con email e password. Restituisce il token JWT.
  /// Il token viene salvato automaticamente in [AuthService].
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.login),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'username': email,
              'password': password,
            },
          )
          .timeout(_timeout);

      final data = _handleResponse(response);
      // Salva token e email in locale
      final token = data['access_token'] as String?;
      if (token != null) {
        await AuthService.saveToken(token);
        await AuthService.saveEmail(email);
        await DatabaseService.saveUserEmail(email); // Sincronizza con Hive
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Impossibile raggiungere il server: $e');
    }
  }

  // ------------------------------------------------------------------
  // POST /api/register
  // ------------------------------------------------------------------

  /// Registrazione nuovo utente. Se il backend restituisce un token,
  /// viene salvato automaticamente (auto-login post-register).
  static Future<Map<String, dynamic>> register(
      Map<String, dynamic> payload) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.register),
            headers: _publicHeaders,
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      final data = _handleResponse(response);
      // Auto-login: salva token se presente nella risposta
      final token = data['access_token'] as String?;
      if (token != null) {
        final email = payload['email'] as String? ?? '';
        await AuthService.saveToken(token);
        await AuthService.saveEmail(email);
        await DatabaseService.saveUserEmail(email); // Sincronizza con Hive
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Impossibile raggiungere il server: $e');
    }
  }

  // ------------------------------------------------------------------
  // GET /api/plans/{email}  [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------

  static Future<Map<String, dynamic>> getPlans(String email) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http
          .get(Uri.parse(ApiConfig.plans(email)), headers: headers)
          .timeout(_timeout);

      _checkUnauthorized(response);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Impossibile raggiungere il server: $e');
    }
  }

  // ------------------------------------------------------------------
  // PUT /api/auth/change-password [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------

  /// Cambia la password dell'utente autenticato.
  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http
          .put(
            Uri.parse(ApiConfig.changePassword),
            headers: headers,
            body: jsonEncode({
              'vecchia_password': oldPassword,
              'nuova_password': newPassword,
            }),
          )
          .timeout(_timeout);

      _checkUnauthorized(response);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Impossibile raggiungere il server: $e');
    }
  }

  // ------------------------------------------------------------------
  // POST /api/measurements [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------

  /// Invia le misurazioni fisiologiche al backend per il tracking.
  static Future<Map<String, dynamic>> postMeasurements(Map<String, dynamic> data) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http
          .post(
            Uri.parse(ApiConfig.measurements),
            headers: headers,
            body: jsonEncode(data),
          )
          .timeout(_timeout);

      _checkUnauthorized(response);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Impossibile raggiungere il server: $e');
    }
  }

  // ------------------------------------------------------------------
  // GET /api/auth/me [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------

  /// Recupera i dati anagrafici e fisiologici dell'utente loggato.
  static Future<Map<String, dynamic>> getMe() async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http
          .get(Uri.parse(ApiConfig.userMe), headers: headers)
          .timeout(_timeout);

      _checkUnauthorized(response);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Impossibile raggiungere il server: $e');
    }
  }

  // ------------------------------------------------------------------
  // POST /api/plans/generate-ai [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------

  /// Richiede al backend di generare una nuova scheda di allenamento tramite AI.
  static Future<Map<String, dynamic>> generateAIPlan({
    required String experienceLevel,
    String? ptNotes,
  }) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http
          .post(
            Uri.parse(ApiConfig.generateAIPlan),
            headers: headers,
            body: jsonEncode({
              'experience_level': experienceLevel,
              'pt_notes': ptNotes ?? '',
            }),
          )
          .timeout(const Duration(seconds: 45)); // Timeout lungo per AI

      _checkUnauthorized(response);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Errore generazione scheda AI: $e');
    }
  }

  // ------------------------------------------------------------------
  // POST /api/analysis/generate [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------

  /// Richiede al backend di generare un report di analisi performance tramite AI.
  static Future<Map<String, dynamic>> generateAnalysis() async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http
          .post(
            Uri.parse(ApiConfig.generateAnalysis),
            headers: headers,
          )
          .timeout(const Duration(seconds: 45)); // Timeout lungo per AI

      _checkUnauthorized(response);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Errore generazione report AI: $e');
    }
  }

  // ------------------------------------------------------------------
  // Helper: controlla 401 e forza logout
  // ------------------------------------------------------------------

  /// Se il server risponde 401, svuota il token e chiama [onUnauthorized]
  /// per riportare l'utente alla schermata di login.
  static void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      AuthService.logout(); // fire-and-forget: non serve await
      onUnauthorized?.call();
      throw const ApiException(
        statusCode: 401,
        message: 'Sessione scaduta. Effettua nuovamente il login.',
      );
    }
  }

  // ------------------------------------------------------------------
  // Helper privato: normalizza la risposta HTTP
  // ------------------------------------------------------------------
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        return {};
      }
    } else {
      String errorMessage = 'Errore del server (${response.statusCode})';
      try {
        final errorBody = jsonDecode(body) as Map<String, dynamic>;
        errorMessage = errorBody['detail']?.toString() ?? errorMessage;
      } catch (_) {
        if (body.isNotEmpty) errorMessage = body;
      }
      throw ApiException(statusCode: response.statusCode, message: errorMessage);
    }
  }
}
