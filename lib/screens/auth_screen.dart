/// ============================================================
/// auth_screen.dart
/// Schermata unificata Login / Registrazione con tab switcher.
/// Gestisce JWT, auto-login post-register e navigazione
/// alla MainScreen dopo autenticazione riuscita.
/// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import '../core/auth_service.dart';
import '../data/database_service.dart';
import '../models/user_profile.dart';
import '../models/biometric_record.dart';
import 'main_screen.dart';

class AuthScreen extends StatefulWidget {
  /// Se true, apre direttamente il tab "Registrazione"
  final bool startOnRegister;
  const AuthScreen({super.key, this.startOnRegister = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.startOnRegister ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _goToMain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ── Logo / Titolo ─────────────────────────────────────
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.cyan, AppTheme.vividPurple],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(bounds),
                child: Text(
                  'FORGE FIT',
                  style: GoogleFonts.orbitron(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),

              const SizedBox(height: 8),
              const Text(
                'Il tuo personal trainer digitale',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ).animate().fade(delay: 200.ms),

              const SizedBox(height: 32),

              // ── Tab Bar Personalizzata (Sliding Selector) ───────────────────────
              _SlidingTabSelector(
                controller: _tabCtrl,
                onTap: (index) => _tabCtrl.animateTo(index),
              ).animate().fade(delay: 300.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // ── Tab Views ─────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _LoginForm(onSuccess: _goToMain),
                    _RegisterForm(onSuccess: _goToMain),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form Login
// ─────────────────────────────────────────────────────────────────────────────
class _LoginForm extends StatefulWidget {
  final VoidCallback onSuccess;
  const _LoginForm({required this.onSuccess});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey  = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading       = false;
  bool _obscure       = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (mounted) widget.onSuccess();
    } on ApiException catch (e) {
      _showSnackBar(e.message, Colors.red.shade700);
    } catch (e) {
      _showSnackBar('Server non raggiungibile.', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AppTheme.glassContainer(
              padding: const EdgeInsets.all(20),
              borderColor: AppTheme.cyan.withOpacity(0.4),
              child: Column(
                children: [
                  const Icon(Icons.lock_outline, color: AppTheme.cyan, size: 40),
                  const SizedBox(height: 16),
                  _buildField('Email', _emailCtrl, TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email obbligatoria';
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v))
                          return 'Email non valida';
                        return null;
                      }),
                  const SizedBox(height: 12),
                  _buildField('Password', _passwordCtrl, TextInputType.visiblePassword,
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Password obbligatoria' : null),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
                          : const Text('ACCEDI',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    TextInputType type, {
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.cyan)),
      ),
      validator: validator,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form Registrazione
// ─────────────────────────────────────────────────────────────────────────────
class _RegisterForm extends StatefulWidget {
  final VoidCallback onSuccess;
  const _RegisterForm({required this.onSuccess});

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _formKey        = GlobalKey<FormState>();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  final _nomeCtrl       = TextEditingController();
  final _cognomeCtrl    = TextEditingController();
  final _altezzaCtrl    = TextEditingController();
  final _pesoCtrl       = TextEditingController();
  final _bicipiteCtrl   = TextEditingController();
  final _pettoCtrl      = TextEditingController();
  final _vitaCtrl       = TextEditingController();
  final _cosciaCtrl     = TextEditingController();
  final _addomeCtrl     = TextEditingController();

  DateTime? _selectedDate;
  String?   _sesso;
  bool _loading  = false;
  bool _obscure  = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    for (final c in [
      _emailCtrl, _passwordCtrl, _confirmCtrl, _nomeCtrl, _cognomeCtrl,
      _altezzaCtrl, _pesoCtrl, _bicipiteCtrl, _pettoCtrl,
      _vitaCtrl, _cosciaCtrl, _addomeCtrl,
    ]) {
      c.dispose();
    }
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
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  int _age(DateTime dob) {
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) age--;
    return age;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnackBar('Seleziona la data di nascita', Colors.orange);
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      _showSnackBar('Le password non coincidono', Colors.orange);
      return;
    }

    setState(() => _loading = true);
    try {
      final payload = {
        'email':    _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'nome':     _nomeCtrl.text.trim(),
        'cognome':  _cognomeCtrl.text.trim(),
        'eta':      _age(_selectedDate!),
        'sesso':    _sesso,
        'peso':     double.tryParse(_pesoCtrl.text)     ?? 0.0,
        'altezza':  double.tryParse(_altezzaCtrl.text)  ?? 0.0,
        'bicipite': double.tryParse(_bicipiteCtrl.text) ?? 0.0,
        'petto':    double.tryParse(_pettoCtrl.text)    ?? 0.0,
        'vita':     double.tryParse(_vitaCtrl.text)     ?? 0.0,
        'coscia':   double.tryParse(_cosciaCtrl.text)   ?? 0.0,
        'addome':   double.tryParse(_addomeCtrl.text)   ?? 0.0,
      };

      await ApiService.register(payload);

      // Salva profilo locale
      await DatabaseService.saveUserEmail(_emailCtrl.text.trim());
      await DatabaseService.saveUserProfile(UserProfile(
        name: '${_nomeCtrl.text.trim()} ${_cognomeCtrl.text.trim()}',
        dateOfBirth: _selectedDate!,
        height: double.tryParse(_altezzaCtrl.text) ?? 0.0,
        sesso: _sesso,
      ));
      await DatabaseService.saveBiometricRecord(BiometricRecord(
        date:    DateTime.now(),
        weight:  double.tryParse(_pesoCtrl.text)     ?? 0.0,
        abdomen: double.tryParse(_addomeCtrl.text)   ?? 0.0,
        biceps:  double.tryParse(_bicipiteCtrl.text) ?? 0.0,
        chest:   double.tryParse(_pettoCtrl.text)    ?? 0.0,
      ));

      if (mounted) widget.onSuccess();
    } on ApiException catch (e) {
      _showSnackBar(e.message, Colors.red.shade700);
    } catch (e) {
      _showSnackBar('Server non raggiungibile.', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Sezione Account ───────────────────────────────────
            _section('Account', AppTheme.cyan, Icons.manage_accounts, [
              _field('Email', _emailCtrl, TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email obbligatoria';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v))
                      return 'Email non valida';
                    return null;
                  }),
              const SizedBox(height: 12),
              _field('Password', _passwordCtrl, TextInputType.visiblePassword,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.textSecondary, size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Minimo 6 caratteri' : null),
              const SizedBox(height: 12),
              _field('Conferma Password', _confirmCtrl, TextInputType.visiblePassword,
                  obscure: _obscure2,
                  suffix: IconButton(
                    icon: Icon(
                        _obscure2 ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.textSecondary, size: 18),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                  validator: (v) => (v != _passwordCtrl.text)
                      ? 'Le password non coincidono' : null),
            ]),

            const SizedBox(height: 16),

            // ── Sezione Anagrafica ────────────────────────────────
            _section('Dati Anagrafici', AppTheme.vividPurple, Icons.person, [
              _field('Nome', _nomeCtrl, TextInputType.name),
              const SizedBox(height: 12),
              _field('Cognome', _cognomeCtrl, TextInputType.name),
              const SizedBox(height: 12),

              // Sesso
              const Text('Sesso',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _sessoBtn('M', '♂', 'Maschio', AppTheme.cyan)),
                  const SizedBox(width: 10),
                  Expanded(child: _sessoBtn('F', '♀', 'Femmina', AppTheme.vividPurple)),
                ],
              ),
              const SizedBox(height: 12),

              // Data di nascita
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
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
                          color: _selectedDate == null
                              ? AppTheme.textSecondary : Colors.white,
                        ),
                      ),
                      const Icon(Icons.calendar_today,
                          color: AppTheme.textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _field('Altezza (cm)', _altezzaCtrl, TextInputType.number,
                  required: false),
            ]),

            const SizedBox(height: 16),

            // ── Sezione Misurazioni ───────────────────────────────
            _section('Misurazioni Iniziali', AppTheme.legsAccent, Icons.monitor_weight, [
              _field('Peso (kg) *', _pesoCtrl, TextInputType.number),
              const SizedBox(height: 12),
              _field('Circ. Addome (cm)', _addomeCtrl, TextInputType.number,
                  required: false),
              const SizedBox(height: 12),
              _field('Circ. Bicipite (cm)', _bicipiteCtrl, TextInputType.number,
                  required: false),
              const SizedBox(height: 12),
              _field('Circ. Petto (cm)', _pettoCtrl, TextInputType.number,
                  required: false),
              const SizedBox(height: 12),
              _field('Circ. Vita (cm)', _vitaCtrl, TextInputType.number,
                  required: false),
              const SizedBox(height: 12),
              _field('Circ. Coscia (cm)', _cosciaCtrl, TextInputType.number,
                  required: false),
            ]),

            const SizedBox(height: 24),

            // ── Pulsante Registrati ───────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.vividPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('CREA ACCOUNT',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sezione container glassmorphic ────────────────────────────────────────
  Widget _section(String title, Color color, IconData icon, List<Widget> children) {
    return AppTheme.glassContainer(
      padding: const EdgeInsets.all(16),
      borderColor: color.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // ── Campo testo ───────────────────────────────────────────────────────────
  Widget _field(
    String label,
    TextEditingController ctrl,
    TextInputType type, {
    bool required = true,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      inputFormatters: type == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
          : null,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        suffixIcon: suffix,
        isDense: true,
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.cyan)),
      ),
      validator: validator ??
          (required
              ? (v) => (v == null || v.isEmpty) ? 'Campo obbligatorio' : null
              : null),
    );
  }

  // ── Toggle sesso ──────────────────────────────────────────────────────────
  Widget _sessoBtn(String value, String symbol, String label, Color color) {
    final bool selected = _sesso == value;
    return GestureDetector(
      onTap: () => setState(() => _sesso = selected ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : Colors.white12,
              width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(symbol,
                style: TextStyle(
                    fontSize: 24,
                    color: selected ? color : AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? color : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Sliding Tab Selector (Modern Cyberpunk UI)
// ─────────────────────────────────────────────────────────────────────────────
class _SlidingTabSelector extends StatefulWidget {
  final TabController controller;
  final ValueChanged<int> onTap;

  const _SlidingTabSelector({
    required this.controller,
    required this.onTap,
  });

  @override
  State<_SlidingTabSelector> createState() => _SlidingTabSelectorState();
}

class _SlidingTabSelectorState extends State<_SlidingTabSelector> {
  @override
  void initState() {
    super.initState();
    // Ascolta i cambi di tab per aggiornare la pillola animata
    widget.controller.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final int index = widget.controller.index;
    const double borderRadius = 30.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          // Pillola animata (Sfondo)
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: index == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00CCFF), Color(0xFFB066FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00CCFF).withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottoni Testo
          Row(
            children: [
              _buildTabButton('ACCEDI', 0, index == 0),
              _buildTabButton('REGISTRATI', 1, index == 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int targetIndex, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onTap(targetIndex),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.1,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

