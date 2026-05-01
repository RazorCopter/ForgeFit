import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import '../data/database_service.dart';
import '../models/user_profile.dart';
import '../models/biometric_record.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _abdomenController = TextEditingController();
  final TextEditingController _chestController = TextEditingController();
  final TextEditingController _bicepsController = TextEditingController();
  final TextEditingController _vitaController = TextEditingController();
  final TextEditingController _cosciaController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _aiResponse;
  
  bool _isAILocked = true;
  DateTime? _expirationDate;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    _loadLatestBiometrics();
    _checkAILock();
    await _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    // 1. Prova da Hive
    var localProfile = DatabaseService.getUserProfile();
    
    // 2. Se manca o dati parziali, prova dal backend
    if (localProfile == null || localProfile.height == 0) {
      try {
        final userData = await ApiService.getMe();
        // Mappatura dati backend -> UserProfile local
        final int eta = userData['age'] ?? 0;
        final newProfile = UserProfile(
          name: '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'.trim(),
          dateOfBirth: DateTime(DateTime.now().year - eta, 1, 1),
          height: (userData['height'] as num?)?.toDouble() ?? 0.0,
          sesso: userData['gender'] ?? '',
        );
        localProfile = newProfile;
        await DatabaseService.saveUserProfile(newProfile);

        // Popoliamo i controller biometrici con gli ultimi dati dal server (se presenti)
        if (mounted) {
          _weightController.text = (userData['weight'] ?? '').toString();
          _chestController.text = (userData['chest'] ?? '').toString();
          _abdomenController.text = (userData['abdomen'] ?? '').toString();
          _bicepsController.text = (userData['biceps'] ?? '').toString();
          _vitaController.text = (userData['waist'] ?? '').toString();
          _cosciaController.text = (userData['thigh'] ?? '').toString();
        }
      } catch (e) {
        debugPrint('Errore recupero profilo backend: $e');
        // Se Hive è vuoto e API fallisce, creiamo un profilo dummy per sbloccare l'UI
        localProfile ??= UserProfile(
          name: 'Atleta',
          dateOfBirth: DateTime(1990),
          height: 0,
        );
      }
    }

    if (mounted) {
      setState(() => _profile = localProfile);
    }
  }

  int _getIsoWeekNumber(DateTime date) {
    DateTime thursday = DateTime(date.year, date.month, date.day);
    thursday = thursday.add(Duration(days: 4 - thursday.weekday));
    DateTime startOfYear = DateTime(thursday.year, 1, 1);
    int days = thursday.difference(startOfYear).inDays;
    return 1 + (days ~/ 7);
  }

  void _checkAILock() {
    final activationDate = DatabaseService.getAIActivationDate();
    if (activationDate != null) {
      final expiration = activationDate.add(const Duration(days: 90));
      if (DateTime.now().isBefore(expiration)) {
        setState(() {
          _isAILocked = false;
          _expirationDate = expiration;
        });
      } else {
        setState(() {
          _isAILocked = true;
          _expirationDate = null;
        });
      }
    }
  }

  void _unlockAI() {
    final now = DateTime.now();
    final currentWeek = _getIsoWeekNumber(now);
    final expectedPassword = 'forza$currentWeek';

    if (_passwordController.text.trim() == expectedPassword) {
      DatabaseService.saveAIActivationDate(now);
      _checkAILock();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Sbloccata con successo!'), backgroundColor: Colors.green),
      );
      _passwordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password errata o scaduta.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _loadLatestBiometrics() {
    final record = DatabaseService.getLatestBiometricRecord();
    if (record != null) {
      _weightController.text = record.weight.toString();
      _abdomenController.text = record.abdomen.toString();
      _chestController.text = record.chest.toString();
      _bicepsController.text = record.biceps.toString();
      _vitaController.text = record.waist?.toString() ?? '';
      _cosciaController.text = record.thigh?.toString() ?? '';
    }
  }

  /// Task 3: Logica di salvataggio indipendente
  Future<void> _saveProgress() async {
    if (_weightController.text.isEmpty || _abdomenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci almeno Peso e Addome!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final record = BiometricRecord(
        date: DateTime.now(),
        weight: double.tryParse(_weightController.text) ?? 0.0,
        abdomen: double.tryParse(_abdomenController.text) ?? 0.0,
        biceps: double.tryParse(_bicepsController.text) ?? 0.0,
        chest: double.tryParse(_chestController.text) ?? 0.0,
        waist: double.tryParse(_vitaController.text) ?? 0.0,
        thigh: double.tryParse(_cosciaController.text) ?? 0.0,
      );

      // Salva locale (Hive)
      await DatabaseService.saveBiometricRecord(record);

      // Invia al backend (usa chiavi inglesi come da schema MeasurementCreate)
      await ApiService.postMeasurements({
        'weight': record.weight,
        'abdomen': record.abdomen,
        'chest': record.chest,
        'biceps': record.biceps,
        'waist': record.waist,
        'thigh': record.thigh,
        'goal': _goalController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progressi salvati con successo!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il salvataggio: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _generateAIReport() async {
    if (_weightController.text.isEmpty || _goalController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dati insufficienti per l\'analisi AI.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _aiResponse = null;
    });

    try {
      // Chiamata al backend FastAPI che gestisce internamente Gemini
      final response = await ApiService.generateAnalysis();

      setState(() {
        _aiResponse = response['analysis'] ?? 'Nessuna risposta dal modello.';
      });
    } catch (e) {
      setState(() {
        _aiResponse = 'Errore durante la generazione del report: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final age = _profile != null ? DateTime.now().difference(_profile!.dateOfBirth).inDays ~/ 365 : 0;

    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Performance Analysis', style: TextStyle(color: AppTheme.textPrimary)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dati Statici (User Info)
              AppTheme.glassContainer(
                padding: const EdgeInsets.all(20),
                borderColor: AppTheme.vividPurple.withOpacity(0.3),
                child: _profile == null 
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.vividPurple))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.badge, color: AppTheme.vividPurple),
                            const SizedBox(width: 8),
                            Text(
                              _profile?.name ?? 'Utente',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.vividPurple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStaticInfo('Età', '$age anni'),
                            _buildStaticInfo('Altezza', '${_profile?.height.toInt() ?? 0} cm'),
                          ],
                        ),
                      ],
                    ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // Aggiorna Dati Fisiologici
              AppTheme.glassContainer(
                padding: const EdgeInsets.all(20),
                borderColor: AppTheme.cyan.withOpacity(0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monitor_weight, color: AppTheme.cyan),
                        const SizedBox(width: 8),
                        const Text(
                          'Aggiorna Dati Fisiologici',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInput('Obiettivo (es. Forza, Dimagrimento)', _goalController, isNumber: false),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildInput('Peso (kg)', _weightController)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInput('Addome (cm)', _abdomenController)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildInput('Petto (cm)', _chestController)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInput('Bicipite (cm)', _bicepsController)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildInput('Vita (cm)', _vitaController)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInput('Coscia (cm)', _cosciaController)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Task 3: Pulsante Salva Progressi sempre attivo
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveProgress,
                        icon: _isSaving 
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.save_alt),
                        label: Text(_isSaving ? 'Salvataggio...' : 'Salva Progressi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 150.ms, duration: 500.ms).slideY(begin: 0.1),

              const SizedBox(height: 32),

              // AREA AI (Condizionale)
              if (_isAILocked)
                _buildLockSection()
              else
                _buildAISection(),

              const SizedBox(height: 60), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockSection() {
    return AppTheme.glassContainer(
      padding: const EdgeInsets.all(24),
      borderColor: Colors.redAccent.withOpacity(0.5),
      child: Column(
        children: [
          const Icon(Icons.lock, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Funzioni AI Bloccate',
            style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Inserisci la password di attivazione fornita dall'amministratore per sbloccare i report avanzati di Gemini.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Password di Sblocco',
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _unlockAI,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Sblocca Funzioni Pro', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).animate().fadeIn().slideY();
  }

  Widget _buildAISection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_open, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI Sbloccata - Scadenza: ${_expirationDate?.day}/${_expirationDate?.month}/${_expirationDate?.year}',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _isLoading
            ? const CircularProgressIndicator(color: AppTheme.cyan)
            : ElevatedButton.icon(
                onPressed: _generateAIReport,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Genera Report Performance AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.vividPurple.withOpacity(0.2),
                  foregroundColor: AppTheme.vividPurple,
                  side: const BorderSide(color: AppTheme.vividPurple, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds),
        
        if (_aiResponse != null) ...[
          const SizedBox(height: 24),
          AppTheme.glassContainer(
            padding: const EdgeInsets.all(24),
            borderColor: AppTheme.cyan,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt, color: AppTheme.cyan),
                    SizedBox(width: 8),
                    Text('AI FEEDBACK', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(_aiResponse!, style: const TextStyle(color: Colors.white, height: 1.5)),
              ],
            ),
          ).animate().fadeIn().slideY(),
        ],
      ],
    );
  }

  Widget _buildStaticInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInput(String label, TextEditingController controller, {bool isNumber = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
