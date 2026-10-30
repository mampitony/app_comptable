// lib/chat/chat_forward_screen.dart
//
// Choix des discussions vers lesquelles transférer un message (texte ou photo).
// Retourne la liste des identifiants de discussions choisies (ou null).
import 'package:flutter/material.dart';

import 'chat_models.dart';
import 'chat_service.dart';
import 'chat_widgets.dart';

class ChatForwardScreen extends StatefulWidget {
  /// Message à transférer.
  final ChatMessage message;

  /// Discussion d'où vient le message (affichée en premier, sans être exclue).
  final String currentConversationId;

  const ChatForwardScreen({
    super.key,
    required this.message,
    required this.currentConversationId,
  });

  @override
  State<ChatForwardScreen> createState() => _ChatForwardScreenState();
}

class _ChatForwardScreenState extends State<ChatForwardScreen> {
  /// Nombre maximum de discussions pour un même transfert (évite les envois
  /// en masse par erreur).
  static const int _maxTargets = 5;

  final ChatService _service = ChatService.instance;
  final TextEditingController _search = TextEditingController();
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length >= _maxTargets) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous pouvez choisir 5 discussions au maximum.'),
          ),
        );
      } else {
        _selected.add(id);
      }
    });
  }

  String get _preview {
    final m = widget.message;
    if (m.isImage) return '📷 Photo';
    final oneLine = m.text.replaceAll('\n', ' ').trim();
    return oneLine.length > 80 ? '${oneLine.substring(0, 80)}…' : oneLine;
  }

  @override
  Widget build(BuildContext context) {
    final dark = chatIsDark(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transférer à…'),
      ),
      body: Column(
        children: [
          // Rappel du message transféré
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF2B303B) : const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.shortcut_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Rechercher une discussion',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<Conversation>>(
              valueListenable: _service.conversations,
              builder: (context, all, _) {
                final q = _search.text.trim().toLowerCase();
                final list = all.where((c) {
                  if (q.isEmpty) return true;
                  return _service.titleOf(c).toLowerCase().contains(q);
                }).toList();

                if (list.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucune discussion trouvée.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final c = list[i];
                    final title = _service.titleOf(c);
                    final other = _service.otherMember(c);
                    final checked = _selected.contains(c.id);
                    final isCurrent = c.id == widget.currentConversationId;

                    return ListTile(
                      onTap: () => _toggle(c.id),
                      leading: ChatAvatar(
                        name: title,
                        imageUrl: other?.profileImage,
                        isGroup: c.isGroup,
                        radius: 22,
                      ),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isCurrent
                            ? 'Discussion actuelle'
                            : (c.isGroup ? 'Groupe' : 'Discussion privée'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Checkbox(
                        value: checked,
                        onChanged: (_) => _toggle(c.id),
                        shape: const CircleBorder(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_selected.toList()),
              icon: const Icon(Icons.send_rounded),
              label: Text(
                _selected.isEmpty
                    ? 'Choisissez une discussion'
                    : 'Envoyer (${_selected.length})',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kChatBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
