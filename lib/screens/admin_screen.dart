// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:app_comptable/screens/gestion_members_screen.dart';
import 'package:app_comptable/screens/configuration_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedMenuIndex = 0;

  final Color primaryDark = const Color(0xFF1E293B);
  final Color accentCyan = const Color(0xFF00AEEF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: primaryDark),
        centerTitle: true,
        title: Text(
          _selectedMenuIndex == 0 ? 'Gestion des membres' : 'Configuration',
          style: TextStyle(
            color: primaryDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        // --- BOUTON DECONNEXION DANS L'APPBAR ---
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            onPressed: () => Navigator.pop(context), // Retour au login
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryDark, const Color(0xFF334155)],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: Color(0xFF00AEEF),
                    size: 50,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Administration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildMenuItem(
              icon: Icons.people_alt_rounded,
              title: 'Gestion membres',
              index: 0,
            ),
            _buildMenuItem(
              icon: Icons.settings_rounded,
              title: 'Configuration',
              index: 1,
            ),

            const Spacer(), // Pousse le bouton vers le bas
            // --- BOUTON DECONNEXION DANS LE MENU ---
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Déconnexion',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // Ferme le menu
                Navigator.pop(context); // Quitte l'écran admin
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedMenuIndex,
        children: const [GestionMembresScreen(), ConfigurationScreen()],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = _selectedMenuIndex == index;

    return ListTile(
      leading: Icon(icon, color: isSelected ? accentCyan : Colors.grey[600]),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryDark : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isSelected ? accentCyan.withOpacity(0.08) : Colors.transparent,
      onTap: () {
        setState(() {
          _selectedMenuIndex = index;
        });
        Navigator.pop(context);
      },
    );
  }
}
