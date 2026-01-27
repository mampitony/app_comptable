import 'package:flutter/material.dart';
import '../database/user_repository.dart';

class AuthScreen extends StatefulWidget {
  final String userType;
  final void Function(Map<String, dynamic> user) onLoginAsAdmin;
  final void Function(Map<String, dynamic> user) onLoginAsUser;

  const AuthScreen({
    super.key,
    required this.userType,
    required this.onLoginAsAdmin,
    required this.onLoginAsUser,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _userRepo = UserRepository();
  bool isLogin = true;

  // Rétablissement des contrôleurs pour la logique
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _adminKeyController = TextEditingController();

  bool _showPassword = false;

  // --- LOGIQUE DE VALIDATION ---
  bool validateEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // --- LOGIQUE DE CONNEXION (RÉPARÉE) ---
  Future<void> handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showAlert('Erreur', 'Veuillez remplir tous les champs');
      return;
    }

    try {
      final user = await _userRepo.getUserByEmail(email);
      if (!mounted) return;
      if (user == null) {
        _showAlert('Erreur', 'Utilisateur non trouvé');
        return;
      }

      final hash = _userRepo.hashPassword(password, user['salt'] as String);
      if (hash != user['passwordHash']) {
        _showAlert('Erreur', 'Mot de passe incorrect');
        return;
      }

      // Redirection selon le type
      if (widget.userType == 'admin') {
        if (user['role'] != 'admin') {
          _showAlert('Erreur', "Accès refusé. Vous n'êtes pas administrateur.");
          return;
        }
        widget.onLoginAsAdmin({
          'prenom': user['prenom'],
          'profileImage': user['profileImage'],
        });
      } else {
        widget.onLoginAsUser({
          'id': user['id'],
          'name': user['name'],
          'email': user['email'],
          'role': user['role'],
        });
      }
    } catch (e) {
      _showAlert('Erreur', e.toString());
    }
  }

  // --- LOGIQUE DE CRÉATION DE COMPTE (RÉPARÉE) ---
  Future<void> handleSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final adminKey = _adminKeyController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showAlert('Erreur', 'Veuillez remplir tous les champs');
      return;
    }

    if (!validateEmail(email)) {
      _showAlert('Erreur', "Format d'email invalide");
      return;
    }

    if (password != confirmPassword) {
      _showAlert('Erreur', 'Les mots de passe ne correspondent pas');
      return;
    }

    try {
      if (widget.userType == 'admin') {
        if (adminKey != 'ADMIN123') {
          _showAlert('Erreur', 'Code admin incorrect');
          return;
        }
        await _userRepo.addUser(
          name: email,
          email: email,
          password: password,
          role: 'admin',
        );
      } else {
        // Logique utilisateur existant (activation)
        final users = await _userRepo.getAllUsers();
        final member = users.where((u) => u['email'] == email).toList();

        if (member.isEmpty) {
          _showAlert('Erreur', "Email non répertorié par l'admin.");
          return;
        }
        await _userRepo.updateUserPassword(member.first['id'] as int, password);
      }

      _showAlert('Succès', 'Compte configuré ! Connectez-vous.');
      setState(() => isLogin = true);
    } catch (e) {
      _showAlert('Erreur', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              const SizedBox(height: 50),
              _buildHeader(widget.userType == 'admin'),
              const SizedBox(height: 30),
              _buildTabSelector(),
              const SizedBox(height: 30),

              // CHAMPS DE SAISIE
              _buildInputField(_emailController, "Email", Icons.email_outlined),
              const SizedBox(height: 15),

              if (!isLogin && widget.userType == 'admin') ...[
                _buildInputField(
                  _adminKeyController,
                  "Code Admin Secret",
                  Icons.vpn_key_outlined,
                ),
                const SizedBox(height: 15),
              ],

              _buildInputField(
                _passwordController,
                isLogin ? "Mot de passe" : "Nouveau mot de passe",
                Icons.lock_outline,
                isPassword: true,
              ),

              if (!isLogin) ...[
                const SizedBox(height: 15),
                _buildInputField(
                  _confirmPasswordController,
                  "Confirmer le mot de passe",
                  Icons.lock_reset,
                  isPassword: true,
                ),
              ],

              const SizedBox(height: 30),
              _buildPrimaryButton(
                isLogin ? "SE CONNECTER" : "CRÉER LE COMPTE",
                isLogin ? handleLogin : handleSignup,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE STYLE REPRIS DE L'ÉTAPE PRÉCÉDENTE ---
  Widget _buildHeader(bool isAdmin) {
    return Column(
      children: [
        Icon(
          isAdmin ? Icons.admin_panel_settings : Icons.account_circle,
          size: 60,
          color: const Color(0xFF1E293B),
        ),
        const SizedBox(height: 10),
        Text(
          isAdmin ? "ACCÈS ADMIN" : "ACCÈS MEMBRE",
          style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildTabOption(
            "Login",
            isLogin,
            () => setState(() => isLogin = true),
          ),
          _buildTabOption(
            "Signup",
            !isLogin,
            () => setState(() => isLogin = false),
          ),
        ],
      ),
    );
  }

  Widget _buildTabOption(String title, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF00AEEF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: active ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !_showPassword,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF00AEEF)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
