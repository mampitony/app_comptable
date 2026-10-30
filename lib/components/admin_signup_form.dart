import 'package:flutter/material.dart';

class AdminSignupForm extends StatefulWidget {
  const AdminSignupForm({Key? key}) : super(key: key);

  @override
  State<AdminSignupForm> createState() => _AdminSignupFormState();
}

class _AdminSignupFormState extends State<AdminSignupForm> {
  final _formKey = GlobalKey<FormState>();

  String nom = '';
  String prenom = '';
  String email = '';
  String dateNaissance = '';
  String etablissement = '';
  String niveau = '';
  String mention = '';
  String telephone = '';
  String profession = '';
  String secteurActivite = '';
  String? roleMembre;
  String? statusMembre; // 'Etudiant' ou 'Autre'

  final List<String> rolesDisponibles = [
    'President',
    'Vice President',
    'Tresorier',
    'Commissaire au compte',
    'Conseiller',
    'Responsable de Communication',
    'Sécretaire',
    'Membre actif',
    'Membre',
  ];

  Future<Map<String, dynamic>?> getUserByEmail(String email) async => null;
  Future<List<Map<String, dynamic>>> getAllUsers() async => [];
  Future<void> addUser(Map<String, dynamic> data) async {}

  bool validateEmail(String email) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  bool validatePhone(String phone) {
    final regex = RegExp(r'^[0-9+\s()-]{10,}$');
    return regex.hasMatch(phone);
  }

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (roleMembre == null || roleMembre!.isEmpty) {
      _showAlert('Erreur', 'Veuillez choisir le rôle du membre');
      return;
    }

    if (statusMembre == null) {
      _showAlert('Erreur', 'Veuillez choisir le statut du membre');
      return;
    }

