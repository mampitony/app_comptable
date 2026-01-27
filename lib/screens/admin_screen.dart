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
  int _selectedMenuIndex = 0; // 0 = Gestion membres, 1 = Configuration

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0163D2),
        title: Text(
          _selectedMenuIndex == 0 ? 'Gestion des membres' : 'Configuration',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        // Le bouton menu (hamburger) sera automatiquement ajouté par Flutter
      ),
      // ✅ Drawer = Menu coulissant
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              // En-tête du drawer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                color: const Color(0xFF0163D2),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.white, size: 50),
                    SizedBox(height: 10),
                    Text(
                      'Administration',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Menu items
              _buildMenuItem(
                icon: Icons.people,
                title: 'Gestion membres',
                index: 0,
              ),
              _buildMenuItem(
                icon: Icons.settings,
                title: 'Configuration',
                index: 1,
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedMenuIndex,
        children: const [
          GestionMembresScreen(),
          ConfigurationScreen(),
        ],
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
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF0163D2) : Colors.grey[700],
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF0163D2) : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
      tileColor: isSelected ? const Color(0xFF0163D2).withOpacity(0.1) : Colors.transparent,
      onTap: () {
        setState(() {
          _selectedMenuIndex = index;
        });
        // Fermer le drawer après la sélection
        Navigator.pop(context);
      },
    );
  }
}