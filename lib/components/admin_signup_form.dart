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
  String password = '';
  String confirmPassword = '';
  String etablissement = '';
  String niveau = '';
  String mention = '';
  String telephone = '';
  String? roleMembre;

  // ==== À remplacer par tes vraies fonctions (API / DB) ====
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    // TODO: implémenter
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    // TODO: implémenter
    return <Map<String, dynamic>>[];
  }

  Future<void> addUser(
    String nom,
    String email,
    String password,
    String roleMembre,
    String prenom,
    String etablissement,
    String niveau,
    String mention,
    String telephone,
  ) async {
    // TODO: implémenter
  }
  // =========================================================

  bool validateEmail(String email) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  bool validatePhone(String phone) {
    final regex = RegExp(r'^[0-9+\s()-]{10,}$');
    return regex.hasMatch(phone);
  }

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (roleMembre == null || roleMembre!.isEmpty) {
      _showAlert('Erreur', 'Veuillez choisir le rôle du membre');
      return;
    }

    if (password != confirmPassword) {
      _showAlert('Erreur', 'Les mots de passe ne correspondent pas');
      return;
    }

    try {
      final existingUser = await getUserByEmail(email);
      if (existingUser != null) {
        _showAlert('Erreur', 'Cet email est déjà utilisé');
        return;
      }

      final users = await getAllUsers();
      final count =
          users.where((u) => u['role'] == roleMembre).length;

      final Map<String, int> limitedRoles = {
        "President": 1,
        "Vice President": 1,
        "Tresorier": 1,
        "Commissaire au compte": 2,
      };

      if (limitedRoles[roleMembre] != null &&
          count >= (limitedRoles[roleMembre] ?? 0)) {
        _showAlert('Erreur',
            'Le rôle $roleMembre est limité à ${limitedRoles[roleMembre]} membre(s).');
        return;
      }

      await addUser(
        nom,
        email,
        password,
        roleMembre!,
        prenom,
        etablissement,
        niveau,
        mention,
        telephone,
      );

      _showAlert(
        'Succès',
        'Administrateur ajouté avec succès',
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

  Widget _buildTextField({
    required String label,
    required String hint,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 5),
        TextFormField(
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          validator: validator,
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inscription d'un administrateur"),
      ),
      body: Container(
        color: const Color(0xFFF5F5F5),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Inscription d'un administrateur",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  label: 'Nom *',
                  hint: 'Nom *',
                  onChanged: (v) => nom = v,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Veuillez saisir le nom' : null,
                ),
                _buildTextField(
                  label: 'Prénom *',
                  hint: 'Prénom *',
                  onChanged: (v) => prenom = v,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Veuillez saisir le prénom' : null,
                ),
                _buildTextField(
                  label: 'Email *',
                  hint: 'Email *',
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (v) => email = v,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Veuillez saisir l\'email';
                    }
                    if (!validateEmail(v)) {
                      return 'Format d\'email invalide. Il doit contenir @ et .';
                    }
                    return null;
                  },
                ),

                const Text(
                  'Rôle du Membre *',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: roleMembre,
                  items: const [
                    DropdownMenuItem(
                      value: 'President',
                      child: Text('Président'),
                    ),
                    DropdownMenuItem(
                      value: 'Vice President',
                      child: Text('Vice Président'),
                    ),
                    DropdownMenuItem(
                      value: 'Tresorier',
                      child: Text('Trésorier'),
                    ),
                    DropdownMenuItem(
                      value: 'Commissaire au compte',
                      child: Text('Commissaire au compte'),
                    ),
                    DropdownMenuItem(
                      value: 'Conseiller',
                      child: Text('Conseiller'),
                    ),
                    DropdownMenuItem(
                      value: 'Communication',
                      child: Text('Communication'),
                    ),
                    DropdownMenuItem(
                      value: 'Utilisateur',
                      child: Text('Utilisateur'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      roleMembre = value;
                    });
                  },
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Veuillez choisir un rôle' : null,
                ),
                const SizedBox(height: 15),

                _buildTextField(
                  label: "Établissement *",
                  hint: "Établissement *",
                  onChanged: (v) => etablissement = v,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Veuillez saisir l\'établissement' : null,
                ),
                _buildTextField(
                  label: "Niveau *",
                  hint: "Niveau *",
                  onChanged: (v) => niveau = v,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Veuillez saisir le niveau' : null,
                ),
                _buildTextField(
                  label: "Mention *",
                  hint: "Mention *",
                  onChanged: (v) => mention = v,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Veuillez saisir la mention' : null,
                ),
                _buildTextField(
                  label: "Téléphone *",
                  hint: "Téléphone *",
                  keyboardType: TextInputType.phone,
                  onChanged: (v) => telephone = v,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Veuillez saisir le téléphone';
                    }
                    if (!validatePhone(v)) {
                      return 'Format de téléphone invalide';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  label: "Mot de passe *",
                  hint: "Mot de passe *",
                  obscureText: true,
                  onChanged: (v) => password = v,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Veuillez saisir le mot de passe' : null,
                ),
                _buildTextField(
                  label: "Confirmer le mot de passe *",
                  hint: "Confirmer le mot de passe *",
                  obscureText: true,
                  onChanged: (v) => confirmPassword = v,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Veuillez confirmer le mot de passe';
                    }
                    if (v != password) {
                      return 'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                ),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: handleSubmit,
                        child: const Text('Ajouter'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
