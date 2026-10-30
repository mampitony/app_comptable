import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'firebase_historique_repository.dart';

class FirebaseRevenuRepository {
  final _firebase = FirebaseService.instance;
  final _historiqueRepo = FirebaseHistoriqueRepository();

  // Total des revenus — INCHANGÉ
  Future<double> getTotalRevenus() async {
    final querySnapshot = await _firebase.revenus.get();
    double total = 0;
    for (var doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['montant'] ?? 0).toDouble();
    }
    return total;
  }

  // Tous les revenus — INCHANGÉ
  Future<List<Map<String, dynamic>>> getAllRevenus() async {
    final querySnapshot = await _firebase.revenus
        .orderBy('date', descending: true)
        .get();
    return querySnapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    }).toList();
  }

  // Ajouter un revenu — ÉTENDU avec les nouveaux champs
  Future<String> addRevenu({
    required String type,
    String? nom,
    String? prenom,
    required String date,
    required double montant,
    String? motif,
    String? membreId,
    String? nomActivite,
    // NOUVEAU
    String? dateDebut,
    String? dateFin,
    String? lieu,
    String? nomEvenement,
    // 🔥 AJOUT : description (un élément par ligne : « nom : prix »)
    String? description,
  }) async {
    final docRef = await _firebase.revenus.add({
      'type': type,
      'nom': nom,
      'prenom': prenom,
      'date': date,
      'montant': montant,
      'motif': motif,
      'membreId': membreId,
      'nomActivite': nomActivite,
      // NOUVEAU
      'dateDebut': dateDebut,
      'dateFin': dateFin,
      'lieu': lieu,
      'nomEvenement': nomEvenement,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _historiqueRepo.addHistorique(
      typeOperation: 'revenu',
      operation: 'ajout',
      details:
          'Ajout d\'un revenu: $type - ${motif ?? "Aucune description"} (Date: $date)',
      montant: montant,
      typeElement: 'revenu',
      elementId: docRef.id,
    );

    return docRef.id;
  }

  // Mettre à jour un revenu — ÉTENDU avec les nouveaux champs
  Future<void> updateRevenu({
    required String id,
    required String type,
    String? nom,
    String? prenom,
    required String date,
    required double montant,
    String? motif,
    String? membreId,
    String? nomActivite,
    // NOUVEAU
    String? dateDebut,
    String? dateFin,
    String? lieu,
    String? nomEvenement,
    // 🔥 AJOUT : description (un élément par ligne : « nom : prix »)
    String? description,
  }) async {
    await _firebase.revenus.doc(id).update({
      'type': type,
      'nom': nom,
      'prenom': prenom,
      'date': date,
      'montant': montant,
      'motif': motif,
      'membreId': membreId,
      'nomActivite': nomActivite,
      // NOUVEAU
      'dateDebut': dateDebut,
      'dateFin': dateFin,
      'lieu': lieu,
      'nomEvenement': nomEvenement,
      'description': description,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _historiqueRepo.addHistorique(
      typeOperation: 'revenu',
      operation: 'modification',
      details:
          'Modification d\'un revenu: $type - ${motif ?? "Aucune description"} (Date: $date)',
      montant: montant,
      typeElement: 'revenu',
      elementId: id,
    );
  }

  // Supprimer un revenu — INCHANGÉ
  Future<void> deleteRevenu(String id) async {
    final doc = await _firebase.revenus.doc(id).get();
    final data = doc.data() as Map<String, dynamic>?;

    await _firebase.revenus.doc(id).delete();

    if (data != null) {
      await _historiqueRepo.addHistorique(
        typeOperation: 'revenu',
        operation: 'suppression',
        details:
            'Suppression d\'un revenu: ${data['type']} - ${data['motif'] ?? "Aucune description"} (Date: ${data['date']})',
        montant: (data['montant'] ?? 0).toDouble(),
        typeElement: 'revenu',
        elementId: id,
      );
    }
  }
}