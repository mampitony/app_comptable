// lib/screens/announcement_screen.dart
import 'package:flutter/material.dart';
import '../services/firebase_announcement_service.dart';

class AnnouncementScreen extends StatefulWidget {
  final String userRole; // ✅ rôle transmis depuis UserDrawerNavigator

  const AnnouncementScreen({Key? key, required this.userRole})
    : super(key: key);

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAnnouncementService _announcementService =
      FirebaseAnnouncementService();
  final TextEditingController _announcementController = TextEditingController();
  late TabController _tabController;
  bool _isPublishing = false;

  // ✅ Seul le "Responsable Communication" peut créer/supprimer
  bool get _canManage => widget.userRole == 'Responsable de Communication';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _canManage ? 2 : 1, // 2 onglets si gestionnaire, 1 sinon
      vsync: this,
    );
    _announcementService.startListening();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _announcementController.dispose();
    _announcementService.stopListening();
    super.dispose();
  }

  Future<void> _publishAnnouncement() async {
    final message = _announcementController.text.trim();
    if (message.isEmpty) {
      _showSnackBar('Veuillez saisir un message.', isError: true);
      return;
    }
    setState(() => _isPublishing = true);
    try {
      await _announcementService.publishAnnouncement(
        message,
        // 🔥 AJOUT : seule info d'identité disponible à cet endroit
        // (aucun écran ne transmet le nom de l'utilisateur jusqu'ici).
        auteur: widget.userRole,
      );
      // 🔔 La notification push est déclenchée dans
      // FirebaseAnnouncementService.publishAnnouncement.
      _announcementController.clear();
      _showSnackBar('Annonce publiée avec succès !', isError: false);
      if (_canManage) _tabController.animateTo(1);
    } catch (e) {
      _showSnackBar('Erreur lors de la publication : $e', isError: true);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  // 🔥 MODIFIÉ : suppression par id de document (au lieu d'un index dans
  // une liste locale), en cohérence avec la nouvelle collection
  // `announcements`.
  Future<void> _deleteAnnouncement(String id) async {
    if (!_canManage) return; // sécurité double

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer l\'annonce'),
        content: const Text(
          'Cette annonce sera définitivement supprimée. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _announcementService.deleteAnnouncement(id);
        _showSnackBar('Annonce supprimée.', isError: false);
      } catch (e) {
        _showSnackBar('Erreur lors de la suppression : $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0163D2),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // le drawer gère la navigation
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.campaign, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Annonces',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
          ],
        ),
        // ✅ Badge indiquant le niveau d'accès
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _canManage
                  ? Colors.green.withOpacity(0.25)
                  : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _canManage
                    ? Colors.greenAccent.withOpacity(0.6)
                    : Colors.white30,
              ),
            ),
            child: Text(
              _canManage ? '✦ Gestionnaire' : '👁 Lecture seule',
              style: TextStyle(
                color: _canManage ? Colors.greenAccent[100] : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        // ✅ TabBar seulement pour le Responsable Communication
        bottom: _canManage
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(icon: Icon(Icons.edit_note, size: 20), text: 'Créer'),
                  Tab(icon: Icon(Icons.list_alt, size: 20), text: 'Publiées'),
                ],
              )
            : null,
      ),
      // ✅ Vue différente selon le rôle
      body: _canManage
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildCreateTab(isSmallScreen),
                _buildListTab(isSmallScreen, canDelete: true),
              ],
            )
          : _buildListTab(isSmallScreen, canDelete: false),
    );
  }

  // ─── Onglet Créer : réservé au Responsable Communication ─────────────────
  Widget _buildCreateTab(bool isSmallScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0163D2), Color(0xFF0288D1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0163D2).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.announcement,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nouvelle annonce',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Visible par tous les membres immédiatement.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit,
                        size: 18,
                        color: Color(0xFF0163D2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Contenu de l\'annonce',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isSmallScreen ? 14 : 15,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _announcementController,
                    maxLines: 8,
                    maxLength: 500,
                    // 🔥 CORRIGÉ : couleur explicite depuis le thème.
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 15,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Rédigez votre annonce ici...\n\nEx : Réunion générale le vendredi 28 février à 14h00 en salle A.',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: isSmallScreen ? 13 : 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF0163D2),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      // 🔥 CORRIGÉ : fond quasi-blanc figé — invisible avec
                      // un texte devenu clair en mode sombre. Le thème
                      // fournit désormais la couleur adaptée.
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD54F)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFFF57C00),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Conseil : Soyez clair et concis. Mentionnez la date, l\'heure et le lieu si nécessaire.',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: const Color(0xFF6D4C00),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isPublishing ? null : _publishAnnouncement,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0163D2),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isPublishing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Publication en cours...'),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Publier l\'annonce',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── Liste annonces : tous les membres (canDelete=false pour les autres) ──
  Widget _buildListTab(bool isSmallScreen, {required bool canDelete}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _announcementService.announcementsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0163D2)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'Erreur: ${snapshot.error}',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        final announcements = snapshot.data ?? [];

        if (announcements.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    size: 52,
                    color: Color(0xFF0163D2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Aucune annonce publiée',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  canDelete
                      ? 'Créez votre première annonce depuis l\'onglet "Créer".'
                      : 'Aucune annonce disponible pour le moment.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                if (canDelete) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => _tabController.animateTo(0),
                    icon: const Icon(Icons.add),
                    label: const Text('Créer une annonce'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0163D2),
                      side: const BorderSide(color: Color(0xFF0163D2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return Column(
          children: [
            // Compteur
            Container(
              margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.campaign,
                      color: Color(0xFF0163D2),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${announcements.length} annonce${announcements.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'En temps réel',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),

            // Liste des annonces
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: 4,
                ),
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  final reversedIndex = announcements.length - 1 - index;
                  final item = announcements[reversedIndex];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF0F7FF),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 14,
                                color: Color(0xFF0163D2),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item['timestamp'] ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF0163D2),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0163D2,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '#${announcements.length - index}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF0163D2),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Message
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            item['message'] ?? '',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 15,
                              color: const Color(0xFF1A1A1A),
                              height: 1.5,
                            ),
                          ),
                        ),
                        // ✅ Bouton supprimer : visible SEULEMENT pour Responsable Communication
                        if (canDelete)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              // 🔥 MODIFIÉ : on passe l'id du document
                              // (item['id']) plutôt qu'un index.
                              onPressed: () =>
                                  _deleteAnnouncement(item['id'] as String),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'Supprimer',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
