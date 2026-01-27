import 'package:flutter/material.dart';
import 'dart:io';
import '../database/revenu_repository.dart';
import '../database/user_repository.dart';

class RevenuScreen extends StatefulWidget {
  final bool canEdit;
  final String? userName;
  final String? userRole;
  final String? profileImage;

  const RevenuScreen({
    Key? key,
    required this.canEdit,
    this.userName,
    this.userRole,
    this.profileImage,
  }) : super(key: key);

  @override
  State<RevenuScreen> createState() => _RevenuScreenState();
}

class _RevenuScreenState extends State<RevenuScreen> {
  final _revenuRepo = RevenuRepository();
  final _userRepo = UserRepository();

  List<Map<String, dynamic>> revenus = [];
  List<Map<String, dynamic>> membres = [];
  double totalRevenus = 0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    await loadMembres();
    await loadRevenus();
  }

  Future<void> loadMembres() async {
    try {
      final data = await _userRepo.getAllUsers();
      if (mounted) setState(() => membres = data);
    } catch (e) {
      debugPrint('❌ Erreur membres: $e');
    }
  }

  Future<void> loadRevenus() async {
    try {
      setState(() => isLoading = true);
      final data = await _revenuRepo.getAllRevenus();
      final total = await _revenuRepo.getTotalRevenus();
      if (mounted) {
        setState(() {
          revenus = data;
          totalRevenus = total;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showAlert('Erreur', 'Impossible de charger les données');
    }
  }

  // --- DESIGN DU HEADER ---
  Widget _buildModernHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Solde Total Entrant",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              Icon(Icons.trending_up, color: Colors.greenAccent.shade100),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${totalRevenus.toStringAsFixed(0)} Ar",
            style: const TextStyle(
                color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "${revenus.length} Transactions enregistrées",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // --- LISTE DES REVENUS ---
  Widget _buildRevenuCard(Map<String, dynamic> item) {
    bool isCotisation = item['type'] == 'Cotisation';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: isCotisation ? Colors.blue.shade50 : Colors.green.shade50,
          child: Icon(
            isCotisation ? Icons.people_alt : Icons.volunteer_activism,
            color: isCotisation ? Colors.blue : Colors.green,
          ),
        ),
        title: Text(
          item['type'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            "${item['date']}\n${item['motif'] ?? ''}",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "+ ${item['montant']} Ar",
              style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            if (widget.canEdit)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.blue),
                    onPressed: () => _openModal(item: item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                    onPressed: () => _deleteRevenu(item),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Gestion des Revenus", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildModernHeader(),
            const SizedBox(height: 25),
            const Text("Historique Récent",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (revenus.isEmpty)
              const Center(child: Text("Aucun revenu trouvé"))
            else
              ...revenus.map((item) => _buildRevenuCard(item)).toList(),
          ],
        ),
      ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF0D47A1),
              onPressed: () => _openModal(),
              label: const Text("Nouveau Revenu"),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  // --- LOGIQUE DU MODAL (CONSERVÉE ET SÉCURISÉE) ---
  void _openModal({Map<String, dynamic>? item}) {
    if (!widget.canEdit) return;

    String dateRevenu = item?['date'] ?? '';
    String montantRevenu = item?['montant']?.toString() ?? '';
    String typeRevenu = item?['type'] ?? 'Cotisation';
    String typeCotisation = 'Mensuel';
    int? membreId;
    String? membreNom;
    String description = item?['motif'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20, right: 20, top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Text(item != null ? 'Modifier l\'entrée' : 'Ajouter un Revenu', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // Date Picker
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: dateRevenu),
                    decoration: const InputDecoration(labelText: "Date *", prefixIcon: Icon(Icons.calendar_today)),
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (picked != null) {
                        setModalState(() => dateRevenu = "${picked.day}/${picked.month}/${picked.year}");
                      }
                    },
                  ),
                  const SizedBox(height: 15),

                  // Type Dropdown
                  DropdownButtonFormField<String>(
                    value: typeRevenu,
                    items: ['Cotisation', 'Don', 'Subvention'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setModalState(() => typeRevenu = val!),
                    decoration: const InputDecoration(labelText: "Type de revenu"),
                  ),
                  
                  if (typeRevenu == 'Cotisation') ...[
                    const SizedBox(height: 15),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: membreId,
                      hint: const Text("Sélectionner le membre"),
                      items: membres.map((m) => DropdownMenuItem<int>(
                        value: m['id'],
                        child: Text("${m['name']} ${m['prenom']}"),
                      )).toList(),
                      onChanged: (val) {
                        final m = membres.firstWhere((element) => element['id'] == val);
                        setModalState(() {
                          membreId = val;
                          membreNom = "${m['name']} ${m['prenom']}";
                        });
                      },
                    ),
                  ],

                  const SizedBox(height: 15),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Montant (Ar) *", prefixIcon: Icon(Icons.money)),
                    onChanged: (val) => montantRevenu = val,
                  ),
                  
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => _submitData(item?['id'], typeRevenu, dateRevenu, montantRevenu, description, membreNom, typeCotisation),
                      child: const Text("Enregistrer", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  // --- SAUVEGARDE ---
  Future<void> _submitData(int? id, String type, String date, String montantStr, String desc, String? mNom, String tCotis) async {
    if (date.isEmpty || montantStr.isEmpty) {
      _showAlert("Erreur", "Champs obligatoires manquants");
      return;
    }
    
    double montant = double.tryParse(montantStr) ?? 0;
    String motifFinal = (type == 'Cotisation') ? "Cotisation $tCotis - $mNom" : desc;

    try {
      if (id != null) {
        await _revenuRepo.updateRevenu(id: id, type: type, date: date, montant: montant, motif: motifFinal);
      } else {
        await _revenuRepo.addRevenu(type: type, date: date, montant: montant, motif: motifFinal);
      }
      Navigator.pop(context);
      loadRevenus();
    } catch (e) {
      _showAlert("Erreur", e.toString());
    }
  }

  // --- FONCTIONS AUXILIAIRES ---
  Future<void> _deleteRevenu(Map<String, dynamic> item) async {
    // Garde ton code de confirmation de suppression ici
  }

  void _showAlert(String title, String message) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]));
  }
}