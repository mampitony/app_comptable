// lib/chat/chat_room_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_call_config.dart';
import 'chat_call_screen.dart';
import 'chat_call_service.dart';
import 'chat_forward_screen.dart';
import 'chat_models.dart';
import 'chat_service.dart';
import 'chat_widgets.dart';
import 'chat_profile_screen.dart';
import 'group_info_screen.dart';
import 'private_info_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final String conversationId;

  const ChatRoomScreen({super.key, required this.conversationId});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  /// Nombre de messages chargés à la fois (économise les lectures Firestore).
  static const int _page = 30;

  final ChatService _service = ChatService.instance;
  final TextEditingController _input = TextEditingController();

  /// Tous les messages vus jusqu'ici. On ne retire jamais rien : quand de
  /// nouveaux messages arrivent, la fenêtre « temps réel » glisse, mais les
  /// anciens restent affichés.
  final Map<String, ChatMessage> _byId = <String, ChatMessage>{};
  List<ChatMessage> _messages = <ChatMessage>[];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  DocumentSnapshot<Map<String, dynamic>>? _oldestDoc;

  bool _loaded = false;
  bool _hasMore = false;
  bool _loadingOlder = false;
  bool _timedOut = false;
  bool _uploading = false;
  String _uploadLabel = '';
  double? _uploadProgress;
  String? _error;
  String? _lastMarkedId;

  @override
  void initState() {
    super.initState();

    _sub = _service.messagesQuery(widget.conversationId, _page).snapshots().listen(
      _onSnapshot,
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _error = chatFriendlyError(e));
      },
    );

    // Messages retirés « pour moi » : mise à jour immédiate de l'écran.
    _service.hidden.addListener(_onHiddenChanged);

    Future<void>.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _service.hidden.removeListener(_onHiddenChanged);
    _sub?.cancel();
    _input.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Données
  // ------------------------------------------------------------------
  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    for (final d in snap.docs) {
      _byId[d.id] = ChatMessage.fromDoc(d);
    }
    if (!_loaded) {
      _loaded = true;
      _hasMore = snap.docs.length >= _page;
    }
    _rebuildList();
    if (!snap.metadata.hasPendingWrites) _markReadIfNeeded();
    if (mounted) setState(() => _error = null);
  }

  void _onHiddenChanged() {
    if (!mounted) return;
    setState(_rebuildList);
  }

  void _rebuildList() {
    final all = _byId.values.toList()
      ..sort((a, b) => b.sortTime.compareTo(a.sortTime));

    // On garde les messages retirés dans _byId (pour la pagination) mais on
    // ne les affiche pas : retirés pour tous, ou retirés « pour moi ».
    final hiddenIds = _service.hiddenIds(widget.conversationId);
    _messages =
        all.where((m) => !m.deleted && !hiddenIds.contains(m.id)).toList();

    DocumentSnapshot<Map<String, dynamic>>? oldest;
    for (final m in all.reversed) {
      if (m.createdAt != null) {
        oldest = m.doc;
        break;
      }
    }
    _oldestDoc = oldest;
  }

  void _markReadIfNeeded() {
    final me = _service.memberId;
    final first = _lastMarkedId == null;
    final latestId = _messages.isEmpty ? '' : _messages.first.id;
    if (latestId == _lastMarkedId) return;
    _lastMarkedId = latestId;

    final fromOther = _messages.isNotEmpty && _messages.first.senderId != me;
    if (first || fromOther) _service.markRead(widget.conversationId);
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _oldestDoc == null) return;
    _loadingOlder = true;
    try {
      final snap = await _service
          .messagesQuery(widget.conversationId, _page)
          .startAfterDocument(_oldestDoc!)
          .get();
      for (final d in snap.docs) {
        _byId[d.id] = ChatMessage.fromDoc(d);
      }
      if (snap.docs.length < _page) _hasMore = false;
      _rebuildList();
    } catch (e) {
      _hasMore = false;
      _error = chatFriendlyError(e);
    } finally {
      _loadingOlder = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    try {
      await _service.sendMessage(widget.conversationId, text);
    } catch (e) {
      if (!mounted) return;
      if (_input.text.isEmpty) _input.text = text;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(chatFriendlyError(e))));
    }
  }

  /// Choix galerie (une ou plusieurs photos) / appareil photo, puis envoi.
  Future<void> _pickAndSendImage() async {
    if (_uploading) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galerie (une ou plusieurs photos)'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Appareil photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picker = ImagePicker();
      List<XFile> picked;
      if (source == ImageSource.gallery) {
        picked = await picker.pickMultiImage(
          imageQuality: 70,
          maxWidth: 1280,
          maxHeight: 1280,
        );
      } else {
        final one = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 70,
          maxWidth: 1280,
          maxHeight: 1280,
        );
        picked = one == null ? <XFile>[] : <XFile>[one];
      }
      if (picked.isEmpty) return;

      // Maximum 10 photos à la fois.
      if (picked.length > 10) {
        picked = picked.take(10).toList();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 10 photos à la fois.')),
          );
        }
      }

      if (mounted) {
        setState(() {
          _uploading = true;
          _uploadLabel = picked.length == 1
              ? 'Envoi de la photo...'
              : 'Envoi des photos (0/${picked.length})...';
          _uploadProgress = picked.length == 1 ? null : 0;
        });
      }

      await _service.sendImages(
        widget.conversationId,
        picked.map((x) => File(x.path)).toList(),
        onProgress: (done, total) {
          if (!mounted || total == 1) return;
          setState(() {
            _uploadLabel = 'Envoi des photos ($done/$total)...';
            _uploadProgress = done / total;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(chatFriendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Choisit les discussions de destination puis y transfère le message.
  Future<void> _forwardMessage(ChatMessage m) async {
    final targets = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => ChatForwardScreen(
          message: m,
          currentConversationId: widget.conversationId,
        ),
      ),
    );
    if (targets == null || targets.isEmpty || !mounted) return;

    try {
      await _service.forwardMessage(m, targets);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targets.length == 1
                ? 'Message transféré'
                : 'Message transféré à ${targets.length} discussions',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(chatFriendlyError(e))));
      }
    }
  }

  /// Appui long sur un message ou un appel : copier / transférer / retirer
  /// pour moi / retirer pour tout le monde.
  Future<void> _showMessageActions(ChatMessage m) async {
    if (m.isPending || m.isSystem) return;
    final isMine = m.senderId == _service.memberId;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (!m.isCall && !m.isImage && m.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copier'),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
            if (!m.isCall && (m.isImage || m.text.isNotEmpty))
              ListTile(
                leading: const Icon(Icons.shortcut_rounded),
                title: const Text('Transférer'),
                subtitle: const Text('Vers une autre discussion'),
                onTap: () => Navigator.pop(ctx, 'forward'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Supprimer pour moi'),
              subtitle: const Text('Les autres le voient toujours'),
              onTap: () => Navigator.pop(ctx, 'me'),
            ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded,
                    color: Colors.red),
                title: const Text('Supprimer pour tout le monde',
                    style: TextStyle(color: Colors.red)),
                subtitle: const Text('Plus personne ne le verra'),
                onTap: () => Navigator.pop(ctx, 'all'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    try {
      if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: m.text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message copié')),
          );
        }
      } else if (action == 'forward') {
        await _forwardMessage(m);
      } else if (action == 'me') {
        await _service.hideForMe(widget.conversationId, m.id);
      } else if (action == 'all') {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Supprimer pour tout le monde ?'),
            content: const Text(
              'Ce message sera retiré de la discussion pour tous les '
              'participants. Cette action est définitive.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (ok == true) {
          await _service.deleteForEveryone(widget.conversationId, m.id);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(chatFriendlyError(e))));
      }
    }
  }

  Widget _imageContent(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatImageViewer(url: url)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 220,
          fit: BoxFit.cover,
          loadingBuilder: (c, child, progress) => progress == null
              ? child
              : const SizedBox(
                  width: 220,
                  height: 160,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
          errorBuilder: (c, e, s) => const SizedBox(
            width: 220,
            height: 120,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Interface
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation:
          Listenable.merge([_service.conversations, _service.directoryTick]),
      builder: (context, _) {
        final convs = _service.conversations.value;
        Conversation? found;
        for (final c in convs) {
          if (c.id == widget.conversationId) {
            found = c;
            break;
          }
        }
        if (found == null) return _buildNotFound();
        return _buildRoom(context, found);
      },
    );
  }

  // ------------------------------------------------------------------
  // Appels (ZEGOCLOUD)
  // ------------------------------------------------------------------

  /// Rejoint un appel déjà en cours (bouton « Rejoindre »).
  void _openCall(Conversation conv, ChatMessage m) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatCallScreen(
          conversationId: conv.id,
          messageId: m.id,
          isGroup: conv.isGroup,
          video: m.isVideoCall,
        ),
      ),
    );
  }

  /// Lance un appel : annonce dans la discussion + notification, puis ouvre l'appel.
  Future<void> _startCall(Conversation conv, {required bool video}) async {
    if (!zegoConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Les appels ne sont pas encore configurés (AppID / AppSign "
            "ZEGOCLOUD dans chat_call_config.dart).",
          ),
        ),
      );
      return;
    }

    final kind = video ? 'vidéo' : 'vocal';
    final others = conv.participants.length - 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(conv.isGroup ? 'Lancer une réunion $kind ?' : 'Lancer un appel $kind ?'),
        content: Text(
          conv.isGroup
              ? 'Les $others autres participants du groupe seront prévenus et '
                  'pourront rejoindre.'
              : '${_service.titleOf(conv)} sera prévenu(e) et pourra rejoindre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Appeler'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final me = _service.memberId;
      final invitees = conv.participants
          .where((p) => p != me)
          .map((p) => (id: p, name: _service.memberById(p).fullName))
          .toList();
      final callMessageId = await _service.startCall(conv.id, video: video);
      // 1) Les téléphones enregistrés sonnent (écran « Appel » géré par
      //    ZEGOCLOUD, minuterie à la réponse, coupure après 60 s).
      final sent = await ChatCallService.instance.invite(
        conversationId: conv.id,
        messageId: callMessageId,
        video: video,
        group: conv.isGroup,
        invitees: invitees,
        title: _service.memberById(me ?? '').fullName,
      );
      if (sent || !mounted) return;

      // 2) Personne n'est enregistré pour la sonnerie : l'appel s'ouvre
      //    quand même, en attente (« Appel »), avec une notification
      //    classique pour inviter à rejoindre depuis la discussion.
      unawaited(_service.notifyCallFallback(conv.id, callMessageId));
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatWaitingCallScreen(
            conversationId: conv.id,
            messageId: callMessageId,
            isGroup: conv.isGroup,
            video: video,
            title: _service.titleOf(conv),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(chatFriendlyError(e))));
      }
    }
  }

  /// Carte d'appel affichée dans la discussion : en cours (Rejoindre),
  /// manqué / refusé (Rappeler) ou terminé.
  Widget _callCard(Conversation conv, ChatMessage m, bool dark) {
    final video = m.isVideoCall;
    final kind = video ? 'vidéo' : 'vocal';
    final mine = m.senderId == _service.memberId;
    final who = mine ? 'Vous avez' : '${_service.nameIn(conv, m.senderId)} a';
    final status = m.callStatus;

    // Un appel sans état reste « en cours » (garde-fou : 2 h maximum).
    final active =
        status == null && DateTime.now().difference(m.sortTime).inMinutes < 120;
    final missed = status == 'missed';
    final declined = status == 'declined';

    final String title;
    final String subtitle;
    if (active) {
      title = '$who lancé un appel $kind';
      subtitle = 'Appel en cours • ${formatHm(m.sortTime)}';
    } else if (missed) {
      title = mine ? 'Appel $kind sans réponse' : 'Appel $kind manqué';
      subtitle = formatHm(m.sortTime);
    } else if (declined) {
      title = 'Appel $kind refusé';
      subtitle = formatHm(m.sortTime);
    } else {
      title = '$who lancé un appel $kind';
      subtitle = 'Appel terminé • ${formatHm(m.sortTime)}';
    }

    final Color avatarColor =
        active ? kChatBlue : ((missed || declined) ? Colors.red : Colors.grey);

    return GestureDetector(
      onLongPress: () => _showMessageActions(m),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2B303B) : const Color(0xFFEAF2FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: avatarColor,
              child: Icon(
                missed
                    ? (video ? Icons.videocam_off_rounded : Icons.call_missed_rounded)
                    : (video ? Icons.videocam_rounded : Icons.call_rounded),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: (missed && !mine) ? Colors.red : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (active)
              ElevatedButton(
                onPressed: () => _openCall(conv, m),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kChatBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Rejoindre'),
              )
            else if (missed || declined)
              OutlinedButton(
                onPressed: () => _startCall(conv, video: video),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kChatBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Rappeler'),
              ),
          ],
        ),
      ),
      ),
    );
  }

  /// Infos de la discussion : groupe (membres, pseudos) ou privée (profil, pseudos).
  void _openInfo(BuildContext context, Conversation conv) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => conv.isGroup
            ? GroupInfoScreen(conversationId: conv.id)
            : PrivateInfoScreen(conversationId: conv.id),
      ),
    );
  }

  Widget _buildNotFound() {
    return Scaffold(
      appBar: AppBar(title: const Text('Discussion')),
      body: Center(
        child: _timedOut
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Cette discussion est introuvable ou vous n\'en faites plus partie.',
                  textAlign: TextAlign.center,
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildRoom(BuildContext context, Conversation conv) {
    final dark = chatIsDark(context);
    final title = _service.titleOf(conv);
    final other = _service.otherMember(conv);
    final subtitle = conv.isGroup
        ? '${conv.participants.length} participants'
        : (other?.roleLabel ?? '');

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        title: InkWell(
          onTap: () => _openInfo(context, conv),
          child: Row(
            children: [
              ChatAvatar(
                name: title,
                imageUrl: other?.profileImage,
                isGroup: conv.isGroup,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.normal),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Appel vocal',
            icon: const Icon(Icons.call_rounded),
            onPressed: () => _startCall(conv, video: false),
          ),
          IconButton(
            tooltip: conv.isGroup ? 'Réunion vidéo' : 'Appel vidéo',
            icon: const Icon(Icons.videocam_rounded),
            onPressed: () => _startCall(conv, video: true),
          ),
          IconButton(
            tooltip: conv.isGroup ? 'Infos du groupe' : 'Informations',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _openInfo(context, conv),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.red.withOpacity(0.12),
              padding: const EdgeInsets.all(8),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          Expanded(child: _buildMessages(context, conv, dark)),
          if (_uploading)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(minHeight: 3, value: _uploadProgress),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                  child: Text(
                    _uploadLabel,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          _buildInput(dark),
        ],
      ),
    );
  }

  Widget _buildMessages(BuildContext context, Conversation conv, bool dark) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'Aucun message. Écrivez le premier !',
          style: TextStyle(color: dark ? Colors.white60 : Colors.black54),
        ),
      );
    }

    final count = _messages.length + (_hasMore ? 1 : 0);
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: count,
      itemBuilder: (context, index) {
        // Dernier élément (tout en haut) : chargement des messages plus anciens.
        if (index == _messages.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadOlder());
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final m = _messages[index];
        final older = index + 1 < _messages.length ? _messages[index + 1] : null;
        final newer = index > 0 ? _messages[index - 1] : null;
        return _buildMessage(context, conv, m, older, newer, dark);
      },
    );
  }

  Widget _buildMessage(
    BuildContext context,
    Conversation conv,
    ChatMessage m,
    ChatMessage? older,
    ChatMessage? newer,
    bool dark,
  ) {
    final me = _service.memberId;
    final isMe = m.senderId == me;

    final showDate = older == null
        ? !_hasMore
        : !sameDay(older.sortTime, m.sortTime);

    final parts = <Widget>[];
    if (showDate) {
      parts.add(_pill(formatDayLabel(m.sortTime), dark, small: true));
    }

    if (m.isSystem) {
      parts.add(_pill(m.text, dark));
      return Column(children: parts);
    }

    if (m.isCall) {
      parts.add(_callCard(conv, m, dark));
      return Column(children: parts);
    }

    final firstOfRun = older == null ||
        older.isSystem ||
        older.senderId != m.senderId ||
        showDate;
    final lastOfRun = newer == null ||
        newer.isSystem ||
        newer.senderId != m.senderId ||
        !sameDay(newer.sortTime, m.sortTime);

    final sender = _service.memberById(m.senderId);
    final showName = !isMe && conv.isGroup && firstOfRun;

    // Coche « vu » (discussion privée) : ✓ envoyé, ✓✓ lu.
    var seen = false;
    if (isMe && !conv.isGroup && !m.isPending) {
      final otherId = conv.participants.firstWhere(
        (p) => p != me,
        orElse: () => '',
      );
      final at = conv.seen[otherId];
      seen = at != null && !at.isBefore(m.sortTime);
    }

    final bubbleColor = isMe
        ? kChatBlue
        : (dark ? const Color(0xFF2B303B) : const Color(0xFFE9EEF5));
    final textColor =
        isMe ? Colors.white : (dark ? Colors.white : Colors.black87);

    final bubbleBox = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(!isMe && lastOfRun ? 4 : 16),
            bottomRight: Radius.circular(isMe && lastOfRun ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showName)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  _service.nameIn(conv, m.senderId),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kChatGreen,
                  ),
                ),
              ),
            if (m.forwarded)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shortcut_rounded,
                        size: 13, color: textColor.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      'Transféré',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            if (m.isImage)
              _imageContent(context, m.imageUrl!)
            else
              Text(
                m.text,
                style: TextStyle(color: textColor, fontSize: 15),
              ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatHm(m.sortTime),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      m.isPending
                          ? Icons.access_time_rounded
                          : (seen ? Icons.done_all_rounded : Icons.done_rounded),
                      size: 14,
                      color: seen ? const Color(0xFF9BE7FF) : Colors.white70,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final bubble = GestureDetector(
      onLongPress: () => _showMessageActions(m),
      child: bubbleBox,
    );

    Widget row;
    if (isMe) {
      row = Align(alignment: Alignment.centerRight, child: bubble);
    } else if (conv.isGroup) {
      row = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 34,
            child: lastOfRun
                ? GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatProfileScreen(memberId: m.senderId),
                      ),
                    ),
                    child: ChatAvatar(
                      name: sender.fullName,
                      imageUrl: sender.profileImage,
                      radius: 14,
                    ),
                  )
                : null,
          ),
          Flexible(child: bubble),
        ],
      );
    } else {
      row = Align(alignment: Alignment.centerLeft, child: bubble);
    }

    parts.add(
      Padding(
        padding: EdgeInsets.fromLTRB(10, firstOfRun ? 6 : 1, 10, 1),
        child: row,
      ),
    );
    return Column(children: parts);
  }

  Widget _pill(String text, bool dark, {bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: dark ? Colors.white10 : Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: small ? 11 : 12,
              color: dark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(bool dark) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: dark ? Colors.white12 : Colors.black12,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Envoyer une photo',
              icon: const Icon(Icons.add_photo_alternate_rounded,
                  color: kChatBlue),
              onPressed: _uploading ? null : _pickAndSendImage,
            ),
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Écrire un message...',
                  counterText: '',
                  filled: true,
                  fillColor:
                      dark ? const Color(0xFF2B303B) : const Color(0xFFF1F4F9),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: kChatBlue,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _send,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
