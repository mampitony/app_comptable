// lib/database/depense_repository.dart
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class DepenseRepository {
  final dbHelper = DatabaseHelper.instance;

  // Total des dépenses
  Future<double> getTotalDepenses() async {
    final db = await dbHelper.database;
    final result =
        await db.rawQuery('SELECT SUM(montant) as total FROM depenses');
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // Toutes les dépenses
  Future<List<Map<String, dynamic>>> getAllDepenses() async {
    final db = await dbHelper.database;
    return await db.query(
      'depenses',
      orderBy: 'date DESC',
    );
  }

  // Ajouter une dépense
  Future<int> addDepense({
    required String type,
    required String date,
    required double montant,
    String? lieu,
    int? nombreParticipants,
    String? nomProduit,
    int? membreAcheteurId,
    String? membreAcheteur,
    String? typeCommunication,
    String? nomActivite,
    String? dateDebut,
    String? dateFin,
    String? lieuActivite,
    String? sousType,
  }) async {
    final db = await dbHelper.database;
    final data = {
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
    };
    return await db.insert('depenses', data);
  }

  // Mettre à jour une dépense
  Future<int> updateDepense({
    required int id,
    required String type,
    required String date,
    required double montant,
    String? lieu,
    int? nombreParticipants,
    String? nomProduit,
    int? membreAcheteurId,
    String? membreAcheteur,
    String? typeCommunication,
    String? nomActivite,
    String? dateDebut,
    String? dateFin,
    String? lieuActivite,
    String? sousType,
  }) async {
    final db = await dbHelper.database;
    final data = {
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
    };
    return await db.update(
      'depenses',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Supprimer une dépense
  Future<int> deleteDepense(int id) async {
    final db = await dbHelper.database;
    return await db.delete(
      'depenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
