// lib/database/database_helper.dart
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // Singleton
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;

  // Getter pour accéder à la DB
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  // Initialisation de la DB
  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'membres.db');

    return await openDatabase(
      path,
      version: 2, // 🔹 AUGMENTÉ DE 1 À 2
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // 🔹 AJOUTÉ
    );
  }

  // Création des tables (pour nouvelle installation)
  Future<void> _onCreate(Database db, int version) async {
    // Table users
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        passwordHash TEXT,
        salt TEXT,
        role TEXT NOT NULL,
        prenom TEXT,
        etablissement TEXT,
        niveau TEXT,
        mention TEXT,
        telephone TEXT,
        profileImage TEXT,
        dateNaissance TEXT
      )
    ''');

    // Table revenus
    await db.execute('''
      CREATE TABLE IF NOT EXISTS revenus (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        nom TEXT,
        prenom TEXT,
        date TEXT NOT NULL,
        montant REAL NOT NULL,
        motif TEXT,
        membreId INTEGER,
        nomActivite TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Table depenses
    await db.execute('''
      CREATE TABLE IF NOT EXISTS depenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        montant REAL NOT NULL,
        lieu TEXT,
        nombreParticipants INTEGER,
        nomProduit TEXT,
        membreAcheteurId INTEGER,
        membreAcheteur TEXT,
        typeCommunication TEXT,
        nomActivite TEXT,
        dateDebut TEXT,
        dateFin TEXT,
        lieuActivite TEXT,
        sousType TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Table historique
    await db.execute('''
      CREATE TABLE IF NOT EXISTS historique (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        typeOperation TEXT NOT NULL,
        operation TEXT NOT NULL,
        details TEXT NOT NULL,
        montant REAL NOT NULL,
        dateOperation DATETIME DEFAULT CURRENT_TIMESTAMP,
        typeElement TEXT,
        elementId INTEGER,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // 🔹 MIGRATION pour ajouter la colonne dateNaissance
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Vérifier si la colonne existe déjà (sécurité)
      var tableInfo = await db.rawQuery('PRAGMA table_info(users)');
      bool columnExists = tableInfo.any((column) => column['name'] == 'dateNaissance');
      
      if (!columnExists) {
        await db.execute('ALTER TABLE users ADD COLUMN dateNaissance TEXT');
        print('✅ Colonne dateNaissance ajoutée avec succès');
      }
    }
  }
}