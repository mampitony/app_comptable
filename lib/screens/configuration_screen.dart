// lib/screens/configuration_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({Key? key}) : super(key: key);

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String? _appLogoPath;

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companySloganController = TextEditingController();
  final TextEditingController _announcementController = TextEditingController();
  final TextEditingController _companyAcronymController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAcronymController.dispose();
    _companySloganController.dispose();
    _announcementController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      _appLogoPath = prefs.getString('app_logo_path');

      _companyNameController.text = prefs.getString('company_name') ?? 'CORE LEDGER';
      _companyAcronymController.text = prefs.getString('company_acronym') ?? 'AJEM';
      _companySloganController.text = prefs.getString('company_slogan') ??
          '« Ndao handray andraikitra, hitondra fampandrosoana ! »';
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informations de l\'entreprise'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _companyNameController,
                decoration: InputDecoration(
                  labelText: 'Nom de l\'entreprise',
                  hintText: 'Ex: CORE LEDGER',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _companyAcronymController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: 'Acronyme',
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
                decoration: InputDecoration(
                  labelText: 'Slogan',
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

    await _saveSetting('company_name', name);
    await _saveSetting('company_acronym', acronym);
    await _saveSetting('company_slogan', slogan);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informations mises à jour avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _pickAppLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? result = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    if (result != null) {
      setState(() {
        _appLogoPath = result.path;
      });
      await _saveSetting('app_logo_path', result.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo mis à jour avec succès')),
        );
      }
    }
  }

  Future<void> _removeAppLogo() async {
    setState(() {
      _appLogoPath = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_logo_path');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo supprimé')),
      );
    }
  }

  void _showAnnouncementDialog() {
    _announcementController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle annonce'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cette annonce sera visible par tous les membres.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _announcementController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Tapez votre annonce ici...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
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
              _publishAnnouncement();
              Navigator.pop(context);
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

  Future<void> _publishAnnouncement() async {
    final announcement = _announcementController.text.trim();

    if (announcement.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L\'annonce est vide')),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final timestamp = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}';

      List<String> announcements = prefs.getStringList('announcements') ?? [];
      announcements.insert(0, '$timestamp|$announcement');

      if (announcements.length > 10) {
        announcements = announcements.sublist(0, 10);
      }

      await prefs.setStringList('announcements', announcements);
      await prefs.setInt('last_read_announcements_count', 0);

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

  void _viewAnnouncements() async {
    final prefs = await SharedPreferences.getInstance();
    final announcements = prefs.getStringList('announcements') ?? [];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annonces publiées'),
        content: SizedBox(
          width: double.maxFinite,
          child: announcements.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Aucune annonce pour le moment',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: announcements.length,
                  itemBuilder: (context, index) {
                    final parts = announcements[index].split('|');
                    final timestamp = parts[0];
                    final message = parts.length > 1 ? parts[1] : announcements[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(
                          Icons.campaign,
                          color: Color(0xFF0163D2),
                        ),
                        title: Text(message),
                        subtitle: Text(
                          timestamp,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _deleteAnnouncement(index);
                            Navigator.pop(context);
                          },
                        ),
                      ),
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

  Future<void> _deleteAnnouncement(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> announcements = prefs.getStringList('announcements') ?? [];

    if (index < announcements.length) {
      announcements.removeAt(index);
      await prefs.setStringList('announcements', announcements);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Annonce supprimée')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Accéder au ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configuration',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              _buildSectionTitle('Informations de l\'entreprise'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.business, color: Color(0xFF0163D2)),
                      title: Text(_companyNameController.text),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Acronyme: ${_companyAcronymController.text}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _companySloganController.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.edit, size: 20),
                      onTap: _showCompanyInfoDialog,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              _buildSectionTitle('Logo de l\'application'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      if (_appLogoPath != null)
                        Column(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(_appLogoPath!),
                                  fit: BoxFit.cover,
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
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.image_outlined,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickAppLogo,
                            icon: const Icon(Icons.upload),
                            label: Text(_appLogoPath == null ? 'Ajouter' : 'Modifier'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0163D2),
                              foregroundColor: Colors.white,
                            ),
                          ),
                          if (_appLogoPath != null) ...[
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: _removeAppLogo,
                              icon: const Icon(Icons.delete),
                              label: const Text('Supprimer'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              _buildSectionTitle('Annonces'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.campaign, color: Color(0xFF0163D2)),
                      title: const Text('Créer une annonce'),
                      subtitle: const Text('Informer tous les membres'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _showAnnouncementDialog,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.list, color: Colors.orange),
                      title: const Text('Voir les annonces'),
                      subtitle: const Text('Gérer les annonces publiées'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _viewAnnouncements,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              _buildSectionTitle('Notifications'),
              _buildSwitchTile(
                title: 'Activer les notifications',
                subtitle: 'Recevoir des alertes et notifications',
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                  _saveSetting('notifications_enabled', value);
                },
              ),

              const Divider(height: 40),

              _buildSectionTitle('Apparence'),
              // 🔥 Mode sombre fonctionnel avec Provider
              SwitchListTile(
                title: const Text('Mode sombre'),
                subtitle: const Text('Activer le thème sombre'),
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  setState(() => _darkModeEnabled = value);
                  themeProvider.toggleTheme(value);
                },
                activeColor: const Color(0xFF0163D2),
              ),

              const Divider(height: 40),

              _buildSectionTitle('Actions'),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Déconnexion'),
                onTap: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0163D2),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF0163D2),
    );
  }
}