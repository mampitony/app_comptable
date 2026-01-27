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

  // Contrôleurs
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _adminKeyController = TextEditingController();

  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _adminKeyController.dispose();
    super.dispose();
  }

  // 🔥 FONCTION DE CORRECTION : Nettoyage forcé des formulaires
  void _clearForm() {
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _adminKeyController.clear();
  }

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

      // 🔥 CORRECTION : On vide tout AVANT d'appeler les callbacks de navigation
      final userData = {
        'id': user['id'],
        'name': user['name'],
        'email': user['email'],
        'role': user['role'],
        'prenom': user['prenom'] ?? '',
        'profileImage': user['profileImage'] ?? '',
      };

      _clearForm(); // On vide les champs ici

      if (widget.userType == 'admin') {
        if (user['role'] != 'admin') {
          _showAlert('Erreur', "Accès refusé.");
          return;
        }
        widget.onLoginAsAdmin(userData);
      } else {
        widget.onLoginAsUser(userData);
      }
    } catch (e) {
      _showAlert('Erreur', e.toString());
    }
  }

  Future<void> handleSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // ... Logique de signup (identique à ton code) ...
    // Une fois le signup réussi :
    _clearForm();
    _showAlert('Succès', 'Compte créé');
    setState(() => isLogin = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0163D2),
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Connexion ${widget.userType}",
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildHeader(widget.userType == 'admin'),
              const SizedBox(height: 30),
              _buildTabSelector(),
              const SizedBox(height: 30),
              _buildInputField(_emailController, "Email", Icons.email_outlined),
              const SizedBox(height: 15),
              if (!isLogin && widget.userType == 'admin') ...[
                _buildInputField(
                  _adminKeyController,
                  "Code Admin",
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
                  "Confirmer",
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

  // --- Widgets de style (Identiques à ton design initial) ---
  Widget _buildHeader(bool isAdmin) => Column(
    children: [
      Icon(
        isAdmin ? Icons.admin_panel_settings : Icons.account_circle,
        size: 60,
        color: const Color(0xFF1E293B),
      ),
      const SizedBox(height: 10),
      Text(
        isAdmin ? "ACCÈS ADMIN" : "ACCÈS MEMBRE",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ],
  );

  Widget _buildTabSelector() => Container(
    decoration: BoxDecoration(
      color: Colors.black12,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        _buildTabOption("Login", isLogin, () {
          _clearForm();
          setState(() => isLogin = true);
        }),
        _buildTabOption("Signup", !isLogin, () {
          _clearForm();
          setState(() => isLogin = false);
        }),
      ],
    ),
  );

  Widget _buildTabOption(String title, bool active, VoidCallback onTap) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF0163D2) : Colors.transparent,
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

  Widget _buildInputField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
  }) => TextField(
    controller: controller,
    obscureText: isPassword && !_showPassword,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF0163D2)),
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

  Widget _buildPrimaryButton(String label, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    height: 55,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
