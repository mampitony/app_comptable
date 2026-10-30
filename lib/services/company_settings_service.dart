// lib/services/company_settings_service.dart
//
// 🔥 NOUVEAU FICHIER
//
// Les informations de l'entreprise (nom, acronyme, slogan, logo) étaient
// stockées dans SharedPreferences : donc locales à chaque téléphone, et le
// logo n'était qu'un chemin de fichier local (invisible sur un autre
// appareil). Elles sont désormais stockées dans Firestore (document
// `app_settings/company`) et diffusées en temps réel à tous les appareils.
// Le logo est hébergé via ImageUploadService (ImgBB) : seule son URL
// publique est enregistrée.
//
// ⚠️ Règles Firestore à ajouter (l'écran d'accueil est affiché AVANT la
// connexion, donc la lecture doit être publique) :
//   match /app_settings/{doc} {
//     allow read: if true;
//     allow write: if request.auth != null; // ou restreint au rôle admin
//   }
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class CompanySettings {
  final String name;
  final String acronym;

  /// null = jamais défini : chaque écran applique alors son texte par défaut.
  final String? slogan;

  /// URL publique du logo (null = pas de logo).
  final String? logoUrl;

  const CompanySettings({
    this.name = 'CORE LEDGER',
    this.acronym = 'AJEM',
    this.slogan,
    this.logoUrl,
  });

  factory CompanySettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const CompanySettings();

    String? clean(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return CompanySettings(
      name: clean(data['name']) ?? 'CORE LEDGER',
      acronym: clean(data['acronym']) ?? 'AJEM',
      slogan: clean(data['slogan']),
      logoUrl: clean(data['logoUrl']),
    );
  }
}

class CompanySettingsService {
  CompanySettingsService._internal();
  static final CompanySettingsService instance =
      CompanySettingsService._internal();

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseService
      .instance
      .firestore
      .collection('app_settings')
      .doc('company');

  /// Flux temps réel : émet à chaque modification faite depuis n'importe
  /// quel appareil.
  Stream<CompanySettings> watch() =>
      _doc.snapshots().map((snap) => CompanySettings.fromMap(snap.data()));

  Future<void> saveInfo({
    required String name,
    required String acronym,
    required String slogan,
  }) {
    return _doc.set({
      'name': name,
      'acronym': acronym,
      'slogan': slogan,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setLogoUrl(String url) {
    return _doc.set({
      'logoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeLogo() {
    return _doc.set({
      'logoUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
