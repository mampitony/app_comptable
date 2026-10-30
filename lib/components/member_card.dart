// lib/components/member_card.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../services/company_settings_service.dart';
import '../services/image_upload_service.dart';
import '../database/firebase_user_repository.dart';

class MemberCard extends StatefulWidget {
  final Map<String, dynamic> member;

  const MemberCard({super.key, required this.member});

  @override
  State<MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<MemberCard> {
  final GlobalKey _globalKey = GlobalKey();

  // Rôles autorisés pour la gestion des cartes membres
  static const String adminPrincipalRole = 'admin_principal_membre';
  static const String adminGestionRole = 'admin_gestion_membre';

  static const double cardWidth = 320.0;
  static const double cardHeight = 620.0;

  static const Color ajemBlue = Color(0xFF0099FF);
  static const Color ajemGreen = Color(0xFF22C55E);
  static const Color ajemCyan = Color(0xFF06FFF0);
  static const Color ajemDark = Color(0xFF1A4D6D);

  String _companyAcronym = "AJEM";
  String _companySlogan =
      "« Ndao handray andraikitra, hitondra fampandrosoana ! »";
  String? _appLogoPath;

  StreamSubscription<CompanySettings>? _companySub;

  @override
  void initState() {
    super.initState();
    _listenCompanyInfo();
  }

  @override
  void dispose() {
    _companySub?.cancel();
    super.dispose();
  }

  // 🔥 Acronyme, slogan et logo viennent de Firestore (partagés par tous
  // les appareils) au lieu de SharedPreferences (local au téléphone).
  void _listenCompanyInfo() {
    _companySub = CompanySettingsService.instance.watch().listen(
      (c) {
        if (!mounted) return;
        setState(() {
          _companyAcronym = c.acronym;
          _companySlogan =
              c.slogan ?? "« Ndao handray andraikitra, hitondra fampandrosoana ! »";
          _appLogoPath = c.logoUrl;
        });
      },
      onError: (e) => debugPrint('Erreur paramètres entreprise: $e'),
    );
  }

  // Mettre le NOM en MAJUSCULE
  String _upperCase(String value) {
    if (value.isEmpty) return value;
    return value.trim().toUpperCase();
  }

  // Mettre le PRENOM avec première lettre en majuscule
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

  // ────────────────────────────────────────────────
  // 🔥 AJOUT : abréviation automatique des textes trop longs
  //
  // La carte garde une taille fixe (cardWidth/cardHeight). Pour éviter tout
  // dépassement ("BOTTOM OVERFLOWED") quand un nom, un prénom ou une
  // fonction est long, on réduit le texte à une largeur de ligne maximale
  // (en caractères) en abrégeant les DERNIERS mots avec leur seule
  // initiale, tout en gardant toujours le premier mot intact (c'est lui
  // qui identifie le mieux la personne ou la fonction).
  //
  // Exemples :
  //   "LAZASOA VONY FANDRESENA" (maxChars 20) -> "LAZASOA VONY F."
  //   "Narindra Perpetue"       (maxChars 14) -> "Narindra P."
  //
  // Si même après abréviation le texte reste trop long (ex. un seul mot
  // très long), une troncature finale propre (avec un point) sert de
  // filet de sécurité, en plus du `overflow: TextOverflow.ellipsis` posé
  // sur chaque Text concerné.
  static String _fitToWidth(String value, int maxChars) {
    var text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty || text.length <= maxChars) return text;

    final words = text.split(' ');

    // Abrège les mots un par un en partant de la fin, en gardant toujours
    // le premier mot entier.
    for (var i = words.length - 1; i > 0 && text.length > maxChars; i--) {
      final word = words[i];
      if (word.length > 2 && !word.endsWith('.')) {
        words[i] = '${word[0].toUpperCase()}.';
        text = words.join(' ');
      }
    }

    if (text.length <= maxChars) return text;

    // Dernier recours : troncature propre avec un point final.
    final safeLength = maxChars - 1;
    if (safeLength <= 0) return text;
    return '${text.substring(0, safeLength).trimRight()}.';
  }

