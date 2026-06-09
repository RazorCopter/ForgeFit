import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import '../data/database_service.dart';

import 'passkeys_service_io.dart' if (dart.library.js_interop) 'passkeys_service_web.dart';

class PasskeysService {
  /// Restituisce vero se l'ambiente supporta WebAuthn
  static bool get isSupported => ForgeFitWebAuthn.isSupported;

  static const Duration _timeout = Duration(seconds: 30);

  // ------------------------------------------------------------------
  // REGISTER (Aggiungi Passkey al Profilo)
  // ------------------------------------------------------------------
  static Future<void> registerPasskey() async {
    if (!isSupported) {
      throw Exception("Autenticazione biometrica (WebAuthn) non supportata su questo dispositivo.");
    }
    
    final headers = await AuthService.authHeaders();

    // 1. Chiedi al server le opzioni per la generazione
    final optionsRes = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/webauthn/register/generate-options'),
      headers: headers,
    ).timeout(_timeout);

    if (optionsRes.statusCode != 200) {
      throw Exception("Impossibile recuperare opzioni Passkey: ${optionsRes.body}");
    }

    final optionsJsonStr = optionsRes.body;

    // 2. Passa le opzioni al browser / sistema per creare la credenziale
    String passkeyPayloadStr;
    try {
      passkeyPayloadStr = await ForgeFitWebAuthn.register(optionsJsonStr);
    } catch (e) {
      throw Exception("Creazione Passkey annullata o fallita: $e");
    }

    // 3. Invia la risposta al backend per la verifica
    final verifyRes = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/webauthn/register/verify'),
      headers: headers,
      body: passkeyPayloadStr, // JSON inviato raw
    ).timeout(_timeout);

    if (verifyRes.statusCode != 200) {
      throw Exception("Verifica Passkey fallita: ${verifyRes.body}");
    }
  }

  // ------------------------------------------------------------------
  // LOGIN (Accedi con Passkey)
  // ------------------------------------------------------------------
  static Future<Map<String, dynamic>> loginWithPasskey(String email) async {
    if (!isSupported) {
      throw Exception("Autenticazione biometrica (WebAuthn) non supportata su questo dispositivo.");
    }

    final pubHeaders = {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };

    // 1. Chiedi al server le opzioni per l'autenticazione passando l'email
    final optionsUrl = Uri.parse('${ApiConfig.baseUrl}/api/auth/webauthn/login/generate-options').replace(queryParameters: {'email': email});
    final optionsRes = await http.get(
      optionsUrl,
      headers: pubHeaders,
    ).timeout(_timeout);

    if (optionsRes.statusCode != 200) {
      throw Exception("Impossibile recuperare opzioni Login Passkey: ${optionsRes.body}");
    }

    final optionsJsonStr = optionsRes.body;

    // 2. Interroga il browser per autenticare
    String passkeyPayloadStr;
    try {
      passkeyPayloadStr = await ForgeFitWebAuthn.login(optionsJsonStr);
    } catch (e) {
      throw Exception("Login biometrico annullato o fallito.");
    }

    // 3. Verifica col backend e ricevi il JWT
    final verifyUrl = Uri.parse('${ApiConfig.baseUrl}/api/auth/webauthn/login/verify').replace(queryParameters: {'email': email});
    final verifyRes = await http.post(
      verifyUrl,
      headers: pubHeaders,
      body: passkeyPayloadStr, // payload raw generato dal JS
    ).timeout(_timeout);

    if (verifyRes.statusCode != 200) {
      throw Exception("Verifica Login Passkey fallita: ${verifyRes.body}");
    }

    final data = jsonDecode(verifyRes.body);

    // Salva JWT e Profile in locale (logica identica ad ApiService.login)
    final token = data['access_token'] as String?;
    if (token != null) {
      await AuthService.saveToken(token);
      final refreshToken = data['refresh_token'] as String?;
      if (refreshToken != null) await AuthService.saveRefreshToken(refreshToken);
      await AuthService.saveEmail(email);
      
      await DatabaseService.saveUserEmail(email);
      
      int? userId;
      try {
        if (data['user'] != null && data['user'] is Map) {
          userId = (data['user']['id'] as num?)?.toInt();
        } else {
          userId = (data['user_id'] as num? ?? data['id'] as num?)?.toInt();
        }
      } catch (e) {
        debugPrint('Errore parsing userId da WebAuthn: $e');
      }

      if (userId != null) {
        await AuthService.saveUserId(userId);
        await DatabaseService.saveUserId(userId);
      }
    }

    return data;
  }
}
