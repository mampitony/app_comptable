import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // Import nécessaire
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/firebase_service.dart';           // Votre service Firebase
import 'services/push_notification_service.dart';  // 🔥 AJOUT : notifications push
import 'screens/splash_screen.dart'; // 🎬 AJOUT : écran de démarrage animé
import 'providers/theme_provider.dart';
import 'chat/chat_call_service.dart'; // 📞 appels avec sonnerie

void main() async {
  // 1. Assure que les liaisons avec le moteur Flutter sont prêtes
  // C'est obligatoire avant de faire un appel asynchrone dans le main
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 2. Initialise Firebase avec la configuration (options)
    // Cela appelle la méthode statique que nous avons corrigée dans FirebaseService
    await FirebaseService.initialize();
    print("🚀 Firebase initialisé avec succès !");
  } catch (e) {
    print("❌ Erreur lors de l'initialisation de Firebase : $e");
  }

  // 🔥 AJOUT : notifications push (Firebase Cloud Messaging).
  // Doit être enregistré avant runApp, et uniquement après
  // l'initialisation de Firebase ci-dessus.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService.initialize();

  // 📞 Appels : clé de navigation + journal ZEGOCLOUD (avant runApp).
  await ChatCallService.prepare();

  // 3. Lance l'application avec le Provider de thème
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: ChatCallService.navigatorKey, // 📞 écran d'appel entrant
          title: 'Comptabilité',
          scaffoldMessengerKey: PushNotificationService.messengerKey, // 🔔 bannière annonces
          // Utilisation des thèmes via le provider
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          // Point d'entrée : écran de démarrage animé, puis AppNavigator
          home: const SplashScreen(),
        );
      },
    );
  }
}