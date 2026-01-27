import 'package:flutter/material.dart';

class AcceuilScreen extends StatelessWidget {
  final VoidCallback? onNavigateToConnexion;

  const AcceuilScreen({super.key, this.onNavigateToConnexion});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF), // Blanc pur pour la clarté
      body: Stack(
        children: [
          // Aura lumineuse en arrière-plan (rappel du home_screen)
          _buildBackgroundAura(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 80),
                  
                  // LOGO GLOBAL MINIMALISTE
                  _buildGlobalBranding(),

                  const Spacer(),

                  // VISUEL DE COMPTABILITÉ MODERNE
                  _buildVisualElement(),

                  const Spacer(),

                  // SECTION TEXTE D'IMPACT
                  _buildHeroText(),

                  const SizedBox(height: 50),

                  // BOUTON D'ACTION PRINCIPAL
                  _buildPrimaryButton(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundAura() {
    return Positioned(
      top: -150,
      right: -100,
      child: Container(
        width: 400,
        height: 400,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              const Color(0xFF00AEEF).withOpacity(0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalBranding() {
    return Column(
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E293B).withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 15),
        const Text(
          "CORE LEDGER",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildVisualElement() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00AEEF).withOpacity(0.1), width: 2),
      ),
      child: const Icon(
        Icons.analytics_outlined,
        size: 80,
        color: Color(0xFF00AEEF),
      ),
    );
  }

  Widget _buildHeroText() {
    return Column(
      children: [
        const Text(
          "La comptabilité,",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w300,
            color: Color(0xFF64748B),
          ),
        ),
        const Text(
          "réinventée.",
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Une solution globale de gestion pour piloter vos actifs avec une précision absolue.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF94A3B8),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton() {
    return GestureDetector(
      onTap: onNavigateToConnexion,
      child: Container(
        width: double.infinity,
        height: 65,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withOpacity(0.3),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            "COMMENCER",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}