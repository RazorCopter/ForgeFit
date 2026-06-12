/// ============================================================
/// home_screen.dart  (refactored — architettura Client-Server)
/// Dashboard principale dell'app. Mostra i giorni di allenamento
/// scaricati dal backend. All'avvio la lista è VUOTA: l'utente
/// deve premere il pulsante "Sincronizza Scheda" per scaricare
/// il proprio piano dal server REST.
/// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/training_data.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import '../core/connectivity_service.dart';
import '../core/sync_service.dart';
import '../data/database_service.dart';
import '../services/plan_service.dart';
import 'day_detail_screen.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TrainingDay> _days = [];
  List<Map<String, dynamic>> _planHistory = [];
  int? _selectedHistoryId;

  /// true mentre è in corso la chiamata GET /api/plans/{user_id}
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    // Carica la scheda dalla cache locale (se disponibile) senza attendere la sync
    final cached = DatabaseService.loadCachedPlan();
    if (cached != null && cached.isNotEmpty) {
      _days = cached;
    }
    _autoSyncIfStale();
  }

  Future<void> _autoSyncIfStale() async {
    final userId = DatabaseService.getUserId();
    if (userId == null) return;
    final lastSync = DatabaseService.getLastSyncTimestamp();
    final isStale = lastSync == null ||
        DateTime.now().difference(lastSync).inHours >= 4;
    if (isStale) {
      await _syncScheda(silent: true);
    } else {
      // Se non fa _syncScheda, proviamo comunque a caricare la history silently
      try {
        final hist = await PlanService.fetchPlanHistory(userId);
        if (mounted) setState(() => _planHistory = hist);
      } catch (_) {}
    }
  }

  // ----------------------------------------------------------------
  // Icona contestuale al tipo di giorno
  // ----------------------------------------------------------------
  IconData _getIconForDay(String dayId) {
    final lower = dayId.toLowerCase();
    if (lower.contains('petto') || lower.contains('chest') || lower.contains('push')) {
      return Icons.fitness_center;
    }
    if (lower.contains('schiena') || lower.contains('back') || lower.contains('pull') || lower.contains('dorsali')) {
      return Icons.accessibility_new;
    }
    if (lower.contains('gambe') || lower.contains('legs') || lower.contains('coscia') || lower.contains('quadricipiti')) {
      return Icons.directions_run;
    }
    if (lower.contains('spalle') || lower.contains('shoulder')) {
      return Icons.sports_handball;
    }
    if (lower.contains('braccia') || lower.contains('bicipiti') || lower.contains('tricipiti') || lower.contains('arms')) {
      return Icons.sports_martial_arts;
    }
    if (lower.contains('full') || lower.contains('corpo') || lower.contains('total')) {
      return Icons.self_improvement;
    }
    if (lower.contains('cardio') || lower.contains('hiit') || lower.contains('corsa')) {
      return Icons.directions_run;
    }
    if (lower.contains('riposo') || lower.contains('rest') || lower.contains('recupero')) {
      return Icons.hotel;
    }
    // fallback per ID legacy (d1..d4)
    switch (dayId) {
      case 'd1': return Icons.fitness_center;
      case 'd2': return Icons.accessibility_new;
      case 'd3': return Icons.directions_run;
      case 'd4': return Icons.home;
      default:   return Icons.sports_gymnastics;
    }
  }

  // ----------------------------------------------------------------
  // Selezione di una scheda storica
  // ----------------------------------------------------------------
  void _selectHistory(int? histId) {
    if (histId == null) {
      // Ritorna alla corrente dalla cache / sync
      final cached = DatabaseService.loadCachedPlan();
      setState(() {
        _selectedHistoryId = null;
        if (cached != null && cached.isNotEmpty) {
          _days = cached;
        }
      });
      return;
    }

    final histItem = _planHistory.firstWhere((e) => e['id'] == histId, orElse: () => {});
    if (histItem.isNotEmpty) {
      final planData = histItem['plan'] as Map<String, dynamic>?;
      if (planData != null) {
        final parsed = DatabaseService.parseTrainingDaysFromJson(planData);
        setState(() {
          _selectedHistoryId = histId;
          _days = parsed;
        });
      }
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
  Future<void> _syncScheda({bool silent = false}) async {
    // Recupera l'ID utente: è necessario per la chiamata REST
    final userId = DatabaseService.getUserId();
    if (kDebugMode) debugPrint('🔄 [HomeScreen] _syncScheda called. userId from Hive: $userId');

    if (userId == null) {
      if (kDebugMode) debugPrint('❌ [HomeScreen] userId is NULL.');
      if (!silent) _showErrorSnackBar('Nessun account trovato. Effettua il login o riavvia l\'app.');
      return;
    }

    // Mostra l'indicatore di caricamento nella AppBar
    setState(() => _isSyncing = true);

    try {
      final List<TrainingDay> parsedDays = await PlanService.syncPlan(userId);
      await DatabaseService.saveLastSyncTimestamp();
      
      try {
        final hist = await PlanService.fetchPlanHistory(userId);
        if (mounted) setState(() => _planHistory = hist);
      } catch (e) {
        debugPrint('Errore fetch history: $e');
      }

      setState(() {
         _days = parsedDays;
         _selectedHistoryId = null;
      });
      if (!silent) _showSuccessSnackBar('Scheda sincronizzata! ${parsedDays.length} giorni caricati.');
    } on ApiException catch (e) {
      if (!silent) _showErrorSnackBar('Errore Server (${e.statusCode}): ${e.message}');
    } catch (e) {
      if (e.toString().contains('no_plan')) {
        if (!silent) _showInfoSnackBar('Nessuna scheda disponibile. Contatta il tuo trainer.');
      } else {
        if (!silent) _showErrorSnackBar('Errore di sistema: $e');
      }
    } finally {
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
  // Formatting Last Sync
  // ----------------------------------------------------------------
  String _formatLastSync() {
    final lastSync = DatabaseService.getLastSyncTimestamp();
    if (lastSync == null) return 'Mai';
    final now = DateTime.now();
    final diff = now.difference(lastSync);
    if (diff.inMinutes < 1) return 'Pochi istanti fa';
    if (diff.inHours < 1) return '${diff.inMinutes} min fa';
    if (diff.inDays < 1) return '${diff.inHours} ore fa';
    return '${lastSync.day.toString().padLeft(2, '0')}/${lastSync.month.toString().padLeft(2, '0')} ${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}';
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
              // ── Banner "FORGE FIT" + indicatore server ───────
              // ── Banner "FORGE FIT" ───────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ShaderMask(
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
                        color: Colors.white,
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
                  ),
                ],
              ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.9, 0.9)),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'La tua Settimana',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ).animate().fade(duration: 500.ms).slideX(begin: -0.1, end: 0),
                  ValueListenableBuilder<bool>(
                    valueListenable: ConnectivityService.isOnline,
                    builder: (context, online, _) {
                      return ValueListenableBuilder(
                        valueListenable: DatabaseService.workoutBoxListenable(),
                        builder: (context, _, __) {
                          final pending = DatabaseService.getUnsyncedWorkouts().length;
                          final Color statusColor;
                          final IconData statusIcon;
                          final String statusTooltip;
                          final bool canForceSync = online && pending > 0;

                          if (!online) {
                            statusColor = Colors.redAccent;
                            statusIcon = Icons.wifi_off_rounded;
                            statusTooltip = 'Offline';
                          } else if (pending > 0) {
                            statusColor = Colors.orange;
                            statusIcon = Icons.cloud_upload_rounded;
                            statusTooltip = '$pending allenament${pending == 1 ? 'o' : 'i'} da sincronizzare — tocca per sync';
                          } else {
                            statusColor = Colors.greenAccent;
                            statusIcon = Icons.wifi_rounded;
                            statusTooltip = 'Online — tutto sincronizzato';
                          }

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Sinc: ${_formatLastSync()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ).animate().fade(delay: 300.ms),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: statusTooltip,
                                child: GestureDetector(
                                  onTap: canForceSync
                                      ? () async {
                                          await SyncService.syncAllPendingData();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Sincronizzazione completata'),
                                                backgroundColor: Colors.green,
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        }
                                      : null,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: statusColor.withOpacity(0.5), width: 1.5),
                                      boxShadow: [
                                        BoxShadow(color: statusColor.withOpacity(0.3), blurRadius: 8),
                                      ],
                                    ),
                                    child: Icon(statusIcon, color: statusColor, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),
              
              // Dropdown Storico Schede
              if (_planHistory.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cyan.withOpacity(0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedHistoryId,
                        icon: const Icon(Icons.history, color: AppTheme.cyan, size: 20),
                        dropdownColor: AppTheme.surfaceVariant,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Corrente / Attiva'),
                          ),
                          ..._planHistory.map((hist) {
                            final ver = hist['version'];
                            final rawDate = hist['created_at'];
                            final label = hist['label'];
                            String dateStr = '';
                            if (rawDate != null) {
                              try {
                                final d = DateTime.parse(rawDate).toLocal();
                                dateStr = '${d.day}/${d.month}/${d.year}';
                              } catch (_) {}
                            }
                            final text = 'v$ver - $dateStr${label != null ? ' ($label)' : ''}';
                            return DropdownMenuItem<int?>(
                              value: hist['id'] as int,
                              child: Text(text),
                            );
                          }),
                        ],
                        onChanged: _selectHistory,
                      ),
                    ),
                  ).animate().fade(duration: 400.ms),
                ),

              const SizedBox(height: 16),

              // ValueListenableBuilder che reagisce agli aggiornamenti dei workout (es. fine sync in background)
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: DatabaseService.workoutBoxListenable(),
                  builder: (context, _, __) {
                    final streak = DatabaseService.getCurrentStreak();
                    Widget streakBanner = const SizedBox.shrink();
                    
                    if (streak >= 2) {
                      // Colori e messaggio adattivi in base alla streak
                      final Color streakColor;
                      final List<Color> streakGradient;
                      final String streakMsg;
                      if (streak >= 14) {
                        streakColor = AppTheme.vividPurple;
                        streakGradient = [AppTheme.vividPurple, AppTheme.cyan];
                        streakMsg = 'Due settimane filate. Leggendario!';
                      } else if (streak >= 7) {
                        streakColor = const Color(0xFFFFD700); // gold
                        streakGradient = [const Color(0xFFFFD700), const Color(0xFFFF8C00)];
                        streakMsg = 'Una settimana intera. Sei inarrestabile!';
                      } else {
                        streakColor = Colors.orangeAccent;
                        streakGradient = [Colors.orangeAccent, Colors.deepOrange];
                        streakMsg = 'Continua così, stai andando alla grande!';
                      }

                      streakBanner = Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              colors: streakGradient
                                  .map((c) => c.withOpacity(0.15))
                                  .toList(),
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            border: Border.all(
                                color: streakColor.withOpacity(0.4), width: 1.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Text(
                                  streak >= 14 ? '⚡' : streak >= 7 ? '🏆' : '🔥',
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (bounds) => LinearGradient(
                                          colors: streakGradient,
                                        ).createShader(bounds),
                                        child: Text(
                                          '$streak giorni di fila!',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        streakMsg,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        streakBanner,
                        Expanded(
                          child: _isSyncing && _days.isEmpty
                              ? _buildShimmerLoading()
                              : _days.isEmpty
                                  ? _buildEmptyState()   // Nessuna scheda caricata
                                  : RefreshIndicator(
                                      onRefresh: () => _syncScheda(silent: true),
                                      color: AppTheme.cyan,
                                      backgroundColor: AppTheme.surface,
                                      child: _buildDaysList(),
                                    ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Shimmer.fromColors(
            baseColor: AppTheme.surfaceVariant,
            highlightColor: AppTheme.surfaceVariant.withOpacity(0.5),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        );
      },
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
    final monthlyDone = DatabaseService.getMonthlyCompletionsForDay(day);
    // Target di riferimento: 4 sessioni/mese (circa 1 a settimana)
    const int monthlyTarget = 4;
    final double ringProgress = (monthlyDone / monthlyTarget).clamp(0.0, 1.0);

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
                      Builder(
                        builder: (context) {
                          String dTitle = day.title;
                          String dSubtitle = day.subtitle;
                          
                          int firstSepIndex = -1;
                          String? usedSep;
                          final separators = [' - ', ' + ', ': '];
                          
                          for (var sep in separators) {
                            int idx = dTitle.indexOf(sep);
                            if (idx != -1 && (firstSepIndex == -1 || idx < firstSepIndex)) {
                              firstSepIndex = idx;
                              usedSep = sep;
                            }
                          }
                          
                          if (firstSepIndex != -1 && usedSep != null) {
                            String leftPart = dTitle.substring(0, firstSepIndex).trim();
                            String rightPart = dTitle.substring(firstSepIndex + usedSep.length).trim();
                            
                            dTitle = leftPart;
                            
                            String normalizedRight = rightPart
                                .replaceAll(' + ', ';')
                                .replaceAll(' - ', ';')
                                .replaceAll(' e ', ';')
                                .replaceAll(',', ';');
                                
                            final bulletList = normalizedRight.split(';')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                                
                            if (bulletList.isNotEmpty) {
                                dSubtitle = bulletList.map((e) => "• $e").join('\n');
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Titolo giorno (es. DAY 1)
                              Text(
                                dTitle,
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: accentColor,
                                  letterSpacing: 1.2,
                                  height: 1.1,
                                ),
                              ),
                              if (dSubtitle.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                // Sottotitolo (muscoli bersaglio in elenco o riga)
                                Text(
                                  dSubtitle,
                                  maxLines: 6,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          );
                        }
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Progress ring mensile
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: ringProgress),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => CircularProgressIndicator(
                          value: value,
                          strokeWidth: 3.5,
                          backgroundColor: accentColor.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ringProgress >= 1.0
                                ? Colors.greenAccent
                                : accentColor,
                          ),
                        ),
                      ),
                      Text(
                        '$monthlyDone',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: ringProgress >= 1.0
                              ? Colors.greenAccent
                              : accentColor,
                        ),
                      ),
                    ],
                  ),
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
