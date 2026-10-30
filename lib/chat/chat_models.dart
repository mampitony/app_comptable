// lib/chat/chat_models.dart
//
// Modèles du module de discussion (messagerie interne AJEM).
import 'package:cloud_firestore/cloud_firestore.dart';

/// Un membre de l'association, vu depuis la messagerie.
class ChatMember {
  final String id;
  final String fullName;
  final String firstName; // prénom
  final String lastName; // nom
  final String? profileImage;
  final String roleLabel;

  /// Date d'inscription du membre (si connue).
  final DateTime? joinedAt;

  /// true si le membre peut utiliser la messagerie : compte activé ET
  /// possède un espace « membre » (un administrateur pur n'en a pas).
  final bool canChat;

  const ChatMember({
    required this.id,
    required this.fullName,
    this.firstName = '',
    this.lastName = '',
    this.profileImage,
    this.roleLabel = '',
    this.joinedAt,
    this.canChat = false,
  });

  ChatMember copyWith({
    String? fullName,
    String? firstName,
    String? lastName,
    String? profileImage,
  }) {
    return ChatMember(
      id: id,
      fullName: fullName ?? this.fullName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      profileImage: profileImage ?? this.profileImage,
      roleLabel: roleLabel,
      joinedAt: joinedAt,
      canChat: canChat,
    );
  }

  /// Membre supprimé ou introuvable.
  factory ChatMember.unknown(String id) =>
      ChatMember(id: id, fullName: 'Ancien membre');
}

/// Une conversation : privée (2 personnes) ou de groupe.
class Conversation {
  final String id;

  /// 'private' ou 'group'
  final String type;
  final String? name;
  final List<String> participants;
  final List<String> admins;
  final String createdBy;
  final String lastMessage;
  final String? lastSenderId;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  /// Dernier passage de chaque participant dans une discussion privée
  /// (sert aux coches « vu » ✓✓).
  final Map<String, DateTime> seen;

  /// Pseudos définis dans CETTE discussion (comme sur Messenger) :
  /// ils ne changent pas le nom du profil du membre.
  final Map<String, String> nicknames;

  const Conversation({
    required this.id,
    required this.type,
    required this.name,
    required this.participants,
    required this.admins,
    required this.createdBy,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastMessageAt,
    required this.createdAt,
    this.seen = const <String, DateTime>{},
    this.nicknames = const <String, String>{},
  });

  bool get isGroup => type == 'group';

  /// Date servant au tri de la liste (dernier message, sinon création).
  DateTime get sortTime => lastMessageAt ?? createdAt;

  factory Conversation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};

    List<String> strList(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : <String>[];

    // Pendant l'écriture locale, le timestamp serveur vaut null :
    // on prend alors l'heure du téléphone pour éviter un « trou » à l'écran.
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;

    final last = (d['lastMessage'] ?? '').toString();
    final seenMap = <String, DateTime>{};
    final rawSeen = d['seen'];
    if (rawSeen is Map) {
      rawSeen.forEach((k, v) {
        seenMap[k.toString()] = v is Timestamp ? v.toDate() : DateTime.now();
      });
    }
    final nickMap = <String, String>{};
    final rawNick = d['nicknames'];
    if (rawNick is Map) {
      rawNick.forEach((k, v) {
        final s = v?.toString().trim() ?? '';
        if (s.isNotEmpty) nickMap[k.toString()] = s;
      });
    }
    return Conversation(
      id: doc.id,
      type: (d['type'] ?? 'private').toString(),
      name: d['name']?.toString(),
      participants: strList(d['participants']),
      admins: strList(d['admins']),
      createdBy: (d['createdBy'] ?? '').toString(),
      lastMessage: last,
      lastSenderId: d['lastSenderId']?.toString(),
      lastMessageAt:
          ts(d['lastMessageAt']) ?? (last.isNotEmpty ? DateTime.now() : null),
      createdAt: ts(d['createdAt']) ?? DateTime.now(),
      seen: seenMap,
      nicknames: nickMap,
    );
  }
}

/// Un message d'une conversation.
class ChatMessage {
  final String id;
  final String senderId;
  final String text;

  /// 'text', 'image' ou 'system' (ex. « Paul a quitté le groupe »)
  final String type;

  /// URL de la photo (messages de type 'image').
  final String? imageUrl;

  /// true si l'expéditeur a retiré le message pour tout le monde.
  final bool deleted;

  /// État d'un appel : null (en cours), 'missed', 'declined' ou 'ended'.
  final String? callStatus;

  /// true si le message a été transféré depuis une autre discussion.
  final bool forwarded;

  /// null tant que le serveur n'a pas confirmé l'envoi.
  final DateTime? createdAt;
  final DocumentSnapshot<Map<String, dynamic>> doc;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.type,
    required this.createdAt,
    required this.doc,
    this.imageUrl,
    this.deleted = false,
    this.callStatus,
    this.forwarded = false,
  });

  bool get isSystem => type == 'system';

  /// Message « appel lancé » (voix ou vidéo).
  bool get isCall => type == 'call_video' || type == 'call_voice';
  bool get isVideoCall => type == 'call_video';
  bool get isImage =>
      type == 'image' && imageUrl != null && imageUrl!.isNotEmpty;
  bool get isPending => createdAt == null;

  DateTime get sortTime => createdAt ?? DateTime.now();

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final created = d['createdAt'];
    return ChatMessage(
      id: doc.id,
      senderId: (d['senderId'] ?? '').toString(),
      text: (d['text'] ?? '').toString(),
      type: (d['type'] ?? 'text').toString(),
      createdAt: created is Timestamp ? created.toDate() : null,
      doc: doc,
      imageUrl: d['imageUrl']?.toString(),
      deleted: d['deleted'] == true,
      callStatus: d['callStatus']?.toString(),
      forwarded: d['forwarded'] == true,
    );
  }
}
