import 'dart:async';
import 'package:js/js.dart';
import 'package:js/js_util.dart';

@JS('forgeFitWebAuthn.isSupported')
external bool _isSupported();

@JS('forgeFitWebAuthn.register')
external dynamic _register(String optionsJsonStr);

@JS('forgeFitWebAuthn.login')
external dynamic _login(String optionsJsonStr);

class ForgeFitWebAuthn {
  static bool get isSupported {
    try {
      return _isSupported();
    } catch (_) {
      return false;
    }
  }
  
  static Future<String> register(String optionsJsonStr) async {
    final promise = _register(optionsJsonStr);
    return await promiseToFuture<String>(promise);
  }
  
  static Future<String> login(String optionsJsonStr) async {
    final promise = _login(optionsJsonStr);
    return await promiseToFuture<String>(promise);
  }
}
