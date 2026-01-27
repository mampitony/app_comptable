import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'navigation/app_navigator.dart';
import 'navigation/user_navigator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _dbInitialized = false;

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      // ouvre la DB et crée les tables
      await DatabaseHelper.instance.database;
      setState(() {
        _dbInitialized = true;
      });
      // ignore: avoid_print
      print('Base de données initialisée avec succès');
    } catch (e) {
      // ignore: avoid_print
      print("Erreur lors de l'initialisation de la base de données: $e");
      setState(() {
        _dbInitialized = true; // comme ton code JS : on charge quand même l'app
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_dbInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppNavigator(), // notre widget de navigation
    );
  }
}
