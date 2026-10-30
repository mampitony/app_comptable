// lib/services/password_reset_service.dart
//
// Réinitialisation du mot de passe par code envoyé par email.
// Le code est généré, envoyé et vérifié par le serveur Vercel
// (api/request-reset.js et api/confirm-reset.js) : rien de secret n'est
// dans l'application (ni identifiants email, ni logique de vérification).
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Adresse de base du serveur Vercel (même projet que les notifications).
const String ajemApiBase = 'https://notificationajem.vercel.app/api';

class PasswordResetResult {
  final bool ok;

  /// invalid | expired | too_many | weak_password | server | network
  final String? code;
  final String message;
  final int? remaining;

  const PasswordResetResult({
    required this.ok,
    this.code,
    this.message = '',
    this.remaining,
  });
}

class PasswordResetService {
  /// Étape 1 : demande l'envoi d'un code à l'adresse email.
  /// La réponse est neutre : elle ne dit pas si le compte existe.
  static Future<PasswordResetResult> requestCode(String email) {
    return _post('request-reset', {'email': email});
  }

  /// Étape 2 : envoie le code reçu et le nouveau mot de passe.
  static Future<PasswordResetResult> confirm({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _post('confirm-reset', {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
  }

  static Future<PasswordResetResult> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$ajemApiBase/$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode == 200 && data['ok'] == true) {
        return const PasswordResetResult(ok: true);
      }
      return PasswordResetResult(
        ok: false,
        code: data['code']?.toString() ?? 'server',
        message: data['error']?.toString() ?? 'Une erreur est survenue',
        remaining: data['remaining'] is int ? data['remaining'] as int : null,
      );
    } catch (_) {
      return const PasswordResetResult(
        ok: false,
        code: 'network',
        message: 'Connexion impossible. Vérifiez votre internet et réessayez.',
      );
    }
  }
}
