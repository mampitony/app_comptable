// lib/chat/new_chat_screen.dart
import 'package:flutter/material.dart';

import 'chat_room_screen.dart';
import 'chat_service.dart';
import 'chat_widgets.dart';
import 'member_select_screen.dart';

/// Annuaire des membres : toucher un nom ouvre la discussion privée,
/// « Nouveau groupe » ouvre la création d'un groupe.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _search = TextEditingController();
  bool _opening = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openPrivate(String memberId) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final id = await ChatService.instance.openPrivateConversation(memberId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatRoomScreen(conversationId: id)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _opening = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(chatFriendlyError(e))));
    }
  }

  Future<void> _newGroup() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const MemberSelectScreen()),
    );
    if (id != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatRoomScreen(conversationId: id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ChatService.instance;
    final query = _search.text.trim().toLowerCase();
    final members = service.chatMembers
        .where((m) =>
            query.isEmpty ||
            m.fullName.toLowerCase().contains(query) ||
            m.roleLabel.toLowerCase().contains(query))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle discussion'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un membre...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: kChatGreen,
                  child: Icon(Icons.group_add_rounded, color: Colors.white),
                ),
                title: const Text(
                  'Nouveau groupe',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: _newGroup,
              ),
              const Divider(height: 1),
              Expanded(
                child: members.isEmpty
                    ? const Center(child: Text('Aucun membre trouvé'))
                    : ListView.separated(
                        itemCount: members.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, i) {
                          final m = members[i];
                          return ListTile(
                            leading: ChatAvatar(
                              name: m.fullName,
                              imageUrl: m.profileImage,
                            ),
                            title: Text(m.fullName),
                            subtitle: m.roleLabel.isEmpty
                                ? null
                                : Text(m.roleLabel),
                            onTap: () => _openPrivate(m.id),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (_opening)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
