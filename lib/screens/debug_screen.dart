import 'package:flutter/material.dart';
import '../database/user_repository.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final _userRepo = UserRepository();
  List<Map<String, dynamic>> users = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    setState(() => isLoading = true);
    final allUsers = await _userRepo.getAllUsers();
    setState(() {
      users = allUsers;
      isLoading = false;
    });
  }

  Future<void> handleResetAll() async {
    final confirm = await _showConfirm(
      'Confirmation',
      'Voulez-vous réinitialiser le mot de passe de TOUS les membres (sauf admin) ?',
    );
    if (confirm != true) return;

    try {
      await _userRepo.resetAllMemberPasswords();
      await _showAlert(
          'Succès', 'Tous les mots de passe ont été réinitialisés');
      await loadUsers();
    } catch (e) {
      await _showAlert('Erreur', e.toString());
    }
  }

  Future<void> handleResetOne(int id, String email) async {
    final confirm = await _showConfirm(
      'Confirmation',
      'Réinitialiser le mot de passe de $email ?',
    );
    if (confirm != true) return;

    try {
      await _userRepo.resetMemberPassword(id);
      await _showAlert('Succès', 'Mot de passe réinitialisé');
      await loadUsers();
    } catch (e) {
      await _showAlert('Erreur', e.toString());
    }
  }

  Future<void> _showAlert(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  Future<bool?> _showConfirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Oui'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    const Text(
                      '🔧 Écran de Débogage',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Liste des utilisateurs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B6B),
                        ),
                        onPressed: handleResetAll,
                        child: const Text(
                          '🔄 Réinitialiser TOUS les mots de passe (sauf admin)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                        ),
                        onPressed: loadUsers,
                        child: const Text('♻️ Rafraîchir la liste'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: users.isEmpty
                          ? const Center(
                              child: Text('Aucun utilisateur'),
                            )
                          : ListView.builder(
                              itemCount: users.length,
                              itemBuilder: (ctx, index) {
                                final user = users[index];
                                final passwordHash =
                                    user['passwordHash'] as String?;
                                final hashLen =
                                    passwordHash != null ? passwordHash.length : 0;
                                final isActivated =
                                    passwordHash != null && passwordHash.isNotEmpty;

                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  elevation: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user['name'] ??
                                              user['email'] ??
                                              'Sans nom',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF333333),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '📧 Email: ${user['email'] ?? '-'}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF666666),
                                          ),
                                        ),
                                        Text(
                                          '👤 Rôle: ${user['role'] ?? 'user'}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF666666),
                                          ),
                                        ),
                                        Text(
                                          '🔐 Mot de passe: ${isActivated ? '✅ Activé' : '❌ Non activé'}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF333333),
                                          ),
                                        ),
                                        Text(
                                          '📏 Longueur hash: $hashLen',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF999999),
                                          ),
                                        ),
                                        if (user['role'] != 'admin')
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFFFF9800),
                                              ),
                                              onPressed: () => handleResetOne(
                                                  user['id'] as int,
                                                  user['email'] as String),
                                              child: const Text(
                                                  '🔄 Réinitialiser ce compte'),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Ici on remonte au stack Connexion
                          Navigator.of(context).maybePop();
                        },
                        child: const Text('← Retour à l\'accueil'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
