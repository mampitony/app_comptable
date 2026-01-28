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
  String _companyName = "CORE LEDGER"; // 🔥 Valeur par défaut
  String _companySlogan = "Une solution globale de gestion pour piloter vos actifs avec une précision absolue."; // 🔥 Valeur par défaut
  
  int _unreadAnnouncementsCount = 0;
  final AnnouncementService _announcementService = AnnouncementService();
  int _lastReadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLogo();
    _loadCompanyInfo(); // 🔥 Charger les infos de la compagnie
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
    setState(() {
      _appLogoPath = prefs.getString('app_logo_path');
    });
  }

  // 🔥 Charger le nom et le slogan de la compagnie
  Future<void> _loadCompanyInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyName = prefs.getString('company_name') ?? "CORE LEDGER";
      _companySlogan = prefs.getString('company_slogan') ?? 
          "Une solution globale de gestion pour piloter vos actifs avec une précision absolue.";
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
    setState(() {
      _unreadAnnouncementsCount = 0;
    });
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.campaign, color: Color(0xFF0163D2)),
            const SizedBox(width: 10),
            const Text('Annonces'),
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

              final announcements = snapshot.data ?? [];

              if (announcements.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 60,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 15),
                      Text(
                        'Aucune annonce pour le moment',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  final announcement = announcements[index];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0163D2).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.campaign,
                                  color: Color(0xFF0163D2),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  announcement['timestamp'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            announcement['message'],
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          _buildBackgroundAura(),
          
          SafeArea(
            child: Positioned(
              top: 20,
              right: 20,
              child: _buildNotificationButton(),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 80),
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

  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: _showAnnouncements,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF1E293B),
              size: 24,
            ),
            if (_unreadAnnouncementsCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Center(
                    child: Text(
                      _unreadAnnouncementsCount > 99 
                          ? '99+' 
                          : '$_unreadAnnouncementsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
          child: const Icon(
            Icons.account_balance_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 15),
        // 🔥 Nom dynamique de la compagnie
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
  }

  Widget _buildVisualElement() {
    if (_appLogoPath != null && _appLogoPath!.isNotEmpty) {
      return Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF00AEEF).withOpacity(0.1),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: Image.file(
            File(_appLogoPath!),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Padding(
                padding: const EdgeInsets.all(25),
                child: const Icon(
                  Icons.analytics_outlined,
                  size: 80,
                  color: Color(0xFF00AEEF),
                ),
              );
            },
          ),
        ),
      );
    }

    return Container(
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
        // 🔥 Slogan dynamique
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