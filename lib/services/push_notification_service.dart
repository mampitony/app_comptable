// lib/services/push_notification_service.dart
//
// Notifications push des annonces — SANS Cloud Functions (qui exigent le
// plan Blaze). Fonctionnement :
//   1. Chaque appareil s'abonne au topic FCM `ajem_announcements`.
//   2. Quand une annonce est publiée, l'app appelle un petit serveur
//      (api/notify.js, hébergé gratuitement sur Vercel) en lui donnant
//      seulement l'ID de l'annonce.
//   3. Ce serveur relit l'annonce dans Firestore, puis envoie la
//      notification à tous les appareils abonnés (même app fermée).
//
// ⚠️ Les identifiants d'envoi FCM restent côté serveur : ils ne doivent
// JAMAIS être mis dans l'application Flutter (extractibles de l'APK).
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Topic FCM auquel tous les appareils de l'application sont abonnés.
const String ajemAnnouncementsTopic = 'ajem_announcements';

/// 🔧 À REMPLACER par l'adresse de ton serveur Vercel une fois déployé,
/// par ex. 'https://ajem-notify.vercel.app/api/notify'
const String ajemNotifyEndpoint =
    'https://association-ajem-fianarantsoa-madagacar.vercel.app/';

/// Gestionnaire de messages reçus quand l'application est fermée ou en
/// arrière-plan (fonction top-level : exigence de firebase_messaging).
/// Le message contient un bloc "notification" : Android l'affiche et joue
/// le son tout seul, rien à faire ici.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Message reçu en arrière-plan : ${message.messageId}');
}

class PushNotificationService {
  static bool _initialized = false;

  /// Clé du ScaffoldMessenger racine (branchée dans main.dart) : permet
  /// d'afficher une bannière quand une annonce arrive pendant que l'app
  /// est ouverte (Android n'affiche pas la notification système dans ce cas).
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// À appeler une seule fois, au démarrage de l'app (voir main.dart).
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final messaging = FirebaseMessaging.instance;

      // Autorisation (obligatoire sur iOS et Android 13+).
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Abonnement au topic commun : un seul envoi touche tous les membres.
      await messaging.subscribeToTopic(ajemAnnouncementsTopic);

      // App ouverte au premier plan : bannière + vibration.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ?? 'Nouvelle annonce';
        final body = message.notification?.body ?? '';
        debugPrint('[FCM] Premier plan : $title - $body');

        HapticFeedback.heavyImpact();
        messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
              backgroundColor: const Color(0xFF0163D2),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          );
      });

      debugPrint(
        '[FCM] Initialisé et abonné au topic "$ajemAnnouncementsTopic".',
      );
    } catch (e) {
      // Une erreur FCM ne doit jamais empêcher le reste de l'app de marcher.
      debugPrint('[FCM] Erreur d\'initialisation : $e');
    }
  }

  /// Demande au serveur d'envoyer la notification d'une annonce déjà
  /// publiée dans Firestore. Appelé automatiquement par
  /// FirebaseAnnouncementService.publishAnnouncement.
  static Future<void> notifyNewAnnouncement(String announcementId) async {
    if (ajemNotifyEndpoint.contains('VOTRE-PROJET')) {
      debugPrint(
        '[FCM] ajemNotifyEndpoint non configuré : aucune notification envoyée.',
      );
      return;
    }
    try {
      final response = await http
          .post(
            Uri.parse(ajemNotifyEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'announcementId': announcementId}),
          )
          .timeout(const Duration(seconds: 20));
      debugPrint(
        '[FCM] Serveur de notification : ${response.statusCode} ${response.body}',
      );
    } catch (e) {
      // Ne doit jamais faire échouer la publication de l'annonce.
      debugPrint('[FCM] Échec de l\'appel au serveur de notification : $e');
    }
  }
}
