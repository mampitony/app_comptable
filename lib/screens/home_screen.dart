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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA), // Gris bleuté très pro
      body: Stack(
        children: [
          // Décor géométrique discret pour le côté "Structure"
          _buildBackgroundStructure(),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // --- SECTION TITRE ET SLOGAN ---
                _buildFinanceHeader(),

                const Spacer(),

                // --- ÉLÉMENT CENTRAL : LE COEUR DE LA GESTION ---
                _buildCentralDashboardIcon(),

                const Spacer(),

                // --- SÉLECTEUR DE PROFIL STYLE "BANKING" ---
                _buildProfileSelector(),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text(
            "La clarté dans vos comptes,",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w400,
              color: Color(0xFF1E293B),
            ),
          ),
          const Text(
            "l'avenir dans vos projets.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 15),
          Container(height: 3, width: 40, color: const Color(0xFF4CAF50)),
        ],
      ),
    );
  }

  Widget _buildCentralDashboardIcon() {
    return Container(
      padding: const EdgeInsets.all(35),
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
          const SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: 0.7, // Décoratif : simule un graphique
              strokeWidth: 8,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00AEEF)),
              backgroundColor: Color(0xFFE2E8F0),
            ),
          ),
          const Icon(
            Icons.insights_rounded,
            size: 50,
            color: Color(0xFF1E293B),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25),
      padding: const EdgeInsets.all(20),
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
        children: [
          const Text(
            "SÉLECTIONNEZ VOTRE PORTAIL",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModernAction(
                label: "Admin",
                icon: Icons.admin_panel_settings,
                color: const Color(0xFF1E293B),
                onTap: () => onNavigateToAuth("admin"),
              ),
              _buildModernAction(
                label: "Membre",
                icon: Icons.person_rounded,
                color: const Color(0xFF00AEEF),
                onTap: () => onNavigateToAuth("user"),
              ),
              _buildModernAction(
                label: "Outils",
                icon: Icons.construction_rounded,
                color: const Color(0xFF4CAF50),
                onTap: onNavigateToDebug,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 65,
            width: 65,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
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
