// lib/screens/acceuil_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_announcement_service.dart';
import '../services/company_settings_service.dart';

class AcceuilScreen extends StatefulWidget {
  final VoidCallback? onNavigateToConnexion;

  const AcceuilScreen({super.key, this.onNavigateToConnexion});

  @override
  State<AcceuilScreen> createState() => _AcceuilScreenState();
}

class _AcceuilScreenState extends State<AcceuilScreen>
    with WidgetsBindingObserver {
  String? _appLogoPath;
  String _companyName = "CORE LEDGER";
  String _companySlogan =
      "Une solution globale de gestion pour piloter vos actifs avec une précision absolue.";

  int _unreadAnnouncementsCount = 0;
  int _lastReadCount = 0;

  // ✅ FIX : écoute directe Firestore sans passer par le singleton
  StreamSubscription? _announcementsSubscription;
  StreamSubscription<CompanySettings>? _companySub; // 🔥 temps réel Firestore
  List<Map<String, dynamic>> _currentAnnouncements = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenCompanySettings();
    _loadLastReadCount().then((_) => _startListening());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _announcementsSubscription?.cancel();
    _companySub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Plus rien à recharger : le flux Firestore se met à jour tout seul.
  }

  // ✅ FIX : écoute directe du stream Firebase via le service singleton
  void _startListening() {
    // On s'assure que le service écoute bien Firebase
    FirebaseAnnouncementService().startListening();

    _announcementsSubscription?.cancel();
    _announcementsSubscription =
        FirebaseAnnouncementService().announcementsStream.listen(
      (announcements) {
        if (mounted) {
          setState(() {
            _currentAnnouncements = announcements;
            final unread = announcements.length - _lastReadCount;
            _unreadAnnouncementsCount = unread < 0 ? 0 : unread;
          });
        }
      },
      onError: (error) {
        debugPrint('Erreur annonces AcceuilScreen: $error');
      },
    );
  }

  // 🔥 Nom, slogan et logo viennent de Firestore (partagés par tous les
  // appareils) au lieu de SharedPreferences (local à chaque téléphone).
  void _listenCompanySettings() {
    _companySub = CompanySettingsService.instance.watch().listen(
      (c) {
        if (!mounted) return;
        setState(() {
          _companyName = c.name;
          _companySlogan = c.slogan ??
              "Une solution globale de gestion pour piloter vos actifs avec une précision absolue.";
          _appLogoPath = c.logoUrl;
        });
      },
      onError: (e) => debugPrint('Erreur paramètres entreprise: $e'),
    );
  }

  Future<void> _loadLastReadCount() async {
    final prefs = await SharedPreferences.getInstance();
    _lastReadCount = prefs.getInt('last_read_announcements_count') ?? 0;
  }

  // ✅ FIX : utilise _currentAnnouncements déjà chargé, pas de re-fetch
  Future<void> _showAnnouncements() async {
    // Marquer toutes comme lues
    final total = _currentAnnouncements.length;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_read_announcements_count', total);
    _lastReadCount = total;
    if (mounted) setState(() => _unreadAnnouncementsCount = 0);

    if (!mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.campaign, color: Color(0xFF0163D2)),
            SizedBox(width: 10),
            Text('Annonces'),
          ],
        ),
        content: SizedBox(
          width: screenWidth > 600 ? 500 : screenWidth * 0.9,
          height: screenHeight > 600 ? 400 : screenHeight * 0.5,
          // ✅ FIX : StreamBuilder branché sur le même service singleton
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirebaseAnnouncementService().announcementsStream,
            initialData: _currentAnnouncements, // ✅ données déjà dispo = pas de flash vide
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.data == null) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              final data = snapshot.data ?? [];

              if (data.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.campaign_outlined,
                          size: 48, color: Color(0xFF0163D2)),
                      SizedBox(height: 12),
                      Text(
                        "Aucune annonce pour le moment.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              // Affichage de la plus récente en premier
              final reversed = data.reversed.toList();

              return ListView.builder(
                itemCount: reversed.length,
                itemBuilder: (context, index) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.campaign,
                          color: Color(0xFF0163D2), size: 20),
                    ),
                    title: Text(
                      reversed[index]['message'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        reversed[index]['timestamp'] ?? '',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer",
                style: TextStyle(color: Color(0xFF0163D2))),
          ),
        ],
      ),
    );
  }

  // Couleurs (mêmes que l'écran de connexion)
  static const Color _blue = Color(0xFF0163D2);
  static const Color _cyan = Color(0xFF00AEEF);
  static const Color _dark = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1F4B), _blue, Color(0xFF0B1F4B)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 30,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: _buildMainCard(MediaQuery.of(context).size),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard(Size screenSize) {
    final isSmall = screenSize.width < 600;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                // Vague en haut à gauche
                Positioned(
                  top: 0,
                  left: 0,
                  child: ClipPath(
                    clipper: _TopLeftWaveClipper(),
                    child: Container(
                      width: 200,
                      height: 130,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_cyan, _blue],
                        ),
                      ),
                    ),
                  ),
                ),
                // Vague en bas (deux couches)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 120,
                  child: Stack(
                    children: [
                      Opacity(
                        opacity: 0.35,
                        child: ClipPath(
                          clipper: _BottomWaveClipper(flip: true),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [_cyan, _blue]),
                            ),
                          ),
                        ),
                      ),
                      ClipPath(
                        clipper: _BottomWaveClipper(),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [_blue, _cyan]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenu
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 120),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(isSmall),
                      const SizedBox(height: 16),
                      _buildName(isSmall),
                      SizedBox(height: isSmall ? 26 : 34),
                      _buildHeroText(isSmall),
                    ],
                  ),
                ),
                // Cloche de notification (en haut à droite)
                Positioned(
                  top: 14,
                  right: 14,
                  child: _buildNotificationButton(),
                ),
              ],
            ),
          ),
        ),
        // Bouton pilule qui déborde en bas de la carte
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(child: _buildPillButton('COMMENCER')),
        ),
      ],
    );
  }

  Widget _buildLogo(bool isSmall) {
    final size = isSmall ? 130.0 : 160.0;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: _cyan.withOpacity(0.25), width: 2),
        boxShadow: [
          BoxShadow(
            color: _blue.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: (_appLogoPath != null && _appLogoPath!.isNotEmpty)
            ? Image.network(
                _appLogoPath!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => SizedBox(
                  width: size,
                  height: size,
                  child: Icon(Icons.account_balance_rounded,
                      size: size * 0.45, color: _blue),
                ),
              )
            : SizedBox(
                width: size,
                height: size,
                child: Icon(Icons.account_balance_rounded,
                    size: size * 0.45, color: _blue),
              ),
      ),
    );
  }

  Widget _buildName(bool isSmall) {
    return Text(
      _companyName.toUpperCase(),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: isSmall ? 13 : 16,
        fontWeight: FontWeight.w800,
        color: _dark,
        letterSpacing: 2.5,
        height: 1.4,
      ),
    );
  }

  Widget _buildHeroText(bool isSmall) {
    return Column(
      children: [
        Text(
          "La comptabilité,",
          style: TextStyle(
            fontSize: isSmall ? 22 : 30,
            fontWeight: FontWeight.w300,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          "réinventée.",
          style: TextStyle(
            fontSize: isSmall ? 28 : 38,
            fontWeight: FontWeight.w900,
            color: _blue,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _companySlogan,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmall ? 13 : 15,
            color: const Color(0xFF94A3B8),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // Cloche : pastille bleu clair + badge rouge des annonces non lues
  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: _showAnnouncements,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F1FC),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _blue.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_none_rounded,
                color: _blue, size: 26),
            if (_unreadAnnouncementsCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$_unreadAnnouncementsCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillButton(String label) {
    return GestureDetector(
      onTap: widget.onNavigateToConnexion,
      child: Container(
        constraints: const BoxConstraints(minWidth: 220, minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 36),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(colors: [_cyan, _blue]),
          boxShadow: [
            BoxShadow(
              color: _blue.withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// Vague en haut à gauche de la carte
class _TopLeftWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path()..lineTo(size.width, 0);
    p.cubicTo(size.width * 0.80, size.height * 0.30, size.width * 0.55,
        size.height * 0.20, size.width * 0.40, size.height * 0.60);
    p.cubicTo(size.width * 0.30, size.height * 0.85, size.width * 0.12,
        size.height * 0.95, 0, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Vague en bas de la carte (flip = version décalée pour la 2e couche)
class _BottomWaveClipper extends CustomClipper<Path> {
  final bool flip;
  _BottomWaveClipper({this.flip = false});

  @override
  Path getClip(Size size) {
    final p = Path();
    if (!flip) {
      p.moveTo(0, size.height * 0.45);
      p.cubicTo(size.width * 0.25, size.height * 0.05, size.width * 0.55,
          size.height * 0.95, size.width, size.height * 0.30);
    } else {
      p.moveTo(0, size.height * 0.20);
      p.cubicTo(size.width * 0.30, size.height * 0.75, size.width * 0.65,
          size.height * 0.00, size.width, size.height * 0.55);
    }
    p.lineTo(size.width, size.height);
    p.lineTo(0, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