    try {
      final existingUser = await getUserByEmail(email);
      if (existingUser != null) {
        _showAlert('Erreur', 'Cet email est déjà utilisé');
        return;
      }

      final users = await getAllUsers();
      final count = users.where((u) => u['role'] == roleMembre).length;

      final Map<String, int> limitedRoles = {
        "President": 1,
        "Vice President": 1,
        "Tresorier": 1,
        "Commissaire au compte": 2,
      };

      if (limitedRoles[roleMembre] != null &&
          count >= (limitedRoles[roleMembre] ?? 0)) {
        _showAlert(
          'Erreur',
          'Le rôle $roleMembre est limité à ${limitedRoles[roleMembre]} membre(s).',
        );
        return;
      }

      await addUser({
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'dateNaissance': dateNaissance,
        'role': roleMembre,
        'status': statusMembre,
        'telephone': telephone,
        if (statusMembre == 'Etudiant') ...{
          'etablissement': etablissement,
          'mention': mention,
          'niveau': niveau,
        },
        if (statusMembre == 'Autre') ...{
          'profession': profession,
          'secteurActivite': secteurActivite,
        },
      });

      _showAlert(
        'Succès',
        'Membre ajouté avec succès',
        onOk: () => Navigator.of(context).pop(),
      );
    } catch (e) {
      _showAlert('Erreur', 'Une erreur est survenue : $e');
    }
  }

  void _showAlert(String title, String message, {VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onOk != null) onOk();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required String label,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1976D2),
            ),
          ),
        ),
        TextFormField(
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
            errorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
          ),
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          validator: validator,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStyledDropdown({
    required String label,
    String? value,
    required List<String> items,
    required Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1976D2),
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          value: value,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
          ),
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          validator: validator,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// Section statut avec checkboxes + champs conditionnels
  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Choisir le statut du membre',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1976D2),
            ),
          ),
        ),

        // Checkbox Étudiant
        Row(
          children: [
            Checkbox(
              value: statusMembre == 'Etudiant',
              activeColor: const Color(0xFF1976D2),
              onChanged: (checked) {
                setState(() {
                  statusMembre = checked == true ? 'Etudiant' : null;
                });
              },
            ),
            const Text('Étudiant', style: TextStyle(fontSize: 15)),
          ],
        ),

        // Checkbox Autre
        Row(
          children: [
            Checkbox(
              value: statusMembre == 'Autre',
              activeColor: const Color(0xFF1976D2),
              onChanged: (checked) {
                setState(() {
                  statusMembre = checked == true ? 'Autre' : null;
                });
              },
            ),
            const Text('Autre', style: TextStyle(fontSize: 15)),
          ],
        ),

        const SizedBox(height: 10),

        // Champs conditionnels Étudiant
        if (statusMembre == 'Etudiant') ...[
          _buildStyledTextField(
            label: 'Établissement',
            onChanged: (v) => etablissement = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Veuillez saisir l\'établissement' : null,
          ),
          _buildStyledTextField(
            label: 'Mention',
            onChanged: (v) => mention = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Veuillez saisir la mention' : null,
          ),
          _buildStyledTextField(
            label: 'Niveau',
            onChanged: (v) => niveau = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Veuillez saisir le niveau' : null,
          ),
        ],

        // Champs conditionnels Autre
        if (statusMembre == 'Autre') ...[
          _buildStyledTextField(
            label: 'Profession',
            onChanged: (v) => profession = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Veuillez saisir la profession' : null,
          ),
          _buildStyledTextField(
            label: "Secteur d'activité",
            onChanged: (v) => secteurActivite = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Veuillez saisir le secteur d\'activité' : null,
          ),
        ],

        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1976D2),
              Color(0xFF1976D2),
              Color(0xFFF5F8FA),
            ],
            stops: [0.0, 0.3, 0.3],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header avec vague
              Stack(
                children: [
                  Container(height: 120, color: Colors.transparent),
                  Positioned(
                    top: 20,
                    left: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: const Size(double.infinity, 60),
                      painter: WavePainter(),
                    ),
                  ),
                  const Positioned(
                    top: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        "Ajout d'un nouveau membre",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Formulaire
              Expanded(
                child: Container(
                  color: const Color(0xFFF5F8FA),
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 30),

                          // Photo de profil
                          Center(
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
                                  child: const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Color(0xFF1976D2),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF1976D2),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              'Photo de profil',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Nom
                          _buildStyledTextField(
                            label: 'Nom',
                            onChanged: (v) => nom = v,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Veuillez saisir le nom' : null,
                          ),

                          // Prénoms
                          _buildStyledTextField(
                            label: 'Prénoms',
                            onChanged: (v) => prenom = v,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Veuillez saisir le prénom' : null,
                          ),

                          // E-mail
                          _buildStyledTextField(
                            label: 'E-mail',
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (v) => email = v,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Veuillez saisir l\'email';
                              if (!validateEmail(v)) return 'Format d\'email invalide';
                              return null;
                            },
                          ),

                          // Date de naissance
                          _buildStyledTextField(
                            label: 'Date de naissance',
                            keyboardType: TextInputType.datetime,
                            onChanged: (v) => dateNaissance = v,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Veuillez saisir la date de naissance' : null,
                          ),

                          // Rôle du membre
                          _buildStyledDropdown(
                            label: 'Rôle du Membre',
                            value: roleMembre,
                            items: rolesDisponibles,
                            onChanged: (value) {
                              setState(() => roleMembre = value);
                            },
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Veuillez choisir un rôle' : null,
                          ),

                          // Statut du membre (Étudiant / Autre) avec champs conditionnels
                          _buildStatusSection(),

                          // Contact / Téléphone
                          _buildStyledTextField(
                            label: 'Contact',
                            keyboardType: TextInputType.phone,
                            onChanged: (v) => telephone = v,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Veuillez saisir le contact';
                              if (!validatePhone(v)) return 'Format de téléphone invalide';
                              return null;
                            },
                          ),

                          const SizedBox(height: 30),

                          // Bouton Ajouter
                          ElevatedButton(
                            onPressed: handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 3,
                            ),
                            child: const Text(
                              'Ajouter',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Bouton Annuler
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Annuler',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter pour la vague
class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5F8FA)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.1,
      size.width * 0.5,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.9,
      size.width,
      size.height * 0.5,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}