// lib/components/member_form.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../database/firebase_user_repository.dart';
import '../services/image_upload_service.dart';
import '../services/role_settings_service.dart';

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
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();
  // 🔥 AJOUT : rôles personnalisés + limites configurables (Firestore).
  RoleSettings _roleSettings = RoleSettings.defaults();

  // Rôles autorisés pour la gestion des membres
  static const String adminPrincipalRole = 'admin_principal_membre';
  static const String adminGestionRole = 'admin_gestion_membre';

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
    // 🔥 AJOUT : option libre — voir _selectedRoleOption / _autreRoleText.
    'Autre',
  ];

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
  String roleMembre = 'Membre';
  // 🔥 AJOUT : option choisie dans le menu déroulant ('Autre' ou un rôle
  // prédéfini) et texte libre saisi quand "Autre" est sélectionné.
  // `roleMembre` reste la seule valeur réellement enregistrée dans
  // Firebase (jamais le mot "Autre").
  String _selectedRoleOption = 'Membre';
  String _autreRoleText = '';
  // 🔥 AJOUT : fonctions supplémentaires (en plus de la fonction principale
  // `roleMembre`). Optionnel : vide = comportement d'origine.
  List<String> _rolesSupplementaires = [];
  String password = '';
  String confirmPassword = '';
  String etablissement = '';
  String niveau = 'L1';
  String mention = '';
  String telephone = '';
  String? profileImagePath;
  // 🔥 AJOUT : true pendant l'envoi de la photo vers ImgBB, pour
  // désactiver le bouton et éviter une double soumission.
  bool _isUploadingImage = false;
  String? dateNaissance;

  // ---- NOUVEAU : statut membre ----
  String? statusMembre; // 'Etudiant' ou 'Autre'
  String profession = '';
  String secteurActivite = '';
  // ---------------------------------

  @override
  void initState() {
    super.initState();
    _loadRoleSettings(); // 🔥 AJOUT : rôles ajoutés par l'admin
    if (widget.member != null) {
      final m = widget.member!;
      nom = m['name'] ?? '';
      prenom = m['prenom'] ?? '';
      roleMembre = m['role'] ?? 'Membre';
      // 🔥 AJOUT : si le rôle enregistré ne fait pas partie de la liste
      // prédéfinie, c'est une valeur libre saisie via "Autre" — on
      // présélectionne donc "Autre" et on préremplit le champ texte,
      // pour que la modification réaffiche bien le rôle personnalisé.
      if (roleMembre.isNotEmpty &&
          roleMembre != 'Autre' &&
          rolesDisponibles.contains(roleMembre)) {
        _selectedRoleOption = roleMembre;
      } else if (roleMembre.isNotEmpty) {
        _selectedRoleOption = 'Autre';
        _autreRoleText = roleMembre;
      }
      // 🔥 AJOUT : fonctions supplémentaires déjà enregistrées.
      _rolesSupplementaires = FirebaseUserRepository.resolveRoles(m)
          .where((r) => r != roleMembre)
          .toList();
      email = m['email'] ?? '';
      etablissement = m['etablissement'] ?? '';
      // 🔥 CORRIGÉ : un niveau vide ('' enregistré pour un non-étudiant)
      // ferait planter le menu déroulant : on retombe sur 'L1'.
      niveau = niveauxDisponibles.contains(m['niveau']) ? m['niveau'] : 'L1';
      mention = m['mention'] ?? '';
      telephone = m['telephone'] ?? '';
      profileImagePath = m['profileImage'];
      dateNaissance = m['dateNaissance'];
      // ---- NOUVEAU ----
      // 🔥 CORRIGÉ : si le membre n'a pas de statut enregistré (anciennes
      // fiches), on le déduit des données existantes pour cocher la bonne
      // case et afficher les champs déjà remplis.
      final String? savedStatus = m['status']?.toString();
      if (savedStatus == 'Etudiant' || savedStatus == 'Autre') {
        statusMembre = savedStatus;
      } else if ((m['etablissement'] ?? '').toString().trim().isNotEmpty ||
          (m['mention'] ?? '').toString().trim().isNotEmpty) {
        statusMembre = 'Etudiant';
      } else if ((m['profession'] ?? '').toString().trim().isNotEmpty ||
          (m['secteurActivite'] ?? '').toString().trim().isNotEmpty) {
        statusMembre = 'Autre';
      } else {
        statusMembre = null;
      }
      profession = m['profession'] ?? '';
      secteurActivite = m['secteurActivite'] ?? '';
      // -----------------
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) {
    return _userRepo.getUserByEmail(email);
  }

  /// 🔥 AJOUT : ajoute à la liste déroulante les rôles personnalisés
  /// enregistrés dans Firestore (avant « Autre »). En cas d'échec, la liste
  /// d'origine reste inchangée.
  Future<void> _loadRoleSettings() async {
    final s = await RoleSettingsService.instance.fetch();
    if (!mounted) return;
    setState(() {
      _roleSettings = s;
      for (final r in s.customRoles) {
        final already = rolesDisponibles
            .any((e) => e.trim().toLowerCase() == r.trim().toLowerCase());
        if (already) continue;
        final autreIdx = rolesDisponibles.indexOf('Autre');
        rolesDisponibles.insert(
          autreIdx < 0 ? rolesDisponibles.length : autreIdx,
          r,
        );
      }
      // Modification d'un membre dont le rôle était libre mais figure
      // maintenant dans la liste : on le présélectionne.
      if (widget.member != null &&
          _selectedRoleOption == 'Autre' &&
          _autreRoleText.trim().isNotEmpty) {
        final match = _autreRoleText.trim().toLowerCase();
        for (final r in rolesDisponibles) {
          if (r != 'Autre' && r.trim().toLowerCase() == match) {
            _selectedRoleOption = r;
            roleMembre = r;
            _autreRoleText = '';
            break;
          }
        }
      }
    });
  }

  /// 🔥 AJOUT : mémorise les rôles saisis librement pour les proposer aux
  /// prochains membres. N'empêche jamais l'enregistrement du membre.
  Future<void> _registerCustomRoles() async {
    if (widget.isAdmin) return;
    try {
      for (final r in _allRoles) {
        await RoleSettingsService.instance.registerRole(r);
      }
    } catch (e) {
      debugPrint('Enregistrement du rôle personnalisé impossible : $e');
    }
  }

  /// 🔥 AJOUT : choix des fonctions supplémentaires (puces sélectionnables).
  Widget _buildExtraRolesSection() {
    final options = <String>[
      ...rolesDisponibles.where(
        (r) => r != 'Autre' && r != 'Membre' && r != 'Membre actif',
      ),
      ..._rolesSupplementaires.where((r) => !rolesDisponibles.contains(r)),
    ].where((r) => r != roleMembre).toList();

    if (options.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Autres fonctions (optionnel)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: options.map((r) {
              final selected = _rolesSupplementaires.contains(r);
              return FilterChip(
                label: Text(r),
                selected: selected,
                selectedColor: const Color(0xFF0163D2).withOpacity(0.15),
                checkmarkColor: const Color(0xFF0163D2),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      if (!_rolesSupplementaires.contains(r)) {
                        _rolesSupplementaires.add(r);
                      }
                    } else {
                      _rolesSupplementaires.remove(r);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Fonction principale + fonctions supplémentaires, sans doublon.
  List<String> get _allRoles {
    final result = <String>[];
    final primary = roleMembre.trim();
    if (primary.isNotEmpty) result.add(primary);
    for (final r in _rolesSupplementaires) {
      final s = r.trim();
      if (s.isNotEmpty && !result.contains(s)) result.add(s);
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() {
    return _userRepo.getAllUsers();
  }

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
      imageQuality: 85,
      maxWidth: 600,
      maxHeight: 600,
    );
    if (result != null) {
      setState(() {
        profileImagePath = result.path;
      });
    }
  }

  ImageProvider? _getImageProvider() {
    // 🔥 CORRIGÉ : gère à la fois une URL déjà hébergée (édition d'un
    // membre existant) et un chemin local (photo qui vient d'être
    // choisie et pas encore envoyée à ImgBB).
    return ImageUploadService.resolveImageProvider(profileImagePath);
  }

  BoxFit _getImageFit() => BoxFit.cover;

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
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isAdmin && password != confirmPassword) {
      _showAlert('Erreur', 'Les mots de passe ne correspondent pas');
      return;
    }

    if (dateNaissance == null || dateNaissance!.isEmpty) {
      _showAlert('Erreur', 'Veuillez saisir la date de naissance');
      return;
    }

    // ---- NOUVEAU : validation statut ----
    if (statusMembre == null) {
      _showAlert('Erreur', 'Veuillez choisir le statut du membre');
      return;
    }
    // -------------------------------------

    // 🔥 AJOUT : si une nouvelle photo a été choisie (chemin local, pas
    // encore une URL), on l'envoie d'abord vers ImgBB. Si le membre
    // existant a déjà une URL ImgBB et qu'aucune nouvelle photo n'a été
    // choisie, on la garde telle quelle — pas de ré-upload inutile.
    String? finalProfileImage = profileImagePath;
    if (profileImagePath != null &&
        profileImagePath!.isNotEmpty &&
        !ImageUploadService.isNetworkUrl(profileImagePath)) {
      debugPrint(
          '[ImgBB] Chemin local détecté, envoi en cours : $profileImagePath');
      setState(() => _isUploadingImage = true);
      try {
        finalProfileImage =
            await ImageUploadService.uploadImage(File(profileImagePath!));
        debugPrint('[ImgBB] Upload réussi, URL reçue : $finalProfileImage');
      } catch (e) {
        debugPrint('[ImgBB] Échec de l\'upload : $e');
        setState(() => _isUploadingImage = false);
        _showAlert('Erreur', "Échec de l'envoi de la photo : $e");
        return;
      }
      setState(() => _isUploadingImage = false);
    } else {
      debugPrint(
          '[ImgBB] Aucun nouvel envoi nécessaire (profileImagePath = $profileImagePath)');
    }

    try {
      final existingUser = await getUserByEmail(email);
      if (existingUser != null) {
        if (widget.member == null ||
            existingUser['id'] != widget.member!['id']) {
          _showAlert('Erreur', 'Cet email est déjà utilisé');
          return;
        }
      }

      final users = await getAllUsers();
      // 🔥 MODIFIÉ : limites lues depuis la configuration admin (mêmes
      // valeurs qu'avant tant que rien n'a été changé).
      final roleSettings = await RoleSettingsService.instance.fetch();
      _roleSettings = roleSettings;
      // Rôle libre déjà existant (à la casse près) : on réutilise le nom officiel.
      if (_selectedRoleOption == 'Autre' && !widget.isAdmin) {
        final official = roleSettings.canonical(roleMembre.trim());
        roleMembre = official ?? roleMembre.trim();
      }
      final limitedRoles = <String, int>{
        ...roleSettings.effectiveLimits,
        adminPrincipalRole: 1,
        adminGestionRole: 2,
      };

      // 🔥 MODIFIÉ : la limite s'applique à CHAQUE fonction du membre
      // (principale + supplémentaires), en tenant compte des fonctions
      // multiples des autres membres.
      for (final r in _allRoles) {
        final limit = limitedRoles[r];
        if (limit == null) continue;

        final count = users.where((u) {
          if (widget.member != null && u['id'] == widget.member!['id']) {
            return false;
          }
          return u['role'] == r ||
              FirebaseUserRepository.resolveRoles(u).contains(r);
        }).length;

        if (count >= limit) {
          _showAlert(
            'Erreur',
            'Le rôle $r est limité à $limit membre(s).',
          );
          return;
        }
      }

      // ---- NOUVEAU : données statut ----
      final Map<String, dynamic> statusData = {
        'status': statusMembre,
        if (statusMembre == 'Etudiant') ...{
          'etablissement': etablissement,
          'mention': mention,
          'niveau': niveau,
        },
        if (statusMembre == 'Autre') ...{
          'profession': profession,
          'secteurActivite': secteurActivite,
        },
      };
      // ----------------------------------

      if (widget.member != null) {
        await _userRepo.updateUser(
          id: widget.member!['id'],
          name: nom,
          email: email,
          password: password.isEmpty ? null : password,
          role: widget.isAdmin ? adminPrincipalRole : roleMembre,
          roles: widget.isAdmin ? null : _allRoles,
          prenom: prenom,
          etablissement: statusMembre == 'Etudiant' ? etablissement : '',
          niveau: statusMembre == 'Etudiant' ? niveau : '',
          mention: statusMembre == 'Etudiant' ? mention : '',
          telephone: telephone,
          profileImage: finalProfileImage,
          dateNaissance: dateNaissance,
          status: statusMembre,
          profession: statusMembre == 'Autre' ? profession : '',
          secteurActivite: statusMembre == 'Autre' ? secteurActivite : '',
        );
        await _registerCustomRoles();
        _showAlert('Succès', 'Membre modifié avec succès', closeAfter: true);
      } else {
        if (password.isNotEmpty) {
          await _userRepo.addUser(
            name: nom,
            email: email,
            password: password,
            role: widget.isAdmin ? adminPrincipalRole : roleMembre,
            roles: widget.isAdmin ? null : _allRoles,
            prenom: prenom,
            etablissement: statusMembre == 'Etudiant' ? etablissement : '',
            niveau: statusMembre == 'Etudiant' ? niveau : '',
            mention: statusMembre == 'Etudiant' ? mention : '',
            telephone: telephone,
            profileImage: finalProfileImage,
            dateNaissance: dateNaissance,
            status: statusMembre,
            profession: statusMembre == 'Autre' ? profession : '',
            secteurActivite: statusMembre == 'Autre' ? secteurActivite : '',
          );
        } else {
          await _userRepo.addMember(
            name: nom,
            email: email,
            role: widget.isAdmin ? adminPrincipalRole : roleMembre,
            roles: widget.isAdmin ? null : _allRoles,
            prenom: prenom,
            etablissement: statusMembre == 'Etudiant' ? etablissement : '',
            niveau: statusMembre == 'Etudiant' ? niveau : '',
            mention: statusMembre == 'Etudiant' ? mention : '',
            telephone: telephone,
            profileImage: finalProfileImage,
            dateNaissance: dateNaissance,
            status: statusMembre,
            profession: statusMembre == 'Autre' ? profession : '',
            secteurActivite: statusMembre == 'Autre' ? secteurActivite : '',
          );
        }
        await _registerCustomRoles();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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

  Widget _buildStyledTextField({
    required String label,
    required Function(String) onChanged,
    String? initialValue,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
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
          initialValue: initialValue,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            suffixIcon: suffixIcon,
          ),
          // 🔥 CORRIGÉ : couleur explicite depuis le thème (au lieu de
          // dépendre de l'héritage implicite, qui ne se propage pas de
          // façon fiable) — foncée en clair, claire en mode sombre.
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
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
    required String value,
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
          value: items.contains(value) ? value : null,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
          ),
          // 🔥 CORRIGÉ : couleur figée en noir → invisible en mode sombre.
          // 🔥 CORRIGÉ : idem — couleur explicite depuis le thème.
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
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

  // ---- NOUVEAU : section statut avec checkboxes ----
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
            initialValue: etablissement,
            onChanged: (v) => etablissement = v,
            validator: (v) => (v == null || v.isEmpty)
                ? 'Veuillez saisir l\'établissement'
                : null,
          ),
          _buildStyledTextField(
            label: 'Mention',
            initialValue: mention,
            onChanged: (v) => mention = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Veuillez saisir la mention' : null,
          ),
          _buildStyledDropdown(
            label: 'Niveau',
            value: niveau,
            items: niveauxDisponibles,
            onChanged: (value) {
              setState(() {
                niveau = value ?? 'L1';
              });
            },
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Veuillez choisir le niveau' : null,
          ),
        ],

        // Champs conditionnels Autre
        if (statusMembre == 'Autre') ...[
          _buildStyledTextField(
            label: 'Profession',
            initialValue: profession,
            onChanged: (v) => profession = v,
            validator: (v) => (v == null || v.isEmpty)
                ? 'Veuillez saisir la profession'
                : null,
          ),
          _buildStyledTextField(
            label: "Secteur d'activité",
            initialValue: secteurActivite,
            onChanged: (v) => secteurActivite = v,
            validator: (v) => (v == null || v.isEmpty)
                ? 'Veuillez saisir le secteur d\'activité'
                : null,
          ),
        ],

        const SizedBox(height: 10),
      ],
    );
  }
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.member != null;

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
              // Header avec vague — INCHANGÉ
              Stack(
                children: [
                  Container(height: 120, color: Colors.transparent),
                  Positioned(
                    top: 20,
                    left: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        if (widget.onClose != null) {
                          widget.onClose!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
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
                  Positioned(
                    top: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        isEditing
                            ? 'Modifier le membre'
                            : 'Ajouter un ${widget.isAdmin ? 'administrateur' : 'membre'}',
                        style: const TextStyle(
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

                          // Photo de profil — INCHANGÉE
                          Center(
                            child: GestureDetector(
                              onTap: pickImage,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFE3F2FD),
                                      border: Border.all(
                                        color: const Color(0xFF1976D2),
                                        width: 3,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: _getImageProvider() != null
                                          ? Image(
                                              image: _getImageProvider()!,
                                              fit: BoxFit.cover,
                                              alignment: Alignment.topCenter,
                                              width: 100,
                                              height: 100,
                                            )
                                          : const Icon(
                                              Icons.person,
                                              size: 50,
                                              color: Color(0xFF1976D2),
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1976D2),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Center(
                            child: Text(
                              'Ajouter une photo (facultatif)',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Champs existants — INCHANGÉS
                          _buildStyledTextField(
                            label: 'Nom',
                            initialValue: nom,
                            onChanged: (v) => nom = v,
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Veuillez saisir le nom'
                                : null,
                          ),

                          _buildStyledTextField(
                            label: 'Prénom',
                            initialValue: prenom,
                            onChanged: (v) => prenom = v,
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Veuillez saisir le prénom'
                                : null,
                          ),

                          _buildStyledTextField(
                            label: 'E-mail',
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

                          // Date de naissance — INCHANGÉE
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 8),
                                child: Text(
                                  'Date de naissance',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1976D2),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: _pickDateNaissance,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 0, vertical: 12),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Color(0xFF4FC3F7), width: 1.5),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Color(0xFF1976D2), width: 2),
                                    ),
                                    suffixIcon: Icon(
                                      Icons.calendar_today,
                                      color: Color(0xFF1976D2),
                                    ),
                                  ),
                                  child: Text(
                                    dateNaissance ?? 'Choisir la date',
                                    style: TextStyle(
                                      fontSize: 16,
                                      // 🔥 CORRIGÉ : colorScheme.onSurface au
                                      // lieu de textTheme.titleMedium — valeur
                                      // garantie non nulle, foncée en clair /
                                      // claire en mode sombre.
                                      color: (dateNaissance == null)
                                          ? Colors.grey[600]
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),

                          // Rôle du membre — INCHANGÉ, + option "Autre"
                          _buildStyledDropdown(
                            label: 'Rôle du Membre',
                            value: _selectedRoleOption,
                            items: rolesDisponibles,
                            onChanged: (value) {
                              setState(() {
                                _selectedRoleOption = value ?? 'Membre';
                                // 🔥 AJOUT : tant que "Autre" est sélectionné,
                                // la valeur réellement enregistrée est le
                                // texte libre (vide tant qu'il n'est pas
                                // saisi) ; sinon c'est le rôle prédéfini.
                                roleMembre = _selectedRoleOption == 'Autre'
                                    ? _autreRoleText
                                    : _selectedRoleOption;
                              });
                            },
                          ),

                          // 🔥 AJOUT : champ "Préciser le rôle", affiché
                          // uniquement quand "Autre" est sélectionné.
                          // Obligatoire dans ce cas uniquement ; la valeur
                          // saisie est enregistrée directement comme rôle
                          // du membre (jamais le mot "Autre").
                          if (_selectedRoleOption == 'Autre')
                            _buildStyledTextField(
                              label: 'Préciser le rôle',
                              initialValue: _autreRoleText,
                              onChanged: (v) {
                                _autreRoleText = v;
                                roleMembre = v;
                              },
                              validator: (v) {
                                if (_selectedRoleOption == 'Autre' &&
                                    (v == null || v.trim().isEmpty)) {
                                  return 'Veuillez préciser le rôle du membre.';
                                }
                                return null;
                              },
                            ),

                          // 🔥 AJOUT : fonctions supplémentaires (optionnel)
                          if (!widget.isAdmin) _buildExtraRolesSection(),

                          // ---- NOUVEAU : section statut juste après Rôle ----
                          _buildStatusSection(),
                          // ----------------------------------------------------

                          // Contact / Téléphone — INCHANGÉ
                          _buildStyledTextField(
                            label: 'Téléphone',
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

                          // Mot de passe admin — INCHANGÉ
                          if (widget.isAdmin) ...[
                            _buildStyledTextField(
                              label: 'Mot de passe',
                              obscureText: true,
                              onChanged: (v) => password = v,
                            ),
                            _buildStyledTextField(
                              label: 'Confirmer le mot de passe',
                              obscureText: true,
                              onChanged: (v) => confirmPassword = v,
                            ),
                          ],

                          const SizedBox(height: 30),

                          // Bouton Soumettre — même design, désactivé et
                          // avec un petit indicateur pendant l'envoi de
                          // la photo vers ImgBB (🔥 AJOUT minimal).
                          ElevatedButton(
                            onPressed: _isUploadingImage ? null : handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 3,
                            ),
                            child: _isUploadingImage
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isEditing ? 'Modifier' : 'Ajouter',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 20),

                          // Lien Annuler — INCHANGÉ
                          TextButton(
                            onPressed: () {
                              if (widget.onClose != null) {
                                widget.onClose!();
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
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

// Custom Painter pour la vague — INCHANGÉ
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