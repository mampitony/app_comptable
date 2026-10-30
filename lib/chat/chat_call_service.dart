// lib/chat/chat_call_service.dart
//
// Appels « façon Messenger » basés sur l'invitation ZEGOCLOUD :
//   - l'appelant voit un écran « Appel en cours… » (sonnerie) tant que
//     personne n'a répondu ; la minuterie ne démarre qu'à la réponse ;
//   - les autres téléphones sonnent avec « Accepter / Refuser » ;
//   - sans réponse après 60 secondes, l'appel s'arrête et la discussion
//     affiche « Appel manqué » ;
//   - en groupe, tout le monde sonne ; ceux qui n'ont pas répondu peuvent
//     rejoindre plus tard avec le bouton « Rejoindre » tant qu'au moins une
//     personne est encore dans l'appel.
//
// Identifiant d'appel (callID) = <idConversation>__<idMessage> : il est unique
// pour chaque appel, ce qui permet de retrouver le message à mettre à jour.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zego_express_engine_for_uikit/zego_express_engine.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import 'chat_call_config.dart';

class ChatCallService {
  ChatCallService._();
  static final ChatCallService instance = ChatCallService._();

  /// Clé de navigation : à donner au MaterialApp (voir main.dart). Elle permet
  /// d'afficher l'écran d'appel entrant par-dessus n'importe quelle page.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Durée de la sonnerie sans réponse avant que l'appel soit coupé.
  static const int ringSeconds = 60;

  /// Volume de lecture de la voix de l'interlocuteur, en % (100 = normal,
  /// 200 = maximum de ZEGOCLOUD). Plus il est haut, plus le micro risque de
  /// reprendre le haut-parleur (écho) : 150 est un bon compromis. Montez à
  /// 200 si le son reste trop faible, baissez à 120 si l'écho persiste.
  static const int callPlayVolume = 150;

  /// Anti-écho et réduction de bruit. ZEGOCLOUD demande de les activer AVANT
  /// le début de la publication / lecture des flux, donc dès la connexion
  /// (start) puis encore à la préparation de chaque appel (configFor).
  static Future<void> applyAudioProcessing() async {
    try {
      final e = ZegoExpressEngine.instance;
      await e.enableAEC(true); // annulation d'écho
      await e.setAECMode(ZegoAECMode.Aggressive); // la plus forte
      await e.enableHeadphoneAEC(true);
      await e.enableAGC(true); // volume du micro stable
      await e.enableANS(true); // réduction de bruit
      await e.enableTransientANS(true); // claquements, touches
      await e.setANSMode(ZegoANSMode.Medium);
    } catch (e) {
      debugPrint('[Call] audio 3A: $e'); // moteur pas encore créé
    }
  }

  static Timer? _volumeTimer;

