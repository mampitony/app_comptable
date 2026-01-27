import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../services/announcement_service.dart';

class AcceuilScreen extends StatefulWidget {
  final VoidCallback? onNavigateToConnexion;

  const AcceuilScreen({super.key, this.onNavigateToConnexion});

  @override
  State<AcceuilScreen> createState() => _AcceuilScreenState();
}

class _AcceuilScreenState extends State<AcceuilScreen> {
  String? _appLogoPath;
  String _companyName = "CORE LEDGER";
  String _companySlogan =
      "Une solution globale de gestion pour piloter vos actifs avec une précision absolue.";

  int _unreadAnnouncementsCount = 0;
  final AnnouncementService _announcementService = AnnouncementService();
  int _lastReadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLogo();
    _loadCompanyInfo();
    _loadLastReadCount();
    _announcementService.startListening();
    _announcementService.announcementsStream.listen((announcements) {
      _updateUnreadCount(announcements.length);
    });
  }

  @override
  void dispose() {
    _announcementService.stopListening();
    super.dispose();
  }

  Future<void> _loadLogo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _appLogoPath = prefs.getString('app_logo_path'));
  }

  Future<void> _loadCompanyInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyName = prefs.getString('company_name') ?? "CORE LEDGER";
      _companySlogan =
          prefs.getString('company_slogan') ??
          "Une solution globale de gestion...";
    });
  }

  Future<void> _loadLastReadCount() async {
    final prefs = await SharedPreferences.getInstance();
    _lastReadCount = prefs.getInt('last_read_announcements_count') ?? 0;
    final announcements = prefs.getStringList('announcements') ?? [];
    _updateUnreadCount(announcements.length);
  }

  void _updateUnreadCount(int totalCount) {
    setState(() {
      _unreadAnnouncementsCount = totalCount - _lastReadCount;
      if (_unreadAnnouncementsCount < 0) _unreadAnnouncementsCount = 0;
    });
  }

  Future<void> _showAnnouncements() async {
    final prefs = await SharedPreferences.getInstance();
    final announcements = prefs.getStringList('announcements') ?? [];
    await prefs.setInt('last_read_announcements_count', announcements.length);
    _lastReadCount = announcements.length;
    setState(() => _unreadAnnouncementsCount = 0);

    if (!mounted) return;
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
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _announcementService.announcementsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final announcementsData = snapshot.data ?? [];
              if (announcementsData.isEmpty) {
                return const Center(
                  child: Text("Aucune annonce pour le moment."),
                );
              }
              return ListView.builder(
                itemCount: announcementsData.length,
                itemBuilder: (context, index) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    title: Text(
                      announcementsData[index]['timestamp'] ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    subtitle: Text(
                      announcementsData[index]['message'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
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
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0163D2),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "ACCUEIL",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        // 🔹 RÉINTÉGRATION DU BOUTON DE NOTIFICATION ICI
        actions: [_buildNotificationButton(), const SizedBox(width: 10)],
      ),
      body: Stack(
        children: [
          _buildBackgroundAura(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  _buildGlobalBranding(),
                  const Spacer(),
                  _buildVisualElement(),
                  const Spacer(),
                  _buildHeroText(),
                  const SizedBox(height: 50),
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

  // Widget du bouton de notification avec le badge (Logique conservée)
  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: _showAnnouncements,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_rounded, // Icône plus moderne
              color: Colors.white,
              size: 28,
            ),
            if (_unreadAnnouncementsCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$_unreadAnnouncementsCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return GestureDetector(
      onTap: widget.onNavigateToConnexion,
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
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundAura() => Positioned(
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

  Widget _buildGlobalBranding() => Column(
    children: [
      Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.account_balance_rounded, color: Colors.white),
      ),
      const SizedBox(height: 15),
      Text(
        _companyName.toUpperCase(),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1E293B),
          letterSpacing: 3,
        ),
      ),
    ],
  );

  Widget _buildVisualElement() => Container(
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFF),
      shape: BoxShape.circle,
      border: Border.all(
        color: const Color(0xFF00AEEF).withOpacity(0.1),
        width: 2,
      ),
    ),
    child: const Icon(
      Icons.analytics_outlined,
      size: 80,
      color: Color(0xFF00AEEF),
    ),
  );

  Widget _buildHeroText() => Column(
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
      Text(
        _companySlogan,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF94A3B8),
          height: 1.5,
        ),
      ),
    ],
  );
}
