import 'package:app_comptable/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'dart:io';
// ⚠️ Assure-toi que ce chemin correspond à ton fichier de connexion

import '../screens/revenu_screen.dart';
import '../screens/depense_screen.dart';
import '../screens/historique_screen.dart';

class UserDrawerNavigator extends StatefulWidget {
  final String userRole;
  final String userName;
  final String? profileImage;

  const UserDrawerNavigator({
    super.key,
    required this.userRole,
    required this.userName,
    this.profileImage,
  });

  @override
  State<UserDrawerNavigator> createState() => _UserDrawerNavigatorState();
}

class _UserDrawerNavigatorState extends State<UserDrawerNavigator> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Gestion des Revenus',
    'Suivi des Dépenses',
    'Historique Global',
  ];

  @override
  Widget build(BuildContext context) {
    final bool canEdit =
        widget.userRole == 'Tresorier' ||
        widget.userRole == 'Commissaire au compte';

    final List<Widget> _screens = [
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
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0163D2),
        elevation: 0,
        centerTitle: true,
      ),
      drawer: _buildModernDrawer(),
      body: _screens[_selectedIndex],
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
                _buildDrawerItem(
                  Icons.account_balance_wallet_rounded,
                  'Revenu',
                  0,
                ),
                _buildDrawerItem(
                  Icons.shopping_cart_checkout_rounded,
                  'Dépenses',
                  1,
                ),
                _buildDrawerItem(Icons.history_rounded, 'Historique', 2),
              ],
            ),
          ),
          const Divider(indent: 20, endIndent: 20),
          // Bouton Déconnexion avec couleur rouge
          _buildDrawerItem(
            Icons.logout_rounded,
            'Déconnexion',
            3,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
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
                backgroundImage:
                    widget.profileImage != null &&
                        widget.profileImage!.isNotEmpty
                    ? FileImage(File(widget.profileImage!))
                    : null,
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
        if (index == 3) {
          // --- LOGIQUE DE LOGOUT CORRIGÉE ---
          _handleLogout();
        } else {
          setState(() => _selectedIndex = index);
          Navigator.pop(context);
        }
      },
    );
  }

  void _handleLogout() {
    // 1. On ferme le drawer
    Navigator.pop(context);

    // 2. On remplace tout par l'écran de login pour "nettoyer" la navigation
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => AuthScreen(
          userType: '',
          onLoginAsAdmin: (Map<String, dynamic> user) {},
          onLoginAsUser: (Map<String, dynamic> user) {},
        ),
      ),
      (route) => false, // Supprime toutes les routes précédentes
    );
  }
}
