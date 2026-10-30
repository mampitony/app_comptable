// lib/chat/member_select_screen.dart
import 'package:flutter/material.dart';

import 'chat_models.dart';
import 'chat_service.dart';
import 'chat_widgets.dart';

/// Deux usages :
///  - [existingGroup] == null : création d'un groupe (nom + membres).
///    Se ferme en renvoyant l'identifiant du nouveau groupe.
///  - [existingGroup] != null : ajout de membres à ce groupe.
///    Se ferme en renvoyant « ok » une fois les membres ajoutés.
class MemberSelectScreen extends StatefulWidget {
  final Conversation? existingGroup;

  const MemberSelectScreen({super.key, this.existingGroup});

  @override
  State<MemberSelectScreen> createState() => _MemberSelectScreenState();
}

class _MemberSelectScreenState extends State<MemberSelectScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _search = TextEditingController();
  final Set<String> _selected = <String>{};
  bool _saving = false;

  bool get _isCreate => widget.existingGroup == null;

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (_isCreate && _name.text.trim().isEmpty) {
      _toast('Donnez un nom au groupe');
      return;
    }
    if (_selected.isEmpty) {
      _toast('Choisissez au moins un membre');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isCreate) {
        final id = await ChatService.instance
            .createGroup(_name.text.trim(), _selected.toList());
        if (!mounted) return;
        Navigator.of(context).pop(id);
      } else {
        await ChatService.instance
            .addMembers(widget.existingGroup!.id, _selected.toList());
        if (!mounted) return;
        Navigator.of(context).pop('ok');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(chatFriendlyError(e));
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final service = ChatService.instance;
    final exclude = widget.existingGroup?.participants.toSet() ?? <String>{};
    final query = _search.text.trim().toLowerCase();

    final candidates = service.chatMembers
        .where((m) => !exclude.contains(m.id))
        .where((m) =>
            query.isEmpty ||
            m.fullName.toLowerCase().contains(query) ||
            m.roleLabel.toLowerCase().contains(query))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? 'Nouveau groupe' : 'Ajouter des membres'),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kChatBlue,
        foregroundColor: Colors.white,
        onPressed: _saving ? null : _submit,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check_rounded),
        label: Text(_isCreate ? 'Créer' : 'Ajouter'),
      ),
      body: Column(
        children: [
          if (_isCreate)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _name,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nom du groupe',
                  prefixIcon: const Icon(Icons.groups_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_selected.length} sélectionné(s)',
                  style: const TextStyle(
                      color: kChatBlue, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Expanded(
            child: candidates.isEmpty
                ? const Center(child: Text('Aucun membre disponible'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: candidates.length,
                    itemBuilder: (context, i) {
                      final m = candidates[i];
                      final checked = _selected.contains(m.id);
                      return CheckboxListTile(
                        value: checked,
                        activeColor: kChatBlue,
                        controlAffinity: ListTileControlAffinity.trailing,
                        secondary:
                            ChatAvatar(name: m.fullName, imageUrl: m.profileImage),
                        title: Text(m.fullName),
                        subtitle:
                            m.roleLabel.isEmpty ? null : Text(m.roleLabel),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(m.id);
                            } else {
                              _selected.remove(m.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
