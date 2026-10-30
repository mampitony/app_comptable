// lib/services/image_upload_service.dart
//
// 🔥 NOUVEAU FICHIER
//
// Remplace le stockage du chemin local de la photo de profil
// (ex. /data/user/0/com.app_comptable/cache/photo.jpg — invisible une
// fois l'APK installé sur un autre appareil, ou après nettoyage du
// cache) par un hébergement externe via l'API ImgBB. Seule l'URL
// publique retournée par ImgBB est conservée, dans le même champ
// Firestore `profileImage` qu'avant.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ImageUploadService {
  // 🔑 Clé API ImgBB — à créer gratuitement sur https://api.imgbb.com/
  // puis à coller ici. Sans cette clé, l'upload échouera.
  static const String _apiKey = '1c491461cfe54111ef926d0be774a47b';

  static const String _endpoint = 'https://api.imgbb.com/1/upload';

  /// Envoie [file] vers ImgBB et retourne l'URL publique de l'image
  /// hébergée (ex. https://i.ibb.co/xxxxx/photo.jpg).
  ///
  /// L'image est déjà compressée en amont par ImagePicker (voir
  /// `pickImage()` dans member_form.dart : imageQuality/maxWidth/
  /// maxHeight), ce qui suffit très largement à rester sous la limite
  /// de 32 Mo de l'API ImgBB.
  static Future<String> uploadImage(File file) async {
    if (_apiKey.isEmpty || _apiKey == 'VOTRE_CLE_API_IMGBB') {
      throw Exception(
        "Clé API ImgBB manquante : renseignez-la dans image_upload_service.dart.",
      );
    }

    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse(_endpoint),
      body: {
        'key': _apiKey,
        'image': base64Image,
      },
    );

    debugPrint('[ImgBB] Code réponse HTTP : ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('[ImgBB] Corps de la réponse : ${response.body}');
      throw Exception(
        "Échec de l'envoi de la photo vers ImgBB (code ${response.statusCode}).",
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    final url = data['data']?['url'] as String?;
    if (data['success'] != true || url == null || url.isEmpty) {
      throw Exception(
        "Réponse ImgBB invalide : impossible de récupérer l'URL de l'image.",
      );
    }

    return url;
  }

  /// true si [path] est déjà une URL hébergée (nouveau système),
  /// false si c'est un chemin local (nouvelle sélection non encore
  /// envoyée, ou ancienne donnée pré-migration).
  static bool isNetworkUrl(String? path) =>
      path != null &&
      (path.startsWith('http://') || path.startsWith('https://'));

  /// ImageProvider adapté quel que soit le format de `profileImage` :
  /// URL ImgBB (nouveau système) ou chemin local (ancien système /
  /// sélection en cours), pour ne rien casser sur les comptes déjà
  /// enregistrés avant cette migration.
  static ImageProvider? resolveImageProvider(String? path) {
    if (path == null || path.isEmpty) return null;
    if (isNetworkUrl(path)) return NetworkImage(path);
    final file = File(path);
    if (file.existsSync()) return FileImage(file);
    return null;
  }
}
