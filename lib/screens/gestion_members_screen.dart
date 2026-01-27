// lib/screens/gestion_membres_screen.dart
import 'package:flutter/material.dart';
import 'package:app_comptable/components/member_list.dart';
import 'package:app_comptable/components/member_form.dart';
import 'package:app_comptable/database/user_repository.dart';

class GestionMembresScreen extends StatefulWidget {
  const GestionMembresScreen({Key? key}) : super(key: key);

  @override
  State<GestionMembresScreen> createState() => _GestionMembresScreenState();
}

class _GestionMembresScreenState extends State<GestionMembresScreen> {
  final UserRepository _userRepo = UserRepository();
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: MemberForm(
            member: member,
            isAdmin: false,
            onClose: () {
              Navigator.pop(context);
              _loadMembers(); // Recharger la liste après ajout/modification
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleEdit(Map<String, dynamic> member) async {
    _showMemberForm(member: member);
  }

  Future<void> _handleDelete(int memberId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Titre simple sans bouton
            const Text(
              'Gestion des membres',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // ✅ Liste des membres
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : MemberList(
                      members: _members,
                      onEdit: _handleEdit,
                      onDelete: _handleDelete,
                    ),
            ),
          ],
        ),
      ),
      
      // ✅ FloatingActionButton pour ajouter un membre (icône "+" en bas)
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMemberForm(),
        backgroundColor: const Color(0xFF0163D2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}