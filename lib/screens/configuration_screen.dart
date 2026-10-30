// lib/screens/configuration_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/theme_provider.dart';
import '../services/company_settings_service.dart';
import '../components/role_settings_dialog.dart'; // 🔥 AJOUT : rôles et effectifs
import '../services/image_upload_service.dart';
import '../services/firebase_announcement_service.dart'; // ✅ AJOUT

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({Key? key}) : super(key: key);

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String? _appLogoPath; // URL publique du logo (Firestore)
  bool _uploadingLogo = false;
  StreamSubscription<CompanySettings>? _companySub;

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companySloganController = TextEditingController();
  final TextEditingController _announcementController = TextEditingController();
  final TextEditingController _companyAcronymController = TextEditingController();

  // ✅ AJOUT : Service Firebase pour les annonces
  final FirebaseAnnouncementService _announcementService = FirebaseAnnouncementService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _listenCompanySettings();
    _announcementService.startListening(); // ✅ AJOUT : démarrer l'écoute Firebase
  }

  // 🔥 Temps réel : toute modification faite par un autre admin apparaît ici.
  void _listenCompanySettings() {
    _companySub = CompanySettingsService.instance.watch().listen(
      (c) {
        if (!mounted) return;
        setState(() {
          _appLogoPath = c.logoUrl;
          _companyNameController.text = c.name;
          _companyAcronymController.text = c.acronym;
          _companySloganController.text =
              c.slogan ?? '« Ndao handray andraikitra, hitondra fampandrosoana ! »';
        });
      },
      onError: (e) => debugPrint('Erreur paramètres entreprise: $e'),
    );
  }

  @override
  void dispose() {
    _companySub?.cancel();
    _companyNameController.dispose();
    _companyAcronymController.dispose();
    _companySloganController.dispose();
    _announcementController.dispose();
    _announcementService.stopListening(); // ✅ AJOUT : arrêter l'écoute Firebase
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  void _showCompanyInfoDialog() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Informations de l\'entreprise',
          style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _companyNameController,
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                decoration: InputDecoration(
                  labelText: 'Nom de l\'entreprise',
                  labelStyle: TextStyle(fontSize: isSmallScreen ? 13 : 15),
                  hintText: 'Ex: CORE LEDGER',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.business),
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              TextField(
                controller: _companyAcronymController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                decoration: InputDecoration(
                  labelText: 'Acronyme',
                  labelStyle: TextStyle(fontSize: isSmallScreen ? 13 : 15),
                  hintText: 'Ex: AJEM, CL, ABC',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.short_text),
                  helperText: 'Version courte du nom (max 10 caractères)',
                ),
              ),
              TextField(
                controller: _companySloganController,
                maxLines: 3,
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                decoration: InputDecoration(
                  labelText: 'Slogan',
                  labelStyle: TextStyle(fontSize: isSmallScreen ? 13 : 15),
                  hintText: 'Décrivez votre entreprise...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.format_quote),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveCompanyInfo();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0163D2),
              foregroundColor: Colors.white,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCompanyInfo() async {
    final name = _companyNameController.text.trim();
    final acronym = _companyAcronymController.text.trim();
    final slogan = _companySloganController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le nom de l\'entreprise ne peut pas être vide'),
        ),
      );
      return;
    }

    if (acronym.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L\'acronyme ne peut pas être vide')),
      );
      return;
    }

    try {
      await CompanySettingsService.instance.saveInfo(
        name: name,
        acronym: acronym,
        slogan: slogan,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informations mises à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de la sauvegarde : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickAppLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? result = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (result == null) return;

    setState(() => _uploadingLogo = true);
    try {
      // 1) héberger l'image (URL publique), 2) l'enregistrer dans Firestore :
      // tous les appareils la reçoivent ensuite en temps réel.
      final url = await ImageUploadService.uploadImage(File(result.path));
      await CompanySettingsService.instance.setLogoUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo mis à jour avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de l\'envoi du logo : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _removeAppLogo() async {
    try {
      await CompanySettingsService.instance.removeLogo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo supprimé')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de la suppression : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔥 AJOUT : gestion des rôles et du nombre maximum de membres par rôle.
  void _showRoleSettings() {
    showDialog(
      context: context,
      builder: (_) => const RoleSettingsDialog(),
    );
  }

  void _showAnnouncementDialog() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    _announcementController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Nouvelle annonce',
          style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cette annonce sera visible par tous les membres.',
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 13,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              TextField(
                controller: _announcementController,
                maxLines: 5,
                // 🔥 CORRIGÉ : couleur explicite depuis le thème (le champ
                // déjà touché la dernière fois pour son fond).
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Tapez votre annonce ici...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  // Fond fourni par le thème (clair/sombre).
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _publishAnnouncement(); // ✅ appelé après fermeture du dialog
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0163D2),
              foregroundColor: Colors.white,
            ),
            child: const Text('Publier'),
          ),
        ],
      ),
    );
  }

  // ✅ CORRIGÉ : Publie sur Firebase au lieu de SharedPreferences
  Future<void> _publishAnnouncement() async {
    final announcement = _announcementController.text.trim();

    if (announcement.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('L\'annonce est vide')),
        );
      }
      return;
    }

    try {
      // ✅ Publication sur Firebase (temps réel pour tous les utilisateurs)
      await _announcementService.publishAnnouncement(announcement);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Annonce publiée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  // ✅ CORRIGÉ : Affiche les annonces depuis Firebase en temps réel
  void _viewAnnouncements() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Annonces publiées',
          style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
        ),
        content: SizedBox(
          width: isSmallScreen ? double.maxFinite : 500,
          height: 400,
          // ✅ StreamBuilder sur Firebase pour affichage en temps réel
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _announcementService.announcementsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              final announcements = snapshot.data ?? [];

              if (announcements.isEmpty) {
                return Container(
                  alignment: Alignment.center,
                  child: Text(
                    'Aucune annonce pour le moment',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  final item = announcements[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(
                        Icons.campaign,
                        color: Color(0xFF0163D2),
                      ),
                      title: Text(
                        item['message'] ?? '',
                        style: TextStyle(fontSize: isSmallScreen ? 13 : 15),
                      ),
                      subtitle: Text(
                        item['timestamp'] ?? '',
                        style: TextStyle(fontSize: isSmallScreen ? 10 : 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        iconSize: isSmallScreen ? 20 : 24,
                        onPressed: () {
                          // 🔥 CORRIGÉ : id du document au lieu d'un index.
                          _deleteAnnouncement(item['id'] as String);
                        },
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

  // 🔥 CORRIGÉ : suppression par id de document, en cohérence avec la
  // nouvelle collection `announcements` (voir firebase_announcement_service.dart).
  Future<void> _deleteAnnouncement(String id) async {
    try {
      await _announcementService.deleteAnnouncement(id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Annonce supprimée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final horizontalPadding = isSmallScreen ? 16.0 : 24.0;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                maxWidth: 800,
              ),
              child: Container(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuration',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 20 : 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 20 : 30),

                    _buildSectionTitle('Informations de l\'entreprise', isSmallScreen),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.business,
                              color: const Color(0xFF0163D2),
                              size: isSmallScreen ? 22 : 26,
                            ),
                            title: Text(
                              _companyNameController.text,
                              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Acronyme: ${_companyAcronymController.text}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isSmallScreen ? 12 : 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _companySloganController.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                                ),
                              ],
                            ),
                            trailing: Icon(Icons.edit, size: isSmallScreen ? 18 : 22),
                            onTap: _showCompanyInfoDialog,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 20 : 30),

                    // 🔥 AJOUT : rôles et effectifs
                    _buildSectionTitle('Rôles et effectifs', isSmallScreen),
                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.groups,
                          color: const Color(0xFF0163D2),
                          size: isSmallScreen ? 22 : 26,
                        ),
                        title: Text(
                          'Gérer les rôles',
                          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                        ),
                        subtitle: Text(
                          'Nombre de secrétaires, trésoriers, commissaires '
                          'aux comptes... et ajout de nouveaux rôles',
                          style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: isSmallScreen ? 14 : 18,
                        ),
                        onTap: _showRoleSettings,
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 20 : 30),

                    _buildSectionTitle('Logo de l\'application', isSmallScreen),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                        child: Column(
                          children: [
                            if (_appLogoPath != null)
                              Column(
                                children: [
                                  Container(
                                    width: isSmallScreen ? 100 : 120,
                                    height: isSmallScreen ? 100 : 120,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        _appLogoPath!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stack) =>
                                            const Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  Container(
                                    width: isSmallScreen ? 100 : 120,
                                    height: isSmallScreen ? 100 : 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: isSmallScreen ? 40 : 50,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _uploadingLogo ? null : _pickAppLogo,
                                  icon: _uploadingLogo
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.upload),
                                  label: Text(_uploadingLogo
                                      ? 'Envoi...'
                                      : (_appLogoPath == null ? 'Ajouter' : 'Modifier')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0163D2),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 12 : 16,
                                      vertical: isSmallScreen ? 10 : 12,
                                    ),
                                  ),
                                ),
                                if (_appLogoPath != null)
                                  OutlinedButton.icon(
                                    onPressed: _removeAppLogo,
                                    icon: const Icon(Icons.delete),
                                    label: const Text('Supprimer'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 12 : 16,
                                        vertical: isSmallScreen ? 10 : 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 20 : 30),

                    _buildSectionTitle('Annonces', isSmallScreen),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.campaign,
                              color: const Color(0xFF0163D2),
                              size: isSmallScreen ? 22 : 26,
                            ),
                            title: Text(
                              'Créer une annonce',
                              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                            ),
                            subtitle: Text(
                              'Informer tous les membres',
                              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: isSmallScreen ? 14 : 18,
                            ),
                            onTap: _showAnnouncementDialog,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.list,
                              color: Colors.orange,
                              size: isSmallScreen ? 22 : 26,
                            ),
                            title: Text(
                              'Voir les annonces',
                              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                            ),
                            subtitle: Text(
                              'Gérer les annonces publiées',
                              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: isSmallScreen ? 14 : 18,
                            ),
                            onTap: _viewAnnouncements,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 20 : 30),

                    _buildSectionTitle('Notifications', isSmallScreen),
                    _buildSwitchTile(
                      title: 'Activer les notifications',
                      subtitle: 'Recevoir des alertes et notifications',
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                        _saveSetting('notifications_enabled', value);
                      },
                      isSmallScreen: isSmallScreen,
                    ),

                    Divider(height: isSmallScreen ? 30 : 40),

                    _buildSectionTitle('Apparence', isSmallScreen),
                    SwitchListTile(
                      title: Text(
                        'Mode sombre',
                        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      ),
                      subtitle: Text(
                        'Activer le thème sombre',
                        style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                      ),
                      value: themeProvider.isDarkMode,
                      onChanged: (value) {
                        setState(() => _darkModeEnabled = value);
                        themeProvider.toggleTheme(value);
                      },
                      activeColor: const Color(0xFF0163D2),
                    ),

                    Divider(height: isSmallScreen ? 30 : 40),

                    _buildSectionTitle('Actions', isSmallScreen),
                    ListTile(
                      leading: Icon(
                        Icons.logout,
                        color: Colors.red,
                        size: isSmallScreen ? 22 : 26,
                      ),
                      title: Text(
                        'Déconnexion',
                        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      ),
                      onTap: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                    ),

                    SizedBox(height: isSmallScreen ? 20 : 30),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: isSmallScreen ? 16 : 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0163D2),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required bool isSmallScreen,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF0163D2),
    );
  }
}