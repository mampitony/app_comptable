// lib/chat/chat_icon_button.dart
//
// Petite icône de messagerie à placer dans l'AppBar de l'espace membre.
// Elle prépare automatiquement la messagerie, affiche la pastille de
// messages non lus et ouvre la liste des discussions au clic.
import 'package:flutter/material.dart';

import 'chat_list_screen.dart';
import 'chat_service.dart';

class ChatIconButton extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ChatIconButton({super.key, required this.userData});

  @override
  State<ChatIconButton> createState() => _ChatIconButtonState();
}

class _ChatIconButtonState extends State<ChatIconButton> {
  @override
  void initState() {
    super.initState();
    // Ne bloque rien : si la préparation échoue, l'erreur s'affiche
    // dans l'écran de discussion avec un bouton « Réessayer ».
    ChatService.instance.init(widget.userData);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ChatService.instance.unreadCount,
      builder: (context, count, _) {
        return IconButton(
          tooltip: 'Discussions',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatListScreen(userData: widget.userData),
              ),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded),
              if (count > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
