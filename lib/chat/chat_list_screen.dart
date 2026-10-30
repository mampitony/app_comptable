// lib/chat/chat_list_screen.dart
import 'package:flutter/material.dart';

import 'chat_models.dart';
import 'chat_profile_screen.dart';
import 'chat_room_screen.dart';
import 'chat_service.dart';
import 'chat_widgets.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const ChatListScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final service = ChatService.instance;
    final dark = chatIsDark(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussions'),
        centerTitle: true,
        elevation: 0,
        actions: [
          // Mon profil : touche l'avatar pour modifier nom et photo.
          AnimatedBuilder(
            animation: Listenable.merge([service.directoryTick, service.ready]),
            builder: (context, _) {
              final me = service.memberId;
              if (me == null || !service.ready.value) {
                return const SizedBox.shrink();
              }
              final m = service.memberById(me);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatProfileScreen(
                        memberId: me,
                        allowMessage: false,
                      ),
                    ),
                  ),
                  child: ChatAvatar(
                    name: m.fullName,
                    imageUrl: m.profileImage,
                    radius: 16,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kChatBlue,
        foregroundColor: Colors.white,
        tooltip: 'Nouvelle discussion',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NewChatScreen()),
          );
        },
        child: const Icon(Icons.edit_rounded),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          service.ready,
          service.error,
          service.conversations,
          service.unreadIds,
          service.directoryTick,
        ]),
        builder: (context, _) {
          final error = service.error.value;
          if (error != null && !service.ready.value) {
            return _ErrorView(
              message: chatFriendlyError(error),
              onRetry: () => service.init(userData),
            );
          }
          if (!service.ready.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = service.conversations.value;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forum_outlined,
                        size: 64,
                        color: dark ? Colors.white38 : Colors.black26),
                    const SizedBox(height: 12),
                    const Text(
                      'Aucune discussion',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Touchez le bouton en bas pour écrire à un membre '
                      'ou créer un groupe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: dark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, i) {
              final c = list[i];
              return _ConversationTile(
                conversation: c,
                unread: service.unreadIds.value.contains(c.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool unread;

  const _ConversationTile({required this.conversation, required this.unread});

  @override
  Widget build(BuildContext context) {
    final service = ChatService.instance;
    final c = conversation;
    final dark = chatIsDark(context);
    final title = service.titleOf(c);
    final other = service.otherMember(c);
    final me = service.memberId;

    String preview;
    if (c.lastMessage.isEmpty) {
      preview = c.isGroup ? 'Groupe créé' : 'Dites bonjour 👋';
    } else if (c.lastSenderId == me) {
      preview = 'Vous : ${c.lastMessage}';
    } else if (c.isGroup && c.lastSenderId != null) {
      final first = service.nameIn(c, c.lastSenderId!).split(' ').first;
      preview = '$first : ${c.lastMessage}';
    } else {
      preview = c.lastMessage;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ChatAvatar(
        name: title,
        imageUrl: other?.profileImage,
        isGroup: c.isGroup,
        radius: 26,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w700 : FontWeight.normal,
          color: unread
              ? (dark ? Colors.white : Colors.black87)
              : (dark ? Colors.white60 : Colors.black54),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (c.lastMessageAt != null)
            Text(
              formatListTime(c.lastMessageAt!),
              style: TextStyle(
                fontSize: 12,
                color: unread ? kChatBlue : Colors.grey,
                fontWeight: unread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          const SizedBox(height: 6),
          if (unread)
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: kChatBlue,
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(conversationId: c.id),
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
