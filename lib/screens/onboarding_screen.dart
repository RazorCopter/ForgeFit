/// ============================================================
/// onboarding_screen.dart
/// Prima schermata al primo avvio: scelta tra Nuova Registrazione
/// e Accesso con email già registrata sul server.
/// ============================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import '../data/database_service.dart';
import '../models/user_profile.dart';
import '../models/biometric_record.dart';
import 'main_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point: mostra la schermata di scelta del flusso
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _OnboardingFlow { choice, newUser, returning }

class _OnboardingScreenState extends State<OnboardingScreen> {
  _OnboardingFlow _flow = _OnboardingFlow.choice;

  @override
  Widget build(BuildContext context) {
    return switch (_flow) {
      _OnboardingFlow.choice    => _ChoiceView(
          onNewUser:     () => setState(() => _flow = _OnboardingFlow.newUser),
          onReturning:   () => setState(() => _flow = _OnboardingFlow.returning),
        ),
      _OnboardingFlow.newUser   => _NewUserForm(
          onBack: () => setState(() => _flow = _OnboardingFlow.choice),
        ),
      _OnboardingFlow.returning => _ReturningUserForm(
          onBack: () => setState(() => _flow = _OnboardingFlow.choice),
        ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schermata di scelta
// ─────────────────────────────────────────────────────────────────────────────
class _ChoiceView extends StatelessWidget {
  final VoidCallback onNewUser;
  final VoidCallback onReturning;

  const _ChoiceView({required this.onNewUser, required this.onReturning});

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo / icona
                const Icon(Icons.fitness_center, size: 72, color: AppTheme.cyan)
                    .animate()
                    .scale(duration: 600.ms, curve: Curves.easeOutBack),

                const SizedBox(height: 24),

                const Text(
                  'FORGE FIT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ).animate().fade(delay: 200.ms),

                const SizedBox(height: 8),

                const Text(
                  'Il tuo personal trainer digitale',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ).animate().fade(delay: 300.ms),

                const SizedBox(height: 56),

                // ── Nuova Registrazione ───────────────────────────────────
                AppTheme.glassContainer(
                  padding: const EdgeInsets.all(4),
                  borderColor: AppTheme.cyan.withOpacity(0.5),
                  child: ElevatedButton.icon(
                    onPressed: onNewUser,
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text(
                      'Nuova Registrazione',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ).animate().slideY(begin: 0.2, delay: 400.ms),

                const SizedBox(height: 16),

                // ── Già Registrato ────────────────────────────────────────
                AppTheme.glassContainer(
                  padding: const EdgeInsets.all(4),
                  borderColor: AppTheme.vividPurple.withOpacity(0.5),
                  child: ElevatedButton.icon(
                    onPressed: onReturning,
                    icon: const Icon(Icons.login_outlined),
                    label: const Text(
                      'Sono già registrato',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.vividPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ).animate().slideY(begin: 0.2, delay: 500.ms),

                const SizedBox(height: 24),

                const Text(
                  'Hai già effettuato la registrazione con il tuo trainer?\nAccedi con la tua email per recuperare la scheda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ).animate().fade(delay: 600.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flusso 1: Nuova Registrazione (form completo)
// ─────────────────────────────────────────────────────────────────────────────
class _NewUserForm extends StatefulWidget {
  final VoidCallback onBack;
  const _NewUserForm({required this.onBack});

  @override
  State<_NewUserForm> createState() => _NewUserFormState();
}

class _NewUserFormState extends State<_NewUserForm> {
  final _formKey           = GlobalKey<FormState>();
  final _emailController   = TextEditingController();
  final _nomeController    = TextEditingController();
  final _cognomeController = TextEditingController();
  final _altezzaController = TextEditingController();
  final _pesoController    = TextEditingController();
  final _bicipiteController= TextEditingController();
  final _pettoController   = TextEditingController();
  final _vitaController    = TextEditingController();
  final _cosciaController  = TextEditingController();
  final _fianchiController = TextEditingController();
  final _polpaccioController = TextEditingController();
  final _colloController   = TextEditingController();
  final _polsoController   = TextEditingController();

  DateTime? _selectedDate;
  bool _isLoading = false;
  /// 'M' | 'F' | null (non ancora selezionato)
  String? _sesso;

  @override
  void dispose() {
    _emailController.dispose();
    _nomeController.dispose();
    _cognomeController.dispose();
    _altezzaController.dispose();
    _pesoController.dispose();
    _bicipiteController.dispose();
    _pettoController.dispose();
    _vitaController.dispose();
    _cosciaController.dispose();
    _fianchiController.dispose();
    _polpaccioController.dispose();
    _colloController.dispose();
    _polsoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.cyan,
            onPrimary: Colors.black,
            surface: AppTheme.surfaceVariant,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  int _calculateAge(DateTime dob) {
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) age--;
    return age;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnackBar('Seleziona la tua data di nascita', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final payload = {
        'email':    _emailController.text.trim(),
        'nome':     _nomeController.text.trim(),
        'cognome':  _cognomeController.text.trim(),
        'eta':      _calculateAge(_selectedDate!),
        'sesso':    _sesso,          // 'M' | 'F' | null
        'peso':     double.tryParse(_pesoController.text) ?? 0.0,
        'altezza':  double.tryParse(_altezzaController.text) ?? 0.0,
        'bicipite': double.tryParse(_bicipiteController.text) ?? 0.0,
        'petto':    double.tryParse(_pettoController.text) ?? 0.0,
        'vita':     double.tryParse(_vitaController.text) ?? 0.0,
        'coscia':   double.tryParse(_cosciaController.text) ?? 0.0,
        'fianchi':  double.tryParse(_fianchiController.text) ?? 0.0,
        'polpaccio': double.tryParse(_polpaccioController.text) ?? 0.0,
        'collo':    double.tryParse(_colloController.text) ?? 0.0,
        'polso':    double.tryParse(_polsoController.text) ?? 0.0,
      };

      await ApiService.register(payload);

      await DatabaseService.saveUserEmail(_emailController.text.trim());
      await DatabaseService.saveUserProfile(UserProfile(
        name: '${_nomeController.text.trim()} ${_cognomeController.text.trim()}',
        dateOfBirth: _selectedDate!,
        height: double.tryParse(_altezzaController.text) ?? 0.0,
        sesso: _sesso,
      ));
      await DatabaseService.saveBiometricRecord(BiometricRecord(
        date:    DateTime.now(),
        weight:  double.tryParse(_pesoController.text) ?? 0.0,
        hips:    double.tryParse(_fianchiController.text) ?? 0.0,
        biceps:  double.tryParse(_bicipiteController.text) ?? 0.0,
        chest:   double.tryParse(_pettoController.text) ?? 0.0,
        waist:   double.tryParse(_vitaController.text) ?? 0.0,
        thigh:   double.tryParse(_cosciaController.text) ?? 0.0,
        calf:    double.tryParse(_polpaccioController.text) ?? 0.0,
        neck:    double.tryParse(_colloController.text) ?? 0.0,
        wrist:   double.tryParse(_polsoController.text) ?? 0.0,
      ));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } on ApiException catch (e) {
      _showSnackBar('Errore registrazione: ${e.message}', Colors.red.shade700);
    } catch (_) {
      _showSnackBar('Server non raggiungibile. Controlla la connessione.', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 5),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildBackground(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Nuova Registrazione'),
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.person_add, size: 56, color: AppTheme.cyan)
                        .animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 12),
                    const Text(
                      'Inserisci i tuoi dati',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ).animate().fade(delay: 100.ms),
                    const SizedBox(height: 4),
                    const Text(
                      'Il trainer li userà per creare la tua scheda personalizzata.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ).animate().fade(delay: 200.ms),
                    const SizedBox(height: 24),

                     // ── Dati anagrafici ───────────────────────────────
                    AppTheme.glassContainer(
                      padding: const EdgeInsets.all(16),
                      borderColor: AppTheme.vividPurple.withOpacity(0.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dati Anagrafici',
                              style: TextStyle(color: AppTheme.vividPurple, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          _buildField('Email', _emailController, TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Email obbligatoria';
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Email non valida';
                                return null;
                              }),
                          const SizedBox(height: 12),
                          _buildField('Nome', _nomeController, TextInputType.name),
                          const SizedBox(height: 12),
                          _buildField('Cognome', _cognomeController, TextInputType.name),
                          const SizedBox(height: 12),

                          // ── Selezione Sesso ────────────────────────────
                          const Text('Sesso',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildSessoBtn('M', '♂', 'Maschio', AppTheme.cyan)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildSessoBtn('F', '♀', 'Femmina', AppTheme.vividPurple)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Date picker
                          GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedDate == null
                                        ? 'Data di nascita'
                                        : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                                            '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                                            '${_selectedDate!.year}',
                                    style: TextStyle(
                                      color: _selectedDate == null ? AppTheme.textSecondary : Colors.white,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today, color: AppTheme.textSecondary, size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildField('Altezza (cm)', _altezzaController, TextInputType.number, required: false),
                        ],
                      ),
                    ).animate().slideY(begin: 0.1, delay: 300.ms),

                    const SizedBox(height: 16),

                    // ── Misurazioni ───────────────────────────────────
                    AppTheme.glassContainer(
                      padding: const EdgeInsets.all(16),
                      borderColor: AppTheme.cyan.withOpacity(0.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Misurazioni Iniziali',
                              style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          const Text('I campi * sono obbligatori.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          const SizedBox(height: 16),
                          _buildField('Peso (kg) *', _pesoController, TextInputType.number),
                          const SizedBox(height: 12),
                          _buildField('Circ. Fianchi (cm)', _fianchiController, TextInputType.number,
                              required: false,
                              tooltip: "Punto di massima sporgenza dei glutei."),
                          const SizedBox(height: 12),
                          _buildField('Circ. Vita (cm)', _vitaController, TextInputType.number,
                              required: false,
                              tooltip: "Punto più stretto del busto."),
                          const SizedBox(height: 12),
                          _buildField('Circ. Polpaccio (cm)', _polpaccioController, TextInputType.number,
                              required: false,
                              tooltip: "Punto più largo del polpaccio."),
                          const SizedBox(height: 12),
                          _buildField('Circ. Bicipite (cm)', _bicipiteController, TextInputType.number, required: false),
                          const SizedBox(height: 12),
                          _buildField('Circ. Petto (cm)', _pettoController, TextInputType.number, required: false),
                          const SizedBox(height: 12),
                          _buildField('Circ. Coscia (cm)', _cosciaController, TextInputType.number, required: false),
                          const SizedBox(height: 12),
                          _buildField('Circ. Collo (cm)', _colloController, TextInputType.number, 
                              required: false, 
                              tooltip: "Sotto il pomo di Adamo, orizzontale."),
                          const SizedBox(height: 12),
                          _buildField('Circ. Polso (cm)', _polsoController, TextInputType.number, 
                              required: false, 
                              tooltip: "Nel punto più stretto tra mano e avambraccio."),
                        ],
                      ),
                    ).animate().slideY(begin: 0.1, delay: 400.ms),

                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cyan,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: AppTheme.cyan.withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Registrati'),
                    ).animate().scale(delay: 500.ms),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyan),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 20),
                    Text('Registrazione in corso...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    TextInputType type, {
    bool required = true,
    String? tooltip,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: type,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.cyan)),
                ),
                validator: validator ?? (required ? (v) => (v == null || v.isEmpty) ? 'Campo obbligatorio' : null : null),
              ),
            ),
            if (tooltip != null)
              IconButton(
                icon: const Icon(Icons.info_outline, color: AppTheme.cyan, size: 18),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tooltip),
                    backgroundColor: AppTheme.surfaceVariant,
                    behavior: SnackBarBehavior.floating,
                  ));
                },
              ),
          ],
        ),
      ],
    );
  }

  /// Pulsante di selezione sesso con icona simbolo e feedback visivo.
  Widget _buildSessoBtn(String value, String symbol, String label, Color color) {
    final bool isSelected = _sesso == value;
    return GestureDetector(
      onTap: () => setState(() => _sesso = isSelected ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.18) : Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              symbol,
              style: TextStyle(
                fontSize: 28,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flusso 2: Già Registrato — solo email, verifica sul server
// ─────────────────────────────────────────────────────────────────────────────
class _ReturningUserForm extends StatefulWidget {
  final VoidCallback onBack;
  const _ReturningUserForm({required this.onBack});

  @override
  State<_ReturningUserForm> createState() => _ReturningUserFormState();
}

class _ReturningUserFormState extends State<_ReturningUserForm> {
  final _formKey         = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading        = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _accedi() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();

      // Verifica che l'utente esista sul server recuperando la scheda
      final response = await ApiService.getPlans(email);

      // Salva l'email localmente — è sufficiente per agganciare la scheda
      await DatabaseService.saveUserEmail(email);

      // Crea un profilo minimale locale basato sul nome restituito dal server
      // (se disponibile), altrimenti usa l'email come placeholder
      final serverName = response['nome'] as String? ??
          response['name'] as String? ??
          email;
      await DatabaseService.saveUserProfile(UserProfile(
        name:        serverName,
        dateOfBirth: DateTime(1990), // placeholder: non noto localmente
        height:      0,
      ));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } on ApiException catch (e) {
      final msg = e.statusCode == 404
          ? 'Nessun account trovato per questa email.\nVerifica o effettua una nuova registrazione.'
          : 'Errore del server: ${e.message}';
      _showSnackBar(msg, Colors.red.shade700);
    } catch (_) {
      _showSnackBar('Server non raggiungibile. Controlla la connessione.', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildBackground(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Accesso'),
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
            ),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.login, size: 64, color: AppTheme.vividPurple)
                          .animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

                      const SizedBox(height: 20),

                      const Text(
                        'Bentornato!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      ).animate().fade(delay: 200.ms),

                      const SizedBox(height: 8),

                      const Text(
                        'Inserisci la tua email per recuperare\nla scheda dal server.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ).animate().fade(delay: 300.ms),

                      const SizedBox(height: 40),

                      AppTheme.glassContainer(
                        padding: const EdgeInsets.all(24),
                        borderColor: AppTheme.vividPurple.withOpacity(0.5),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofocus: true,
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                              decoration: InputDecoration(
                                labelText: 'La tua Email',
                                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                                prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.vividPurple),
                                filled: true,
                                fillColor: Colors.black26,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.white12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppTheme.vividPurple, width: 2),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Email obbligatoria';
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Email non valida';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _accedi,
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text(
                                  'Accedi',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.vividPurple,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppTheme.vividPurple.withOpacity(0.4),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().slideY(begin: 0.15, delay: 400.ms),

                      const SizedBox(height: 24),

                      TextButton(
                        onPressed: widget.onBack,
                        child: const Text(
                          'Non hai un account? Registrati',
                          style: TextStyle(color: AppTheme.cyan),
                        ),
                      ).animate().fade(delay: 500.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.vividPurple),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Recupero scheda in corso...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _emailController.text,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
