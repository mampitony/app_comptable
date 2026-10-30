// lib/services/description_calculator.dart
//
// 🔥 NOUVEAU FICHIER
//
// Calcule automatiquement le montant à partir d'une description écrite à
// raison d'un élément par ligne, au format  « nom : prix » :
//
//   vidin'ny tavoangy : 2000ar
//   Siramamy : 5000 Ar
//   Vilia : 10000
//
// Règles :
//  - le prix est le nombre situé après le DERNIER « : » de la ligne ;
//  - l'unité est facultative : « ar », « Ar », « Ariary » (ou « MGA ») ;
//  - les espaces dans le nombre sont ignorés (« 2 000 » = 2000) ;
//  - un point ou une virgule suivi de 3 chiffres est un séparateur de
//    milliers (« 10.000 » = 10000) ; sinon c'est une décimale (« 2,5 ») ;
//  - les lignes sans « : » ou sans prix valide sont ignorées (titres, notes).

class DescriptionResult {
  final double total;

  /// Nombre de lignes dont un prix a été reconnu.
  final int count;

  const DescriptionResult(this.total, this.count);

  bool get hasPrices => count > 0;
}

class DescriptionCalculator {
  DescriptionCalculator._();

  static DescriptionResult parse(String text) {
    double total = 0;
    int count = 0;

    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final idx = line.lastIndexOf(':');
      if (idx <= 0) continue;
      // Il faut un nom avant les deux-points.
      if (line.substring(0, idx).trim().isEmpty) continue;

      final price = parsePrice(line.substring(idx + 1));
      if (price == null) continue;

      total += price;
      count++;
    }
    return DescriptionResult(total, count);
  }

  /// Lit un prix (« 2000ar », « 10 000 Ariary », « 2.500 », « 1,5 »...).
  /// Renvoie null si le texte n'est pas un prix.
  static double? parsePrice(String raw) {
    var s = raw.trim();
    // Unité (Ar, Ariary, MGA) avant ou après le nombre.
    s = s.replaceFirst(
        RegExp(r'^(ariary|ar|mga)\.?\s*', caseSensitive: false), '');
    s = s.replaceFirst(
        RegExp(r'\s*(ariary|ar|mga)\.?$', caseSensitive: false), '');
    // Espaces (y compris insécables) à l'intérieur du nombre.
    s = s.replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return null;

    // 2000
    if (RegExp(r'^\d+$').hasMatch(s)) return double.tryParse(s);

    // 10.000 / 1,250,000 (séparateurs de milliers)
    if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(s)) {
      return double.tryParse(s.replaceAll(RegExp(r'[.,]'), ''));
    }

    // 2,5 / 2.50 (décimales)
    if (RegExp(r'^\d+[.,]\d{1,2}$').hasMatch(s)) {
      return double.tryParse(s.replaceAll(',', '.'));
    }

    // 10.000,50 / 1,000.5 (milliers + décimales)
    if (RegExp(r'^\d{1,3}([.,]\d{3})+[.,]\d{1,2}$').hasMatch(s)) {
      final cut = s.lastIndexOf(RegExp(r'[.,]'));
      final intPart = s.substring(0, cut).replaceAll(RegExp(r'[.,]'), '');
      final decPart = s.substring(cut + 1);
      return double.tryParse('$intPart.$decPart');
    }

    return null;
  }

  /// Texte à mettre dans le champ « Montant » (2000, ou 2500.50).
  static String plain(double value) {
    if (value == value.truncateToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  /// Texte lisible pour l'affichage (« 17 000 », « 2 500.50 »).
  static String format(double value) {
    final s = plain(value);
    final dot = s.indexOf('.');
    final intPart = dot < 0 ? s : s.substring(0, dot);
    final decPart = dot < 0 ? '' : s.substring(dot);
    final grouped = intPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$grouped$decPart';
  }

  static List<String> _lines(String text) => text
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  /// Description sur une seule ligne (lignes séparées par « ; »).
  static String flatten(String text, {String separator = ' ; '}) =>
      _lines(text).join(separator);

  /// Première ligne non vide, ou [fallback] si la description est vide.
  static String firstLine(String text, {String fallback = ''}) {
    final lines = _lines(text);
    return lines.isEmpty ? fallback : lines.first;
  }

  /// Toutes les lignes sauf la première (vide s'il n'y en a pas).
  static String withoutFirstLine(String text) {
    final lines = _lines(text);
    return lines.length <= 1 ? '' : lines.skip(1).join('\n');
  }
}
