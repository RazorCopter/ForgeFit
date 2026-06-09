import 'dart:async';

class ForgeFitWebAuthn {
  static bool get isSupported => false;
  
  static Future<String> register(String optionsJsonStr) async {
    throw UnsupportedError("WebAuthn is only supported on Web.");
  }
  
  static Future<String> login(String optionsJsonStr) async {
    throw UnsupportedError("WebAuthn is only supported on Web.");
  }
}