  Future<void> _saveAndShareCard(BuildContext context) async {
    try {
      // 🔥 CORRIGÉ : une photo ImgBB (réseau) peut mettre plus de 300ms à
      // charger — on l'attend explicitement avant la capture, sinon le
      // partage pouvait figer l'avatar en placeholder.
      final photoPath = widget.member['profileImage'] as String?;
      if (ImageUploadService.isNetworkUrl(photoPath) && context.mounted) {
        try {
          await precacheImage(NetworkImage(photoPath!), context);
        } catch (_) {
          // Si le chargement échoue, on continue quand même la capture
          // (le placeholder s'affichera, comme pour une image locale
          // manquante).
        }
      }

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
      final file = File(
        '${dir.path}/carte_${_companyAcronym.toLowerCase()}_${widget.member['id'] ?? 'temp'}.png',
      );
      await file.writeAsBytes(imageBytes);

      if (!context.mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Carte de membre $_companyAcronym - ${_upperCase(widget.member['name'] ?? '')} ${_capitalize(widget.member['prenom'] ?? '')}',
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
                              // const SizedBox(height: 16),
                              // // _buildOff(), // ✅ ID ICI dans la section blanche
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
            width: 80,
            height: 80,
            // decoration: BoxDecoration(
            //   color: Colors.white.withOpacity(0.95),
            //   shape: BoxShape.circle,
            // ),
            padding: const EdgeInsets.all(8),
            child: ClipOval(
              child: _appLogoPath != null && _appLogoPath!.isNotEmpty
                  ? Image.network(
                      _appLogoPath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.business,
                        color: Color(0xFF0099FF),
                        size: 45,
                      ),
                    )
                  : Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.business,
                        color: Color(0xFF0099FF),
                        size: 45,
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
    // 🔥 CORRIGÉ : l'ancienne version faisait toujours Image.file, qui ne
    // fonctionne jamais avec une URL ImgBB. On distingue maintenant URL
    // hébergée (nouveau système) et chemin local (anciennes données non
    // migrées), sans changer ni la taille ni le design de l'avatar.
    final String? path = widget.member['profileImage'] as String?;
    final bool hasImage = path != null && path.isNotEmpty;
    final placeholder = Container(
      color: Colors.grey[300],
      child: const Icon(Icons.person, size: 80, color: Colors.grey),
    );

    Widget imageWidget;
    if (!hasImage) {
      imageWidget = placeholder;
    } else if (ImageUploadService.isNetworkUrl(path)) {
      imageWidget = Image.network(
        path,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    } else {
      // Ancienne donnée : chemin local (souvent absent sur l'APK).
      imageWidget = Image.file(
        File(path),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }

    return Container(
      width: 160,
      height: 160,
      child: ClipOval(child: imageWidget),
    );
  }

  Widget _buildIdentity() {
    // 🔥 AJOUT : abréviation automatique nom / prénom / fonction pour
    // garantir une hauteur d'affichage constante, quelle que soit la
    // longueur des informations. Le style visuel (couleur, taille,
    // graisse) reste strictement identique à l'original.
    final nom = _fitToWidth(_upperCase(widget.member['name'] ?? ''), 20);
    final prenom = _fitToWidth(_capitalize(widget.member['prenom'] ?? ''), 20);
    // 🔥 AJOUT : si le membre a plusieurs fonctions, on affiche la
    // principale suivie de « +N » (hauteur de la carte inchangée).
    final extraRoles = FirebaseUserRepository.extraRolesCount(widget.member);
    final fonctionBrute = (widget.member['role'] ?? 'MEMBRE').toString();
    final fonction = _fitToWidth(
      (extraRoles > 0 ? '$fonctionBrute +$extraRoles' : fonctionBrute)
          .toUpperCase(),
      18,
    );

    const identityStyle = TextStyle(
      color: Color(0xFF2C3E50),
      fontWeight: FontWeight.bold,
      fontSize: 18,
      letterSpacing: 0.4,
      height: 1.25,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Nom et prénom sur deux lignes fixes (au lieu d'un seul bloc
          // à 3 lignes qui pouvait pousser le contenu hors de la carte).
          Text(
            nom,
            textAlign: TextAlign.center,
            style: identityStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (prenom.isNotEmpty)
            Text(
              prenom,
              textAlign: TextAlign.center,
              style: identityStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 10),
          Text(
            fonction,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ajemBlue,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.8,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOffice() {
    // 🔥 AJOUT : même principe pour la formation (mention + établissement) —
    // abréviation puis troncature de sécurité, en gardant exactement le
    // même format d'affichage qu'avant ("mention -établissement").
    final rawFormation =
        '${widget.member['mention'] ?? ''} -${widget.member['etablissement'] ?? ''}';
    final formation = _fitToWidth(rawFormation, 34);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        formation,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF7A8A99),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
  //   Widget _buildOff() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 20),
  //     child: Text(
  //       '${widget.member['telephone'] ?? ''}',
  //       textAlign: TextAlign.center,
  //       style: const TextStyle(
  //         color: Color(0xFF7A8A99),
  //         fontSize: 13,
  //         fontWeight: FontWeight.w500,
  //       ),
  //     ),
  //   );
  // }

  // ✅ ID dans la section BLANCHE avec couleurs appropriées
  // Widget _buildID() {
  //   return Center(
  //     child: RichText(
  //       textAlign: TextAlign.center,
  //       text: TextSpan(
  //         children: [
  //           // const TextSpan(
  //           //   text: 'ID : ',
  //           //   style: TextStyle(
  //           //     color: Color(0xFF2C3E50), // Gris foncé pour fond blanc
  //           //     fontSize: 16,
  //           //     fontWeight: FontWeight.w600,
  //           //   ),
  //           // ),
  //           // TextSpan(
  //           //   text: widget.member['id']?.toString().padLeft(12, '0') ?? '000000000000',
  //           //   style: const TextStyle(
  //           //     color: Color(0xFF0099FF), // Bleu vif pour contraste
  //           //     fontSize: 16,
  //           //     fontWeight: FontWeight.bold,
  //           //     letterSpacing: 1.5,
  //           //   ),
  //           // ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

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

  static const String _siteUrl = 'https://web-site-ajem.vercel.app';

  String _generateQRData() => _siteUrl;
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
