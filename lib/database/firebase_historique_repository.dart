import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class FirebaseHistoriqueRepository {
  final _firebase = FirebaseService.instance;

  // Obtenir l'historique
  Future<List<Map<String, dynamic>>> getHistorique({String? typeOperation}) async {
    Query query = _firebase.historique.orderBy('dateOperation', descending: true);

    if (typeOperation != null) {
      query = query.where('typeOperation', isEqualTo: typeOperation);
    }

    final querySnapshot = await query.get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // ✅ CORRECTION : convertir Timestamp en String lisible
      if (data['dateOperation'] is Timestamp) {
        final ts = data['dateOperation'] as Timestamp;
        final dt = ts.toDate();
        data['dateOperation'] =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }

      if (data['createdAt'] is Timestamp) {
        final ts = data['createdAt'] as Timestamp;
        final dt = ts.toDate();
        data['createdAt'] =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }

      return {'id': doc.id, ...data};
    }).toList();
  }

  // Ajouter une entrée — INCHANGÉ
  Future<String> addHistorique({
    required String typeOperation,
    required String operation,
    required String details,
    required double montant,
    String? typeElement,
    String? elementId,
  }) async {
    final docRef = await _firebase.historique.add({
      'typeOperation': typeOperation,
      'operation': operation,
      'details': details,
      'montant': montant,
      'typeElement': typeElement,
      'elementId': elementId,
      'dateOperation': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // Vider l'historique — INCHANGÉ
  Future<void> clearHistorique() async {
    final querySnapshot = await _firebase.historique.get();
    for (var doc in querySnapshot.docs) {
      await doc.reference.delete();
    }
  }
}