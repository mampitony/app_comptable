// lib/screens/admin_screen.dart
import 'package:app_comptable/components/member_form.dart';
import 'package:app_comptable/components/member_list.dart';
import 'package:flutter/material.dart';
import '../database/user_repository.dart';

class AdminScreen extends StatefulWidget {
  final Map<String, dynamic>? user; // prenom, profileImage, etc.

  const AdminScreen({
    super.key,
    this.user,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _userRepo = UserRepository();

  List<Map<String, dynamic>> members = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadMembers();
  }

  Future<void> loadMembers() async {
    try {
      if (!mounted) return;
      setState(() => isLoading = true);

      // On récupère tous les utilisateurs
      final users = await _userRepo.getAllUsers();

      if (!mounted) return;
      setState(() {
        members = users;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint('Erreur lors du chargement des membres: $e');
      _showAlert('Erreur', 'Impossible de charger les membres');
    }
  }

  // --- Ouvre le formulaire en mode AJOUT (membre normal) ---
  void openAddMemberForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true, // Permet de fermer en touchant à l'extérieur
      enableDrag: true, // Permet de fermer en glissant vers le bas
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: MemberForm(
            member: null,
            isAdmin: false,
            onClose: () {
              Navigator.of(ctx).pop();
              loadMembers();
            },
          ),
        );
      },
    );
  }

  // --- Ouvre le formulaire en mode AJOUT (admin) ---
  void openAddAdminForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: MemberForm(
            member: null,
            isAdmin: true,
            onClose: () {
              Navigator.of(ctx).pop();
              loadMembers();
            },
          ),
        );
      },
    );
  }

  // --- Ouvre le formulaire en mode MODIFICATION ---
  void openEditMemberForm(Map<String, dynamic> member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: MemberForm(
            member: member,
            isAdmin: member['role'] == 'admin',
            onClose: () {
              Navigator.of(ctx).pop();
              loadMembers();
            },
          ),
        );
      },
    );
  }

  // --- Suppression depuis la liste (avec confirmation & DB) ---
  Future<void> deleteMember(int id) async {
    // CORRECTION: Utiliser le context actuel avec mounted check
    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Empêche de fermer en touchant à l'extérieur
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce membre ?'),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () {
              // IMPORTANT: Utiliser dialogContext pour fermer le dialog
              Navigator.of(dialogContext).pop(false);
            },
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
            onPressed: () {
              // IMPORTANT: Utiliser dialogContext pour fermer le dialog
              Navigator.of(dialogContext).pop(true);
            },
          ),
        ],
      ),
    );

    // Si l'utilisateur a annulé ou fermé le dialog
    if (confirm != true) return;

    // Vérifier que le widget est toujours monté avant de continuer
    if (!mounted) return;

    try {
      // Effectuer la suppression
      final result = await _userRepo.deleteUser(id);
      
      if (!mounted) return;

      if (result > 0) {
        // Suppression réussie
        await loadMembers();
        
        if (!mounted) return;
        
        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Membre supprimé avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Aucune ligne supprimée
        if (!mounted) return;
        _showAlert('Erreur', 'Impossible de supprimer le membre');
      }
    } catch (e) {
      debugPrint('Erreur lors de la suppression: $e');
      if (!mounted) return;
      _showAlert('Erreur', 'Une erreur est survenue lors de la suppression: $e');
    }
  }

  Future<void> _showAlert(String title, String message) async {
    if (!mounted) return;
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              // Utiliser dialogContext pour fermer uniquement le dialog
              Navigator.of(dialogContext).pop();
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final prenom = user?['prenom'] as String?;
    final profileImage = user?['profileImage'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // En-tête avec prénom + photo
              Row(
                children: [
                  if (profileImage != null && profileImage.isNotEmpty)
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(profileImage),
                    ),
                  if (profileImage != null && profileImage.isNotEmpty)
                    const SizedBox(width: 10),
                  Text(
                    prenom ?? 'Gestion des Membres',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Ligne de boutons Ajouter membre / Ajouter admin
              // Row(
              //   children: [
              //     const SizedBox(width: 10),
              //     Expanded(
              //       child: ElevatedButton(
              //         style: ElevatedButton.styleFrom(
              //           backgroundColor: const Color(0xFFFF5722),
              //         ),
              //         onPressed: openAddAdminForm,
              //         child: const Text('Ajouter un admin'),
              //       ),
              //     ),
              //   ],
              // ),
              const SizedBox(height: 20),

              // Liste des membres
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : members.isEmpty
                        ? const Center(
                            child: Text('Aucun membre trouvé.'),
                          )
                        : MemberList(
                            members: members,
                            onEdit: openEditMemberForm,
                            onDelete: deleteMember,
                          ),
              ),
            ],
          ),
        ),
      ),
      // On garde aussi le FAB si tu veux un accès rapide
      floatingActionButton: FloatingActionButton(
        onPressed: openAddMemberForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}