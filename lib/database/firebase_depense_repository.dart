import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class FirebaseDepenseRepository {
  final _firebase = FirebaseService.instance;

  // Total des dépenses — INCHANGÉ
  Future<double> getTotalDepenses() async {
    final querySnapshot = await _firebase.depenses.get();
    double total = 0;
    for (var doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['montant'] ?? 0).toDouble();
    }
    return total;
  }

  // Toutes les dépenses — INCHANGÉ
  Future<List<Map<String, dynamic>>> getAllDepenses() async {
    final querySnapshot = await _firebase.depenses
        .orderBy('date', descending: true)
        .get();
    return querySnapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    }).toList();
  }

  // Ajouter une dépense — ÉTENDU avec description
  Future<String> addDepense({
    required String type,
    required String date,
    required double montant,
    String? lieu,
    int? nombreParticipants,
    String? nomProduit,
    String? membreAcheteurId,
    String? membreAcheteur,
    String? typeCommunication,
    String? nomActivite,
    String? dateDebut,
    String? dateFin,
    String? lieuActivite,
    String? sousType,
    String? description, // ---- NOUVEAU ----
  }) async {
    final docRef = await _firebase.depenses.add({
      'type': type,
      'date': date,
      'montant': montant,
      'lieu': lieu,
      'nombreParticipants': nombreParticipants,
      'nomProduit': nomProduit,
      'membreAcheteurId': membreAcheteurId,
      'membreAcheteur': membreAcheteur,
      'typeCommunication': typeCommunication,
      'nomActivite': nomActivite,
      'dateDebut': dateDebut,
      'dateFin': dateFin,
      'lieuActivite': lieuActivite,
      'sousType': sousType,
      'description': description, // ---- NOUVEAU ----
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Mettre à jour une dépense — ÉTENDU avec description
  Future<void> updateDepense({
    required String id,
    required String type,
    required String date,
    required double montant,
    String? lieu,
    int? nombreParticipants,
    String? nomProduit,
    String? membreAcheteurId,
    String? membreAcheteur,
    String? typeCommunication,
    String? nomActivite,
    String? dateDebut,
    String? dateFin,
    String? lieuActivite,
    String? sousType,
    String? description, // ---- NOUVEAU ----
  }) async {
    await _firebase.depenses.doc(id).update({
      'type': type,
      'date': date,
      'montant': montant,
      'lieu': lieu,
      'nombreParticipants': nombreParticipants,
      'nomProduit': nomProduit,
      'membreAcheteurId': membreAcheteurId,
      'membreAcheteur': membreAcheteur,
      'typeCommunication': typeCommunication,
      'nomActivite': nomActivite,
      'dateDebut': dateDebut,
      'dateFin': dateFin,
      'lieuActivite': lieuActivite,
      'sousType': sousType,
      'description': description, // ---- NOUVEAU ----
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Supprimer une dépense — INCHANGÉ
  Future<void> deleteDepense(String id) async {
    await _firebase.depenses.doc(id).delete();
  }
}