import 'package:flutter/material.dart';
import 'dart:ui';

class HomeScreen extends StatelessWidget {
  final void Function(String userType) onNavigateToAuth;
  final VoidCallback onNavigateToDebug;

  const HomeScreen({
    super.key,
    required this.onNavigateToAuth,
    required this.onNavigateToDebug,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    
    // Calcul des tailles adaptatives
    final isVerySmallScreen = screenHeight < 700;
    final isSmallScreen = screenWidth < 600;
    
    // Facteur de réduction pour petits écrans
    final scaleFactor = isVerySmallScreen ? 0.75 : (screenHeight < 800 ? 0.85 : 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: Stack(
        children: [
          _buildBackgroundStructure(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 20 : 40,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(height: 20 * scaleFactor),
                          _buildFinanceHeader(scaleFactor),
                          SizedBox(height: 20 * scaleFactor),
                          _buildCentralDashboardIcon(scaleFactor),
                          SizedBox(height: 20 * scaleFactor),
                          _buildProfileSelector(scaleFactor, isSmallScreen),
                          SizedBox(height: 20 * scaleFactor),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceHeader(double scaleFactor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scaleFactor),
      child: Column(
        children: [
          SizedBox(height: 12 * scaleFactor),
          Text(
            "La clarté dans vos comptes,",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22 * scaleFactor,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            "l'avenir dans vos projets.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24 * scaleFactor,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 15 * scaleFactor),
          Container(
            height: 3,
            width: 40 * scaleFactor,
            color: const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  Widget _buildCentralDashboardIcon(double scaleFactor) {
    return Container(
      padding: EdgeInsets.all(35 * scaleFactor),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00AEEF).withOpacity(0.1),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120 * scaleFactor,
            height: 120 * scaleFactor,
            child: CircularProgressIndicator(
              value: 0.7,
              strokeWidth: 8 * scaleFactor,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00AEEF)),
              backgroundColor: const Color(0xFFE2E8F0),
            ),
          ),
          Icon(
            Icons.insights_rounded,
            size: 50 * scaleFactor,
            color: const Color(0xFF1E293B),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSelector(double scaleFactor, bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 15 : 25),
      padding: EdgeInsets.all(20 * scaleFactor),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "SÉLECTIONNEZ VOTRE PORTAIL",
            style: TextStyle(
              fontSize: 11 * scaleFactor,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 25 * scaleFactor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModernAction(
                label: "Admin",
                icon: Icons.admin_panel_settings,
                color: const Color(0xFF1E293B),
                onTap: () => onNavigateToAuth("admin"),
                scaleFactor: scaleFactor,
              ),
              _buildModernAction(
                label: "Membre",
                icon: Icons.person_rounded,
                color: const Color(0xFF00AEEF),
                onTap: () => onNavigateToAuth("user"),
                scaleFactor: scaleFactor,
              ),
              _buildModernAction(
                label: "Outils",
                icon: Icons.construction_rounded,
                color: const Color(0xFF4CAF50),
                onTap: onNavigateToDebug,
                scaleFactor: scaleFactor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double scaleFactor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 65 * scaleFactor,
            width: 65 * scaleFactor,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28 * scaleFactor,
            ),
          ),
          SizedBox(height: 10 * scaleFactor),
          Text(
            label,
            style: TextStyle(
              fontSize: 13 * scaleFactor,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundStructure() {
    return Positioned(
      top: -100,
      left: -50,
      child: Transform.rotate(
        angle: 0.5,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF00AEEF).withOpacity(0.05),
              width: 40,
            ),
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      ),
    );
  }
}