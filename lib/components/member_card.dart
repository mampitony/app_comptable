// lib/components/member_card.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemberCard extends StatefulWidget {
  final Map<String, dynamic> member;

  const MemberCard({super.key, required this.member});

  @override
  State<MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<MemberCard> {
  final GlobalKey _globalKey = GlobalKey();

  static const double cardWidth = 320.0;
  static const double cardHeight = 620.0;

  static const Color ajemBlue = Color(0xFF0099FF);
  static const Color ajemGreen = Color(0xFF22C55E);
  static const Color ajemCyan = Color(0xFF06FFF0);
  static const Color ajemDark = Color(0xFF1A4D6D);

  String _companyAcronym = "AJEM";
  String _companySlogan = "« Ndao handray andraikitra, hitondra fampandrosoana ! »";
  String? _appLogoPath;

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();
  }

  Future<void> _loadCompanyInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyAcronym = prefs.getString('company_acronym') ?? "AJEM";
      _companySlogan = prefs.getString('company_slogan') ?? 
          "« Ndao handray andraikitra, hitondra fampandrosoana ! »";
      _appLogoPath = prefs.getString('app_logo_path');
    });
  }

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
      await Future.delayed(const Duration(milliseconds: 300));

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

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/carte_${_companyAcronym.toLowerCase()}_${widget.member['id'] ?? 'temp'}.png');
      await file.writeAsBytes(imageBytes);

      if (!context.mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Carte de membre $_companyAcronym - ${_capitalize(widget.member['name'] ?? '')} ${_capitalize(widget.member['prenom'] ?? '')}',
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
        title: Text('Carte de Membre $_companyAcronym'),
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
                    Container(color: Colors.white),

                    // Section supérieure dégradée
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

                    // Section inférieure bleue foncée
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClipPath(
                        clipper: InvertedVShapeClipper(),
                        child: Container(height: 190, color: ajemDark),
                      ),
                    ),

                    // ✅ Contenu principal
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ✅ Partie supérieure (Header + Avatar)
                          Column(
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 10),
                              _buildAvatar(),
                            ],
                          ),

                          // ✅ Partie centrale BLANCHE (Nom + Rôle + Niveau + ID)
                          Column(
                            children: [
                              _buildIdentity(),
                              const SizedBox(height: 8),
                              _buildOffice(),
                              const SizedBox(height: 16),
                              _buildID(), // ✅ ID ICI dans la section blanche
                            ],
                          ),

                          // ✅ Partie inférieure (QR + Slogan)
                          Column(
                            children: [
                              _buildQRSection(),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ],
                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: ClipOval(
              child: _appLogoPath != null && _appLogoPath!.isNotEmpty
                  ? Image.file(
                      File(_appLogoPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.business,
                        color: Color(0xFF0099FF),
                        size: 35,
                      ),
                    )
                  : Image.asset(
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
          Text(
            _companyAcronym.toUpperCase(),
            style: const TextStyle(
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
        child: widget.member['profileImage'] != null &&
                (widget.member['profileImage'] as String).isNotEmpty
            ? Image.file(
                File(widget.member['profileImage']),
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
            _capitalize('${widget.member['name'] ?? ''} ${widget.member['prenom'] ?? ''}'),
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
          ),
          const SizedBox(height: 10),
          Text(
            (widget.member['role'] ?? 'MEMBRE').toUpperCase(),
            textAlign: TextAlign.center,
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
        '${widget.member['niveau'] ?? ''} - ${widget.member['mention'] ?? ''}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF7A8A99),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ✅ ID dans la section BLANCHE avec couleurs appropriées
  Widget _buildID() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            const TextSpan(
              text: 'ID : ',
              style: TextStyle(
                color: Color(0xFF2C3E50), // Gris foncé pour fond blanc
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: widget.member['id']?.toString().padLeft(12, '0') ?? '000000000000',
              style: const TextStyle(
                color: Color(0xFF0099FF), // Bleu vif pour contraste
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
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
            // decoration: BoxDecoration(
            //   borderRadius: BorderRadius.circular(8),
            //   border: Border.all(color: ajemCyan, width: 2),
            // ),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _companySlogan,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Color.fromARGB(255, 244, 245, 245),
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
ID:${widget.member['id']}
NOM:${widget.member['name'] ?? ''} ${widget.member['prenom'] ?? ''}
ROLE:${widget.member['role'] ?? 'MEMBRE'}
NIVEAU:${widget.member['niveau'] ?? ''} - ${widget.member['mention'] ?? ''}
ETABL:${widget.member['etablissement'] ?? ''}
ASSO:$_companyAcronym
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
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.68);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, size.height * 0.68);
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
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height * 0.38);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, size.height * 0.38);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}