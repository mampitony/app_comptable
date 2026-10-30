// lib/chat/chat_service.dart
//
// Service unique de la messagerie. Il ne modifie AUCUNE donnée existante
// (users, revenus, dépenses...) : il utilise uniquement ses propres
// collections Firestore :
//   - chatUsers/{authUid}      lien « compte Firebase anonyme -> membre » + jeton FCM
//   - chatReads/{memberId}     dernière lecture de chaque conversation
//   - conversations/{id}       conversations privées / groupes
//   - conversations/{id}/messages/{id}
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../database/firebase_user_repository.dart';
import '../services/image_upload_service.dart';
import 'chat_call_service.dart';
import 'chat_models.dart';

/// ⚠️ À adapter : URL de ton déploiement Vercel + « /api/notify-chat ».
const String chatNotifyEndpoint =
    'https://association-ajem-fianarantsoa-madagacar.vercel.app/api/notify-chat';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');
  CollectionReference<Map<String, dynamic>> get _chatUsers =>
      _db.collection('chatUsers');
  CollectionReference<Map<String, dynamic>> get _chatReads =>
      _db.collection('chatReads');
  CollectionReference<Map<String, dynamic>> get _chatHidden =>
      _db.collection('chatHidden');

  // ------------------------------------------------------------------
  // État observable par l'interface
  // ------------------------------------------------------------------
  String? _memberId;
  String? get memberId => _memberId;

  /// Conversations de l'utilisateur, triées de la plus récente à la plus ancienne.
  final ValueNotifier<List<Conversation>> conversations =
      ValueNotifier<List<Conversation>>(<Conversation>[]);

  /// Nombre de conversations contenant des messages non lus (pastille).
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// Identifiants des conversations non lues.
  final ValueNotifier<Set<String>> unreadIds =
      ValueNotifier<Set<String>>(<String>{});

  /// Messages que CE membre a retirés « pour lui » : conversation -> ids.
  final ValueNotifier<Map<String, Set<String>>> hidden =
      ValueNotifier<Map<String, Set<String>>>(<String, Set<String>>{});

  /// Incrémenté quand l'annuaire change (nom / photo modifiés) pour
  /// rafraîchir les écrans ouverts.
  final ValueNotifier<int> directoryTick = ValueNotifier<int>(0);

  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  Map<String, ChatMember> _directory = <String, ChatMember>{};

  /// Données du membre connecté (la même Map que celle de l'application),
  /// mises à jour quand il modifie son profil.
  Map<String, dynamic>? _userData;
  Map<String, DateTime> _reads = <String, DateTime>{};

  Future<void>? _initFuture;
  String? _initFor;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _convSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _readsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _hiddenSub;
  StreamSubscription<String>? _tokenSub;

  // ------------------------------------------------------------------
  // Initialisation (appelée automatiquement par l'icône de messagerie)
  // ------------------------------------------------------------------

  /// Prépare la messagerie pour le membre connecté. Idempotent : on peut
  /// l'appeler plusieurs fois, la préparation n'a lieu qu'une fois par membre.
  Future<void> init(Map<String, dynamic> userData) {
    final id = (userData['id'] ?? '').toString();
    if (id.isEmpty) return Future<void>.value();
    if (_initFor == id && _initFuture != null) return _initFuture!;

    _initFor = id;
    _userData = userData;
    _initFuture = _doInit(id).catchError((Object e) {
      debugPrint('[Chat] init error: $e');
      error.value = e.toString();
      // Permet de réessayer plus tard.
      _initFuture = null;
      _initFor = null;
    });
    return _initFuture!;
  }

  Future<void> _doInit(String id) async {
    ready.value = false;
    error.value = null;
    await _convSub?.cancel();
    await _readsSub?.cancel();
    await _hiddenSub?.cancel();
    _convSub = null;
    _readsSub = null;
    _hiddenSub = null;
    hidden.value = <String, Set<String>>{};
    conversations.value = <Conversation>[];
    _reads = <String, DateTime>{};
    _recomputeUnread();

    _memberId = id;
    await _ensureSignedIn(id);
    await loadDirectory();
    _startListeners();
    unawaited(_registerToken());
    ready.value = true;

    // 📞 Prêt à recevoir des appels (sonnerie) dès la connexion.
    unawaited(ChatCallService.instance
        .start(userId: id, userName: memberById(id).fullName));
  }

  /// Connecte l'appareil à Firebase en mode anonyme et le relie au membre.
  /// L'écran de connexion existant n'est pas modifié : c'est un simple
  /// « badge » invisible qui permet aux règles Firestore de savoir qui lit.
  Future<void> _ensureSignedIn(String memberId) async {
    final current = _auth.currentUser;
    if (current != null) {
      final snap = await _chatUsers.doc(current.uid).get();
      if (snap.exists) {
        if (snap.data()?['memberId'] == memberId) return; // déjà lié
        // Un autre membre utilise ce téléphone : on repart d'un badge neuf.
        await _chatUsers.doc(current.uid).delete();
        await _auth.signOut();
      }
    }

    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
    final uid = _auth.currentUser!.uid;
    final ref = _chatUsers.doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set(<String, dynamic>{
        'memberId': memberId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// À appeler (facultatif) à la déconnexion : le téléphone cesse de
  /// recevoir les notifications de discussion de ce membre.
  Future<void> signOut() async {
    await ChatCallService.instance.stop();
    try {
      await _convSub?.cancel();
      await _readsSub?.cancel();
      await _hiddenSub?.cancel();
      _convSub = null;
      _readsSub = null;
      _hiddenSub = null;
      hidden.value = <String, Set<String>>{};
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _chatUsers.doc(uid).delete();
        await _auth.signOut();
      }
    } catch (e) {
      debugPrint('[Chat] signOut error: $e');
    }
    _memberId = null;
    _initFor = null;
    _initFuture = null;
    conversations.value = <Conversation>[];
    _reads = <String, DateTime>{};
    _recomputeUnread();
    ready.value = false;
  }

  // ------------------------------------------------------------------
  // Annuaire des membres (chargé une seule fois par session)
  // ------------------------------------------------------------------

  /// Un membre peut utiliser la messagerie s'il possède un espace « membre ».
  /// Même logique que SpaceSwitcher.spacesFor : un administrateur sans
  /// fonction spécifique n'a pas d'espace membre, donc pas de messagerie.
  static bool hasMemberSpace(Map<String, dynamic> user) {
    final adminRole = FirebaseUserRepository.resolveAdminRole(user);
    if (adminRole == null) return true;
    final roles = FirebaseUserRepository.resolveRoles(user);
    return roles.any((r) {
      final x = r.trim().toLowerCase();
      return x != 'membre' && x != 'membre actif';
    });
  }

  Future<void> loadDirectory() async {
    final snap = await _db.collection('users').get();
    final map = <String, ChatMember>{};
    for (final doc in snap.docs) {
      final user = <String, dynamic>{'id': doc.id, ...doc.data()};
      final prenom = (user['prenom'] ?? '').toString().trim();
      final nom = (user['name'] ?? '').toString().trim();
      final full = [prenom, nom].where((s) => s.isNotEmpty).join(' ');
      final activated = (user['passwordHash'] ?? '').toString().isNotEmpty;

      var roleLabel = FirebaseUserRepository.rolesLabel(user);
      if (roleLabel.startsWith('admin_')) roleLabel = '';

      final created = user['createdAt'];
      map[doc.id] = ChatMember(
        id: doc.id,
        fullName: full.isEmpty ? 'Membre' : full,
        firstName: prenom,
        lastName: nom,
        profileImage: user['profileImage']?.toString(),
        roleLabel: roleLabel,
        joinedAt: created is Timestamp ? created.toDate() : null,
        canChat: activated && hasMemberSpace(user),
      );
    }
    _directory = map;
  }

  ChatMember memberById(String id) =>
      _directory[id] ?? ChatMember.unknown(id);

  /// Membres avec qui on peut discuter (hors soi-même), triés par nom.
  List<ChatMember> get chatMembers {
    final list = _directory.values
        .where((m) => m.canChat && m.id != _memberId)
        .toList()
      ..sort((a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return list;
  }

  /// Interlocuteur d'une conversation privée.
  ChatMember? otherMember(Conversation c) {
    if (c.isGroup) return null;
    final other = c.participants.firstWhere(
      (p) => p != _memberId,
      orElse: () => '',
    );
    return other.isEmpty ? null : memberById(other);
  }

  /// Nom à afficher pour un membre dans une conversation : son pseudo s'il
  /// en a un dans cette discussion, sinon le nom de son profil.
  String nameIn(Conversation? c, String memberId) {
    final nick = c?.nicknames[memberId];
    if (nick != null && nick.trim().isNotEmpty) return nick;
    return memberById(memberId).fullName;
  }

  String titleOf(Conversation c) {
    if (c.isGroup) {
      final n = (c.name ?? '').trim();
      return n.isEmpty ? 'Groupe' : n;
    }
    final other = c.participants.firstWhere(
      (p) => p != _memberId,
      orElse: () => '',
    );
    return other.isEmpty ? 'Discussion' : nameIn(c, other);
  }

  // ------------------------------------------------------------------
  // Écoute des conversations + lectures
  // ------------------------------------------------------------------

  void _startListeners() {
    final me = _memberId;
    if (me == null) return;

    _convSub = _conversations
        .where('participants', arrayContains: me)
        .snapshots()
        .listen(
      (snap) {
        final list = snap.docs.map(Conversation.fromDoc).toList()
          ..sort((a, b) => b.sortTime.compareTo(a.sortTime));
        conversations.value = list;
        error.value = null;
        _recomputeUnread();
      },
      onError: (Object e) {
        debugPrint('[Chat] conversations error: $e');
        error.value = e.toString();
      },
    );

    _readsSub = _chatReads.doc(me).snapshots().listen(
      (snap) {
        final data = snap.data() ?? <String, dynamic>{};
        final map = <String, DateTime>{};
        data.forEach((key, value) {
          // Valeur null = écriture locale en attente : on prend l'heure actuelle.
          map[key] = value is Timestamp ? value.toDate() : DateTime.now();
        });
        _reads = map;
        _recomputeUnread();
      },
      onError: (Object e) => debugPrint('[Chat] reads error: $e'),
    );

    _hiddenSub = _chatHidden.doc(me).snapshots().listen(
      (snap) {
        final data = snap.data() ?? <String, dynamic>{};
        final map = <String, Set<String>>{};
        data.forEach((convId, value) {
          if (value is List) {
            map[convId] = value.map((e) => e.toString()).toSet();
          }
        });
        hidden.value = map;
      },
      onError: (Object e) => debugPrint('[Chat] hidden error: $e'),
    );
  }

  /// Ids des messages retirés « pour moi » dans une conversation.
  Set<String> hiddenIds(String conversationId) =>
      hidden.value[conversationId] ?? const <String>{};

  void _recomputeUnread() {
    final me = _memberId;
    final ids = <String>{};
    if (me != null) {
      for (final c in conversations.value) {
        final at = c.lastMessageAt;
        if (at == null || c.lastSenderId == me) continue;
        final read = _reads[c.id];
        if (read == null || at.isAfter(read)) ids.add(c.id);
      }
    }
    unreadIds.value = ids;
    unreadCount.value = ids.length;
  }

  /// Marque la conversation comme lue (un seul petit document par membre,
  /// donc aucune lecture inutile chez les autres participants).
  Future<void> markRead(String conversationId) async {
    final me = _memberId;
    if (me == null) return;
    try {
      await _chatReads.doc(me).set(
        <String, dynamic>{conversationId: FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      // Discussion privée : l'autre personne voit les coches « vu » ✓✓.
      Conversation? conv;
      for (final c in conversations.value) {
        if (c.id == conversationId) {
          conv = c;
          break;
        }
      }
      if (conv != null && !conv.isGroup) {
        await _conversations.doc(conversationId).update(<String, dynamic>{
          'seen.$me': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[Chat] markRead error: $e');
    }
  }

  // ------------------------------------------------------------------
  // Messages
  // ------------------------------------------------------------------

  Query<Map<String, dynamic>> messagesQuery(String conversationId, int limit) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }

  Future<void> sendMessage(String conversationId, String text) async {
    final me = _requireMe();
    var t = text.trim();
    if (t.isEmpty) return;
    if (t.length > 2000) t = t.substring(0, 2000);

    final convRef = _conversations.doc(conversationId);
    final msgRef = convRef.collection('messages').doc();
    final oneLine = t.replaceAll('\n', ' ');
    final preview =
        oneLine.length > 120 ? '${oneLine.substring(0, 120)}…' : oneLine;

    final batch = _db.batch();
    batch.set(msgRef, <String, dynamic>{
      'senderId': me,
      'text': t,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(convRef, <String, dynamic>{
      'lastMessage': preview,
      'lastSenderId': me,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    unawaited(_notify(conversationId, msgRef.id));
  }

  /// Envoie une ou plusieurs photos (une seule notification pour le lot).
  /// Chaque photo est hébergée sur ImgBB (comme les photos de profil) et
  /// seule son URL est enregistrée dans Firestore. Chaque photo est un
  /// message à part : on peut donc en retirer une seule.
  Future<void> sendImages(
    String conversationId,
    List<File> files, {
    void Function(int done, int total)? onProgress,
  }) async {
    final me = _requireMe();
    final convRef = _conversations.doc(conversationId);
    String? lastId;
    var sent = 0;

    try {
      for (var i = 0; i < files.length; i++) {
        onProgress?.call(i, files.length);
        final url = await ImageUploadService.uploadImage(files[i]);

        final msgRef = convRef.collection('messages').doc();
        final batch = _db.batch();
        batch.set(msgRef, <String, dynamic>{
          'senderId': me,
          'text': '',
          'imageUrl': url,
          'type': 'image',
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.update(convRef, <String, dynamic>{
          'lastMessage': '📷 Photo',
          'lastSenderId': me,
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
        lastId = msgRef.id;
        sent++;
      }
      onProgress?.call(files.length, files.length);
    } finally {
      if (lastId != null) {
        unawaited(_notify(conversationId, lastId, count: sent));
      }
    }
  }

  /// Transfère un message texte ou une photo vers une ou plusieurs
  /// discussions. La photo n'est pas renvoyée sur ImgBB : son adresse est
  /// simplement réutilisée. Les appels et messages système ne se transfèrent pas.
  Future<void> forwardMessage(
    ChatMessage m,
    List<String> conversationIds,
  ) async {
    final me = _requireMe();
    if (m.isCall || m.isSystem || m.deleted) return;

    final isImage = m.isImage;
    var text = isImage ? '' : m.text.trim();
    if (!isImage && text.isEmpty) return;
    if (text.length > 2000) text = text.substring(0, 2000);

    final oneLine = text.replaceAll('\n', ' ');
    final preview = isImage
        ? '📷 Photo'
        : (oneLine.length > 120 ? '${oneLine.substring(0, 120)}…' : oneLine);

    for (final convId in conversationIds) {
      final convRef = _conversations.doc(convId);
      final msgRef = convRef.collection('messages').doc();

      final batch = _db.batch();
      batch.set(msgRef, <String, dynamic>{
        'senderId': me,
        'text': text,
        'type': isImage ? 'image' : 'text',
        if (isImage) 'imageUrl': m.imageUrl,
        'forwarded': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(convRef, <String, dynamic>{
        'lastMessage': preview,
        'lastSenderId': me,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      unawaited(_notify(convId, msgRef.id));
    }
  }

  // ------------------------------------------------------------------
  // Appels
  // ------------------------------------------------------------------

  /// Annonce un appel dans la discussion (message « Appel vidéo / vocal »
  /// avec bouton « Rejoindre ») et notifie les autres participants.
  /// Retourne l'identifiant du message : il identifie l'appel (voir
  /// ChatCallService.callIdFor).
  Future<String> startCall(String conversationId, {required bool video}) async {
    final me = _requireMe();
    final convRef = _conversations.doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    final batch = _db.batch();
    batch.set(msgRef, <String, dynamic>{
      'senderId': me,
      'text': video ? 'Appel vidéo' : 'Appel vocal',
      'type': video ? 'call_video' : 'call_voice',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(convRef, <String, dynamic>{
      'lastMessage': video ? '🎥 Appel vidéo' : '📞 Appel vocal',
      'lastSenderId': me,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    // Pas de notification de message ici : la sonnerie d'appel (ZEGOCLOUD)
    // prévient déjà les autres téléphones, même application fermée.
    return msgRef.id;
  }

  // ------------------------------------------------------------------
  // Retirer un message
  // ------------------------------------------------------------------

  /// « Supprimer pour moi » : le message disparaît seulement de mon écran.
  Future<void> hideForMe(String conversationId, String messageId) async {
    final me = _requireMe();
    await _chatHidden.doc(me).set(
      <String, dynamic>{
        conversationId: FieldValue.arrayUnion(<String>[messageId]),
      },
      SetOptions(merge: true),
    );
  }

  /// « Supprimer pour tout le monde » (expéditeur uniquement) : le contenu
  /// du message est effacé de la base, plus personne ne le voit.
  Future<void> deleteForEveryone(String conversationId, String messageId) async {
    await _conversations
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update(<String, dynamic>{
      'deleted': true,
      'text': '',
      'imageUrl': FieldValue.delete(),
    });
    await _refreshLastMessage(conversationId);
  }

  /// Recalcule l'aperçu de la liste (dernier message encore visible), pour
  /// qu'un message retiré ne reste pas affiché dans la liste des discussions.
  Future<void> _refreshLastMessage(String conversationId) async {
    try {
      final convRef = _conversations.doc(conversationId);
      final snap = await convRef
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      ChatMessage? last;
      for (final d in snap.docs) {
        final m = ChatMessage.fromDoc(d);
        if (m.deleted || m.isSystem || m.createdAt == null) continue;
        last = m;
        break;
      }

      if (last != null) {
        final oneLine = last.text.replaceAll('\n', ' ');
        final preview = last.isImage
            ? '📷 Photo'
            : last.isCall
                ? (last.isVideoCall ? '🎥 Appel vidéo' : '📞 Appel vocal')
                : (oneLine.length > 120 ? '${oneLine.substring(0, 120)}…' : oneLine);
        await convRef.update(<String, dynamic>{
          'lastMessage': preview,
          'lastSenderId': last.senderId,
          'lastMessageAt': Timestamp.fromDate(last.createdAt!),
        });
      } else {
        await convRef.update(<String, dynamic>{
          'lastMessage': '',
          'lastSenderId': FieldValue.delete(),
          'lastMessageAt': FieldValue.delete(),
        });
      }
    } catch (e) {
      debugPrint('[Chat] refreshLastMessage error: $e');
    }
  }

  Future<void> _addSystemMessage(String conversationId, String text) async {
    await _conversations.doc(conversationId).collection('messages').add(
      <String, dynamic>{
        'senderId': _requireMe(),
        'text': text,
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// Demande au serveur Vercel d'envoyer la notification push.
  /// Un échec n'est pas grave : le message est déjà enregistré.
  /// Notification classique « appel » pour les personnes qui ne sont pas
  /// encore enregistrées à la sonnerie (elles rejoignent depuis la discussion).
  Future<void> notifyCallFallback(String conversationId, String messageId) =>
      _notify(conversationId, messageId);

  Future<void> _notify(String conversationId, String messageId,
      {int count = 1}) async {
    try {
      await http
          .post(
            Uri.parse(chatNotifyEndpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'conversationId': conversationId,
              'messageId': messageId,
              'count': count,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('[Chat] notify error: $e');
    }
  }

  // ------------------------------------------------------------------
  // Création de conversations
  // ------------------------------------------------------------------

  /// Ouvre (ou crée) la discussion privée avec un membre. L'identifiant est
  /// déterministe : il n'y a jamais deux discussions privées entre les
  /// mêmes personnes.
  Future<String> openPrivateConversation(String otherId) async {
    final me = _requireMe();
    final ids = <String>[me, otherId]..sort();
    final id = 'p_${ids[0]}_${ids[1]}';
    final ref = _conversations.doc(id);

    final snap = await ref.get();
    if (!snap.exists) {
      try {
        await ref.set(<String, dynamic>{
          'type': 'private',
          'participants': ids,
          'admins': <String>[],
          'createdBy': me,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException {
        // L'autre personne vient peut-être de la créer en même temps.
        final again = await ref.get();
        if (!again.exists) rethrow;
      }
    }
    return id;
  }

  Future<String> createGroup(String name, List<String> memberIds) async {
    final me = _requireMe();
    final participants = <String>{me, ...memberIds}.toList();
    final ref = _conversations.doc();
    await ref.set(<String, dynamic>{
      'type': 'group',
      'name': name.trim(),
      'participants': participants,
      'admins': <String>[me],
      'createdBy': me,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _addSystemMessage(
        ref.id, '${memberById(me).fullName} a créé le groupe');
    return ref.id;
  }

  // ------------------------------------------------------------------
  // Mon profil (fiche membre) et pseudos
  // ------------------------------------------------------------------

  /// Modifie MON prénom / nom / photo. Ces champs sont ceux de la fiche
  /// membre : ils changent donc aussi dans la liste des membres.
  Future<void> updateMyProfile({
    required String firstName,
    required String lastName,
    File? newPhoto,
  }) async {
    final me = _requireMe();
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isEmpty && l.isEmpty) {
      throw ArgumentError('Le nom ne peut pas être vide.');
    }

    final updates = <String, dynamic>{'prenom': f, 'name': l};
    String? url;
    if (newPhoto != null) {
      url = await ImageUploadService.uploadImage(newPhoto);
      updates['profileImage'] = url;
    }
    await _db.collection('users').doc(me).update(updates);

    // Met à jour l'annuaire local et les données de session.
    final old = memberById(me);
    _directory[me] = old.copyWith(
      fullName: [f, l].where((s) => s.isNotEmpty).join(' '),
      firstName: f,
      lastName: l,
      profileImage: url,
    );
    try {
      _userData?['prenom'] = f;
      _userData?['name'] = l;
      if (url != null) _userData?['profileImage'] = url;
    } catch (_) {
      // Map non modifiable : sans importance, rechargée à la prochaine connexion.
    }
    directoryTick.value++;
  }

  /// Définit (ou retire, si vide) le pseudo d'un participant dans cette
  /// discussion uniquement. Le nom du profil ne change pas.
  Future<void> setNickname(
      String conversationId, String targetId, String nickname) async {
    final me = _requireMe();
    var n = nickname.trim();
    if (n.length > 30) n = n.substring(0, 30);

    await _conversations.doc(conversationId).update(<String, dynamic>{
      'nicknames.$targetId': n.isEmpty ? FieldValue.delete() : n,
    });

    final actor = memberById(me).fullName;
    final target = memberById(targetId).fullName;
    await _addSystemMessage(
      conversationId,
      n.isEmpty
          ? '$actor a retiré le pseudo de $target'
          : '$actor a défini le pseudo de $target : « $n »',
    );
  }

  // ------------------------------------------------------------------
  // Gestion d'un groupe
  // ------------------------------------------------------------------

  Future<void> renameGroup(String conversationId, String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    await _conversations.doc(conversationId).update(<String, dynamic>{
      'name': n,
    });
  }

  Future<void> addMembers(String conversationId, List<String> ids) async {
    if (ids.isEmpty) return;
    await _conversations.doc(conversationId).update(<String, dynamic>{
      'participants': FieldValue.arrayUnion(ids),
    });
    final names = ids.map((i) => memberById(i).fullName).join(', ');
    await _addSystemMessage(conversationId,
        '${memberById(_requireMe()).fullName} a ajouté $names');
  }

  Future<void> removeMember(String conversationId, String memberId) async {
    await _conversations.doc(conversationId).update(<String, dynamic>{
      'participants': FieldValue.arrayRemove(<String>[memberId]),
      'admins': FieldValue.arrayRemove(<String>[memberId]),
    });
    await _addSystemMessage(conversationId,
        '${memberById(_requireMe()).fullName} a retiré ${memberById(memberId).fullName}');
  }

  Future<void> makeAdmin(String conversationId, String memberId) async {
    await _conversations.doc(conversationId).update(<String, dynamic>{
      'admins': FieldValue.arrayUnion(<String>[memberId]),
    });
  }

  Future<void> leaveGroup(Conversation c) async {
    final me = _requireMe();
    // Le message doit être écrit AVANT de partir (après, on n'a plus accès).
    await _addSystemMessage(c.id, '${memberById(me).fullName} a quitté le groupe');

    final remaining = c.participants.where((p) => p != me).toList();
    final admins = c.admins.where((a) => a != me).toList();
    // Si le dernier administrateur part, le plus ancien participant le devient.
    if (admins.isEmpty && remaining.isNotEmpty) admins.add(remaining.first);

    await _conversations.doc(c.id).update(<String, dynamic>{
      'participants': remaining,
      'admins': admins,
    });
  }

  // ------------------------------------------------------------------
  // Notifications push : on enregistre le jeton FCM de l'appareil
  // ------------------------------------------------------------------

  Future<void> _registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
      _tokenSub ??= FirebaseMessaging.instance.onTokenRefresh.listen(
        (t) => _saveToken(t),
      );
    } catch (e) {
      debugPrint('[Chat] token error: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _chatUsers.doc(uid).set(
        <String, dynamic>{
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[Chat] saveToken error: $e');
    }
  }

  String _requireMe() {
    final me = _memberId;
    if (me == null) throw StateError('Messagerie non initialisée');
    return me;
  }
}
