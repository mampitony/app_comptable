// lib/services/announcement_service.dart
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementService {
  static final AnnouncementService _instance = AnnouncementService._internal();
  factory AnnouncementService() => _instance;
  AnnouncementService._internal();

  // Stream pour diffuser les annonces
  final _announcementsController = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get announcementsStream => _announcementsController.stream;

  Timer? _pollingTimer;
  List<Map<String, dynamic>> _lastAnnouncements = [];

  // Démarrer l'écoute en temps réel
  void startListening() {
    // Vérifier les nouvelles annonces toutes les 5 secondes
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _checkForNewAnnouncements();
    });
    
    // Charger immédiatement au démarrage
    _checkForNewAnnouncements();
  }

  // Vérifier les nouvelles annonces
  Future<void> _checkForNewAnnouncements() async {
    final prefs = await SharedPreferences.getInstance();
    final announcements = prefs.getStringList('announcements') ?? [];
    
    final formattedAnnouncements = announcements.map((item) {
      final parts = item.split('|');
      return {
        'timestamp': parts[0],
        'message': parts.length > 1 ? parts[1] : item,
        'raw': item,
      };
    }).toList();

    // Si les annonces ont changé, diffuser la mise à jour
    if (_hasChanged(formattedAnnouncements)) {
      _lastAnnouncements = formattedAnnouncements;
      _announcementsController.add(formattedAnnouncements);
    }
  }

  // Vérifier si les annonces ont changé
  bool _hasChanged(List<Map<String, dynamic>> newAnnouncements) {
    if (newAnnouncements.length != _lastAnnouncements.length) return true;
    
    for (int i = 0; i < newAnnouncements.length; i++) {
      if (newAnnouncements[i]['raw'] != _lastAnnouncements[i]['raw']) {
        return true;
      }
    }
    return false;
  }

  // Arrêter l'écoute
  void stopListening() {
    _pollingTimer?.cancel();
  }

  // Nettoyer les ressources
  void dispose() {
    stopListening();
    _announcementsController.close();
  }
}