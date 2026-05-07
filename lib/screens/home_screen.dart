/// ============================================================
/// home_screen.dart  (refactored — architettura Client-Server)
/// Dashboard principale dell'app. Mostra i giorni di allenamento
/// scaricati dal backend. All'avvio la lista è VUOTA: l'utente
/// deve premere il pulsante "Sincronizza Scheda" per scaricare
/// il proprio piano dal server REST.
/// ============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/training_data.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import '../data/database_service.dart';
import 'day_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ----------------------------------------------------------------
  // Stato della lista di giorni di allenamento
  // Inizia VUOTA: l'utente deve sincronizzare dal server.
  // ----------------------------------------------------------------
  List<TrainingDay> _days = [];

  /// true mentre è in corso la chiamata GET /api/plans/{user_id}
  bool _isSyncing = false;

  // ----------------------------------------------------------------
  // Icona contestuale al tipo di giorno
  // ----------------------------------------------------------------
  IconData _getIconForDay(String dayId) {
    switch (dayId) {
      case 'd1': return Icons.fitness_center;    // Push
      case 'd2': return Icons.accessibility_new; // Pull
      case 'd3': return Icons.directions_run;    // Legs
      case 'd4': return Icons.home;              // Home
      default:   return Icons.sports_gymnastics;
    }
  }

  // ----------------------------------------------------------------
  // Sincronizzazione: GET /api/plans/{user_id}
  // ----------------------------------------------------------------

  /// Recupera la scheda di allenamento dal backend e aggiorna la UI.
  ///
  /// Flusso:
  /// 1. Legge l'ID dell'utente da Hive (salvato durante il login)
  /// 2. Chiama GET /api/plans/{user_id} tramite [ApiService]
  /// 3. Estrae il campo `plan` dalla risposta
  /// 4. Parsa il JSON in oggetti [TrainingDay] tramite [DatabaseService]
  /// 5. Chiama [setState] per aggiornare la UI
  Future<void> _syncScheda() async {
    // Recupera l'ID utente: è necessario per la chiamata REST
    final userId = DatabaseService.getUserId();
    debugPrint('🔄 [HomeScreen] _syncScheda called. userId from Hive: $userId');

    if (userId == null) {
      debugPrint('❌ [HomeScreen] userId is NULL. Showing error snackbar.');
      _showErrorSnackBar(
        'Nessun account trovato. Effettua il login o riavvia l\'app.',
      );
      return;
    }

    // Mostra l'indicatore di caricamento nella AppBar
    setState(() => _isSyncing = true);

    try {
      // Chiamata REST al backend FastAPI usando l'ID numerico
      final response = await ApiService.getPlans(userId);

      // Estrazione del campo "plan" dalla risposta del backend.
      // Il backend restituisce: { "plan": { "titolo": "...", "giorni": [...] } }
      // NOTA: la chiave è "plan", NON "plan_json".
      final rawPlanJson = response['plan'];

      // ── DEBUG ─────────────────────────────────────────────────────────────
      print('[HomeScreen] rawPlanJson runtimeType: ${rawPlanJson?.runtimeType}');
      // ─────────────────────────────────────────────────────────────

      if (rawPlanJson == null) {
        // Il server ha risposto ma senza scheda: l'utente non ha ancora
        // un piano assegnato dal trainer.
        _showInfoSnackBar('Nessuna scheda disponibile. Contatta il tuo trainer.');
        return;
      }

      // ── Decodifica difensiva ──────────────────────────────────────────────
      // Caso 1: plan_json è già una Map (backend lo ha serializzato come JSON annidato)
      // Caso 2: plan_json è una String (backend lo ha salvato come testo e restituito as-is)
      Map<String, dynamic> planMap;
      if (rawPlanJson is Map<String, dynamic>) {
        planMap = rawPlanJson;
      } else if (rawPlanJson is String) {
        // Double-decode: la stringa è essa stessa JSON da parsare
        print('[HomeScreen] plan_json è una String → eseguo jsonDecode');
        planMap = jsonDecode(rawPlanJson) as Map<String, dynamic>;
      } else {
        // Tipo inatteso — stampa e mostra errore
        print('[HomeScreen] plan_json tipo inatteso: ${rawPlanJson.runtimeType} — valore: $rawPlanJson');
        _showErrorSnackBar('Formato scheda non riconosciuto. Contatta il supporto.');
        return;
      }
      // ─────────────────────────────────────────────────────────────

      // Parsing del JSON in modelli Flutter.
      // parseTrainingDaysFromJson accetta la Map completa e ne estrae "giorni".
      final List<TrainingDay> parsedDays =
          DatabaseService.parseTrainingDaysFromJson(planMap);

      // ── DEBUG ─────────────────────────────────────────────────────────────
      print('[HomeScreen] Giorni parsati: ${parsedDays.length}');
      for (final d in parsedDays) {
        print('  └ Giorno: ${d.title} | Esercizi: ${d.exercises.length}');
      }
      // ─────────────────────────────────────────────────────────────

      // Aggiornamento reattivo dell'UI
      setState(() => _days = parsedDays);

      // Feedback positivo all'utente
      _showSuccessSnackBar(
        'Scheda sincronizzata! ${parsedDays.length} giorni caricati.',
      );
    } on ApiException catch (e) {
      // Errore HTTP specifico (es. 401 Unauthorized, 404 Not Found)
      debugPrint('❌ [HomeScreen] ApiException: ${e.statusCode} - ${e.message}');
      _showErrorSnackBar('Errore Server (${e.statusCode}): ${e.message}');
    } catch (e, stack) {
      // Errore di parsing, rete o inatteso
      debugPrint('❌ [HomeScreen] Errore inatteso: $e');
      debugPrint('🥞 [HomeScreen] StackTrace: $stack');
      _showErrorSnackBar('Errore di sistema: $e');
    } finally {
      // Nasconde il loading in ogni caso (successo o errore)
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ----------------------------------------------------------------
  // SnackBar helpers
  // ----------------------------------------------------------------

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blueGrey.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Build
  // ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 10, // Minimal height: il banner è nel body
          actions: [
            // ── Pulsante Sincronizza Scheda ──────────────────────
            // Visibile solo quando la chiamata non è già in corso
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 4.0),
              child: _isSyncing
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppTheme.cyan),
                        ),
                      ),
                    )
                  : IconButton(
                      // Pulsante principale di sincronizzazione scheda
                      icon: const Icon(Icons.cloud_sync, color: AppTheme.cyan),
                      tooltip: 'Sincronizza Scheda',
                      onPressed: _syncScheda,
                    ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Banner "FORGE FIT" ───────────────────────────
              Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppTheme.cyan, AppTheme.vividPurple],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds),
                  child: Text(
                    'FORGE FIT',
                    style: GoogleFonts.orbitron(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: Colors.white, // Richiesto da ShaderMask
                      shadows: [
                        Shadow(
                          color: AppTheme.cyan.withOpacity(0.5),
                          blurRadius: 15,
                        ),
                        Shadow(
                          color: AppTheme.vividPurple.withOpacity(0.5),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 800.ms).scale(
                      begin: const Offset(0.9, 0.9),
                    ),
              ),

              const SizedBox(height: 32),

              const Text(
                'La tua Settimana',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ).animate().fade(duration: 500.ms).slideX(begin: -0.1, end: 0),

              const SizedBox(height: 24),

              // ── Lista giorni o placeholder ───────────────────────
              Expanded(
                child: _days.isEmpty
                    ? _buildEmptyState()   // Nessuna scheda caricata
                    : _buildDaysList(),    // Lista giorni di allenamento
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Stato vuoto — mostrato finché non si sincronizza la scheda
  // ----------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: AppTheme.glassContainer(
        padding: const EdgeInsets.all(32),
        borderColor: AppTheme.cyan.withOpacity(0.3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icona cloud animata
            Icon(
              Icons.cloud_download_outlined,
              size: 72,
              color: AppTheme.cyan.withOpacity(0.7),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(end: 1.1, duration: 1500.ms, curve: Curves.easeInOut),

            const SizedBox(height: 24),

            const Text(
              'Scheda non caricata',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Premi l\'icona  ☁↓  in alto a destra\n'
              'per scaricare la scheda dal tuo trainer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 24),

            // Bottone alternativo per avviare la sync
            OutlinedButton.icon(
              onPressed: _isSyncing ? null : _syncScheda,
              icon: const Icon(Icons.cloud_sync, color: AppTheme.cyan),
              label: const Text(
                'Sincronizza Scheda',
                style: TextStyle(color: AppTheme.cyan),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.cyan),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ).animate().fade(duration: 600.ms).slideY(begin: 0.1, end: 0),
    );
  }

  // ----------------------------------------------------------------
  // Lista giorni di allenamento
  // ----------------------------------------------------------------
  Widget _buildDaysList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _days.length,
      itemBuilder: (context, index) {
        final day = _days[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: _buildDayCard(day),
        ).animate().fade(
              delay: (150 * index).ms,
              duration: 600.ms,
            ).slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuart);
      },
    );
  }

  // ----------------------------------------------------------------
  // Card singolo giorno di allenamento
  // ----------------------------------------------------------------
  Widget _buildDayCard(TrainingDay day) {
    final accentColor = AppTheme.getAccentForDay(day.id);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DayDetailScreen(day: day),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: AppTheme.glassContainer(
        borderColor: accentColor.withOpacity(0.5),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icona del tipo di allenamento
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Icon(
                    _getIconForDay(day.id),
                    color: accentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Contenuto testuale flessibile
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Titolo giorno (es. PUSH, PULL, LEGS)
                      Text(
                        day.title,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24, // Leggermente ridotto per gestire 2 righe
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          letterSpacing: 1.2,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Sottotitolo (muscoli bersaglio)
                      Text(
                        day.subtitle,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  color: accentColor.withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Priorità / note del trainer
            Text(
              day.priority,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            // Badge con numero di esercizi
            Row(
              children: [
                Icon(Icons.list_alt,
                    size: 14, color: accentColor.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text(
                  '${day.exercises.length} esercizi',
                  style: TextStyle(
                    fontSize: 12,
                    color: accentColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
