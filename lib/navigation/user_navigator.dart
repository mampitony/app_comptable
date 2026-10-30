// lib/navigation/user_drawer_navigator.dart
import 'package:app_comptable/screens/auth_screen.dart';
import 'package:flutter/material.dart';

import '../screens/admin_screen.dart';
import '../screens/dashboard_screen.dart'; // 📊 AJOUT
import '../screens/revenu_screen.dart';
import '../screens/depense_screen.dart';
import '../screens/historique_screen.dart';
import '../screens/annoucement_screen.dart'; // ✅ AJOUT
import '../services/image_upload_service.dart';
import 'space_switcher.dart';
import '../chat/chat_icon_button.dart'; // 💬 AJOUT : messagerie

class UserDrawerNavigator extends StatefulWidget {
  final String userRole;
  final String userName;
  final String? profileImage;

  /// 🔥 AJOUT : données de l'utilisateur connecté (fonctions + droit admin),
  /// pour proposer « Changer d'espace » quand il a plusieurs rôles.
  final Map<String, dynamic>? userData;

  const UserDrawerNavigator({
    super.key,
    required this.userRole,
    required this.userName,
    this.profileImage,
    this.userData,
  });

  @override
  State<UserDrawerNavigator> createState() => _UserDrawerNavigatorState();
}

class _UserDrawerNavigatorState extends State<UserDrawerNavigator> {
  int _selectedIndex = 0;

  bool get _canSwitchSpace =>
      widget.userData != null &&
      SpaceSwitcher.spacesFor(widget.userData!).length > 1;

  final List<String> _titles = [
    'Tableau de bord', // 📊 AJOUT (index 0)
    'Gestion des Revenus',
    'Suivi des Dépenses',
    'Historique Global',
    'Annonces',            // ✅ AJOUT
  ];

  @override
  Widget build(BuildContext context) {
    final bool canEdit =
        widget.userRole == 'Tresorier' ||
        widget.userRole == 'Commissaire au compte';

    final List<Widget> screens = [
      const DashboardScreen(), // 📊 AJOUT (index 0)
      RevenuScreen(
        canEdit: canEdit,
        userName: widget.userName,
        userRole: widget.userRole,
        profileImage: widget.profileImage,
      ),
      DepenseScreen(
        canEdit: canEdit,
        userName: widget.userName,
        userRole: widget.userRole,
        profileImage: widget.profileImage,
      ),
      const HistoriqueScreen(),
      // ✅ On passe le userRole à AnnouncementScreen pour gérer les droits
      AnnouncementScreen(userRole: widget.userRole),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0163D2),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // 💬 AJOUT : icône de messagerie (espace membre uniquement)
        actions: [
          if (widget.userData != null)
            ChatIconButton(userData: widget.userData!),
        ],
      ),
      drawer: _buildModernDrawer(),
      body: screens[_selectedIndex],
    );
  }

  Widget _buildModernDrawer() {
    return Drawer(
      child: Column(
        children: [
          _buildUserHeader(),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                // 📊 AJOUT : Tableau de bord, au-dessus de Revenu
                _buildDrawerItem(
                  Icons.dashboard_rounded,
                  'Tableau de bord',
                  0,
                ),
                _buildDrawerItem(
                  Icons.account_balance_wallet_rounded,
                  'Revenu',
                  1,
                ),
                _buildDrawerItem(
                  Icons.shopping_cart_checkout_rounded,
                  'Dépenses',
                  2,
                ),
                _buildDrawerItem(
                  Icons.history_rounded,
                  'Historique',
                  3,
                ),
                // ✅ AJOUT : item Annonces visible pour tous les membres
                _buildDrawerItem(
                  Icons.campaign_rounded,
                  'Annonces',
                  4,
                ),
              ],
            ),
          ),
          // 🔥 AJOUT : bascule entre les rôles / espaces du membre
          if (_canSwitchSpace)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                leading: Icon(Icons.swap_horiz_rounded,
                    color: Colors.grey.shade600),
                title: const Text(
                  'Changer d\'espace',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(context);
                  SpaceSwitcher.showSwitcher(
                    context,
                    widget.userData!,
                    currentKey: 'role:${widget.userRole}',
                  );
                },
              ),
            ),
          const Divider(indent: 20, endIndent: 20),
          _buildDrawerItem(
            Icons.logout_rounded,
            'Déconnexion',
            -1,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    // 🔥 CORRIGÉ : calculé une seule fois, pour piloter à la fois
    // `backgroundImage` et savoir si `onBackgroundImageError` peut être
    // fourni (CircleAvatar interdit ce callback quand backgroundImage
    // est null — c'est l'erreur observée : "backgroundImage != null ||
    // onBackgroundImageError == null").
    final avatarProvider =
        ImageUploadService.resolveImageProvider(widget.profileImage);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0163D2), Color(0xFF0D47A1)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFF0163D2),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white,
                backgroundImage: avatarProvider,
                onBackgroundImageError:
                    avatarProvider != null ? (exception, stackTrace) {} : null,
                child:
                    (widget.profileImage == null ||
                        widget.profileImage!.isEmpty)
                    ? const Icon(
                        Icons.person,
                        size: 50,
                        color: Color(0xFF0163D2),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.userName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
            ),
            child: Text(
              widget.userRole.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    int index, {
    Color? color,
  }) {
    final bool isSelected = _selectedIndex == index;
    final Color activeColor = const Color(0xFF0163D2);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(
        icon,
        color: color ?? (isSelected ? activeColor : Colors.grey.shade600),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: color ?? (isSelected ? activeColor : Colors.black87),
        ),
      ),
      selected: isSelected,
      selectedTileColor: activeColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        if (index == -1) {
          _handleLogout();
        } else {
          setState(() => _selectedIndex = index);
          Navigator.pop(context);
        }
      },
    );
  }

  void _handleLogout() {
    Navigator.pop(context);
    // 🔥 CORRIGÉ : AuthScreen n'a plus de paramètre `userType` (écran de
    // connexion unique). Les callbacks étaient vides ici — une
    // reconnexion depuis cet écran de déconnexion ne menait donc nulle
    // part. Ils redirigent maintenant réellement vers l'espace approprié,
    // avec la même logique automatique (adminRole / role) que le reste
    // de l'application.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => AuthScreen(
          onLoginAsAdmin: (user) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => AdminScreen(
                  userRole:
                      user['role']?.toString() ?? 'admin_principal_membre',
                  userData: user,
                ),
              ),
              (route) => false,
            );
          },
          onLoginAsUser: (user) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => UserDrawerNavigator(
                  userRole: user['role']?.toString() ?? 'membre',
                  userName:
                      user['prenom'] ?? user['name'] ?? 'Utilisateur',
                  profileImage: user['profileImage'] as String?,
                  userData: user,
                ),
              ),
              (route) => false,
            );
          },
        ),
      ),
      (route) => false,
    );
  }
}