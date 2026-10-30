// lib/components/form_style.dart
//
// Style visuel commun des formulaires d'ajout (Revenus, Dépenses) :
// même univers que l'écran de connexion (vague bleue, champs arrondis avec
// icône dans une pastille, bouton pilule dégradé).
// ⚠️ Purement visuel : aucune logique métier ici.
import 'package:flutter/material.dart';

class FormStyle {
  FormStyle._();

  static const Color blue = Color(0xFF0163D2);
  static const Color cyan = Color(0xFF00AEEF);

  /// Décoration d'un champ (TextField / DropdownButtonFormField).
  static InputDecoration input({
    String? label,
    IconData? icon,
    String? hint,
    String? helper,
    TextStyle? helperStyle,
    int? helperMaxLines,
    double? labelFontSize,
    bool topIcon = false,
    bool alignLabelWithHint = false,
  }) {
    Widget? prefix;
    if (icon != null) {
      final tile = Padding(
        padding: const EdgeInsets.all(6),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: blue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: blue, size: 20),
        ),
      );
      prefix = topIcon
          ? Align(
              alignment: Alignment.topCenter,
              widthFactor: 1,
              heightFactor: 1,
              child: tile,
            )
          : tile;
    }

    final enabled = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.withOpacity(0.45)),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperStyle: helperStyle,
      helperMaxLines: helperMaxLines,
      alignLabelWithHint: alignLabelWithHint,
      labelStyle: TextStyle(fontSize: labelFontSize, color: Colors.grey.shade600),
      floatingLabelStyle:
          const TextStyle(color: blue, fontWeight: FontWeight.w600),
      prefixIcon: prefix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: enabled,
      enabledBorder: enabled,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: blue, width: 1.6),
      ),
    );
  }

  /// En-tête de la feuille : poignée + titre centré + petit trait bleu.
  static Widget sheetHeader({required String title, VoidCallback? onClose}) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  color: blue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
          if (onClose != null)
            Positioned(
              top: 10,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: onClose,
              ),
            ),
        ],
      ),
    );
  }

  /// Bouton principal en pilule dégradée.
  static Widget saveButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(colors: [cyan, blue]),
        boxShadow: [
          BoxShadow(
            color: blue.withOpacity(0.40),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

/// Vague bleue en haut à gauche de la feuille (à placer dans un Stack).
class FormWave extends StatelessWidget {
  const FormWave({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 86,
      child: Stack(
        children: [
          Opacity(
            opacity: 0.45,
            child: ClipPath(
              clipper: _WaveClipper(),
              child: Container(
                width: 150,
                height: 86,
                color: FormStyle.cyan,
              ),
            ),
          ),
          ClipPath(
            clipper: _WaveClipper(),
            child: Container(
              width: 122,
              height: 70,
              color: FormStyle.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final w = s.width, h = s.height;
    final p = Path()..lineTo(w, 0);
    p.cubicTo(w * 0.80, h * 0.2326, w * 0.6667, h * 0.1163, w * 0.52, h * 0.488);
    p.cubicTo(w * 0.4133, h * 0.7674, w * 0.2267, h * 0.907, 0, h);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
