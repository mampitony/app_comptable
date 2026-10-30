import 'package:flutter/material.dart';
import '../database/firebase_user_repository.dart';
import 'forgot_password_screen.dart';
import '../navigation/space_switcher.dart';
import '../services/company_settings_service.dart';
import 'dart:async';

class AuthScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> user) onLoginAsAdmin;
  final void Function(Map<String, dynamic> user) onLoginAsUser;

  const AuthScreen({
    super.key,
    required this.onLoginAsAdmin,
    required this.onLoginAsUser,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _userRepo = FirebaseUserRepository();
  bool isLogin = true;

  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupPasswordController =
      TextEditingController();
  final TextEditingController _signupConfirmPasswordController =
      TextEditingController();
  final TextEditingController _adminKeyController = TextEditingController();

  bool showLoginPassword = false;
  bool showSignupPassword = false;
  bool showConfirmPassword = false;
  bool showAdminKey = false;

  // Couleurs de l'écran
  static const Color _blue = Color(0xFF0163D2);
  static const Color _cyan = Color(0xFF00AEEF);
  static const Color _dark = Color(0xFF1E293B);

  // Logo + nom de l'association (temps réel depuis Firestore)
  String? _logoUrl;
  String _companyName = '';
  StreamSubscription<CompanySettings>? _companySub;

  @override
  void initState() {
    super.initState();
    _companySub = CompanySettingsService.instance.watch().listen(
      (c) {
        if (!mounted) return;
        setState(() {
          _logoUrl = c.logoUrl;
          _companyName = c.name;
        });
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _companySub?.cancel();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    _adminKeyController.dispose();
    super.dispose();
  }

  bool validateEmail(String email) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  // 🔥 MODIFIÉ : Retourne maintenant un Future pour pouvoir attendre
  Future<void> _showAlert(String title, String message) {
    return showDialog<void>(
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

  Future<void> handleLogin() async {
    final loginEmail = _loginEmailController.text.trim();
    final loginPassword = _loginPasswordController.text;

    if (loginEmail.isEmpty || loginPassword.isEmpty) {
      await _showAlert('Erreur', 'Veuillez remplir tous les champs');
      return;
    }

    try {
      final user = await _userRepo.getUserByEmail(loginEmail);
      print("USER FIREBASE = $user");
      if (!mounted) return;
      if (user == null) {
        await _showAlert('Erreur', 'Utilisateur non trouvé');
        return;
      }

      if (user['passwordHash'] == null ||
          (user['passwordHash'] as String).isEmpty) {
        await _showAlert(
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
        await _showAlert('Erreur', 'Mot de passe incorrect');
        return;
      }

      // 🔥 NOUVELLE LOGIQUE (écran de connexion unique) : l'utilisateur ne
      // choisit plus son espace. La redirection est entièrement décidée
      // par les données Firebase :
      //   - adminRole = admin_principal_membre -> espace Admin principal
      //   - adminRole = admin_gestion_membre   -> espace Admin gestion membre
      //   - adminRole = null                   -> espace Membre (inclut
      //     les comptables : leur droit vit dans `role`, logique
      //     comptable existante strictement inchangée).
      // 🔥 ROLES MULTIPLES : si le membre n'a qu'un seul espace, il y entre
      // directement (comportement d'avant). S'il en a plusieurs (ex.
      // Administration + Sécretaire, ou Sécretaire + Responsable de
      // Communication), il choisit celui avec lequel il veut continuer ;
      // il pourra ensuite en changer depuis le menu (« Changer d'espace »).
      final spaces = SpaceSwitcher.spacesFor(user);
      var chosen = spaces.first;
      if (spaces.length > 1) {
        if (!mounted) return;
        final picked = await SpaceSwitcher.choose(context, spaces);
        // Menu fermé sans choix : on reste sur l'écran de connexion.
        if (picked == null) return;
        chosen = picked;
      }

      final payload = SpaceSwitcher.payload(user, chosen);
      if (chosen.isAdmin) {
        widget.onLoginAsAdmin(payload);
      } else {
        widget.onLoginAsUser(payload);
      }
      _loginEmailController.clear();
      _loginPasswordController.clear();
    } catch (e) {
      if (!mounted) return;
      await _showAlert('Erreur de connexion', e.toString());
    }
  }

  Future<void> handleSignup() async {
    final signupEmail = _signupEmailController.text.trim();
    final signupPassword = _signupPasswordController.text;
    final signupConfirmPassword = _signupConfirmPasswordController.text;
    final adminKey = _adminKeyController.text;

    if (signupEmail.isEmpty ||
        signupPassword.isEmpty ||
        signupConfirmPassword.isEmpty) {
      await _showAlert('Erreur', 'Veuillez remplir tous les champs');
      return;
    }

    if (!validateEmail(signupEmail)) {
      await _showAlert(
        'Erreur',
        "Format d'email invalide. Il doit contenir @ et .",
      );
      return;
    }

    if (signupPassword != signupConfirmPassword) {
      await _showAlert('Erreur', 'Les mots de passe ne correspondent pas');
      return;
    }

    if (signupPassword.length < 6) {
      await _showAlert(
        'Erreur',
        'Le mot de passe doit au moins contenir 6 caractères',
      );
      return;
    }

    try {
      // 🔥 NOUVELLE LOGIQUE : plus de portail choisi à l'avance. On
      // détermine automatiquement s'il s'agit de l'activation d'un
      // compte membre déjà enregistré par un administrateur, ou de la
      // création du tout premier compte administrateur principal
      // (uniquement possible si l'email est inconnu de la base et que
      // le mot clé admin est fourni).
      final existingUser = await _userRepo.getUserByEmail(signupEmail);
      if (!mounted) return;

      if (existingUser != null) {
        // Compte membre déjà enregistré par un administrateur :
        // activation — logique strictement inchangée.
        if (existingUser['passwordHash'] != null &&
            (existingUser['passwordHash'] as String).isNotEmpty) {
          await _showAlert(
            'Erreur',
            'Votre compte est déjà activé. Utilisez la connexion.',
          );
          return;
        }

        await _userRepo.updateUserPassword(
          existingUser['id'] as String,
          signupPassword,
        );

        await _showAlert('Succès', 'Votre compte a été activé !');
      } else {
        // Email inconnu de la base membres : seule la création du tout
        // premier administrateur principal est possible dans ce cas.
        if (adminKey.isEmpty) {
          await _showAlert(
            'Erreur',
            "Cet email n'existe pas dans la liste des membres. Contactez l'administrateur.",
          );
          return;
        }
        if (adminKey != 'ADMIN123') {
          await _showAlert('Erreur', 'Mot clé administrateur incorrect');
          return;
        }
        // 🔥 CORRIGÉ : l'existence de l'admin principal se vérifie
        // désormais via `adminRole` (et non plus `role`, qui ne contient
        // plus jamais de valeur d'administration).
        if (await _userRepo.adminPrincipalExists()) {
          await _showAlert('Erreur', 'Un compte administrateur existe déjà.');
          return;
        }

        // Crée le compte : `role` = fonction normale ('membre'),
        // `adminRole` = admin_principal_membre.
        await _userRepo.createAdminPrincipal(
          name: signupEmail,
          email: signupEmail,
          password: signupPassword,
        );

        await _showAlert('Succès', 'Compte administrateur créé avec succès !');
      }

      // 🔥 MODIFIÉ : Nettoie les champs APRÈS que l'utilisateur a vu le message
      _signupEmailController.clear();
      _signupPasswordController.clear();
      _signupConfirmPasswordController.clear();
      _adminKeyController.clear();

      // 🔥 MODIFIÉ : Change d'onglet APRÈS que l'utilisateur a fermé la dialog
      if (mounted) {
        setState(() => isLogin = true);
      }
    } catch (e) {
      if (!mounted) return;
      await _showAlert('Erreur', 'Une erreur est survenue : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1F4B), _blue, Color(0xFF0B1F4B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildMainCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Grande carte blanche avec la vague bleue en haut à gauche
  Widget _buildMainCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: ClipPath(
                clipper: _TopLeftWaveClipper(),
                child: Container(
                  width: 190,
                  height: 120,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_cyan, _blue],
                    ),
                  ),
                ),
              ),
            ),
            if (Navigator.of(context).canPop())
              Positioned(
                top: 6,
                left: 6,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 34, 20, 16),
              child: Column(
                children: [
                  _buildLogoHeader(),
                  const SizedBox(height: 26),
                  _buildTabs(),
                  const SizedBox(height: 14),
                  _buildFormCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: (_logoUrl != null && _logoUrl!.isNotEmpty)
                ? Image.network(
                    _logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.account_balance,
                        size: 40,
                        color: _blue),
                  )
                : const Icon(Icons.account_balance, size: 40, color: _blue),
          ),
        ),
        if (_companyName.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _companyName.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _dark,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  // Onglets texte : Connexion (gauche) / Inscription (droite)
  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTab('Connexion', isLogin, () => setState(() => isLogin = true)),
          _buildTab(
              'Inscription', !isLogin, () => setState(() => isLogin = false)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: active ? 18 : 15,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? _blue : Colors.black45,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: active ? 30 : 0,
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Carte flottante du formulaire + vague en bas + bouton qui déborde
  Widget _buildFormCard() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 64,
                  child: ClipPath(
                    clipper: _BottomWaveClipper(),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_blue, _cyan],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 70),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: isLogin
                        ? KeyedSubtree(
                            key: const ValueKey('login'),
                            child: _buildLoginFields(),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('signup'),
                            child: _buildSignupFields(),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: _buildPillButton(
              isLogin ? 'SE CONNECTER' : "S'INSCRIRE",
              isLogin ? handleLogin : handleSignup,
            ),
          ),
        ),
      ],
    );
  }

  // 🔑 Mot de passe oublié : code envoyé par email, puis nouveau mot de passe.
  Future<void> _openForgotPassword() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: _loginEmailController.text.trim(),
        ),
      ),
    );
    if (!mounted || email == null) return;

    setState(() {
      _loginEmailController.text = email;
      _loginPasswordController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mot de passe modifié. Vous pouvez vous connecter.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildLoginFields() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLineField(
          label: 'Email',
          icon: Icons.email_outlined,
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _buildLineField(
          label: 'Mot de passe',
          icon: Icons.lock_outline,
          controller: _loginPasswordController,
          isPassword: true,
          visible: showLoginPassword,
          onToggle: () => setState(() => showLoginPassword = !showLoginPassword),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _openForgotPassword,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Mot de passe oublié ?',
              style: TextStyle(
                color: _dark,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupFields() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLineField(
          label: 'Votre email',
          icon: Icons.email_outlined,
          controller: _signupEmailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        // Uniquement pour la création du tout premier compte administrateur.
        _buildLineField(
          label: 'Mot clé Admin (1er admin uniquement)',
          icon: Icons.vpn_key_outlined,
          controller: _adminKeyController,
          isPassword: true,
          visible: showAdminKey,
          onToggle: () => setState(() => showAdminKey = !showAdminKey),
        ),
        const SizedBox(height: 12),
        _buildLineField(
          label: 'Créer mot de passe',
          icon: Icons.lock_outline,
          controller: _signupPasswordController,
          isPassword: true,
          visible: showSignupPassword,
          onToggle: () =>
              setState(() => showSignupPassword = !showSignupPassword),
        ),
        const SizedBox(height: 12),
        _buildLineField(
          label: 'Confirmer mot de passe',
          icon: Icons.lock_outline,
          controller: _signupConfirmPasswordController,
          isPassword: true,
          visible: showConfirmPassword,
          onToggle: () =>
              setState(() => showConfirmPassword = !showConfirmPassword),
        ),
      ],
    );
  }

  // Champ souligné, icône à droite (comme sur la capture)
  Widget _buildLineField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    bool visible = false,
    VoidCallback? onToggle,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !visible,
      keyboardType: keyboardType,
      cursorColor: _blue,
      style: const TextStyle(fontSize: 15, color: _dark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: Colors.black54),
        floatingLabelStyle:
            const TextStyle(color: _blue, fontWeight: FontWeight.w600),
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black54, width: 1),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _blue, width: 2),
        ),
        border: const UnderlineInputBorder(),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  visible ? Icons.visibility : Icons.visibility_off,
                  color: _dark,
                  size: 22,
                ),
                onPressed: onToggle,
              )
            : Icon(icon, color: _dark, size: 22),
      ),
    );
  }

  Widget _buildPillButton(String label, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(colors: [_cyan, _blue]),
        boxShadow: [
          BoxShadow(
            color: _blue.withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(190, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// Vague en haut à gauche de la carte
class _TopLeftWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path()..lineTo(size.width, 0);
    p.cubicTo(size.width * 0.80, size.height * 0.30, size.width * 0.55,
        size.height * 0.20, size.width * 0.40, size.height * 0.60);
    p.cubicTo(size.width * 0.30, size.height * 0.85, size.width * 0.12,
        size.height * 0.95, 0, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Vague en bas de la carte du formulaire
class _BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path()..moveTo(0, size.height * 0.45);
    p.cubicTo(size.width * 0.25, size.height * 0.05, size.width * 0.55,
        size.height * 0.95, size.width, size.height * 0.30);
    p.lineTo(size.width, size.height);
    p.lineTo(0, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
