import 'package:flutter/material.dart';

class ComptableSignupForm extends StatefulWidget {
  const ComptableSignupForm({Key? key}) : super(key: key);

  @override
  State<ComptableSignupForm> createState() => _ComptableSignupFormState();
}

class _ComptableSignupFormState extends State<ComptableSignupForm> {
  final _formKey = GlobalKey<FormState>();

  String nom = '';
  String motifs = '';
  String montant = '';
  String date = '';

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // TODO: sauvegarder dans la base de données
    _showAlert('Succès', 'Enregistrement de la cotisation effectué');
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: (v) =>
          (v == null || v.isEmpty) ? 'Veuillez remplir ce champ' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cotisation'),
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        color: const Color(0xFFF5F5F5),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Text(
                  'Cotisation',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  hint: 'Nom *',
                  onChanged: (v) => nom = v,
                ),
                const SizedBox(height: 15),

                _buildTextField(
                  hint: 'Cotisation ou droit ou sortie ou ... *',
                  onChanged: (v) => motifs = v,
                ),
                const SizedBox(height: 15),

                _buildTextField(
                  hint: 'Montant *',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => montant = v,
                ),
                const SizedBox(height: 15),

                _buildTextField(
                  hint: 'Date *',
                  onChanged: (v) => date = v,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: handleSubmit,
                        child: const Text('Ajouter'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
