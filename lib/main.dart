import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database/database_helper.dart';
import 'navigation/app_navigator.dart';
import 'providers/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    // 🔥 Wrapper avec ChangeNotifierProvider
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
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

    // 🔥 Utiliser Consumer pour écouter les changements de thème
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          
          // 🔥 Application des thèmes dynamiques
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          
          home: AppNavigator(), // notre widget de navigation
        );
      },
    );
  }
}