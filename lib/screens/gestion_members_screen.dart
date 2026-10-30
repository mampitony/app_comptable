// lib/screens/gestion_membres_screen.dart
import 'package:flutter/material.dart';
import 'package:app_comptable/components/member_list.dart';
import 'package:app_comptable/components/member_form.dart';
import 'package:app_comptable/database/firebase_user_repository.dart';

class GestionMembresScreen extends StatefulWidget {
  /// Rôle de l'utilisateur connecté.
  /// Seul l'administrateur principal peut attribuer ou retirer
  /// le rôle administrateur gestion membre.
  final String currentUserRole;

  const GestionMembresScreen({
    Key? key,
    this.currentUserRole = FirebaseUserRepository.adminPrincipalRole,
  }) : super(key: key);

  @override
  State<GestionMembresScreen> createState() => _GestionMembresScreenState();
}

class _GestionMembresScreenState extends State<GestionMembresScreen> {
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();

  // Autorisations module gestion des membres
  static const String adminPrincipalRole =
      FirebaseUserRepository.adminPrincipalRole;
  static const String adminGestionRole =
      FirebaseUserRepository.adminGestionRole;

  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  /// Seul l'administrateur principal dispose des actions sur les rôles.
  bool get _isAdminPrincipal => widget.currentUserRole == adminPrincipalRole;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await _userRepo.getAllMembers();
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _showMemberForm({Map<String, dynamic>? member}) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? screenSize.width * 0.95 : 600,
          ),
          child: MemberForm(
            member: member,
            isAdmin: false,
            onClose: () {
              Navigator.pop(context);
              _loadMembers();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleEdit(Map<String, dynamic> member) async {
    _showMemberForm(member: member);
  }

  /// Confirmation générique pour les actions sur les rôles.
  Future<bool> _confirmRoleAction({
    required String title,
    required String message,
    required String actionLabel,
    required Color actionColor,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: actionColor),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    return confirm == true;
  }

  /// Attribue le rôle administrateur gestion membre.
  /// Le nombre d'administrateurs gestion membre n'est pas limité.
  Future<void> _promoteToAdminGestion(String memberId) async {
    if (!_isAdminPrincipal) {
      _showMessage(
        "Seul l'administrateur principal peut attribuer ce rôle.",
      );
      return;
    }

    final member = _findMember(memberId);
    final nom = _displayName(member);

    final ok = await _confirmRoleAction(
      title: 'Attribuer le rôle',
      message:
          "Autoriser $nom comme administrateur gestion membre ?\n\n"
          "Sa fonction dans l'association reste inchangée.",
      actionLabel: 'Autoriser',
      actionColor: Colors.orange,
    );

    if (!ok) return;

    try {
      await _userRepo.promoteMemberToAdminGestion(memberId);
      await _loadMembers();
      _showMessage('$nom est administrateur gestion membre');
    } catch (e) {
      _showMessage('Erreur: $e');
    }
  }

  /// Retire le rôle administrateur gestion membre.
  /// Le compte n'est pas supprimé : le membre redevient un membre normal.
  Future<void> _removeAdminGestionRole(String memberId) async {
    if (!_isAdminPrincipal) {
      _showMessage(
        "Seul l'administrateur principal peut retirer ce rôle.",
      );
      return;
    }

    final member = _findMember(memberId);
    final nom = _displayName(member);

    final ok = await _confirmRoleAction(
      title: 'Retirer le rôle',
      message:
          "Retirer le rôle administrateur gestion membre à $nom ?\n\n"
          "Le compte n'est pas supprimé : $nom redevient un membre normal.",
      actionLabel: 'Retirer',
      actionColor: Colors.redAccent,
    );

    if (!ok) return;

    try {
      await _userRepo.removeAdminGestionRole(memberId);
      await _loadMembers();
      _showMessage('Rôle administrateur gestion membre retiré');
    } catch (e) {
      _showMessage('Erreur: $e');
    }
  }

  Map<String, dynamic>? _findMember(String id) {
    for (final m in _members) {
      if (m['id'].toString() == id) return m;
    }
    return null;
  }

  String _displayName(Map<String, dynamic>? member) {
    if (member == null) return 'ce membre';
    final nom = (member['name'] ?? '').toString().trim();
    final prenom = (member['prenom'] ?? '').toString().trim();
    final complet = '$nom $prenom'.trim();
    return complet.isEmpty ? 'ce membre' : complet;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleDelete(String memberId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer ce membre ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _userRepo.deleteUser(memberId);
        await _loadMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Membre supprimé avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final horizontalPadding = isSmallScreen ? 16.0 : 24.0;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestion des membres',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _members.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: isSmallScreen ? 60 : 80,
                                    color: Colors.grey.shade300,
                                  ),
                                  SizedBox(height: isSmallScreen ? 12 : 16),
                                  Text(
                                    'Aucun membre',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : MemberList(
                              members: _members,
                              onEdit: _handleEdit,
                              onDelete: _handleDelete,
                              // Actions sur les rôles visibles uniquement
                              // pour l'administrateur principal.
                              isAdminPrincipal: _isAdminPrincipal,
                              onPromoteAdminGestion: _promoteToAdminGestion,
                              onRemoveAdminGestionRole: _removeAdminGestionRole,
                            ),
                ),
              ],
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMemberForm(),
        backgroundColor: const Color(0xFF0163D2),
        icon: Icon(
          Icons.add,
          color: Colors.white,
          size: isSmallScreen ? 20 : 24,
        ),
        label: Text(
          'Ajouter',
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 13 : 15,
          ),
        ),
      ),
    );
  }
}