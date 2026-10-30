// lib/chat/chat_widgets.dart
import 'package:flutter/material.dart';

import '../services/image_upload_service.dart';
import 'chat_models.dart';
import 'chat_service.dart';

const Color kChatBlue = Color(0xFF0163D2);
const Color kChatGreen = Color(0xFF16A34A);

// ----------------------------------------------------------------------
// Dates
// ----------------------------------------------------------------------
String _two(int n) => n.toString().padLeft(2, '0');

String formatHm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int _daysAgo(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  return today.difference(day).inDays;
}

/// Heure affichée dans la liste des discussions.
String formatListTime(DateTime d) {
  final diff = _daysAgo(d);
  if (diff <= 0) return formatHm(d);
  if (diff == 1) return 'Hier';
  if (diff < 7) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[d.weekday - 1];
  }
  return '${_two(d.day)}/${_two(d.month)}/${d.year % 100}';
}

/// Séparateur de date dans une conversation.
String formatDayLabel(DateTime d) {
  final diff = _daysAgo(d);
  if (diff <= 0) return "Aujourd'hui";
  if (diff == 1) return 'Hier';
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

// ----------------------------------------------------------------------
// Avatar
// ----------------------------------------------------------------------
String chatInitials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

class ChatAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;
  final bool isGroup;

  const ChatAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
    this.isGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = ImageUploadService.resolveImageProvider(imageUrl);
    final color = isGroup ? kChatGreen : kChatBlue;

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(0.15),
      backgroundImage: provider,
      onBackgroundImageError: provider != null ? (e, s) {} : null,
      child: provider != null
          ? null
          : (isGroup
              ? Icon(Icons.groups_rounded, color: color, size: radius)
              : Text(
                  chatInitials(name),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.75,
                  ),
                )),
    );
  }
}

// ----------------------------------------------------------------------
// Divers
// ----------------------------------------------------------------------
bool chatIsDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Message d'erreur lisible à partir d'une exception Firebase.
String chatFriendlyError(Object e) {
  final s = e.toString();
  if (s.contains('CONFIGURATION_NOT_FOUND')) {
    return "Firebase Authentication n'est pas encore activé pour ce projet. "
        "Console Firebase > Authentication > « Commencer », puis "
        "Méthode de connexion > Anonyme > Activer.";
  }
  if (s.contains('admin-restricted-operation') ||
      s.contains('operation-not-allowed')) {
    return "La connexion anonyme n'est pas activée dans Firebase "
        "(Authentication > Méthode de connexion > Anonyme).";
  }
  if (s.contains('permission-denied')) {
    return "Accès refusé par les règles Firestore. Vérifiez que les règles "
        "de la messagerie ont bien été publiées.";
  }
  if (s.contains('network') || s.contains('unavailable')) {
    return 'Pas de connexion internet.';
  }
  return 'Une erreur est survenue : $s';
}

/// Affichage d'une photo en plein écran (zoom possible).
class ChatImageViewer extends StatelessWidget {
  final String url;

  const ChatImageViewer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (c, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (c, e, s) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}

/// « Octobre 2026 »
String formatMonthYear(DateTime d) {
  const months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  return '${months[d.month - 1]} ${d.year}';
}

/// Boîte de dialogue « Pseudo » (comme sur Messenger) : le pseudo n'est
/// valable que dans cette discussion et ne change pas le nom du profil.
Future<void> showNicknameDialog(
  BuildContext context,
  Conversation conv,
  String memberId,
) async {
  final service = ChatService.instance;
  final current = conv.nicknames[memberId] ?? '';

  final result = await showDialog<String>(
    context: context,
    builder: (_) => _NicknameDialog(
      realName: service.memberById(memberId).fullName,
      current: current,
    ),
  );

  if (result == null || result == current) return;
  try {
    await service.setNickname(conv.id, memberId, result);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(chatFriendlyError(e))));
    }
  }
}

/// Le dialogue possède son propre contrôleur de texte et le libère dans
/// dispose() : il n'est donc jamais détruit pendant l'animation de fermeture.
class _NicknameDialog extends StatefulWidget {
  final String realName;
  final String current;

  const _NicknameDialog({required this.realName, required this.current});

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
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
      title: Text('Pseudo de ${widget.realName.split(' ').first}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 30,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: widget.realName),
          ),
          const SizedBox(height: 4),
          const Text(
            'Visible par tous les participants de cette discussion. '
            'Le nom du profil ne change pas.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        if (widget.current.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Retirer', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
