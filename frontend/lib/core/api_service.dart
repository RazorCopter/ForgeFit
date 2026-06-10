/// ============================================================
/// api_service.dart
/// Servizio centralizzato per tutte le chiamate HTTP al backend.
/// Inietta automaticamente il token JWT in ogni richiesta
/// (tranne login e register). Forza logout su 401.
/// ============================================================
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

/// Segnale interno usato da [ApiService._checkUnauthorizedAsync] per indicare
/// che l'access token è stato rinnovato e la richiesta va ritentata.
class _RetryWithNewToken implements Exception {
  final String newToken;
  const _RetryWithNewToken(this.newToken);
}

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
      
      if (kDebugMode) {
        debugPrint('🔑 [ApiService] Login Response Body: $data');
      }

      // Salva token e email in locale
      final token = data['access_token'] as String?;
      if (token != null) {
        await AuthService.saveToken(token);
        final refreshToken = data['refresh_token'] as String?;
        if (refreshToken != null) await AuthService.saveRefreshToken(refreshToken);
        await AuthService.saveEmail(email);
        await DatabaseService.saveUserEmail(email); // Sincronizza con Hive
        
        // Estrazione ID utente ultra-robusta
        int? userId;
        try {
          if (data['user'] != null && data['user'] is Map) {
            userId = (data['user']['id'] as num?)?.toInt();
          } else {
            userId = (data['user_id'] as num? ?? data['id'] as num?)?.toInt();
          }
        } catch (e) {
          debugPrint('❌ [ApiService] Errore parsing userId: $e');
        }

        if (kDebugMode) {
          debugPrint('👤 [ApiService] Extracted userId: $userId');
          debugPrint('🏷️ [ApiService] Backend Version: ${data['version'] ?? "Unknown (Old)"}');
        }

        if (userId != null) {
          await AuthService.saveUserId(userId);
          await DatabaseService.saveUserId(userId);
          if (kDebugMode) debugPrint('✅ [ApiService] userId $userId saved to persistent storage.');
        } else {
          if (kDebugMode) debugPrint('⚠️ [ApiService] userId is NULL after extraction!');
        }
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

        // Estrazione ID utente ultra-robusta
        int? userId;
        try {
          if (data['user'] != null && data['user'] is Map) {
            userId = (data['user']['id'] as num?)?.toInt();
          } else {
            userId = (data['user_id'] as num? ?? data['id'] as num?)?.toInt();
          }
        } catch (e) {
          debugPrint('Errore parsing userId post-register: $e');
        }

        if (userId != null) {
          await AuthService.saveUserId(userId);
          await DatabaseService.saveUserId(userId);
        }
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Impossibile raggiungere il server: $e');
    }
  }

  // ------------------------------------------------------------------
  // GET /api/plans/{user_id}/history  [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------
  static Future<List<dynamic>> getPlanHistory(int userId) async {
    final url = '${ApiConfig.plans(userId)}/history';
    Future<http.Response> doRequest(Map<String, String> headers) =>
        http.get(Uri.parse(url), headers: headers).timeout(_timeout);

    try {
      var headers = await AuthService.authHeaders();
      var response = await doRequest(headers);
      try {
        await _checkUnauthorizedAsync(response);
      } on _RetryWithNewToken catch (_) {
        headers = await AuthService.authHeaders();
        response = await doRequest(headers);
        await _checkUnauthorized(response);
      }
      return _handleResponse(response) as List<dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Impossibile ottenere lo storico schede: $e');
    }
  }

  // ------------------------------------------------------------------
  // GET /api/plans/{user_id}  [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------
  static Future<Map<String, dynamic>> getPlans(int userId) async {
    final url = ApiConfig.plans(userId);
    Future<http.Response> doRequest(Map<String, String> headers) =>
        http.get(Uri.parse(url), headers: headers).timeout(_timeout);

    try {
      var headers = await AuthService.authHeaders();
      var response = await doRequest(headers);
      try {
        await _checkUnauthorizedAsync(response);
      } on _RetryWithNewToken catch (r) {
        headers = await AuthService.authHeaders();
        response = await doRequest(headers);
        await _checkUnauthorized(response);
      }
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw const ApiException(statusCode: 404, message: 'Nessuna scheda trovata per questo utente.');
      }
      rethrow;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw Exception('Impossibile raggiungere il server: $e');
    }
  }

  // ------------------------------------------------------------------
  // POST /api/workouts/save [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------
  static Future<void> saveWorkout(dynamic workout) async {
    final userId = await AuthService.getUserId();
    if (userId == null) throw Exception("Utente non autenticato o ID mancante.");

    // Assume workout is an instance of CompletedWorkout. We serialize it to JSON.
    // Convert to the exact payload expected by backend.
    final payload = {
      'user_id': userId,
      'title': workout.title,
      'duration_seconds': workout.durationSeconds,
      'exercises': workout.exercises.map((e) => e.toJson()).toList(),
    };

    final headers = await AuthService.authHeaders();

    if (kDebugMode) debugPrint('🚀 [ApiService] POST ${ApiConfig.saveWorkout}');

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.saveWorkout),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      if (kDebugMode) debugPrint('📥 [ApiService] saveWorkout Status: ${response.statusCode}');
      if (kDebugMode && response.statusCode >= 300) {
        debugPrint('❌ [ApiService] Error Body: ${response.body}');
      }

      await _checkUnauthorized(response);
      _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('🚨 [ApiService] saveWorkout Error: $e');
      throw Exception('Errore di connessione: $e');
    }
  }

  // ------------------------------------------------------------------
  // GET /api/workouts/history/{user_id} [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------
  static Future<List<dynamic>> getWorkoutHistory(int userId) async {
    final url = ApiConfig.workoutHistory(userId);
    Future<http.Response> doRequest(Map<String, String> headers) =>
        http.get(Uri.parse(url), headers: headers).timeout(_timeout);

    try {
      var headers = await AuthService.authHeaders();
      var response = await doRequest(headers);
      try {
        await _checkUnauthorizedAsync(response);
      } on _RetryWithNewToken catch (_) {
        headers = await AuthService.authHeaders();
        response = await doRequest(headers);
        await _checkUnauthorized(response);
      }
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Errore di connessione: $e');
    }
  }

  // ------------------------------------------------------------------
  // GET /api/measurements/history/{user_id} [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------
  static Future<List<dynamic>> getBiometricHistory(int userId) async {
    final url = ApiConfig.measurementHistory(userId);
    Future<http.Response> doRequest(Map<String, String> headers) =>
        http.get(Uri.parse(url), headers: headers).timeout(_timeout);

    try {
      var headers = await AuthService.authHeaders();
      var response = await doRequest(headers);
      try {
        await _checkUnauthorizedAsync(response);
      } on _RetryWithNewToken catch (_) {
        headers = await AuthService.authHeaders();
        response = await doRequest(headers);
        await _checkUnauthorized(response);
      }
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Errore di connessione: $e');
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

      await _checkUnauthorized(response);
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

      await _checkUnauthorized(response);
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

      await _checkUnauthorized(response);
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

      await _checkUnauthorized(response);
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

      await _checkUnauthorized(response);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Errore generazione report AI: $e');
    }
  }

  // ------------------------------------------------------------------
  // POST /api/auth/unlock-ai [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------

  /// Verifica il codice di sblocco AI lato server.
  /// Restituisce `{ "valid": true, "expires_at": "ISO8601" }` se corretto.
  static Future<Map<String, dynamic>> unlockAI({required String code}) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http
          .post(
            Uri.parse(ApiConfig.unlockAI),
            headers: headers,
            body: jsonEncode({'code': code}),
          )
          .timeout(_timeout);

      await _checkUnauthorized(response);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Impossibile raggiungere il server: $e');
    }
  }

  // ------------------------------------------------------------------
  // GET /api/workouts/suggestions/{user_id} [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------

  /// Recupera i suggerimenti di progressive overload per l'utente.
  static Future<Map<String, dynamic>> getOverloadSuggestions(int userId) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http
          .get(Uri.parse(ApiConfig.overloadSuggestions(userId)), headers: headers)
          .timeout(_timeout);
      await _checkUnauthorized(response);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Impossibile recuperare suggerimenti: $e');
    }
  }

  // ------------------------------------------------------------------
  // POST /api/ai/analyze [PROTETTO — richiede JWT]
  // ------------------------------------------------------------------

  /// Metodo passthrough generico per inviare un prompt e un contesto al backend.
  static Future<Map<String, dynamic>> analyzeWithAI({
    required String prompt,
    Map<String, dynamic>? contextData,
  }) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http
          .post(
            Uri.parse(ApiConfig.aiAnalyze),
            headers: headers,
            body: jsonEncode({
              'prompt_text': prompt,
              'context_data': contextData ?? {},
            }),
          )
          .timeout(const Duration(seconds: 45));

      await _checkUnauthorized(response);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Errore durante l\'analisi passthrough AI: $e');
    }
  }

  // ------------------------------------------------------------------
  // Helper: controlla 401 — tenta refresh, poi logout se fallisce
  // ------------------------------------------------------------------

  /// Se il server risponde 401, prova a rinnovare l'access token via refresh token.
  /// Se il refresh riesce, salva il nuovo token e lancia [_RetryWithNewToken].
  /// Se fallisce, fa logout e chiama [onUnauthorized].
  static Future<void> _checkUnauthorizedAsync(http.Response response) async {
    if (response.statusCode != 401) return;

    final refreshToken = await AuthService.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        final refreshResponse = await http.post(
          Uri.parse(ApiConfig.refreshToken),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({'refresh_token': refreshToken}),
        ).timeout(_timeout);

        if (refreshResponse.statusCode == 200) {
          final body = jsonDecode(utf8.decode(refreshResponse.bodyBytes)) as Map<String, dynamic>;
          final newToken = body['access_token'] as String?;
          if (newToken != null) {
            await AuthService.saveToken(newToken);
            throw _RetryWithNewToken(newToken);
          }
        }
      } catch (e) {
        if (e is _RetryWithNewToken) rethrow;
        // Refresh fallito — cadere nel logout sotto
      }
    }

    await AuthService.logout();
    onUnauthorized?.call();
    throw const ApiException(
      statusCode: 401,
      message: 'Sessione scaduta. Effettua nuovamente il login.',
    );
  }

  /// Versione asincrona mantenuta per retrocompatibilità dove non serve retry.
  static Future<void> _checkUnauthorized(http.Response response) async {
    if (response.statusCode == 401) {
      await AuthService.logout();
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
  static dynamic _handleResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(body);
      } catch (_) {
        return body.isEmpty ? {} : body;
      }
    } else {
      String errorMessage = 'Errore del server (${response.statusCode})';
      try {
        final errorBody = jsonDecode(body);
        if (errorBody is Map && errorBody.containsKey('detail')) {
          errorMessage = errorBody['detail']?.toString() ?? errorMessage;
        }
      } catch (_) {
        if (body.isNotEmpty) errorMessage = body;
      }
      throw ApiException(statusCode: response.statusCode, message: errorMessage);
    }
  }
}
