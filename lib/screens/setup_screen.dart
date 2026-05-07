import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/theme.dart';
import '../core/api_service.dart';
import '../core/auth_service.dart';
import '../data/database_service.dart';
import 'auth_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _isSyncing = false;

  /// Riscarica la scheda dal server e la salva in memoria.
  /// Utile quando il trainer aggiorna il piano dell'utente.
  Future<void> _syncScheda() async {
    final userId = DatabaseService.getUserId();
    if (userId == null) {
      _showSnackBar('Nessun account. Effettua prima il login.', Colors.red.shade700);
      return;
    }
    setState(() => _isSyncing = true);
    try {
      final response = await ApiService.getPlans(userId);
      final rawPlan = response['plan'];
      if (rawPlan == null) {
        _showSnackBar('Nessuna scheda disponibile. Contatta il trainer.', Colors.orange);
        return;
      }
      // Il server può restituire il piano come Map o come stringa JSON
      final planMap = rawPlan is String
          ? jsonDecode(rawPlan) as Map<String, dynamic>
          : rawPlan as Map<String, dynamic>;
      final days = DatabaseService.parseTrainingDaysFromJson(planMap);
      _showSnackBar(
        'Scheda aggiornata! ${days.length} giorni caricati.',
        Colors.green.shade700,
      );
    } on ApiException catch (e) {
      _showSnackBar('Errore dal server: ${e.message}', Colors.red.shade700);
    } catch (_) {
      _showSnackBar('Server non raggiungibile.', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: const Text('Esci dall\'account?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Il token di sessione verrà rimosso. Dovrai ri-effettuare il login.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla',
                style: TextStyle(color: AppTheme.cyan)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Esci',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 4),
    ));
  }

  /// Apre un dialog per cambiare la password dell'account.
  Future<void> _showChangePasswordDialog() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cambia Password', style: TextStyle(color: AppTheme.cyan)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Inserisci le credenziali per aggiornare la tua chiave di accesso.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  _buildDialogField('Password attuale', oldCtrl, true),
                  const SizedBox(height: 12),
                  _buildDialogField('Nuova password', newCtrl, true),
                  const SizedBox(height: 12),
                  _buildDialogField('Conferma nuova password', confirmCtrl, true, 
                    validator: (v) => v != newCtrl.text ? 'Le password non coincidono' : null),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(context),
              child: const Text('Annulla', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: loading ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => loading = true);
                try {
                  await ApiService.changePassword(
                    oldPassword: oldCtrl.text,
                    newPassword: newCtrl.text,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    _showSnackBar('Password aggiornata con successo! Effettua nuovamente il login.', Colors.green.shade700);
                    // Logout forzato per sicurezza
                    await AuthService.logout();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                      (route) => false,
                    );
                  }
                } on ApiException catch (e) {
                  _showSnackBar(e.message, Colors.red.shade700);
                } catch (e) {
                  _showSnackBar('Errore di connessione.', Colors.red.shade700);
                } finally {
                  setDialogState(() => loading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: loading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('Aggiorna'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController ctrl, bool obscure, {String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        filled: true,
        fillColor: Colors.black26,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      validator: validator ?? (v) => (v == null || v.length < 6) ? 'Minimo 6 caratteri' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Setup & Sicurezza', style: TextStyle(color: AppTheme.textPrimary)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ── Sezione Scheda ─────────────────────────────────────────
            const Text(
              'Sincronizzazione',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ).animate().fade().slideY(),
            const SizedBox(height: 8),
            const Text(
              'Scarica l\'ultima versione della tua scheda personalizzata assegnata dal trainer.',
              style: TextStyle(color: AppTheme.textSecondary),
            ).animate().fade(delay: 100.ms).slideY(),
            const SizedBox(height: 16),

            // Pulsante sincronizzazione
            InkWell(
              onTap: _isSyncing ? null : _syncScheda,
              borderRadius: BorderRadius.circular(16),
              child: AppTheme.glassContainer(
                padding: const EdgeInsets.all(20),
                borderColor: AppTheme.cyan.withOpacity(0.6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cyan.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: _isSyncing
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyan),
                              ),
                            )
                          : const Icon(Icons.cloud_sync, color: AppTheme.cyan, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSyncing ? 'Sincronizzazione...' : 'Sincronizza Ora',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cyan,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Aggiorna esercizi e target dal server',
                            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ).animate().fade(delay: 150.ms).slideX(),

            const SizedBox(height: 32),

            // ── Sezione Sicurezza ─────────────────────────────────────────
            const Text(
              'Sicurezza Account',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ).animate().fade(delay: 200.ms).slideY(),
            const SizedBox(height: 8),
            const Text(
              'Gestisci la tua password e la sessione di accesso.',
              style: TextStyle(color: AppTheme.textSecondary),
            ).animate().fade(delay: 250.ms).slideY(),
            const SizedBox(height: 16),

            _buildSetupCard(
              title: 'Cambia Password',
              subtitle: 'Aggiorna la tua chiave di accesso',
              icon: Icons.vpn_key,
              color: AppTheme.vividPurple,
              onTap: _showChangePasswordDialog,
            ).animate().fade(delay: 300.ms).slideX(),
            
            const SizedBox(height: 16),
            
            _buildSetupCard(
              title: 'Esci dall\'Account',
              subtitle: 'Termina la sessione corrente',
              icon: Icons.logout,
              color: Colors.redAccent,
              onTap: _logout,
            ).animate().fade(delay: 400.ms).slideX(),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AppTheme.glassContainer(
        padding: const EdgeInsets.all(20),
        borderColor: color.withOpacity(0.5),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
