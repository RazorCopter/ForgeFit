/// ============================================================
/// api_config.dart
/// Configurazione centralizzata dell'endpoint REST del backend.
/// Modifica [baseUrl] per puntare all'ambiente corretto
/// (locale, staging, produzione).
/// ============================================================
class ApiConfig {
  ApiConfig._(); // Classe non istanziabile — solo costanti statiche

  /// Indirizzo del backend gestito tramite --dart-define.
  /// Esempio: flutter run --dart-define=API_BASE_URL=https://fitconsole.ghome.it
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://fitconsole.ghome.it',
  );

  // --- Endpoint ---

  /// POST  /api/auth/register → registrazione nuovo utente (restituisce JWT)
  static const String register = '$baseUrl/api/auth/register';

  /// POST  /api/auth/login    → login con email+password (restituisce JWT)
  static const String login = '$baseUrl/api/auth/login';

  /// GET   /api/plans/{email} → recupero scheda di allenamento
  static String plans(String email) => '$baseUrl/api/plans/$email';

  /// POST  /api/plans/generate-ai → genera scheda tramite AI
  static const String generateAIPlan = '$baseUrl/api/plans/generate-ai';

  /// POST  /api/analysis/generate → genera report analisi performance tramite AI
  static const String generateAnalysis = '$baseUrl/api/analysis/generate';

  /// POST  /api/ai/analyze → passthrough generico per analisi AI
  static const String aiAnalyze = '$baseUrl/api/ai/analyze';

  /// PUT   /api/auth/change-password → cambio password utente loggato
  static const String changePassword = '$baseUrl/api/auth/change-password';

  /// POST  /api/measurements → invio misure fisiologiche al backend
  static const String measurements = '$baseUrl/api/measurements';

  /// GET   /api/auth/me → recupero dati profilo utente loggato
  static const String userMe = '$baseUrl/api/auth/me';
}
