// lib/database/historique_repository.dart
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class HistoriqueRepository {
  final dbHelper = DatabaseHelper.instance;

  // Obtenir l'historique (optionnellement filtré par typeOperation)
  Future<List<Map<String, dynamic>>> getHistorique({
    String? typeOperation,
  }) async {
    final db = await dbHelper.database;
    String query = 'SELECT * FROM historique';
    List<dynamic> params = [];

    if (typeOperation != null) {
      query += ' WHERE typeOperation = ?';
      params.add(typeOperation);
    }

    query += ' ORDER BY dateOperation DESC';

    return await db.rawQuery(query, params);
  }

  // Ajouter une entrée dans l'historique
  Future<int> addHistorique({
    required String typeOperation,
    required String operation,
    required String details,
    required double montant,
    String? typeElement,
    int? elementId,
  }) async {
    final db = await dbHelper.database;

    final data = {
      'typeOperation': typeOperation,
      'operation': operation,
      'details': details,
      'montant': montant,
      'typeElement': typeElement,
      'elementId': elementId,
      'dateOperation': DateTime.now().toIso8601String(), // ✅ AJOUT ICI
      'createdAt': DateTime.now().toIso8601String(),
    };

    return await db.insert('historique', data);
  }

  // Vider l'historique
  Future<int> clearHistorique() async {
    final db = await dbHelper.database;
    return await db.delete('historique');
  }
}
