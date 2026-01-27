import 'package:flutter/material.dart';
import '../navigation/user_navigator.dart';

class UserScreen extends StatelessWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // On récupère les infos user envoyées via Navigator.pushNamed
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    // On sécurise un minimum
    final userRole = args?['role']?.toString() ?? 'membre';
    final userName = args?['prenom'] ?? args?['name'] ?? 'Utilisateur';
    final profileImage = args?['profileImage'] as String?;

    // ✅ Retourner directement le UserDrawerNavigator qui a déjà son propre Scaffold
    // Pas besoin d'envelopper dans un autre Scaffold
    return UserDrawerNavigator(
      userRole: userRole,
      userName: userName,
      profileImage: profileImage,
    );
  }
}