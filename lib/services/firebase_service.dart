import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart'; // 🔥 Import indispensable des options générées

class FirebaseService {
  // Singleton pour accéder à l'instance partout dans l'app
  static final FirebaseService instance = FirebaseService._internal();
  
  FirebaseService._internal();

  // Instances privées
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔥 Initialiser Firebase avec les configurations spécifiques au projet
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // --- Références des collections Firestore ---
  
  // Accès à la collection des utilisateurs
  CollectionReference get users => _firestore.collection('users');
  
  // Accès à la collection des revenus
  CollectionReference get revenus => _firestore.collection('revenus');
  
  // Accès à la collection des dépenses
  CollectionReference get depenses => _firestore.collection('depenses');
  
  // Accès à la collection de l'historique des transactions
  CollectionReference get historique => _firestore.collection('historique');
  
  // Accès à la collection de configuration globale
  CollectionReference get config => _firestore.collection('config');

  // --- Getters additionnels utiles ---
  
  FirebaseFirestore get firestore => _firestore;
  FirebaseAuth get auth => _auth;
}