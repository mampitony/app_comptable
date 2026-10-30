// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:app_comptable/screens/gestion_members_screen.dart';
import 'package:app_comptable/screens/configuration_screen.dart';
import 'package:app_comptable/navigation/space_switcher.dart';

class AdminScreen extends StatefulWidget {
  final String userRole;

  /// 🔥 AJOUT : données de l'utilisateur connecté (fonctions + droit admin),
  /// pour proposer « Changer d'espace » quand il a plusieurs rôles.
  final Map<String, dynamic>? userData;

  const AdminScreen({
    Key? key,
    this.userRole = 'admin_principal_membre',
    this.userData,
  }) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedMenuIndex = 0;

  static const String adminPrincipalRole = 'admin_principal_membre';
  static const String adminGestionRole = 'admin_gestion_membre';

  bool get isAdminGestion =>
      widget.userRole == adminGestionRole;

  bool get canAccessConfiguration =>
      widget.userRole == adminPrincipalRole;

  bool get _canSwitchSpace =>
      widget.userData != null &&
      SpaceSwitcher.spacesFor(widget.userData!).length > 1;

  final Color primaryDark = const Color(0xFF1E293B);
  final Color accentCyan = const Color(0xFF00AEEF);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1024;

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
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            iconSize: isSmallScreen ? 22 : 26,
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
        ],
      ),
      drawer: Drawer(
        width: isTablet ? 320 : (isSmallScreen ? 280 : 300),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 40 : 50,
                horizontal: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryDark, const Color(0xFF334155)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: const Color(0xFF00AEEF),
                    size: isSmallScreen ? 45 : 55,
                  ),
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  Text(
                    'Administration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            _buildMenuItem(
              icon: Icons.people_alt_rounded,
              title: 'Gestion membres',
              index: 0,
              isSmallScreen: isSmallScreen,
            ),
            if (canAccessConfiguration)
              _buildMenuItem(
                icon: Icons.settings_rounded,
                title: 'Configuration',
                index: 1,
                isSmallScreen: isSmallScreen,
              ),
            const Spacer(),
            // 🔥 AJOUT : bascule entre les rôles / espaces du membre
            if (_canSwitchSpace)
              ListTile(
                leading: Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.grey[700],
                  size: isSmallScreen ? 22 : 26,
                ),
                title: Text(
                  'Changer d\'espace',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  SpaceSwitcher.showSwitcher(
                    context,
                    widget.userData!,
                    currentKey: 'admin:${widget.userRole}',
                  );
                },
              ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Colors.redAccent,
                size: isSmallScreen ? 22 : 26,
              ),
              title: Text(
                'Déconnexion',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
            SizedBox(height: isSmallScreen ? 15 : 20),
          ],
        ),
      ),
      // 🔥 CORRIGÉ : le rôle de l'utilisateur connecté (widget.userRole)
      // n'était jamais transmis à GestionMembresScreen, qui retombait donc
      // toujours sur sa valeur par défaut. currentUserRole doit refléter
      // l'utilisateur réellement connecté pour que les actions
      // d'attribution/retrait du droit administrateur soient correctement
      // autorisées ou bloquées.
      body: IndexedStack(
        index: _selectedMenuIndex,
        children: [
          GestionMembresScreen(currentUserRole: widget.userRole),
          const ConfigurationScreen(),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required int index,
    required bool isSmallScreen,
  }) {
    final isSelected = _selectedMenuIndex == index;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? accentCyan : Colors.grey[600],
        size: isSmallScreen ? 22 : 26,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryDark : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: isSmallScreen ? 14 : 16,
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