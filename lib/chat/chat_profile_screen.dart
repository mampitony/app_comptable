// lib/chat/chat_profile_screen.dart
//
// Profil d'un membre.
//  - Son propre profil : on peut modifier prénom, nom et photo. Ce sont les
//    champs de la fiche membre, ils changent donc aussi dans la liste des
//    membres de l'application.
//  - Le profil d'un autre membre : consultation seulement.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_models.dart';
import 'chat_room_screen.dart';
import 'chat_service.dart';
import 'chat_widgets.dart';

class ChatProfileScreen extends StatefulWidget {
  final String memberId;

  /// Affiche le bouton « Envoyer un message » (profil d'un autre membre).
  final bool allowMessage;

  const ChatProfileScreen({
    super.key,
    required this.memberId,
    this.allowMessage = true,
  });

  @override
  State<ChatProfileScreen> createState() => _ChatProfileScreenState();
}

class _ChatProfileScreenState extends State<ChatProfileScreen> {
  final ChatService _service = ChatService.instance;
  late final TextEditingController _first;
  late final TextEditingController _last;
  File? _newPhoto;
  bool _saving = false;
  bool _opening = false;

  bool get _isMe => widget.memberId == _service.memberId;

  @override
  void initState() {
    super.initState();
    final m = _service.memberById(widget.memberId);
    _first = TextEditingController(text: m.firstName);
    _last = TextEditingController(text: m.lastName);
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  bool get _changed {
    final m = _service.memberById(widget.memberId);
    return _newPhoto != null ||
        _first.text.trim() != m.firstName ||
        _last.text.trim() != m.lastName;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galerie'),
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
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked != null && mounted) {
        setState(() => _newPhoto = File(picked.path));
      }
    } catch (e) {
      if (mounted) _toast(chatFriendlyError(e));
    }
  }

  Future<void> _save() async {
    if (_saving || !_changed) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await _service.updateMyProfile(
        firstName: _first.text,
        lastName: _last.text,
        newPhoto: _newPhoto,
      );
      if (!mounted) return;
      setState(() {
        _newPhoto = null;
        _saving = false;
      });
      _toast('Profil mis à jour');
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message?.toString() ?? 'Données invalides');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(chatFriendlyError(e));
    }
  }

  Future<void> _sendMessage() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final id = await _service.openPrivateConversation(widget.memberId);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatRoomScreen(conversationId: id)),
      );
    } catch (e) {
      if (mounted) _toast(chatFriendlyError(e));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service.directoryTick,
      builder: (context, _) {
        final m = _service.memberById(widget.memberId);
        final dark = chatIsDark(context);

        Widget avatar;
        if (_newPhoto != null) {
          avatar = CircleAvatar(
            radius: 64,
            backgroundImage: FileImage(_newPhoto!),
          );
        } else {
          avatar = GestureDetector(
            onTap: (m.profileImage != null && m.profileImage!.isNotEmpty && !_isMe)
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatImageViewer(url: m.profileImage!),
                      ),
                    )
                : null,
            child: ChatAvatar(
              name: m.fullName,
              imageUrl: m.profileImage,
              radius: 64,
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_isMe ? 'Mon profil' : 'Profil'),
            centerTitle: true,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Center(
                child: Stack(
                  children: [
                    avatar,
                    if (_isMe)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: kChatBlue,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _pickPhoto,
                            child: const Padding(
                              padding: EdgeInsets.all(9),
                              child: Icon(Icons.photo_camera_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isMe) ..._editForm(dark) else ..._infoView(m, dark),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Mon profil : modification
  // ------------------------------------------------------------------
  List<Widget> _editForm(bool dark) {
    final m = _service.memberById(widget.memberId);
    return [
      TextField(
        controller: _first,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Prénom',
          prefixIcon: const Icon(Icons.person_outline_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _last,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Nom',
          prefixIcon: const Icon(Icons.badge_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Ces informations sont celles de votre fiche membre : elles changent '
        'aussi dans la liste des membres. Pour changer le nom affiché '
        'seulement dans une discussion, utilisez « Pseudos ».',
        style: TextStyle(
          fontSize: 12,
          color: dark ? Colors.white54 : Colors.black54,
        ),
      ),
      const SizedBox(height: 18),
      SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: (_changed && !_saving) ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: kChatBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Enregistrer'),
        ),
      ),
      if (m.roleLabel.isNotEmpty) ...[
        const SizedBox(height: 22),
        _infoTile(Icons.workspace_premium_outlined, 'Fonction', m.roleLabel),
      ],
      if (m.joinedAt != null)
        _infoTile(Icons.event_outlined, 'Membre depuis',
            formatMonthYear(m.joinedAt!)),
    ];
  }

  // ------------------------------------------------------------------
  // Profil d'un autre membre : consultation
  // ------------------------------------------------------------------
  List<Widget> _infoView(ChatMember m, bool dark) {
    return [
      Text(
        m.fullName,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 20),
      if (m.roleLabel.isNotEmpty)
        _infoTile(Icons.workspace_premium_outlined, 'Fonction', m.roleLabel),
      if (m.joinedAt != null)
        _infoTile(Icons.event_outlined, 'Membre depuis',
            formatMonthYear(m.joinedAt!)),
      if (widget.allowMessage) ...[
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _opening ? null : _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: kChatBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Envoyer un message'),
          ),
        ),
      ],
    ];
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: kChatBlue.withOpacity(0.12),
        child: Icon(icon, color: kChatBlue, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}
