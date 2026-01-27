// lib/components/member_form.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../database/user_repository.dart';

class MemberForm extends StatefulWidget {
  final Map<String, dynamic>? member;
  final bool isAdmin;
  final VoidCallback? onClose;

  const MemberForm({
    Key? key,
    this.member,
    this.isAdmin = false,
    this.onClose,
  }) : super(key: key);

  @override
  State<MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<MemberForm> {
  final _formKey = GlobalKey<FormState>();
  final _userRepo = UserRepository();

  // --- listes de valeurs autorisées ---
  final List<String> rolesDisponibles = [
    'President',
    'Vice President',
    'Tresorier',
    'Commissaire au compte',
    'Conseiller',
    'Communication',
    'Utilisateur',
  ];

  // ICI : niveaux sous forme L1, L2, L3, M1, M2
  final List<String> niveauxDisponibles = [
    'L1',
    'L2',
    'L3',
    'M1',
    'M2',
  ];

  String nom = '';
  String prenom = '';
  String email = '';
  String roleMembre = 'Utilisateur';
  String password = '';
  String confirmPassword = '';
  String etablissement = '';
  String niveau = 'L1';
  String mention = '';
  String telephone = '';
  String? profileImagePath;

  String? dateNaissance; // texte formaté JJ/MM/AAAA

  @override
  void initState() {
    super.initState();
    if (widget.member != null) {
      final m = widget.member!;
      nom = m['name'] ?? '';
      prenom = m['prenom'] ?? '';
      roleMembre = m['role'] ?? 'Utilisateur';
      email = m['email'] ?? '';
      etablissement = m['etablissement'] ?? '';
      niveau = m['niveau'] ?? 'L1';
      mention = m['mention'] ?? '';
      telephone = m['telephone'] ?? '';
      profileImagePath = m['profileImage'];
      dateNaissance = m['dateNaissance'];
    }
  }

  // ==== Fonctions DB reliées au UserRepository ====

  Future<Map<String, dynamic>?> getUserByEmail(String email) {
    return _userRepo.getUserByEmail(email);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() {
    return _userRepo.getAllUsers();
  }

  // =====================================

  bool validateEmail(String email) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  bool validatePhone(String phone) {
    final regex = RegExp(r'^[0-9+\s()-]{10,}$');
    return regex.hasMatch(phone);
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? result = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (result != null) {
      setState(() {
        profileImagePath = result.path;
      });
    }
  }

  /// Ouvre le calendrier pour choisir la date de naissance
  Future<void> _pickDateNaissance() async {
    final now = DateTime.now();
    final initialDate = now.subtract(const Duration(days: 365 * 20));
    final firstDate = DateTime(1900);
    final lastDate = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: dateNaissance != null
          ? _parseDate(dateNaissance!) ?? initialDate
          : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      final formatted =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      setState(() {
        dateNaissance = formatted;
      });
    }
  }

  DateTime? _parseDate(String value) {
    try {
      final parts = value.split('/');
      if (parts.length == 3) {
        final d = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final y = int.parse(parts[2]);
        return DateTime(y, m, d);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.isAdmin && password != confirmPassword) {
      _showAlert('Erreur', 'Les mots de passe ne correspondent pas');
      return;
    }

    if (dateNaissance == null || dateNaissance!.isEmpty) {
      _showAlert('Erreur', 'Veuillez saisir la date de naissance');
      return;
    }

    try {
      // Vérification email déjà utilisé
      final existingUser = await getUserByEmail(email);
      if (existingUser != null) {
        if (widget.member == null ||
            existingUser['id'] != widget.member!['id']) {
          _showAlert('Erreur', 'Cet email est déjà utilisé');
          return;
        }
      }

      // Limitation sur certains rôles
      final users = await getAllUsers();
      final limitedRoles = {
        "President": 1,
        "Vice President": 1,
        "Tresorier": 1,
        "Commissaire au compte": 2,
      };

      final count = users.where((u) {
        final sameRole = u['role'] == roleMembre;
        if (widget.member != null && u['id'] == widget.member!['id']) {
          return false;
        }
        return sameRole;
      }).length;

      if (limitedRoles[roleMembre] != null &&
          count >= (limitedRoles[roleMembre] ?? 0)) {
        _showAlert(
          'Erreur',
          'Le rôle $roleMembre est limité à ${limitedRoles[roleMembre]} membre(s).',
        );
        return;
      }

      if (widget.member != null) {
        // --- Modification ---
        await _userRepo.updateUser(
          id: widget.member!['id'],
          name: nom,
          email: email,
          password: password.isEmpty ? null : password,
          role: widget.isAdmin ? 'admin' : roleMembre,
          prenom: prenom,
          etablissement: etablissement,
          niveau: niveau,
          mention: mention,
          telephone: telephone,
          profileImage: profileImagePath,
          dateNaissance: dateNaissance,
        );
        _showAlert('Succès', 'Membre modifié avec succès', closeAfter: true);
      } else {
        // --- Ajout ---
        if (password.isNotEmpty) {
          // admin ou membre avec mot de passe
          await _userRepo.addUser(
            name: nom,
            email: email,
            password: password,
            role: widget.isAdmin ? 'admin' : roleMembre,
            prenom: prenom,
            etablissement: etablissement,
            niveau: niveau,
            mention: mention,
            telephone: telephone,
            profileImage: profileImagePath,
            dateNaissance: dateNaissance,
          );
        } else {
          // membre sans mot de passe
          await _userRepo.addMember(
            name: nom,
            email: email,
            role: widget.isAdmin ? 'admin' : roleMembre,
            prenom: prenom,
            etablissement: etablissement,
            niveau: niveau,
            mention: mention,
            telephone: telephone,
            profileImage: profileImagePath,
            dateNaissance: dateNaissance,
          );
        }
        _showAlert(
          'Succès',
          '${widget.isAdmin ? 'Administrateur' : 'Membre'} ajouté avec succès',
          closeAfter: true,
        );
      }
    } catch (e) {
      _showAlert('Erreur', 'Une erreur est survenue: $e');
    }
  }

  void _showAlert(String title, String message, {bool closeAfter = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (closeAfter) {
                if (widget.onClose != null) {
                  widget.onClose!();
                } else {
                  Navigator.of(context).pop();
                }
              }
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
    String? initialValue,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 5),
        TextFormField(
          initialValue: initialValue,
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
    final isEditing = widget.member != null;

    return Scaffold(
      // appBar: AppBar(
      //   title: Text(
      //     isEditing
      //         ? 'Modifier le membre'
      //         : 'Ajouter un ${widget.isAdmin ? 'administrateur' : 'membre'}',
      //   ),
      // ),
      body: Container(
        padding: const EdgeInsets.all(20),
        color: const Color(0xFFF5F5F5),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text(
                  isEditing
                      ? 'Modifier le membre'
                      : 'Ajouter un ${widget.isAdmin ? 'administrateur' : 'membre'}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  label: 'Noms du Membre *',
                  hint: 'Nom *',
                  initialValue: nom,
                  onChanged: (v) => nom = v,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Veuillez saisir le nom' : null,
                ),
                _buildTextField(
                  label: 'Prénoms du Membre *',
                  hint: 'Prénom *',
                  initialValue: prenom,
                  onChanged: (v) => prenom = v,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Veuillez saisir le prénom'
                      : null,
                ),
                _buildTextField(
                  label: 'Email du Membre *',
                  hint: 'Email *',
                  initialValue: email,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (v) => email = v,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Veuillez saisir l\'email';
                    }
                    if (!validateEmail(v)) {
                      return 'Format d\'email invalide';
                    }
                    return null;
                  },
                ),

                // === Date de naissance ===
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Date de naissance *',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 5),
                InkWell(
                  onTap: _pickDateNaissance,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      dateNaissance ?? 'Choisir la date',
                      style: TextStyle(
                        color: (dateNaissance == null)
                            ? Colors.grey[600]
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // === Rôle ===
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Rôle du Membre *',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  value: rolesDisponibles.contains(roleMembre)
                      ? roleMembre
                      : 'Utilisateur',
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: rolesDisponibles
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(r),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      roleMembre = value ?? 'Utilisateur';
                    });
                  },
                ),
                const SizedBox(height: 15),

                _buildTextField(
                  label: "Nom de l'Établissement*",
                  hint: "Établissement *",
                  initialValue: etablissement,
                  onChanged: (v) => etablissement = v,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Veuillez saisir l\'établissement'
                      : null,
                ),

                // === Niveau (L1, L2, L3, M1, M2) ===
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Niveau *',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  value: niveauxDisponibles.contains(niveau) ? niveau : null,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: niveauxDisponibles
                      .map(
                        (n) => DropdownMenuItem(
                          value: n,
                          child: Text(n),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      niveau = value ?? 'L1';
                    });
                  },
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Veuillez choisir le niveau'
                      : null,
                ),
                const SizedBox(height: 15),

                _buildTextField(
                  label: "Mention *",
                  hint: "Mention *",
                  initialValue: mention,
                  onChanged: (v) => mention = v,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Veuillez saisir la mention' : null,
                ),
                _buildTextField(
                  label: "Contact*",
                  hint: "Téléphone *",
                  initialValue: telephone,
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

                if (widget.isAdmin) ...[
                  _buildTextField(
                    label: 'Mot de passe',
                    hint: 'Mot de passe',
                    obscureText: true,
                    onChanged: (v) => password = v,
                  ),
                  _buildTextField(
                    label: 'Confirmer le mot de passe',
                    hint: 'Confirmer le mot de passe',
                    obscureText: true,
                    onChanged: (v) => confirmPassword = v,
                  ),
                ],

                const SizedBox(height: 10),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: pickImage,
                      child: const Text(
                          'Ajouter une image de profil (facultatif)'),
                    ),
                    if (profileImagePath != null) ...[
                      const SizedBox(height: 10),
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: FileImage(File(profileImagePath!)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (widget.onClose != null) {
                            widget.onClose!();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: handleSubmit,
                        child: Text(isEditing ? 'Modifier' : 'Ajouter'),
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