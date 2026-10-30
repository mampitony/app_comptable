// lib/chat/group_info_screen.dart
import 'package:flutter/material.dart';

import 'chat_models.dart';
import 'chat_profile_screen.dart';
import 'chat_service.dart';
import 'chat_widgets.dart';
import 'member_select_screen.dart';

class GroupInfoScreen extends StatelessWidget {
  final String conversationId;

  const GroupInfoScreen({super.key, required this.conversationId});

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _rename(BuildContext context, Conversation conv) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameGroupDialog(current: conv.name ?? ''),
    );

    if (newName == null || newName.isEmpty || newName == conv.name) return;
    try {
      await ChatService.instance.renameGroup(conv.id, newName);
    } catch (e) {
      if (context.mounted) _toast(context, chatFriendlyError(e));
    }
  }

  Future<void> _addMembers(BuildContext context, Conversation conv) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MemberSelectScreen(existingGroup: conv),
      ),
    );
  }

  Future<void> _remove(
      BuildContext context, Conversation conv, String memberId) async {
    final name = ChatService.instance.memberById(memberId).fullName;
    final ok = await _confirm(
      context,
      title: 'Retirer du groupe',
      message: 'Retirer $name de « ${ChatService.instance.titleOf(conv)} » ?',
      action: 'Retirer',
    );
    if (ok != true) return;
    try {
      await ChatService.instance.removeMember(conv.id, memberId);
    } catch (e) {
      if (context.mounted) _toast(context, chatFriendlyError(e));
    }
  }

  Future<void> _makeAdmin(
      BuildContext context, Conversation conv, String memberId) async {
    try {
      await ChatService.instance.makeAdmin(conv.id, memberId);
    } catch (e) {
      if (context.mounted) _toast(context, chatFriendlyError(e));
    }
  }

  Future<void> _leave(BuildContext context, Conversation conv) async {
    final ok = await _confirm(
      context,
      title: 'Quitter le groupe',
      message:
          'Vous ne recevrez plus les messages de « ${ChatService.instance.titleOf(conv)} ».',
      action: 'Quitter',
    );
    if (ok != true || !context.mounted) return;

    final nav = Navigator.of(context);
    try {
      await ChatService.instance.leaveGroup(conv);
      // Ferme les infos du groupe, puis la conversation : retour à la liste.
      nav.pop();
      nav.pop();
    } catch (e) {
      if (context.mounted) _toast(context, chatFriendlyError(e));
    }
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ChatService.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([service.conversations, service.directoryTick]),
      builder: (context, _) {
        final convs = service.conversations.value;
        Conversation? found;
        for (final c in convs) {
          if (c.id == conversationId) {
            found = c;
            break;
          }
        }
        if (found == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Infos du groupe')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final Conversation conv = found;
        final me = service.memberId;
        final isAdmin = conv.admins.contains(me);
        final title = service.titleOf(conv);

        // Administrateurs en premier, puis ordre alphabétique.
        final participants = List<String>.from(conv.participants)
          ..sort((a, b) {
            final aa = conv.admins.contains(a) ? 0 : 1;
            final bb = conv.admins.contains(b) ? 0 : 1;
            if (aa != bb) return aa.compareTo(bb);
            return service
                .memberById(a)
                .fullName
                .toLowerCase()
                .compareTo(service.memberById(b).fullName.toLowerCase());
          });

        return Scaffold(
          appBar: AppBar(
            title: const Text('Infos du groupe'),
            centerTitle: true,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 24),
              Center(
                child: ChatAvatar(name: title, isGroup: true, radius: 46),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isAdmin)
                    IconButton(
                      tooltip: 'Modifier le nom',
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      onPressed: () => _rename(context, conv),
                    ),
                ],
              ),
              Center(
                child: Text(
                  'Groupe • ${conv.participants.length} participants',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              if (isAdmin)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: kChatBlue,
                    child: Icon(Icons.person_add_alt_1_rounded,
                        color: Colors.white),
                  ),
                  title: const Text(
                    'Ajouter des membres',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => _addMembers(context, conv),
                ),
              const Divider(),
              for (final id in participants)
                _participantTile(context, conv, id, isAdmin, me),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app_rounded,
                    color: Colors.red),
                title: const Text(
                  'Quitter le groupe',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600),
                ),
                onTap: () => _leave(context, conv),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _participantTile(
    BuildContext context,
    Conversation conv,
    String id,
    bool iAmAdmin,
    String? me,
  ) {
    final member = ChatService.instance.memberById(id);
    final isMe = id == me;
    final memberIsAdmin = conv.admins.contains(id);

    final nick = conv.nicknames[id];
    final shown = nick ?? member.fullName;

    return ListTile(
      leading: ChatAvatar(name: member.fullName, imageUrl: member.profileImage),
      title: Text(isMe ? '$shown (vous)' : shown),
      subtitle: nick != null
          ? Text(member.fullName)
          : (member.roleLabel.isEmpty ? null : Text(member.roleLabel)),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatProfileScreen(memberId: id),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (memberIsAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kChatGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Admin',
                style: TextStyle(
                  color: kChatGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'profile') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatProfileScreen(memberId: id),
                  ),
                );
              }
              if (v == 'nick') showNicknameDialog(context, conv, id);
              if (v == 'admin') _makeAdmin(context, conv, id);
              if (v == 'remove') _remove(context, conv, id);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('Voir le profil'),
              ),
              const PopupMenuItem(
                value: 'nick',
                child: Text('Définir un pseudo'),
              ),
              if (iAmAdmin && !isMe && !memberIsAdmin)
                const PopupMenuItem(
                  value: 'admin',
                  child: Text('Nommer administrateur du groupe'),
                ),
              if (iAmAdmin && !isMe)
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Retirer du groupe',
                      style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dialogue de renommage : possède et libère lui-même son contrôleur.
class _RenameGroupDialog extends StatefulWidget {
  final String current;

  const _RenameGroupDialog({required this.current});

  @override
  State<_RenameGroupDialog> createState() => _RenameGroupDialogState();
}

class _RenameGroupDialogState extends State<_RenameGroupDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nom du groupe'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
