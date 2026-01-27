// lib/database/user_repository.dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class UserRepository {
  final dbHelper = DatabaseHelper.instance;

  // Générer un sel (équivalent generateSalt)
  String generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  // Hasher le mot de passe + sel (équivalent hashPassword)
  String hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Ajouter un utilisateur (avec mot de passe - admin ou membre avec compte)
  Future<int> addUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? prenom,
    String? etablissement,
    String? niveau,
    String? mention,
    String? telephone,
    String? profileImage,
    String? dateNaissance, // 🔹 nouveau champ
  }) async {
    final db = await dbHelper.database;
    final salt = generateSalt();
    final passwordHash = hashPassword(password, salt);

    final data = {
      'name': name,
      'email': email,
      'passwordHash': passwordHash,
      'salt': salt,
      'role': role,
      'prenom': prenom,
      'etablissement': etablissement,
      'niveau': niveau,
      'mention': mention,
      'telephone': telephone,
      'profileImage': profileImage,
      'dateNaissance': dateNaissance, // 🔹 stocké dans la DB
    };

    return await db.insert('users', data);
  }

  // Ajouter un membre (sans mot de passe)
  Future<int> addMember({
    required String name,
    required String email,
    required String role,
    String? prenom,
    String? etablissement,
    String? niveau,
    String? mention,
    String? telephone,
    String? profileImage,
    String? dateNaissance, // 🔹 nouveau
  }) async {
    final db = await dbHelper.database;

    final data = {
      'name': name,
      'email': email,
      'passwordHash': '',
      'salt': '',
      'role': role,
      'prenom': prenom,
      'etablissement': etablissement,
      'niveau': niveau,
      'mention': mention,
      'telephone': telephone,
      'profileImage': profileImage,
      'dateNaissance': dateNaissance, // 🔹 stocké aussi
    };

    return await db.insert('users', data);
  }

  // Obtenir un utilisateur par email
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (result.isNotEmpty) return result.first;
    return null;
  }

  // Obtenir un utilisateur par ID
  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isNotEmpty) return result.first;
    return null;
  }

  // Obtenir tous les utilisateurs
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await dbHelper.database;
    return await db.query('users');
  }

  // Obtenir tous les membres (role != admin)
  Future<List<Map<String, dynamic>>> getAllMembers() async {
    final db = await dbHelper.database;
    return await db.query(
      'users',
      where: 'role != ?',
      whereArgs: ['admin'],
    );
  }

  // Mettre à jour un utilisateur (avec option de changer mot de passe)
  Future<int> updateUser({
    required int id,
    required String name,
    required String email,
    String? password,
    required String role,
    String? prenom,
    String? etablissement,
    String? niveau,
    String? mention,
    String? telephone,
    String? profileImage,
    String? dateNaissance, // 🔹 nouveau
  }) async {
    final db = await dbHelper.database;
    Map<String, dynamic> data;

    if (password != null && password.trim().isNotEmpty) {
      final salt = generateSalt();
      final passwordHash = hashPassword(password, salt);

      data = {
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
        'salt': salt,
        'role': role,
        'prenom': prenom,
        'etablissement': etablissement,
        'niveau': niveau,
        'mention': mention,
        'telephone': telephone,
        'profileImage': profileImage,
        'dateNaissance': dateNaissance,
      };
    } else {
      data = {
        'name': name,
        'email': email,
        'role': role,
        'prenom': prenom,
        'etablissement': etablissement,
        'niveau': niveau,
        'mention': mention,
        'telephone': telephone,
        'profileImage': profileImage,
        'dateNaissance': dateNaissance,
      };
    }

    return await db.update(
      'users',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Mettre à jour infos membre (sans toucher au mot de passe)
  Future<int> updateMemberInfo({
    required int id,
    required String name,
    required String email,
    required String role,
    String? prenom,
    String? etablissement,
    String? niveau,
    String? mention,
    String? telephone,
    String? profileImage,
    String? dateNaissance, // 🔹 nouveau
  }) async {
    final db = await dbHelper.database;

    final data = {
      'name': name,
      'email': email,
      'role': role,
      'prenom': prenom,
      'etablissement': etablissement,
      'niveau': niveau,
      'mention': mention,
      'telephone': telephone,
      'profileImage': profileImage,
      'dateNaissance': dateNaissance,
    };

    return await db.update(
      'users',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Mettre à jour uniquement le mot de passe
  Future<int> updateUserPassword(int id, String password) async {
    final db = await dbHelper.database;
    final salt = generateSalt();
    final passwordHash = hashPassword(password, salt);

    final data = {
      'passwordHash': passwordHash,
      'salt': salt,
    };

    return await db.update(
      'users',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Supprimer un utilisateur
  Future<int> deleteUser(int id) async {
    final db = await dbHelper.database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Réinitialiser le mot de passe d'un membre
  Future<int> resetMemberPassword(int id) async {
    final db = await dbHelper.database;
    final data = {
      'passwordHash': '',
      'salt': '',
    };
    return await db.update(
      'users',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Réinitialiser tous les mots de passe des membres (non admin)
  Future<int> resetAllMemberPasswords() async {
    final db = await dbHelper.database;
    final data = {
      'passwordHash': '',
      'salt': '',
    };
    return await db.update(
      'users',
      data,
      where: 'role != ?',
      whereArgs: ['admin'],
    );
  }
}
