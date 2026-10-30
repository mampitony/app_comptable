// lib/components/description_montant_fields.dart
//
// 🔥 NOUVEAU FICHIER
//
// Paire de champs « Description » + « Montant » partagée par les écrans
// Dépenses et Revenus.
//
//  - Description : un élément par ligne, au format « nom : prix ».
//  - Dès que la description contient au moins un prix valide, le champ
//    Montant est remplacé par la somme de ces prix.
//  - Le montant reste modifiable à la main ; il n'est recalculé que lorsque
//    la description change (jamais à l'ouverture d'une fiche existante).
import 'package:flutter/material.dart';

import '../services/description_calculator.dart';
import 'form_style.dart';

class DescriptionMontantFields extends StatefulWidget {
  final String initialDescription;
  final String initialMontant;
  final String descriptionLabel;
  final String montantLabel;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<String> onMontantChanged;

  /// Espace entre les deux champs.
  final double spacing;

  /// Tailles de police (null = valeurs par défaut du thème).
  final double? fontSize;
  final double? labelFontSize;

  /// Affiche des icônes devant les champs (style de l'écran Revenus).
  final bool showIcons;

  const DescriptionMontantFields({
    Key? key,
    required this.initialDescription,
    required this.initialMontant,
    required this.onDescriptionChanged,
    required this.onMontantChanged,
    this.descriptionLabel = 'Description (optionnel)',
    this.montantLabel = 'Montant (Ar)',
    this.spacing = 16,
    this.fontSize,
    this.labelFontSize,
    this.showIcons = false,
  }) : super(key: key);

  @override
  State<DescriptionMontantFields> createState() =>
      _DescriptionMontantFieldsState();
}

class _DescriptionMontantFieldsState extends State<DescriptionMontantFields> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _montantCtrl;
  late DescriptionResult _result;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.initialDescription);
    _montantCtrl = TextEditingController(text: widget.initialMontant);
    _result = DescriptionCalculator.parse(widget.initialDescription);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _montantCtrl.dispose();
    super.dispose();
  }

  void _onDescriptionChanged(String value) {
    final result = DescriptionCalculator.parse(value);
    setState(() => _result = result);
    widget.onDescriptionChanged(value);

    // Au moins un prix reconnu : le montant devient la somme.
    if (result.hasPrices) {
      final text = DescriptionCalculator.plain(result.total);
      _montantCtrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      widget.onMontantChanged(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final helper = r.hasPrices
        ? 'Total calculé : ${DescriptionCalculator.format(r.total)} Ar '
            '(${r.count} ligne${r.count > 1 ? 's' : ''})'
        : 'Un élément par ligne : nom : prix  (ex. Siramamy : 5000 Ar)';

    return Column(
      children: [
        TextField(
          controller: _descCtrl,
          minLines: 3,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _onDescriptionChanged,
          style: TextStyle(fontSize: widget.fontSize),
          decoration: FormStyle.input(
            label: widget.descriptionLabel,
            labelFontSize: widget.labelFontSize,
            alignLabelWithHint: true,
            hint: "vidin'ny tavoangy : 2000 Ar\nSiramamy : 5000 Ar",
            helper: helper,
            helperMaxLines: 2,
            helperStyle: TextStyle(
              color: r.hasPrices ? Colors.green.shade700 : null,
              fontWeight: r.hasPrices ? FontWeight.w600 : null,
            ),
            icon: Icons.description_outlined,
            topIcon: true,
          ),
        ),
        SizedBox(height: widget.spacing),
        TextField(
          controller: _montantCtrl,
          keyboardType: TextInputType.number,
          onChanged: widget.onMontantChanged,
          style: TextStyle(fontSize: widget.fontSize),
          decoration: FormStyle.input(
            label: widget.montantLabel,
            labelFontSize: widget.labelFontSize,
            icon: Icons.payments_outlined,
          ),
        ),
      ],
    );
  }
}
