// lib/components/member_card.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class MemberCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final GlobalKey _globalKey = GlobalKey();

  static const double cardWidth = 320.0;
  static const double cardHeight = 620.0;

  static const Color ajemBlue = Color(0xFF0099FF);
  static const Color ajemGreen = Color(0xFF22C55E);
  static const Color ajemCyan = Color(0xFF06FFF0);
  static const Color ajemDark = Color(0xFF1A4D6D);

  MemberCard({super.key, required this.member});

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value
        .trim()
        .toLowerCase()
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '',
        )
        .join(' ');
  }

  Future<void> _saveAndShareCard(BuildContext context) async {
    try {
      // Délai pour laisser le temps au widget de se stabiliser
      await Future.delayed(const Duration(milliseconds: 300));

      // Vérifier que le context existe
      if (_globalKey.currentContext == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur: Widget non initialisé'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Capturer l'image avec RenderRepaintBoundary
      RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Capture échouée – veuillez réessayer'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final Uint8List imageBytes = byteData.buffer.asUint8List();

      // Sauvegarder dans un fichier temporaire
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/carte_ajem_${member['id'] ?? 'temp'}.png');
      await file.writeAsBytes(imageBytes);

      // Partager le fichier
      if (!context.mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Carte de membre AJEM - ${_capitalize(member['name'] ?? '')} ${_capitalize(member['prenom'] ?? '')}',
      );
    } catch (e, stack) {
      debugPrint('Erreur partage/capture: $e\n$stack');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString().split('\n').first}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Carte de Membre AJEM'),
        backgroundColor: ajemBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _saveAndShareCard(context),
            tooltip: 'Partager / Télécharger',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: RepaintBoundary(
            key: _globalKey,
            child: Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Fond blanc
                    Container(color: Colors.white),

                    // Section supérieure avec forme en V (clipper personnalisé)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ClipPath(
                        clipper: VShapeClipper(),
                        child: Container(
                          height: 280,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [ajemBlue, ajemGreen],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Section inférieure avec forme en V inversé
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClipPath(
                        clipper: InvertedVShapeClipper(),
                        child: Container(height: 200, color: ajemDark),
                      ),
                    ),

                    // Contenu principal
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 10),
                        _buildAvatar(),
                        const SizedBox(height: 20),
                        _buildIdentity(),
                        const SizedBox(height: 4),
                        _buildOffice(),
                        const SizedBox(height: 12),
                        _buildID(),
                        const SizedBox(height: 16),
                        _buildQRSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          // Logo
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: ClipOval(
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.business,
                  color: Color(0xFF0099FF),
                  size: 35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Nom de l'organisation
          const Text(
            'AJEM',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
              letterSpacing: 2.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child:
            member['profileImage'] != null &&
                (member['profileImage'] as String).isNotEmpty
            ? Image.file(
                File(member['profileImage']),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.person, size: 80, color: Colors.grey),
                ),
              )
            : Container(
                color: Colors.grey[300],
                child: const Icon(Icons.person, size: 80, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _buildIdentity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            _capitalize('${member['name'] ?? ''} ${member['prenom'] ?? ''}'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.4,
              height: 1.25,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
          const SizedBox(height: 10),
          Text(
            (member['role'] ?? 'MEMBRE').toUpperCase(),
            style: TextStyle(
              color: ajemBlue,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffice() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        '${member['niveau'] ?? ''} - ${member['mention'] ?? ''}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF7A8A99),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildID() {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'ID : ',
            style: TextStyle(
              color: ajemCyan,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: member['id']?.toString().padLeft(12, '0') ?? '000000000000',
            style: TextStyle(
              color: ajemCyan,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 50),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ajemCyan, width: 2),
            ),
            child: QrImageView(
              data: _generateQRData(),
              version: QrVersions.auto,
              size: 85,
              backgroundColor: Colors.transparent,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.white,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "« Ndao handray andraikitra, hitondra fampandrosoana ! »",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: ui.Color.fromARGB(255, 244, 245, 245), // ou Colors.black87 pour plus de contraste
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  String _generateQRData() {
    return '''
ID:${member['id']}
NOM:${member['name'] ?? ''} ${member['prenom'] ?? ''}
ROLE:${member['role'] ?? 'MEMBRE'}
NIVEAU:${member['niveau'] ?? ''} - ${member['mention'] ?? ''}
ETABL:${member['etablissement'] ?? ''}
ASSO:AJEM Mahasoabe
''';
  }
}

// ────────────────────────────────────────────────
//  Custom Clipper pour la forme en V du haut
// ────────────────────────────────────────────────
class VShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Commence en haut à gauche
    path.lineTo(0, 0);
    // Ligne du haut
    path.lineTo(size.width, 0);
    // Côté droit
    path.lineTo(size.width, size.height * 0.68);
    // Pointe du V (au centre bas)
    path.lineTo(size.width / 2, size.height);
    // Côté gauche
    path.lineTo(0, size.height * 0.68);
    // Fermer
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ────────────────────────────────────────────────
//  Custom Clipper pour la forme en V inversé du bas
// ────────────────────────────────────────────────
class InvertedVShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Commence au centre haut (pointe du V inversé)
    path.moveTo(size.width / 2, 0);
    // Ligne vers le coin bas droit
    path.lineTo(size.width, size.height * 0.38);
    // Côté droit vers le bas
    path.lineTo(size.width, size.height);
    // Ligne du bas
    path.lineTo(0, size.height);
    // Côté gauche vers le haut
    path.lineTo(0, size.height * 0.38);
    // Retour au centre
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