  /// Applique le volume maximal aux voix reçues. Le réglage est refait toutes
  /// les 2 s car il doit être reposé à chaque nouvelle arrivée de flux.
  static void startVolumeBoost() {
    _volumeTimer?.cancel();
    var ticks = 0;
    _volumeTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      ticks++;
      if (ticks > 5400) {
        stopVolumeBoost(); // sécurité : 3 h maximum
        return;
      }
      try {
        await ZegoExpressEngine.instance.setAllPlayStreamVolume(callPlayVolume);
      } catch (_) {
        // Moteur pas encore prêt ou déjà détruit : on réessaie au prochain tour.
      }
    });
  }

  static void stopVolumeBoost() {
    _volumeTimer?.cancel();
    _volumeTimer = null;
  }

  /// Ressource de notification push d'appel créée dans la console ZEGOCLOUD
  /// (Configuration des notifications > Ressource push personnalisée).
  /// Elle permet de faire sonner un téléphone dont l'application est fermée.
  static const String pushResourceId = 'ajem_call';

  String? _userId;
  String? _outgoingCallId; // dernier appel lancé depuis ce téléphone
  bool _outgoingGroup = false;

  /// Appel dans lequel ce téléphone se trouve actuellement.
  String? currentCallId;

  // ------------------------------------------------------------------
  // Identifiants
  // ------------------------------------------------------------------

  /// ZEGO n'accepte que lettres, chiffres, « _ » et « - » dans un identifiant.
  static String zegoId(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');

  static String callIdFor(String conversationId, String messageId) =>
      '${conversationId}__$messageId';

  /// Retrouve (conversation, message) à partir de l'identifiant d'appel.
  static ({String conversationId, String messageId})? parseCallId(
      String callId) {
    final i = callId.lastIndexOf('__');
    if (i <= 0 || i + 2 >= callId.length) return null;
    return (
      conversationId: callId.substring(0, i),
      messageId: callId.substring(i + 2),
    );
  }

  // ------------------------------------------------------------------
  // Démarrage (à appeler une fois dans main(), avant runApp)
  // ------------------------------------------------------------------

  static Future<void> prepare() async {
    ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);
    await ZegoUIKit().initLog();
    // Appel entrant avec l'application fermée : écran d'appel système + sonnerie.
    ZegoUIKitPrebuiltCallInvitationService()
        .useSystemCallingUI([ZegoUIKitSignalingPlugin()]);
  }

  // ------------------------------------------------------------------
  // Connexion / déconnexion du service d'invitation
  // ------------------------------------------------------------------

  /// À appeler dès que le membre est connecté pour pouvoir recevoir des appels.
  Future<void> start({required String userId, required String userName}) async {
    if (!zegoConfigured) return;
    final zid = zegoId(userId);
    if (_userId == zid) return;
    if (_userId != null) await stop();
    _userId = zid;

    try {
      await ZegoUIKitPrebuiltCallInvitationService().init(
        appID: zegoAppID,
        appSign: zegoAppSign,
        userID: zid,
        userName: userName,
        plugins: [ZegoUIKitSignalingPlugin()],
        // Configuration de l'écran d'appel, une fois quelqu'un a répondu.
        requireConfig: (ZegoCallInvitationData data) {
          currentCallId = data.callID;
          final video = data.type == ZegoCallInvitationType.videoCall;
          final group = data.invitees.length > 1 || data.customData == 'group';
          return configFor(video: video, group: group);
        },
        events: ZegoUIKitPrebuiltCallEvents(onCallEnd: handleCallEnd),
        invitationEvents: ZegoUIKitPrebuiltCallInvitationEvents(
          // Personne n'a répondu en 60 secondes.
          onOutgoingCallTimeout: (String callID, List<ZegoCallUser> callees,
              bool isVideoCall) {
            _setStatus(callID, 'missed');
          },
          // Appel refusé (discussion privée uniquement).
          onOutgoingCallDeclined:
              (String callID, ZegoCallUser callee, String customData) {
            if (!_outgoingGroup) _setStatus(callID, 'declined');
          },
          // L'appelant a raccroché avant toute réponse.
          onOutgoingCallCancelButtonPressed: () {
            final id = _outgoingCallId;
            if (id != null) _setStatus(id, 'missed');
          },
        ),
      );
      await applyAudioProcessing();
    } catch (e) {
      debugPrint('[Call] init error: $e');
      _userId = null;
    }
  }

  Future<void> stop() async {
    if (_userId == null) return;
    _userId = null;
    try {
      await ZegoUIKitPrebuiltCallInvitationService().uninit();
    } catch (e) {
      debugPrint('[Call] uninit error: $e');
    }
  }

  // ------------------------------------------------------------------
  // Lancer un appel (la sonnerie démarre sur les autres téléphones)
  // ------------------------------------------------------------------

  /// [invitees] : identifiants des autres participants avec leur nom.
  Future<bool> invite({
    required String conversationId,
    required String messageId,
    required bool video,
    required bool group,
    required List<({String id, String name})> invitees,
    required String title,
  }) async {
    if (_userId == null || invitees.isEmpty) return false;
    final callId = callIdFor(conversationId, messageId);
    _outgoingCallId = callId;
    _outgoingGroup = group;
    currentCallId = callId;
    try {
      return await ZegoUIKitPrebuiltCallInvitationService().send(
        invitees: invitees
            .map((u) => ZegoCallUser(zegoId(u.id), u.name))
            .toList(),
        isVideoCall: video,
        callID: callId,
        customData: group ? 'group' : 'private',
        timeoutSeconds: ringSeconds,
        resourceID: pushResourceId,
        notificationTitle: title,
        notificationMessage:
            video ? 'Appel vidéo entrant' : 'Appel vocal entrant',
      );
    } catch (e) {
      debugPrint('[Call] send error: $e');
      return false;
    }
  }

  /// Appel impossible à faire sonner (personne de joignable) : la carte passe
  /// en « sans réponse » au lieu de rester « en cours ».
  Future<void> closeUnanswered(String conversationId, String messageId) =>
      _setStatus(callIdFor(conversationId, messageId), 'missed');

  // ------------------------------------------------------------------
  // Configuration de l'écran d'appel
  // ------------------------------------------------------------------

  static ZegoUIKitPrebuiltCallConfig configFor({
    required bool video,
    required bool group,
    bool showDuration = true,
  }) {
    final ZegoUIKitPrebuiltCallConfig config;
    if (group) {
      config = video
          ? ZegoUIKitPrebuiltCallConfig.groupVideoCall()
          : ZegoUIKitPrebuiltCallConfig.groupVoiceCall();
    } else {
      config = video
          ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
          : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();
    }
    // Son fort : par défaut, un appel vocal à deux utilise l'écouteur du
    // téléphone (très faible, comme à l'oreille). On démarre sur le haut-parleur ;
    // le bouton haut-parleur de l'écran d'appel permet de repasser à l'écouteur.
    config.useSpeakerWhenJoining = true;

    // Anti-écho avant le début des flux audio, puis volume renforcé.
    applyAudioProcessing();
    startVolumeBoost();

    // La durée affichée démarre quand la personne a répondu.
    config.duration.isVisible = showDuration;
    return config;
  }

  // ------------------------------------------------------------------
  // Fin d'appel : la dernière personne qui quitte clôt l'appel
  // ------------------------------------------------------------------

  void handleCallEnd(ZegoCallEndEvent event, VoidCallback defaultAction) {
    final id = currentCallId;
    if (id != null) {
      bool lastOne;
      try {
        lastOne = ZegoUIKit().getRemoteUsers().isEmpty;
      } catch (_) {
        lastOne = false;
      }
      if (lastOne || event.reason == ZegoCallEndReason.remoteHangUp) {
        _setStatus(id, 'ended');
      }
    }
    currentCallId = null;
    stopVolumeBoost();
    defaultAction.call();
  }

  // ------------------------------------------------------------------
  // État de l'appel dans la discussion (missed / declined / ended)
  // ------------------------------------------------------------------

  Future<void> _setStatus(String callId, String status) async {
    final p = parseCallId(callId);
    if (p == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(p.conversationId)
          .collection('messages')
          .doc(p.messageId)
          .update(<String, dynamic>{'callStatus': status});
    } catch (e) {
      // Déjà clos par un autre participant : sans importance.
      debugPrint('[Call] status error: $e');
    }
  }
}
