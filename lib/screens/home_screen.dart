import 'package:flutter/material.dart';

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
      backgroundColor: const Color(0xFFF3F6FF),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ------------ TITRE ------------
              const Text(
                "Vohibato tsa mipody vato zinera",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 10),

              // ------------ GRAND CERCLE DU HAUT ------------
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00AEEF), Color(0xFF0085D1)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.account_circle,
                    color: Colors.white,
                    size: 120,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                "Choisissez votre catégorie",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 30),

              // ------------ LIGNE A-B-C ------------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCircleButton(
                    label: "A",
                    color: Colors.blueAccent,
                    onTap: () => onNavigateToAuth("admin"),
                  ),
                  const SizedBox(width: 30),
                  _buildCircleButton(
                    label: "U",
                    color: Colors.orangeAccent,
                    onTap: () => onNavigateToAuth("user"),
                  ),
                  const SizedBox(width: 30),
                  _buildCircleButton(
                    label: "D",
                    color: Colors.lightBlue,
                    onTap: onNavigateToDebug,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ------------ NOMS EN TEXTE -------------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(width: 70, child: Text("Admin", textAlign: TextAlign.center)),
                  SizedBox(width: 70, child: Text("Utilisateur", textAlign: TextAlign.center)),
                  SizedBox(width: 70, child: Text("Debug", textAlign: TextAlign.center)),
                ],
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------
  // BOUTON CERCLE STYLE PREMIUM
  // ------------------------------
  Widget _buildCircleButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.9), color],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
