// lib/navigation/space_switcher.dart
//
// Rôles multiples : un membre peut cumuler plusieurs fonctions
// (ex. Sécretaire + Responsable de Communication) ET un droit
// d'administration. À la connexion — et ensuite à tout moment depuis le
// menu — il choisit l'espace dans lequel il veut travailler.
//
// Les écrans existants ne changent pas : chacun reçoit toujours UN seul
// rôle actif (`userRole`), exactement comme avant.
import 'package:flutter/material.dart';

import '../database/firebase_user_repository.dart';
import '../screens/admin_screen.dart';
import 'user_navigator.dart';

/// Un espace dans lequel l'utilisateur peut travailler :
/// l'espace Administration, ou l'espace Membre avec une fonction précise.
class AppSpace {
  final bool isAdmin;

  /// Droit d'administration (admin_principal_membre / admin_gestion_membre)
  /// si `isAdmin`, sinon la fonction du membre (ex. 'Sécretaire').
  final String role;
  final String label;
  final IconData icon;

  const AppSpace({
    required this.isAdmin,
    required this.role,
    required this.label,
    required this.icon,
  });

  /// Identifiant stable, utilisé pour savoir quel espace est actif.
  String get key => isAdmin ? 'admin:$role' : 'role:$role';
}

class SpaceSwitcher {
  static bool _isGeneric(String role) {
    final r = role.trim().toLowerCase();
    return r == 'membre' || r == 'membre actif';
  }

  static IconData _iconForRole(String role) {
    final r = role.toLowerCase();
    if (r.contains('communication')) return Icons.campaign_rounded;
    if (r.contains('tresor') ||
        r.contains('trésor') ||
        r.contains('commissaire') ||
        r.contains('comptable')) {
      return Icons.account_balance_wallet_rounded;
    }
    return Icons.badge_rounded;
  }

  /// Espaces accessibles à l'utilisateur. Jamais vide.
  ///   - droit d'administration         -> 1 espace Administration
  ///   - chaque fonction « précise »     -> 1 espace Membre
  ///     (une fonction générique comme « Membre » ne compte que s'il n'y a
  ///     rien d'autre et que l'utilisateur n'est pas administrateur)
  /// Un seul espace = connexion directe, comme avant.
  static List<AppSpace> spacesFor(Map<String, dynamic> user) {
    final spaces = <AppSpace>[];

    final adminRole = FirebaseUserRepository.resolveAdminRole(user);
    if (adminRole != null) {
      spaces.add(AppSpace(
        isAdmin: true,
        role: adminRole,
        label: adminRole == FirebaseUserRepository.adminPrincipalRole
            ? 'Administrateur principal'
            : 'Administrateur gestion membres',
        icon: Icons.admin_panel_settings_rounded,
      ));
    }

    final roles = FirebaseUserRepository.resolveRoles(user);
    final specific = roles.where((r) => !_isGeneric(r)).toList();
    final memberRoles = specific.isNotEmpty
        ? specific
        : (adminRole == null ? <String>[roles.first] : <String>[]);

    for (final r in memberRoles) {
      spaces.add(AppSpace(
        isAdmin: false,
        role: r,
        label: r,
        icon: _iconForRole(r),
      ));
    }

    return spaces;
  }

  /// Données transmises aux écrans pour l'espace choisi. `role` = le rôle
  /// ACTIF (comme avant) ; `roles` et `adminRole` permettent de rebasculer.
  static Map<String, dynamic> payload(
    Map<String, dynamic> user,
    AppSpace space,
  ) {
    return {
      'id': user['id'],
      'name': user['name'],
      'prenom': user['prenom'],
      'email': user['email'],
      'profileImage': user['profileImage'],
      'role': space.role,
      FirebaseUserRepository.rolesField:
          FirebaseUserRepository.resolveRoles(user),
      FirebaseUserRepository.adminRoleField:
          FirebaseUserRepository.resolveAdminRole(user),
    };
  }

  /// Menu de choix de l'espace. Renvoie null si l'utilisateur l'ignore.
  static Future<AppSpace?> choose(
    BuildContext context,
    List<AppSpace> spaces, {
    String? currentKey,
  }) {
    return showModalBottomSheet<AppSpace>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choisir un espace',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Vous avez plusieurs rôles. Avec lequel voulez-vous continuer ?',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              for (final s in spaces)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        const Color(0xFF0163D2).withOpacity(0.1),
                    child: Icon(s.icon, color: const Color(0xFF0163D2)),
                  ),
                  title: Text(
                    s.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: s.key == currentKey
                      ? const Icon(Icons.check_circle,
                          color: Color(0xFF0163D2))
                      : const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Remplace l'écran courant par celui de l'espace choisi (la pile de
  /// navigation en dessous — dont l'écran de connexion — est conservée,
  /// donc « Déconnexion » fonctionne comme avant).
  static void switchTo(
    BuildContext context,
    Map<String, dynamic> user,
    AppSpace space,
  ) {
    final data = payload(user, space);
    final Widget page = space.isAdmin
        ? AdminScreen(userRole: space.role, userData: data)
        : UserDrawerNavigator(
            userRole: space.role,
            userName: (data['prenom'] ?? data['name'] ?? 'Utilisateur')
                .toString(),
            profileImage: data['profileImage'] as String?,
            userData: data,
          );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => page,
        settings: RouteSettings(name: space.isAdmin ? '/admin' : '/user'),
      ),
    );
  }

  /// Bouton « Changer d'espace » : menu de choix puis bascule.
  static Future<void> showSwitcher(
    BuildContext context,
    Map<String, dynamic> user, {
    required String currentKey,
  }) async {
    final spaces = spacesFor(user);
    final picked = await choose(context, spaces, currentKey: currentKey);
    if (picked == null || picked.key == currentKey) return;
    if (!context.mounted) return;
    switchTo(context, user, picked);
  }
}
