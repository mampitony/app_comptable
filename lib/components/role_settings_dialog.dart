// lib/components/role_settings_dialog.dart
//
// 🔥 NOUVEAU FICHIER
//
// Fenêtre de la page de configuration : l'admin voit tous les rôles, règle
// le nombre maximum de membres pour chacun (secrétaire, trésorier,
// commissaire aux comptes, ...), ajoute de nouveaux rôles et supprime ceux
// qu'il a ajoutés.
import 'dart:async';
import 'package:flutter/material.dart';

import '../database/firebase_user_repository.dart';
import '../services/role_settings_service.dart';

class RoleSettingsDialog extends StatefulWidget {
  const RoleSettingsDialog({Key? key}) : super(key: key);

  @override
  State<RoleSettingsDialog> createState() => _RoleSettingsDialogState();
}

class _RoleSettingsDialogState extends State<RoleSettingsDialog> {
  static const Color _blue = Color(0xFF0163D2);

  RoleSettings _settings = RoleSettings.defaults();
  bool _loaded = false;
  Map<String, int> _counts = {};
  StreamSubscription<RoleSettings>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = RoleSettingsService.instance.watch().listen(
      (s) {
        if (!mounted) return;
        setState(() {
          _settings = s;
          _loaded = true;
        });
      },
      onError: (e) {
        debugPrint('Erreur paramètres rôles: $e');
        if (mounted) setState(() => _loaded = true);
      },
    );
    _loadCounts();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Nombre de membres actuels par rôle (information seulement).
  Future<void> _loadCounts() async {
    try {
      final users = await FirebaseUserRepository().getAllUsers();
      final counts = <String, int>{};
      for (final u in users) {
        for (final r in FirebaseUserRepository.resolveRoles(u)) {
          counts[r] = (counts[r] ?? 0) + 1;
        }
      }
      if (mounted) setState(() => _counts = counts);
    } catch (e) {
      debugPrint('Erreur comptage rôles: $e');
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _editLimit(String role) async {
    final result = await showDialog<_RoleEditResult>(
      context: context,
      builder: (_) => _RoleEditDialog(
        settings: _settings,
        role: role,
        initialLimit: _settings.limitFor(role),
      ),
    );
    if (result == null) return;
    try {
      await RoleSettingsService.instance.setLimit(role, result.limit);
      _snack('Limite du rôle « $role » mise à jour');
    } catch (e) {
      _snack('Échec de la sauvegarde : $e', error: true);
    }
  }

  Future<void> _addRole() async {
    final result = await showDialog<_RoleEditResult>(
      context: context,
      builder: (_) => _RoleEditDialog(settings: _settings),
    );
    if (result == null || result.name == null) return;
    try {
      await RoleSettingsService.instance.addRole(
        result.name!,
        max: result.limit,
      );
      _snack('Rôle « ${result.name} » ajouté');
    } catch (e) {
      _snack('Échec de l\'ajout : $e', error: true);
    }
  }

  Future<void> _removeRole(String role) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce rôle ?'),
        content: Text(
          'Le rôle « $role » ne sera plus proposé pour les nouveaux '
          'membres. Les membres qui l\'ont déjà le gardent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await RoleSettingsService.instance.removeRole(role);
      _snack('Rôle « $role » supprimé');
    } catch (e) {
      _snack('Échec de la suppression : $e', error: true);
    }
  }

  Widget _roleTile(String role) {
    final limit = _settings.limitFor(role);
    final count = _counts[role] ?? 0;
    final isCustom = !_settings.isDefault(role);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        isCustom ? Icons.star_outline : Icons.badge_outlined,
        color: _blue,
        size: 22,
      ),
      title: Text(role, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        limit > 0
            ? 'Maximum : $limit membre(s) • actuellement $count'
            : 'Illimité • actuellement $count',
        style: TextStyle(
          fontSize: 12,
          color: (limit > 0 && count > limit) ? Colors.red : Colors.grey,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Modifier la limite',
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () => _editLimit(role),
          ),
          if (isCustom)
            IconButton(
              tooltip: 'Supprimer ce rôle',
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Colors.red),
              onPressed: () => _removeRole(role),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = _settings.allRoles;

    return AlertDialog(
      title: const Text('Rôles et effectifs'),
      content: SizedBox(
        width: 480,
        child: !_loaded
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Définissez le nombre maximum de membres par rôle '
                    '(0 = illimité). Les rôles ajoutés sont proposés '
                    'automatiquement aux nouveaux membres.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: roles.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _roleTile(roles[i]),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _loaded ? _addRole : null,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un rôle'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class _RoleEditResult {
  final String? name; // null quand on modifie seulement la limite
  final int limit;
  const _RoleEditResult(this.name, this.limit);
}

/// Saisie d'un nouveau rôle (nom + limite) ou modification d'une limite.
class _RoleEditDialog extends StatefulWidget {
  final RoleSettings settings;
  final String? role; // null = nouveau rôle
  final int initialLimit;

  const _RoleEditDialog({
    required this.settings,
    this.role,
    this.initialLimit = 0,
  });

  @override
  State<_RoleEditDialog> createState() => _RoleEditDialogState();
}

class _RoleEditDialogState extends State<_RoleEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _limitCtrl;
  String? _error;

  bool get _isNew => widget.role == null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _limitCtrl = TextEditingController(text: widget.initialLimit.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final limit = int.tryParse(_limitCtrl.text.trim());
    if (limit == null || limit < 0) {
      setState(() => _error = 'Entrez un nombre (0 = illimité).');
      return;
    }
    if (_isNew) {
      final err = RoleSettingsService.instance
          .validateNewRole(widget.settings, _nameCtrl.text);
      if (err != null) {
        setState(() => _error = err);
        return;
      }
      Navigator.pop(context, _RoleEditResult(_nameCtrl.text.trim(), limit));
    } else {
      Navigator.pop(context, _RoleEditResult(null, limit));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'Nouveau rôle' : widget.role!),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isNew) ...[
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nom du rôle',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _limitCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Nombre maximum de membres',
                helperText: '0 = illimité',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0163D2),
            foregroundColor: Colors.white,
          ),
          child: Text(_isNew ? 'Ajouter' : 'Enregistrer'),
        ),
      ],
    );
  }
}
