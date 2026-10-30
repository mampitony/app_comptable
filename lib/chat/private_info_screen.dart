// lib/chat/private_info_screen.dart
//
// « Informations sur la discussion » d'une conversation privée
// (comme sur Messenger) : voir le profil, définir les pseudos.
import 'package:flutter/material.dart';

import 'chat_models.dart';
import 'chat_profile_screen.dart';
import 'chat_service.dart';
import 'chat_widgets.dart';

class PrivateInfoScreen extends StatelessWidget {
  final String conversationId;

  const PrivateInfoScreen({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context) {
    final service = ChatService.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([service.conversations, service.directoryTick]),
      builder: (context, _) {
        Conversation? found;
        for (final c in service.conversations.value) {
          if (c.id == conversationId) {
            found = c;
            break;
          }
        }
        if (found == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Informations')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final Conversation conv = found;

        final me = service.memberId ?? '';
        final otherId = conv.participants.firstWhere(
          (p) => p != me,
          orElse: () => '',
        );
        final other = service.memberById(otherId);
        final shownName = service.nameIn(conv, otherId);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Informations'),
            centerTitle: true,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => _openProfile(context, otherId),
                  child: ChatAvatar(
                    name: other.fullName,
                    imageUrl: other.profileImage,
                    radius: 56,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  shownName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              if (shownName != other.fullName)
                Center(
                  child: Text(
                    other.fullName,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              if (other.roleLabel.isNotEmpty)
                Center(
                  child: Text(
                    other.roleLabel,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 20),
              _sectionTitle(context, 'Informations sur la discussion'),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: kChatBlue,
                  child: Icon(Icons.person_rounded, color: Colors.white),
                ),
                title: const Text('Voir le profil'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openProfile(context, otherId),
              ),
              const SizedBox(height: 8),
              _sectionTitle(context, 'Pseudos'),
              _nicknameTile(context, conv, otherId),
              if (me.isNotEmpty) _nicknameTile(context, conv, me),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  'Un pseudo n\'est visible que dans cette discussion. '
                  'Il ne change pas le nom du profil.',
                  style: TextStyle(
                    fontSize: 12,
                    color: chatIsDark(context) ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openProfile(BuildContext context, String memberId) {
    if (memberId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatProfileScreen(memberId: memberId),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: chatIsDark(context) ? Colors.white60 : Colors.black54,
        ),
      ),
    );
  }

  Widget _nicknameTile(BuildContext context, Conversation conv, String id) {
    final service = ChatService.instance;
    final member = service.memberById(id);
    final nick = conv.nicknames[id];
    final isMe = id == service.memberId;

    return ListTile(
      leading: ChatAvatar(
        name: member.fullName,
        imageUrl: member.profileImage,
        radius: 20,
      ),
      title: Text(nick != null ? nick : member.fullName),
      subtitle: Text(
        nick != null
            ? (isMe ? '${member.fullName} (vous)' : member.fullName)
            : (isMe ? 'Vous • définir un pseudo' : 'Définir un pseudo'),
      ),
      trailing: const Icon(Icons.edit_rounded, size: 20),
      onTap: () => showNicknameDialog(context, conv, id),
    );
  }
}
