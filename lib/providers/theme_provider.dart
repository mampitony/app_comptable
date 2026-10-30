// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  // Charger la préférence de thème
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('dark_mode_enabled') ?? false;
    notifyListeners();
  }

  // Basculer le thème
  Future<void> toggleTheme(bool isDark) async {
    _isDarkMode = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode_enabled', isDark);
    notifyListeners();
  }

  // Thème clair
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF0163D2),
      scaffoldBackgroundColor: Colors.white,

      colorScheme: ColorScheme.light(
        primary: const Color(0xFF0163D2),
        secondary: const Color(0xFF00AEEF),
        surface: Colors.white,
        background: const Color(0xFFF4F6F8),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: const Color(0xFF1E293B),
        onBackground: const Color(0xFF1E293B),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0163D2),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0163D2),
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        // 🔥 AJOUT : couleurs explicites pour label/placeholder/icônes,
        // afin qu'aucun champ ne dépende d'une valeur par défaut qui
        // pourrait rester sombre en mode clair ou clair en mode sombre.
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
        floatingLabelStyle: const TextStyle(color: Color(0xFF0163D2)),
        hintStyle: TextStyle(color: Colors.grey[500]),
        prefixIconColor: const Color(0xFF64748B),
        suffixIconColor: const Color(0xFF64748B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0163D2), width: 2),
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
        // 🔥 AJOUT : c'est ce style (par défaut, si un TextField/
        // TextFormField ne fixe pas sa propre couleur) qui détermine la
        // couleur du texte SAISI. Sans lui, le texte pouvait dépendre
        // d'une valeur par défaut du framework non garantie.
        titleMedium: TextStyle(fontSize: 16, color: Color(0xFF1E293B)),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF1E293B)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
      ),
    );
  }

  // Thème sombre
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF0163D2),
      scaffoldBackgroundColor: const Color(0xFF0F172A),

      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF0163D2),
        secondary: const Color(0xFF00AEEF),
        surface: const Color(0xFF1E293B),
        background: const Color(0xFF0F172A),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0163D2),
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF334155),
        // 🔥 AJOUT : symétrique du thème clair.
        labelStyle: const TextStyle(color: Color(0xFFCBD5E1)),
        floatingLabelStyle: const TextStyle(color: Color(0xFF64B5F6)),
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIconColor: const Color(0xFFCBD5E1),
        suffixIconColor: const Color(0xFFCBD5E1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0163D2), width: 2),
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        // 🔥 AJOUT : couleur du texte saisi par défaut en mode sombre.
        titleMedium: TextStyle(fontSize: 16, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
      ),
    );
  }
}
