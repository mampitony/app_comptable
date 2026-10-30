import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class FirebaseUserRepository {
  final _firebase = FirebaseService.instance;

  static const String adminPrincipalRole = 'admin_principal_membre';
  static const String adminGestionRole = 'admin_gestion_membre';
  static const String comptableRole = 'comptable';

  // ============================================================
  // DROIT ADMINISTRATEUR — champ dedie, modele final (base propre)
  //
  // `role`      = fonction normale du membre dans l'association
  //               (membre, president, tresorier, secretaire, ...).
  //               Il n'est JAMAIS modifie par l'attribution ou le
  //               retrait du droit administrateur.
  // `adminRole` = droit d'administration du module membres. Valeurs
  //               possibles : admin_principal_membre, admin_gestion_membre,
  //               ou null (aucune autorisation administrative).
  //
  // Cette separation permet de promouvoir un "tresorier" sans lui faire
  // perdre sa fonction, et de la retrouver intacte apres retrait du droit.
  // Le droit d'administration se lit UNIQUEMENT dans `adminRole` ; `role`
  // ne contient plus jamais de valeur d'administration.
  // ============================================================
  static const String adminRoleField = 'adminRole';

  // ============================================================
  // FONCTIONS MULTIPLES — un membre peut cumuler plusieurs fonctions
  // (ex. Sécretaire + Responsable de Communication).
  //
  // `roles` = liste de toutes ses fonctions (champ optionnel).
  // `role`  = fonction principale, conservée telle quelle : tout le code
  //           existant qui lit `role` continue de fonctionner.
  // Un membre sans champ `roles` (ancien format) est simplement vu comme
  // ayant une seule fonction : `role`.
  // ============================================================
  static const String rolesField = 'roles';

  /// Toutes les fonctions du membre (sans les droits d'administration),
  /// sans doublon. Jamais vide : retombe sur 'membre'.
  static List<String> resolveRoles(Map<String, dynamic> user) {
    final result = <String>[];
    void add(dynamic value) {
      final s = (value ?? '').toString().trim();
      if (s.isEmpty || s == adminPrincipalRole || s == adminGestionRole) {
        return;
      }
      if (!result.contains(s)) result.add(s);
    }

    final extra = user[rolesField];
    if (extra is List) {
      for (final r in extra) {
        add(r);
      }
    }
    add(user['role']);
    if (result.isEmpty) result.add(defaultMemberRole);
    return result;
  }

  /// Texte d'affichage des fonctions. Sans champ `roles`, renvoie
  /// exactement la valeur de `role` (affichage historique inchangé).
  static String rolesLabel(Map<String, dynamic> user,
      {String separator = ' • '}) {
    final extra = user[rolesField];
    if (extra is! List || extra.isEmpty) {
      return (user['role'] ?? '').toString();
    }
    return resolveRoles(user).join(separator);
  }

  /// Nombre de fonctions en plus de la principale (0 si une seule).
  static int extraRolesCount(Map<String, dynamic> user) {
    if (user[rolesField] is! List) return 0;
    final n = resolveRoles(user).length - 1;
    return n > 0 ? n : 0;
  }

  /// Fonction attribuee par defaut a un membre normal.
  static const String defaultMemberRole = 'membre';

  // ------------------------------------------------------------
  // Lecture des droits — basee exclusivement sur `adminRole`.
  // ------------------------------------------------------------

  static bool isAdminPrincipal(Map<String, dynamic> user) =>
      user[adminRoleField] == adminPrincipalRole;

  static bool isAdminGestion(Map<String, dynamic> user) =>
      user[adminRoleField] == adminGestionRole;

  static bool isComptable(Map<String, dynamic> user) =>
      resolveRoles(user).contains(comptableRole);

  /// Droit d'administration effectif (valeur de `adminRole`), ou null si
  /// l'utilisateur n'est pas administrateur du module membres.
  static String? resolveAdminRole(Map<String, dynamic> user) {
    final value = user[adminRoleField];
    if (value == adminPrincipalRole || value == adminGestionRole) {
      return value as String;
    }
    return null;
  }

  String generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  String hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Vérifie l'existence de l'administrateur principal via `adminRole`
  /// (et non plus via `role`, qui ne contient plus de valeur d'admin).
  Future<bool> adminPrincipalExists() async {
    final result = await _firebase.users
        .where(adminRoleField, isEqualTo: adminPrincipalRole)
        .limit(1)
        .get();

    return result.docs.isNotEmpty;
  }

  /// Crée l'administrateur principal unique de l'association.
  /// Réservé au tout premier compte (base vide) : à appeler uniquement
  /// après avoir vérifié `adminPrincipalExists()`.
  /// `role` reste une fonction normale ('membre' par défaut), `adminRole`
  /// porte seul le droit d'administration.
  Future<String> createAdminPrincipal({
    required String name,
    required String email,
    required String password,
  }) async {
    if (await adminPrincipalExists()) {
      throw Exception("Un administrateur principal existe déjà.");
    }

    final salt = generateSalt();
    final passwordHash = hashPassword(password, salt);

    final docRef = await _firebase.users.add({
      'name': name,
      'email': email,
      'passwordHash': passwordHash,
      'salt': salt,
      'role': defaultMemberRole,
      adminRoleField: adminPrincipalRole,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// 🔥 AJOUT : champs « statut du membre » (Étudiant / Autre).
  /// Si `status` n'est pas fourni (anciens appelants), rien n'est écrit :
  /// le comportement d'origine est conservé. Sinon `profession` et
  /// `secteurActivite` sont écrits (vides si non concernés) pour effacer
  /// les anciennes données quand le statut change.
  static Map<String, dynamic> statusFields(
    String? status,
    String? profession,
    String? secteurActivite,
  ) {
    if (status == null) return const <String, dynamic>{};
    return {
      'status': status,
      'profession': profession ?? '',
      'secteurActivite': secteurActivite ?? '',
    };
  }

  Future<String> addUser({
    required String name,
    required String email,
    required String password,
    required String role,
    List<String>? roles,
    String? prenom,
    String? etablissement,
    String? niveau,
    String? mention,
    String? telephone,
    String? profileImage,
    String? dateNaissance,
    String? status,
    String? profession,
    String? secteurActivite,
  }) async {
    final salt = generateSalt();
    final passwordHash = hashPassword(password, salt);

    final docRef = await _firebase.users.add({
      'name': name,
      'email': email,
      'passwordHash': passwordHash,
      'salt': salt,
      'role': role,
      if (roles != null && roles.isNotEmpty) rolesField: roles,
      // Un membre créé via ce chemin n'a par défaut aucun droit
      // d'administration : `adminRole` est explicitement null.
      adminRoleField: null,
      'prenom': prenom,
      'etablissement': etablissement,
      'niveau': niveau,
      'mention': mention,
      'telephone': telephone,
      'profileImage': profileImage,
      'dateNaissance': dateNaissance,
      ...statusFields(status, profession, secteurActivite),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<String> addMember({
    required String name,
    required String email,
    required String role,
    List<String>? roles,
    String? prenom,
    String? etablissement,
    String? niveau,
    String? mention,
    String? telephone,
    String? profileImage,
    String? dateNaissance,
    String? status,
    String? profession,
    String? secteurActivite,
  }) async {

    final docRef = await _firebase.users.add({
      'name': name,
      'email': email,
      'passwordHash': '',
      'salt': '',
      'role': role,
      if (roles != null && roles.isNotEmpty) rolesField: roles,
      // Idem : aucun droit d'administration à la création.
      adminRoleField: null,
      'prenom': prenom,
      'etablissement': etablissement,
      'niveau': niveau,
      'mention': mention,
      'telephone': telephone,
      'profileImage': profileImage,
      'dateNaissance': dateNaissance,
      ...statusFields(status, profession, secteurActivite),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final querySnapshot = await _firebase.users
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final querySnapshot = await _firebase.users.get();

    return querySnapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    }).toList();
  }

  /// Liste des membres gerables.
  ///
  /// Les administrateurs gestion membre y figurent : ils restent des
  /// membres de l'association (leur `role` reste leur fonction normale),
  /// et l'administrateur principal doit pouvoir leur retirer le droit
  /// a tout moment. L'administrateur principal et les comptables restent
  /// exclus de cette liste.
  Future<List<Map<String, dynamic>>> getAllMembers() async {
    final querySnapshot = await _firebase.users.get();

    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .where((user) => !isAdminPrincipal(user) && !isComptable(user))
        .toList();
  }

  /// Liste des administrateurs gestion membre actuellement en poste.
  Future<List<Map<String, dynamic>>> getAllAdminGestion() async {
    final querySnapshot = await _firebase.users.get();

    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .where(isAdminGestion)
        .toList();
  }

  /// Nombre d'administrateurs gestion membre. Aucune limite n'est appliquee :
  /// l'organisation en definit librement le nombre.
  Future<int> countAdminGestion() async {
    final admins = await getAllAdminGestion();
    return admins.length;
  }

  // ============================================================
  // ATTRIBUTION / RETRAIT DU DROIT ADMINISTRATEUR GESTION MEMBRE
  // Reserve a l'administrateur principal (controle cote ecran).
  // ============================================================

  /// Attribue le droit administrateur gestion membre a un membre existant.
  /// Le nombre d'administrateurs gestion membre n'est pas limite.
  /// La fonction associative du membre (`role`) est conservee telle quelle.
  Future<void> promoteMemberToAdminGestion(String id) async {
    final snapshot = await _firebase.users.doc(id).get();

    if (!snapshot.exists) {
      throw Exception("Membre introuvable.");
    }

    final data = {'id': snapshot.id, ...snapshot.data() as Map<String, dynamic>};

    if (isAdminPrincipal(data)) {
      throw Exception(
          "L'administrateur principal dispose déjà de tous les droits.");
    }

    if (isComptable(data)) {
      throw Exception(
          "Un compte comptable ne peut pas administrer les membres.");
    }

    if (isAdminGestion(data)) {
      throw Exception("Ce membre est déjà administrateur gestion membre.");
    }

    await _firebase.users.doc(id).update({
      adminRoleField: adminGestionRole,
      'adminGrantedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Attribue le droit a plusieurs membres en une seule action.
  /// Un membre deja promu ou non eligible n'interrompt pas le lot.
  Future<void> promoteMembersToAdminGestion(List<String> ids) async {
    for (final id in ids) {
      try {
        await promoteMemberToAdminGestion(id);
      } catch (_) {
        // ignore et poursuit le lot
      }
    }
  }

  /// Retire le droit administrateur gestion membre.
  /// Le compte n'est PAS supprime et sa fonction (`role`) n'est jamais
  /// touchee : seul `adminRole` repasse a null.
  Future<void> removeAdminGestionRole(String id) async {
    final snapshot = await _firebase.users.doc(id).get();

    if (!snapshot.exists) {
      throw Exception("Utilisateur introuvable.");
    }

    final data = {'id': snapshot.id, ...snapshot.data() as Map<String, dynamic>};

    if (isAdminPrincipal(data)) {
      throw Exception(
          "L'administrateur principal ne peut pas perdre son rôle.");
    }

    if (!isAdminGestion(data)) {
      throw Exception("Ce membre n'est pas administrateur gestion membre.");
    }

    await _firebase.users.doc(id).update({
      adminRoleField: null,
      'adminGrantedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUser({
    required String id,
    required String name,
    required String email,
    String? password,
    required String role,
    List<String>? roles,
    String? prenom,
    String? etablissement,
    String? niveau,
    String? mention,
    String? telephone,
    String? profileImage,
    String? dateNaissance,
    String? status,
    String? profession,
    String? secteurActivite,
  }) async {

    // `adminRole` n'est volontairement pas dans cette map :
    // modifier la fiche d'un membre ne touche jamais a ses droits.
    Map<String, dynamic> data = {
      'name': name,
      'email': email,
      'role': role,
      if (roles != null && roles.isNotEmpty) rolesField: roles,
      'prenom': prenom,
      'etablissement': etablissement,
      'niveau': niveau,
      'mention': mention,
      'telephone': telephone,
      'profileImage': profileImage,
      'dateNaissance': dateNaissance,
      ...statusFields(status, profession, secteurActivite),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (password != null && password.trim().isNotEmpty) {
      final salt = generateSalt();
      data['passwordHash'] = hashPassword(password, salt);
      data['salt'] = salt;
    }

    await _firebase.users.doc(id).update(data);
  }

  Future<void> updateUserPassword(String id, String password) async {
    final salt = generateSalt();
    final passwordHash = hashPassword(password, salt);

    await _firebase.users.doc(id).update({
      'passwordHash': passwordHash,
      'salt': salt,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUser(String id) async {
    final user = await _firebase.users.doc(id).get();

    if (user.exists) {
      final data = {'id': user.id, ...user.data() as Map<String, dynamic>};

      if (isAdminPrincipal(data)) {
        throw Exception(
            "L'administrateur principal ne peut pas être supprimé.");
      }
    }

    await _firebase.users.doc(id).delete();
  }

  Future<void> resetMemberPassword(String id) async {
    await _firebase.users.doc(id).update({
      'passwordHash': '',
      'salt': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resetAllMemberPasswords() async {
    final querySnapshot = await _firebase.users.get();

    final batch = _firebase.users.firestore.batch();

    for (var doc in querySnapshot.docs) {
      final data = {'id': doc.id, ...doc.data() as Map<String, dynamic>};

      // Les comptes administrateurs (principal ET gestion membre) et
      // comptables conservent leur mot de passe.
      if (!isAdminPrincipal(data) &&
          !isAdminGestion(data) &&
          !isComptable(data)) {
        batch.update(doc.reference, {
          'passwordHash': '',
          'salt': '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }
}