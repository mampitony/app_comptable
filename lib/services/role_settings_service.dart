// lib/services/role_settings_service.dart
//
// 🔥 NOUVEAU FICHIER
//
// Paramètres des rôles, stockés dans Firestore (document `app_settings/roles`)
// et partagés en temps réel entre tous les appareils :
//
//   customRoles : [String]          rôles ajoutés en plus de ceux par défaut
//   limits      : { rôle : nombre } nombre maximum de membres par rôle
//                                   (0 = illimité). Si un rôle n'a pas de
//                                   valeur ici, la valeur par défaut
//                                   ci-dessous s'applique : le comportement
//                                   d'origine est donc conservé tant que
//                                   l'admin ne modifie rien.
//
// ⚠️ Règles Firestore : le document est dans `app_settings`, déjà couvert par
// la règle de CompanySettingsService (lecture publique, écriture connectée).
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class RoleSettings {
  /// Rôles ajoutés par l'admin (ou saisis via « Autre »), hors rôles par défaut.
  final List<String> customRoles;

  /// Limites enregistrées explicitement (0 = illimité).
  final Map<String, int> limits;

  const RoleSettings({
    this.customRoles = const [],
    this.limits = const {},
  });

  factory RoleSettings.defaults() => const RoleSettings();

  /// Rôles par défaut (identiques à la liste historique du formulaire
  /// membre, sans l'option « Autre »).
  static const List<String> defaultRoles = [
    'President',
    'Vice President',
    'Tresorier',
    'Commissaire au compte',
    'Conseiller',
    'Responsable de Communication',
    'Sécretaire',
    'Membre actif',
    'Membre',
  ];

  /// Limites d'origine : appliquées tant que l'admin ne les a pas changées.
  static const Map<String, int> defaultLimits = {
    'President': 1,
    'Vice President': 1,
    'Tresorier': 1,
    'Commissaire au compte': 2,
  };

  static String _norm(String s) => s.trim().toLowerCase();

  factory RoleSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return RoleSettings.defaults();

    final custom = <String>[];
    final rawRoles = data['customRoles'];
    if (rawRoles is List) {
      for (final r in rawRoles) {
        final s = r?.toString().trim() ?? '';
        if (s.isNotEmpty && !custom.any((c) => _norm(c) == _norm(s))) {
          custom.add(s);
        }
      }
    }

    final limits = <String, int>{};
    final rawLimits = data['limits'];
    if (rawLimits is Map) {
      rawLimits.forEach((k, v) {
        if (v is num) limits[k.toString()] = v.toInt().clamp(0, 9999);
      });
    }

    return RoleSettings(customRoles: custom, limits: limits);
  }

  List<String> get allRoles => [...defaultRoles, ...customRoles];

  bool isDefault(String role) => defaultRoles.contains(role);

  bool exists(String role) =>
      allRoles.any((r) => _norm(r) == _norm(role));

  /// Nom officiel d'un rôle existant (insensible à la casse), sinon null.
  String? canonical(String role) {
    for (final r in allRoles) {
      if (_norm(r) == _norm(role)) return r;
    }
    return null;
  }

  /// Limite effective d'un rôle (0 = illimité).
  int limitFor(String role) => limits[role] ?? defaultLimits[role] ?? 0;

  /// Uniquement les rôles réellement limités (> 0).
  Map<String, int> get effectiveLimits {
    final result = <String, int>{};
    for (final r in allRoles) {
      final l = limitFor(r);
      if (l > 0) result[r] = l;
    }
    return result;
  }
}

class RoleSettingsService {
  RoleSettingsService._internal();
  static final RoleSettingsService instance = RoleSettingsService._internal();

  /// Rôles réservés au système : jamais proposés comme rôle personnalisé.
  static const Set<String> _reserved = {
    'autre',
    'admin_principal_membre',
    'admin_gestion_membre',
  };

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseService
      .instance
      .firestore
      .collection('app_settings')
      .doc('roles');

  Stream<RoleSettings> watch() =>
      _doc.snapshots().map((snap) => RoleSettings.fromMap(snap.data()));

  /// Lecture unique. En cas d'erreur (hors-ligne, règles...), renvoie les
  /// valeurs par défaut : l'application se comporte alors comme avant.
  Future<RoleSettings> fetch() async {
    try {
      final snap = await _doc.get();
      return RoleSettings.fromMap(snap.data());
    } catch (_) {
      return RoleSettings.defaults();
    }
  }

  /// Message d'erreur si le nom n'est pas valide, sinon null.
  String? validateNewRole(RoleSettings current, String name) {
    final s = name.trim();
    if (s.isEmpty) return 'Le nom du rôle ne peut pas être vide.';
    if (s.length > 40) return 'Le nom du rôle est trop long (40 max).';
    if (_reserved.contains(s.toLowerCase())) {
      return 'Ce nom est réservé par le système.';
    }
    if (current.exists(s)) return 'Ce rôle existe déjà.';
    return null;
  }

  /// Définit le nombre maximum de membres pour un rôle (0 = illimité).
  Future<void> setLimit(String role, int max) {
    return _doc.set({
      'limits': {role: max.clamp(0, 9999)},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Ajoute un rôle personnalisé (avec une limite optionnelle).
  Future<void> addRole(String name, {int? max}) {
    final s = name.trim();
    return _doc.set({
      'customRoles': FieldValue.arrayUnion([s]),
      if (max != null) 'limits': {s: max.clamp(0, 9999)},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Retire un rôle personnalisé de la liste proposée. Les membres qui
  /// l'ont déjà gardent leur rôle (rien n'est modifié sur leur fiche).
  Future<void> removeRole(String name) {
    return _doc.set({
      'customRoles': FieldValue.arrayRemove([name]),
      'limits': {name: FieldValue.delete()},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Enregistre automatiquement un rôle saisi librement (« Autre ») pour
  /// qu'il soit proposé aux prochains membres. Sans effet s'il existe déjà.
  Future<void> registerRole(String name) async {
    final s = name.trim();
    if (s.isEmpty || _reserved.contains(s.toLowerCase())) return;
    final current = await fetch();
    if (current.exists(s)) return;
    await addRole(s);
  }
}
