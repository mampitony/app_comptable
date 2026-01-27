import 'package:flutter/material.dart';
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

  // --- TA LOGIQUE DE VARIABLES CONSERVÉE ---
  String loginEmail = '';
  String loginPassword = '';
  String signupEmail = '';
  String signupPassword = '';
  String signupConfirmPassword = '';
  String adminKey = '';

  bool showLoginPassword = false;
  bool showSignupPassword = false;
  bool showConfirmPassword = false;
  bool showAdminKey = false;

  // Ta validation d'email
  bool validateEmail(String email) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  void _showAlert(String title, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK', style: TextStyle(color: Color(0xFF0163D2))),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  // --- TA LOGIQUE DE CONNEXION INITIALE ---
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
        _showAlert(
          'Erreur',
          "Votre compte n'est pas encore activé. Veuillez vous inscrire d'abord.",
        );
        return;
      }

      final hash = _userRepo.hashPassword(
        loginPassword,
        user['salt'] as String,
      );
      if (hash != user['passwordHash']) {
        _showAlert('Erreur', 'Mot de passe incorrect');
        return;
      }

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
        if (user['role'] == 'admin') {
          _showAlert(
            'Erreur',
            'Les administrateurs doivent utiliser l\'espace Administrateur.',
          );
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

      setState(() {
        loginEmail = '';
        loginPassword = '';
      });
    } catch (e) {
      if (!mounted) return;
      _showAlert('Erreur de connexion', e.toString());
    }
  }

  // --- TA LOGIQUE DE SIGNUP INITIALE ---
  Future<void> handleSignup() async {
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
      _showAlert(
        'Erreur',
        'Le mot de passe doit au moins contenir 6 caractères',
      );
      return;
    }

    try {
      final allUsers = await _userRepo.getAllUsers();
      if (!mounted) return;

      if (widget.userType == 'admin') {
        if (adminKey.isEmpty) {
          _showAlert('Erreur', 'Veuillez saisir le mot clé administrateur');
          return;
        }
        if (adminKey != 'ADMIN123') {
          // Ta clé de sécurité
          _showAlert('Erreur', 'Mot clé administrateur incorrect');
          return;
        }

        final existingAdmin = allUsers
            .where((u) => u['role'] == 'admin')
            .toList();
        if (existingAdmin.isNotEmpty) {
          _showAlert('Erreur', 'Un compte administrateur existe déjà.');
          return;
        }

        await _userRepo.addUser(
          name: signupEmail,
          email: signupEmail,
          password: signupPassword,
          role: 'admin',
        );
        _showAlert('Succès', 'Compte administrateur créé avec succès.');
      } else {
        // Logique membre : vérification existence email avant activation
        final memberExists = allUsers
            .where((u) => u['email']?.toString() == signupEmail)
            .toList();

        if (memberExists.isEmpty) {
          _showAlert(
            'Erreur',
            "Cet email n'existe pas dans la liste des membres. Contactez l'administrateur.",
          );
          return;
        }

        final member = memberExists.first;
        if (member['passwordHash'] != null &&
            (member['passwordHash'] as String).isNotEmpty) {
          _showAlert(
            'Erreur',
            'Votre compte est déjà activé. Utilisez la connexion.',
          );
          return;
        }

        await _userRepo.updateUserPassword(member['id'] as int, signupPassword);
        _showAlert('Succès', 'Votre compte a été activé !');
      }

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

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.userType == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0163D2),
        elevation: 0,
        centerTitle: true,
        title: Text(
          isAdmin ? "ESPACE ADMIN" : "ESPACE MEMBRE",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildProfileHeader(isAdmin),
              const SizedBox(height: 30),
              _buildTabSelector(),
              const SizedBox(height: 25),
              isLogin ? _buildLoginForm() : _buildSignupForm(isAdmin),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isAdmin) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0163D2).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isAdmin ? Icons.admin_panel_settings : Icons.person_rounded,
            size: 60,
            color: const Color(0xFF0163D2),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Welcome Back",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _buildTabOption(
            "Connexion",
            isLogin,
            () => setState(() => isLogin = true),
          ),
          _buildTabOption(
            "Inscription",
            !isLogin,
            () => setState(() => isLogin = false),
          ),
        ],
      ),
    );
  }

  Widget _buildTabOption(String title, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0163D2) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
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

  Widget _buildLoginForm() {
    return Column(
      children: [
        _buildTextField(
          'Email',
          Icons.email_outlined,
          (v) => loginEmail = v,
          initialValue: loginEmail,
        ),
        const SizedBox(height: 15),
        _buildPasswordField(
          'Mot de passe',
          showLoginPassword,
          (v) => loginPassword = v,
          () => setState(() => showLoginPassword = !showLoginPassword),
        ),
        const SizedBox(height: 30),
        _buildActionButton("SE CONNECTER", handleLogin),
      ],
    );
  }

  Widget _buildSignupForm(bool isAdmin) {
    return Column(
      children: [
        _buildTextField(
          'Votre Email',
          Icons.email_outlined,
          (v) => signupEmail = v,
          initialValue: signupEmail,
        ),
        if (isAdmin) ...[
          const SizedBox(height: 15),
          _buildPasswordField(
            'Mot clé Admin',
            showAdminKey,
            (v) => adminKey = v,
            () => setState(() => showAdminKey = !showAdminKey),
            hint: 'ADMIN123',
          ),
        ],
        const SizedBox(height: 15),
        _buildPasswordField(
          'Créer mot de passe',
          showSignupPassword,
          (v) => signupPassword = v,
          () => setState(() => showSignupPassword = !showSignupPassword),
        ),
        const SizedBox(height: 15),
        _buildPasswordField(
          'Confirmer mot de passe',
          showConfirmPassword,
          (v) => signupConfirmPassword = v,
          () => setState(() => showConfirmPassword = !showConfirmPassword),
        ),
        const SizedBox(height: 30),
        _buildActionButton("S'INSCRIRE", handleSignup),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    Function(String) onChanged, {
    String initialValue = '',
  }) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF0163D2)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    bool isVisible,
    Function(String) onChanged,
    VoidCallback onToggle, {
    String hint = '',
  }) {
    return TextField(
      onChanged: onChanged,
      obscureText: !isVisible,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF0163D2)),
        suffixIcon: IconButton(
          icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
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
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
