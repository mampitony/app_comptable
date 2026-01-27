import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/user_repository.dart';

class AuthScreen extends StatefulWidget {
  final String userType; // 'admin' ou 'user'
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

  // Login
  String loginEmail = '';
  String loginPassword = '';

  // Signup
  String signupEmail = '';
  String signupPassword = '';
  String signupConfirmPassword = '';
  String adminKey = '';

  // visibilité mots de passe
  bool showLoginPassword = false;
  bool showSignupPassword = false;
  bool showConfirmPassword = false;
  bool showAdminKey = false;

  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  bool validateEmail(String email) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  void _showAlert(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF4CAF50)), // Vert
            ),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  Future<void> handleLogin() async {
    if (loginEmail.isEmpty || loginPassword.isEmpty) {
      _showAlert('Erreur', 'Veuillez remplir tous les champs');
      return;
    }

    try {
      final user = await _userRepo.getUserByEmail(loginEmail);
      if (!mounted) return;
      if (user == null) {
        _showAlert('Erreur', 'Utilisateur non trouvé');
        return;
      }

      if (user['passwordHash'] == null ||
          (user['passwordHash'] as String).isEmpty) {
        _showAlert('Erreur',
            "Votre compte n'est pas encore activé. Veuillez vous inscrire d'abord.");
        return;
      }

      final hash =
          _userRepo.hashPassword(loginPassword, user['salt'] as String);
      if (hash != user['passwordHash']) {
        _showAlert('Erreur', 'Mot de passe incorrect');
        return;
      }

      if (widget.userType == 'admin') {
        if (user['role'] != 'admin') {
          _showAlert(
              'Erreur', "Accès refusé. Vous n'êtes pas administrateur.");
          return;
        }
        widget.onLoginAsAdmin({
          'prenom': user['prenom'],
          'profileImage': user['profileImage'],
        });
      } else {
        if (user['role'] == 'admin') {
          _showAlert('Erreur',
              'Les administrateurs doivent utiliser l\'espace Administrateur.');
          return;
        }

        widget.onLoginAsUser({
          'id': user['id'],
          'name': user['name'],
          'prenom': user['prenom'],
          'email': user['email'],
          'profileImage': user['profileImage'],
          'role': user['role'],
        });
      }

      if (!mounted) return;

      setState(() {
        loginEmail = '';
        loginPassword = '';
      });
    } catch (e) {
      if (!mounted) return;
      _showAlert('Erreur de connexion', e.toString());
    }
  }

  Future<void> handleSignup() async {
    final userType = widget.userType;

    if (signupEmail.isEmpty ||
        signupPassword.isEmpty ||
        signupConfirmPassword.isEmpty) {
      _showAlert('Erreur', 'Veuillez remplir tous les champs');
      return;
    }

    if (!validateEmail(signupEmail)) {
      _showAlert('Erreur', "Format d'email invalide. Il doit contenir @ et .");
      return;
    }

    if (signupPassword != signupConfirmPassword) {
      _showAlert('Erreur', 'Les mots de passe ne correspondent pas');
      return;
    }

    if (signupPassword.length < 6) {
      _showAlert('Erreur',
          'Le mot de passe doit contenir au moins 6 caractères');
      return;
    }

    try {
      final allUsers = await _userRepo.getAllUsers();

      if (!mounted) return;

      if (userType == 'admin') {
        if (adminKey.isEmpty) {
          _showAlert('Erreur', 'Veuillez saisir le mot clé administrateur');
          return;
        }

        if (adminKey != 'ADMIN123') {
          _showAlert('Erreur', 'Mot clé administrateur incorrect');
          return;
        }

        final existingAdmin =
            allUsers.where((u) => u['role'] == 'admin').toList();
        if (existingAdmin.isNotEmpty) {
          _showAlert('Erreur',
              'Un compte administrateur existe déjà. Un seul admin est autorisé.');
          return;
        }

        final emailExists =
            allUsers.any((u) => u['email']?.toString() == signupEmail);
        if (emailExists) {
          _showAlert('Erreur', 'Cet email est déjà utilisé.');
          return;
        }

        await _userRepo.addUser(
          name: signupEmail,
          email: signupEmail,
          password: signupPassword,
          role: 'admin',
        );

        _showAlert('Succès',
            'Compte administrateur créé avec succès. Vous pouvez vous connecter.');
      } else {
        final memberExists =
            allUsers.where((u) => u['email']?.toString() == signupEmail).toList();

        if (memberExists.isEmpty) {
          _showAlert(
            'Erreur',
            "Cet email n'existe pas dans la liste des membres. Contactez l'administrateur pour vous inscrire.",
          );
          return;
        }

        final member = memberExists.first;

        if (member['role'] == 'admin') {
          _showAlert('Erreur',
              'Les administrateurs doivent utiliser l\'espace Administrateur.');
          return;
        }

        final passwordHash = member['passwordHash'] as String?;
        if (passwordHash != null && passwordHash.isNotEmpty) {
          _showAlert(
              'Erreur', 'Votre compte est déjà activé. Utilisez la connexion.');
          return;
        }

        await _userRepo.updateUserPassword(
          member['id'] as int,
          signupPassword,
        );

        _showAlert(
          'Succès',
          'Votre compte a été activé avec succès ! Vous pouvez maintenant vous connecter.',
        );
      }

      if (!mounted) return;

      setState(() {
        signupEmail = '';
        signupPassword = '';
        signupConfirmPassword = '';
        adminKey = '';
        isLogin = true;
      });
    } catch (e) {
      if (!mounted) return;
      _showAlert('Erreur', 'Une erreur est survenue : $e');
    }
  }

  // =================== UI ===================

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.userType == 'admin';

    return Scaffold(
      key: _scaffoldMessengerKey,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4CAF50), // Vert
              Color(0xFF06FFF0), // Cyan
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAdmin ? 'Espace Administrateur' : 'Espace Utilisateur',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildAuthCard(isAdmin),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard(bool isAdmin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Welcome',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50), // Vert
            ),
          ),
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFF06FFF0).withOpacity(0.2), // Cyan clair
            child: const Icon(
              Icons.person,
              size: 40,
              color: Color(0xFF4CAF50), // Vert
            ),
          ),
          const SizedBox(height: 24),
          _buildTabsStyled(),
          const SizedBox(height: 16),
          isLogin ? _buildLoginForm() : _buildSignupForm(isAdmin),
        ],
      ),
    );
  }

  Widget _buildTabsStyled() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), // Gris très clair
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isLogin = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isLogin ? const Color(0xFF4CAF50) : Colors.transparent, // Vert
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    'Connexion',
                    style: TextStyle(
                      color: isLogin ? Colors.white : const Color(0xFF666666),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isLogin = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !isLogin ? const Color(0xFF4CAF50) : Colors.transparent, // Vert
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    'Inscription',
                    style: TextStyle(
                      color: !isLogin ? Colors.white : const Color(0xFF666666),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =================== FORMULAIRES ===================

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildLabel('Entrez votre adresse email'),
          _buildTextField(
            value: loginEmail,
            hint: 'Email',
            keyboard: TextInputType.emailAddress,
            onChanged: (v) => setState(() => loginEmail = v),
          ),
          const SizedBox(height: 12),
          _buildLabel('Entrez votre mot de passe'),
          _buildPasswordField(
            value: loginPassword,
            hint: 'Mot de passe',
            obscure: !showLoginPassword,
            onToggle: () =>
                setState(() => showLoginPassword = !showLoginPassword),
            onChanged: (v) => setState(() => loginPassword = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50), // Vert
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 3,
              ),
              onPressed: handleLogin,
              child: const Text(
                'Se connecter',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupForm(bool isAdmin) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildLabel('Votre adresse email'),
          _buildTextField(
            value: signupEmail,
            hint: 'Email *',
            keyboard: TextInputType.emailAddress,
            onChanged: (v) => setState(() => signupEmail = v),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 12),
            _buildLabel("Mot clé d'administrateur"),
            _buildPasswordField(
              value: adminKey,
              hint: 'Mot clé',
              obscure: !showAdminKey,
              onToggle: () => setState(() => showAdminKey = !showAdminKey),
              onChanged: (v) => setState(() => adminKey = v),
            ),
          ],
          const SizedBox(height: 12),
          _buildLabel('Créer un mot de passe'),
          _buildPasswordField(
            value: signupPassword,
            hint: 'Mot de passe (min. 6 caractères) *',
            obscure: !showSignupPassword,
            onToggle: () =>
                setState(() => showSignupPassword = !showSignupPassword),
            onChanged: (v) => setState(() => signupPassword = v),
          ),
          const SizedBox(height: 12),
          _buildLabel('Confirmer votre mot de passe'),
          _buildPasswordField(
            value: signupConfirmPassword,
            hint: 'Confirmer le mot de passe *',
            obscure: !showConfirmPassword,
            onToggle: () =>
                setState(() => showConfirmPassword = !showConfirmPassword),
            onChanged: (v) => setState(() => signupConfirmPassword = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50), // Vert
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 3,
              ),
              onPressed: handleSignup,
              child: const Text(
                "S'inscrire",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // =================== WIDGETS UTILITAIRES ===================

  Widget _buildLabel(String text) {
    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333), // Gris foncé
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String value,
    required String hint,
    required ValueChanged<String> onChanged,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      keyboardType: keyboard,
      style: const TextStyle(color: Color(0xFF333333)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF999999)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF06FFF0), width: 2), // Cyan
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildPasswordField({
    required String value,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCCCCCC)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              obscureText: obscure,
              style: const TextStyle(color: Color(0xFF333333)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF999999)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: onChanged,
            ),
          ),
          IconButton(
            icon: Icon(
              obscure ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF06FFF0), // Cyan
            ),
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}