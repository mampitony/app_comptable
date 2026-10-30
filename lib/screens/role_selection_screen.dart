import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  void navigateToLogin(BuildContext context, String userType) {
    Navigator.pushNamed(
      context,
      '/login',
      arguments: {'userType': userType},
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final horizontalPadding = isSmallScreen ? 20.0 : screenSize.width * 0.2;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0163D2),
        title: Text(
          'Choisir votre rôle',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 18 : 22,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                    maxWidth: 600,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: screenSize.height * 0.05),
                        
                        // Icône et titre
                        _buildHeader(isSmallScreen),
                        
                        SizedBox(height: screenSize.height * 0.08),
                        
                        // Bouton Administrateur
                        _buildRoleButton(
                          context: context,
                          label: 'Administrateur',
                          icon: Icons.admin_panel_settings,
                          color: const Color(0xFF0163D2),
                          userType: 'admin_principal_membre',
                          isSmallScreen: isSmallScreen,
                        ),
                        
                        SizedBox(height: isSmallScreen ? 20 : 25),
                        
                        // Bouton Utilisateur
                        _buildRoleButton(
                          context: context,
                          label: 'Utilisateur',
                          icon: Icons.person_rounded,
                          color: const Color(0xFF1E293B),
                          userType: 'user',
                          isSmallScreen: isSmallScreen,
                        ),
                        
                        SizedBox(height: screenSize.height * 0.05),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 20 : 25),
          decoration: BoxDecoration(
            color: const Color(0xFF0163D2).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.how_to_reg_rounded,
            size: isSmallScreen ? 60 : 80,
            color: const Color(0xFF0163D2),
          ),
        ),
        SizedBox(height: isSmallScreen ? 15 : 20),
        Text(
          'Bienvenue',
          style: TextStyle(
            fontSize: isSmallScreen ? 26 : 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        Text(
          'Sélectionnez votre type de compte',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required String userType,
    required bool isSmallScreen,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => navigateToLogin(context, userType),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: isSmallScreen ? 70 : 80,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: isSmallScreen ? 28 : 32,
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 17 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}