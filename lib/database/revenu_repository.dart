// lib/database/revenu_repository.dart
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'historique_repository.dart';

class RevenuRepository {
  final dbHelper = DatabaseHelper.instance;
  final historiqueRepo = HistoriqueRepository();

  // Total des revenus
  Future<double> getTotalRevenus() async {
    final db = await dbHelper.database;
    final result =
        await db.rawQuery('SELECT SUM(montant) as total FROM revenus');
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // Tous les revenus
  Future<List<Map<String, dynamic>>> getAllRevenus() async {
    final db = await dbHelper.database;
    return await db.query(
      'revenus',
      orderBy: 'date DESC',
    );
  }

  // Ajouter un revenu
  Future<int> addRevenu({
    required String type,
    String? nom,
    String? prenom,
    required String date,
    required double montant,
    String? motif,
    int? membreId,
    String? nomActivite,
  }) async {
    final db = await dbHelper.database;
    final data = {
      'type': type,
      'nom': nom,
      'prenom': prenom,
      'date': date,
      'montant': montant,
      'motif': motif,
      'membreId': membreId,
      'nomActivite': nomActivite,
    };
    
    final revenuId = await db.insert('revenus', data);
    
    // Enregistrer dans l'historique
    await historiqueRepo.addHistorique(
      typeOperation: 'revenu',
      operation: 'ajout',
      details: 'Ajout d\'un revenu: $type - ${motif ?? "Aucune description"} (Date: $date)',
      montant: montant,
      typeElement: 'revenu',
      elementId: revenuId,
    );
    
    return revenuId;
  }

  // Mettre à jour un revenu
  Future<int> updateRevenu({
    required int id,
    required String type,
    String? nom,
    String? prenom,
    required String date,
    required double montant,
    String? motif,
    int? membreId,
    String? nomActivite,
  }) async {
    final db = await dbHelper.database;
    final data = {
      'type': type,
      'nom': nom,
      'prenom': prenom,
      'date': date,
      'montant': montant,
      'motif': motif,
      'membreId': membreId,
      'nomActivite': nomActivite,
    };
    
    final result = await db.update(
      'revenus',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
    
    // Enregistrer dans l'historique
    await historiqueRepo.addHistorique(
      typeOperation: 'revenu',
      operation: 'modification',
      details: 'Modification d\'un revenu: $type - ${motif ?? "Aucune description"} (Date: $date)',
      montant: montant,
      typeElement: 'revenu',
      elementId: id,
    );
    
    return result;
  }

  // Supprimer un revenu
  Future<int> deleteRevenu(int id) async {
    final db = await dbHelper.database;
    
    // Récupérer les infos du revenu avant suppression
    final revenu = await db.query(
      'revenus',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    final result = await db.delete(
      'revenus',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    // Enregistrer dans l'historique
    if (revenu.isNotEmpty) {
      final revenuData = revenu.first;
      await historiqueRepo.addHistorique(
        typeOperation: 'revenu',
        operation: 'suppression',
        details: 'Suppression d\'un revenu: ${revenuData['type']} - ${revenuData['motif'] ?? "Aucune description"} (Date: ${revenuData['date']})',
        montant: (revenuData['montant'] as num).toDouble(),
        typeElement: 'revenu',
        elementId: id,
      );
    }
    
    return result;
  }
}