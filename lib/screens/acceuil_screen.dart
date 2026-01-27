import 'package:flutter/material.dart';

class AcceuilScreen extends StatelessWidget {
  final VoidCallback? onNavigateToConnexion;
  
  const AcceuilScreen({
    super.key,
    this.onNavigateToConnexion,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ImageBackground
          Image.asset(
            'assets/comptabilite.jpg',
            fit: BoxFit.cover,
          ),
          
          // Overlay avec dégradé Vert → Cyan
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4CAF50).withOpacity(0.7), // Vert
                  const Color(0xFF06FFF0).withOpacity(0.7), // Cyan
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          // Contenu principal
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  
                  // Header - Nom de l'association
                  _buildHeader(),
                  
                  const SizedBox(height: 30),
                  
                  // Content - Bienvenue + Logo + Bouton
                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === HEADER ===
  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'ASSOCIATIONS DES JEUNES ETUDIANTS DE MAHASOABE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white, // Texte blanc sur fond coloré
            shadows: const [
              Shadow(
                offset: Offset(2, 2),
                blurRadius: 4,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // === CONTENT ===
  Widget _buildContent() {
    return Column(
      children: [
        // Titre "Tongasoa"
        const Text(
          'Tongasoa',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(2, 2),
                blurRadius: 5,
                color: Colors.black54,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        
        // Titre "Bienvenue"
        const Text(
          'Bienvenue',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(2, 2),
                blurRadius: 5,
                color: Colors.black54,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),

        const Text(
          'Welcome',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(2, 2),
                blurRadius: 5,
                color: Colors.black54,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 50),
        
        // Logo CENTRÉ avec bordure Cyan
        Center(
          child: Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF06FFF0), // Bordure Cyan
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06FFF0).withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        
        const Spacer(),
        
        // Bouton "Commencer" - VERT
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50), // Vert
              foregroundColor: Colors.white, // Texte blanc
              padding: const EdgeInsets.symmetric(
                vertical: 15,
                horizontal: 40,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
            ),
            onPressed: () {
              if (onNavigateToConnexion != null) {
                onNavigateToConnexion!();
              }
            },
            child: const Text(
              'Commencer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 40),
      ],
    );
  }
}