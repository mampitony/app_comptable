// lib/services/firebase_announcement_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'push_notification_service.dart';

class FirebaseAnnouncementService {
  static final FirebaseAnnouncementService _instance =
      FirebaseAnnouncementService._internal();
  factory FirebaseAnnouncementService() => _instance;
  FirebaseAnnouncementService._internal();

  final _firebase = FirebaseService.instance;

  // Collection `announcements` : un document Firestore par annonce.
  //
  // ⚠️ Ne pas pointer vers `announcement_notifications` : c'est une
  // collection différente, utilisée uniquement comme déclencheur pour le
  // serveur Node.js (voir push_notification_service.dart).
  CollectionReference get _announcementsCollection =>
      _firebase.firestore.collection('announcements');

  // ─────────────────────────────────────────────────────────────────
  // 🔥 CORRECTIF "Publiées reste en chargement"
  //
  // Avant : un StreamController.broadcast() partagé. Deux défauts :
  //  1. un flux broadcast ne rejoue PAS la dernière valeur : un écran qui
  //     s'abonne après l'arrivée des données attend indéfiniment ;
  //  2. chaque écran appelait stopListening() dans son dispose(), ce qui
  //     coupait l'écoute Firestore partagée par TOUS les autres écrans
  //     (l'ancien écran est détruit après la création du nouveau).
  //
  // Maintenant : une seule écoute Firestore, jamais coupée par un écran,
  // et chaque nouvel abonné reçoit immédiatement la dernière liste connue.
  // ─────────────────────────────────────────────────────────────────
  final StreamController<List<Map<String, dynamic>>> _changes =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  List<Map<String, dynamic>>? _lastValue;
  Object? _lastError;
  StreamSubscription<QuerySnapshot>? _subscription;

  /// Flux des annonces : rejoue la dernière valeur à chaque nouvel abonné.
  /// (champ `late final` : la même instance est retournée à chaque accès,
  /// donc les StreamBuilder ne se réabonnent pas à chaque rebuild)
  late final Stream<List<Map<String, dynamic>>> announcementsStream =
      Stream<List<Map<String, dynamic>>>.multi((controller) {
    _startIfNeeded();

    final last = _lastValue;
    if (last != null) {
      controller.add(last);
    } else if (_lastError != null) {
      controller.addError(_lastError!);
    }

    final sub = _changes.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = () => sub.cancel();
  }, isBroadcast: true);

  void _startIfNeeded() {
    if (_subscription != null) return;

    // Pas de orderBy('createdAt') côté serveur : il exclurait les
    // documents sans ce champ. Le tri est fait ici, côté client.
    _subscription = _announcementsCollection.snapshots().listen(
      (snapshot) {
        final now = DateTime.now();
        final entries = snapshot.docs.map((doc) {
          final data = (doc.data() as Map<String, dynamic>?) ?? {};
          final created = data['createdAt'];
          // createdAt est null le temps que le serveur confirme l'écriture
          final date = created is Timestamp ? created.toDate() : now;
          return MapEntry(date, <String, dynamic>{
            'id': doc.id,
            'titre': data['titre'] ?? '',
            'auteur': data['auteur'] ?? '',
            'timestamp': data['timestamp'] ?? '',
            'message': data['message'] ?? '',
          });
        }).toList()
          ..sort((a, b) => a.key.compareTo(b.key)); // ancien → récent

        final announcements = entries.map((e) => e.value).toList();
        _lastValue = announcements;
        _lastError = null;
        _changes.add(announcements);
      },
      onError: (Object error) {
        _lastError = error;
        _lastValue = null;
        _changes.addError(error);
        // Le flux Firestore est terminé après une erreur : on libère pour
        // que le prochain abonné relance l'écoute.
        _subscription?.cancel();
        _subscription = null;
      },
    );
  }

  /// Démarre l'écoute si elle ne l'est pas déjà (idempotent).
  void startListening() => _startIfNeeded();

  /// Volontairement sans effet : l'écoute est partagée par tous les écrans
  /// et ne doit pas être coupée quand l'un d'eux est détruit.
  void stopListening() {}

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _changes.close();
  }

  // Publier une annonce (Admin / Responsable Communication uniquement,
  // contrôlé côté écran comme avant).
  Future<void> publishAnnouncement(
    String message, {
    String? titre,
    String auteur = 'Administration',
  }) async {
    final now = DateTime.now();
    final timestamp =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final trimmedMessage = message.trim();
    final resolvedTitre = (titre != null && titre.trim().isNotEmpty)
        ? titre.trim()
        : (trimmedMessage.length > 40
            ? '${trimmedMessage.substring(0, 40).trim()}...'
            : trimmedMessage);

    final ref = await _announcementsCollection.add({
      'titre': resolvedTitre,
      'message': message,
      'auteur': auteur,
      'timestamp': timestamp,
      'createdAt': FieldValue.serverTimestamp(),
      'statut': 'publiee',
    });

    // 🔔 Notification push à tous les membres (quel que soit l'écran qui
    // publie). Sans attente : ne ralentit ni ne fait échouer la publication.
    unawaited(PushNotificationService.notifyNewAnnouncement(ref.id));
  }

  // Suppression directe par identifiant de document.
  Future<void> deleteAnnouncement(String id) async {
    await _announcementsCollection.doc(id).delete();
  }
}
