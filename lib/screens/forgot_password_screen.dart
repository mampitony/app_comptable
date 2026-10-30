// lib/screens/forgot_password_screen.dart
//
// Mot de passe oublié :
//   1. le membre saisit son email -> le serveur lui envoie un code à 6 chiffres ;
//   2. il saisit le code + son nouveau mot de passe -> validé par le serveur.
// Se ferme avec l'email en résultat quand le mot de passe a été modifié.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/password_reset_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _blue = Color(0xFF0163D2);
  static const _dark = Color(0xFF1E293B);

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  bool _showPassword = false;
  int _cooldown = 0;
  Timer? _timer;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!_validEmail(email)) {
      setState(() => _error = "Format d'email invalide.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final result = await PasswordResetService.requestCode(email);
    if (!mounted) return;

    if (result.ok) {
      setState(() {
        _loading = false;
        _codeSent = true;
        _info = 'Un code à 6 chiffres vient d\'être envoyé à cette adresse. '
            'Pensez à vérifier vos spams.';
      });
      _startCooldown();
    } else {
      setState(() {
        _loading = false;
        _error = result.message;
      });
    }
  }

  Future<void> _confirm() async {
    final otp = _otpController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (otp.length != 6) {
      setState(() => _error = 'Saisissez le code à 6 chiffres reçu par email.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final result = await PasswordResetService.confirm(
      email: _emailController.text.trim(),
      otp: otp,
      newPassword: password,
    );
    if (!mounted) return;

    if (result.ok) {
      Navigator.of(context).pop(_emailController.text.trim());
      return;
    }

    var message = result.message;
    if (result.code == 'invalid' && result.remaining != null) {
      message = '$message (${result.remaining} essai(s) restant(s))';
    }
    setState(() {
      _loading = false;
      _error = message;
      if (result.code == 'expired' || result.code == 'too_many') {
        _otpController.clear();
      }
    });
  }

  void _changeEmail() {
    _timer?.cancel();
    setState(() {
      _codeSent = false;
      _cooldown = 0;
      _error = null;
      _info = null;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final small = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: _blue,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'MOT DE PASSE OUBLIÉ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: small ? 17 : 21,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 24 : size.width * 0.2,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _codeSent ? Icons.mark_email_read_outlined : Icons.lock_reset,
                      size: small ? 48 : 60,
                      color: _blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _codeSent ? 'Nouveau mot de passe' : 'Réinitialiser le mot de passe',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: small ? 20 : 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _codeSent
                        ? 'Saisissez le code reçu par email, puis choisissez votre nouveau mot de passe.'
                        : 'Entrez l\'email de votre compte : nous vous enverrons un code de vérification.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  if (_info != null) _banner(_info!, Colors.green),
                  if (_error != null) _banner(_error!, Colors.red),
                  if (!_codeSent) ..._emailStep() else ..._codeStep(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _emailStep() {
    return [
      _field('Email', Icons.email_outlined, _emailController,
          keyboard: TextInputType.emailAddress),
      const SizedBox(height: 24),
      _button('ENVOYER LE CODE', _loading ? null : _sendCode),
    ];
  }

  List<Widget> _codeStep() {
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Code envoyé à ${_emailController.text.trim()}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      TextField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        style: TextStyle(
          fontSize: 26,
          letterSpacing: 10,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: _decoration('Code à 6 chiffres', Icons.pin_outlined),
      ),
      const SizedBox(height: 14),
      _passwordField('Nouveau mot de passe', _passwordController),
      const SizedBox(height: 14),
      _passwordField('Confirmer le mot de passe', _confirmController),
      const SizedBox(height: 24),
      _button('CHANGER LE MOT DE PASSE', _loading ? null : _confirm),
      const SizedBox(height: 12),
      TextButton(
        onPressed: (_loading || _cooldown > 0) ? null : _sendCode,
        child: Text(
          _cooldown > 0 ? 'Renvoyer le code dans ${_cooldown}s' : 'Renvoyer le code',
        ),
      ),
      TextButton(
        onPressed: _loading ? null : _changeEmail,
        child: const Text('Changer d\'adresse email'),
      ),
    ];
  }

  Widget _banner(String text, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _blue),
      suffixIcon: suffix,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _field(
    String label,
    IconData icon,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: TextStyle(
        fontSize: 16,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: _decoration(label, icon),
    );
  }

  Widget _passwordField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: !_showPassword,
      style: TextStyle(
        fontSize: 16,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: _decoration(
        label,
        Icons.lock_outline,
        suffix: IconButton(
          icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
      ),
    );
  }

  Widget _button(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _dark,
          disabledBackgroundColor: _dark.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}
