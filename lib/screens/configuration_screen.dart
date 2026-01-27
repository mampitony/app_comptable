// lib/screens/configuration_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({Key? key}) : super(key: key);

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String? _appLogoPath;
  final TextEditingController _announcementController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _announcementController.dispose();
    super.dispose();
  }

  // Charger les paramètres sauvegardés
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      _appLogoPath = prefs.getString('app_logo_path');
    });
  }

  // Sauvegarder un paramètre
  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  // Sélectionner le logo de l'application
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

  // Supprimer le logo
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

  // Afficher le dialog pour créer une annonce
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

  // Publier l'annonce
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
      
      // Récupérer les annonces existantes
      List<String> announcements = prefs.getStringList('announcements') ?? [];
      
      // Ajouter la nouvelle annonce avec timestamp
      announcements.insert(0, '$timestamp|$announcement');
      
      // Limiter à 10 annonces maximum
      if (announcements.length > 10) {
        announcements = announcements.sublist(0, 10);
      }
      
      // Sauvegarder
      await prefs.setStringList('announcements', announcements);
      
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

  // Afficher les annonces existantes
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

  // Supprimer une annonce
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
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configuration',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              
              // ✅ Section Logo de l'application
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
              
              // ✅ Section Annonces
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
              
              // Section Notifications
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
              
              // Section Apparence
              _buildSectionTitle('Apparence'),
              _buildSwitchTile(
                title: 'Mode sombre',
                subtitle: 'Activer le thème sombre',
                value: _darkModeEnabled,
                onChanged: (value) {
                  setState(() => _darkModeEnabled = value);
                  _saveSetting('dark_mode_enabled', value);
                },
              ),
              
              const Divider(height: 40),
              
              // Section Actions
              _buildSectionTitle('Actions'),
              ListTile(
                leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                title: const Text('Vider le cache'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache vidé')),
                  );
                },
              ),
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