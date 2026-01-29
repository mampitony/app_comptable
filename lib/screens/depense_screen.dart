import 'package:flutter/material.dart';

// Repositories
import '../database/depense_repository.dart';
import '../database/revenu_repository.dart';
import '../database/user_repository.dart';
import '../database/historique_repository.dart';

class DepenseScreen extends StatefulWidget {
  final bool canEdit;
  final String? userName;
  final String? userRole;
  final String? profileImage;

  const DepenseScreen({
    Key? key,
    required this.canEdit,
    this.userName,
    this.userRole,
    this.profileImage,
  }) : super(key: key);

  @override
  State<DepenseScreen> createState() => _DepenseScreenState();
}

class _DepenseScreenState extends State<DepenseScreen> {
  String sectionActive = 'Déplacement';
  String searchQuery = '';

  // Repositories
  final DepenseRepository _depenseRepo = DepenseRepository();
  final RevenuRepository _revenuRepo = RevenuRepository();
  final UserRepository _userRepo = UserRepository();
  final HistoriqueRepository _historiqueRepo = HistoriqueRepository();

  List<Map<String, dynamic>> membres = [];
  double totalRevenus = 0;

  // États formulaire
  String typeDepense = 'Déplacement';
  String dateDepense = '';
  String montantDepense = '';
  String lieuDeplacement = '';
  String nombreParticipants = '';
  String nomProduit = '';
  String membreAcheteur = '';
  String typeCommunication = 'Crédit téléphone';
  String nomActivite = '';
  String dateDebutActivite = '';
  String dateFinActivite = '';
  String lieuActivite = '';

  Map<String, dynamic>? editItem;

  Map<String, List<Map<String, dynamic>>> depenses = {
    'Déplacement': [],
    'Achat': [],
    'Communication': [],
    'Activités': [],
  };

  bool get canEdit => widget.canEdit;

  @override
  void initState() {
    super.initState();
    _initDepenses();
  }

  // --- LOGIQUE DE DONNÉES ---

  Future<void> _initDepenses() async {
    try {
      await _loadMembres();
      await _loadTotalRevenus();
      await _loadDepensesFromDB();
    } catch (e) {
      debugPrint("Erreur init dépense: $e");
    }
  }

  Future<void> _loadMembres() async {
    final users = await _userRepo.getAllMembers();
    setState(() => membres = users);
  }

  Future<void> _loadTotalRevenus() async {
    final total = await _revenuRepo.getTotalRevenus();
    setState(() => totalRevenus = total);
  }

  Future<void> _loadDepensesFromDB() async {
    final all = await _depenseRepo.getAllDepenses();
    final Map<String, List<Map<String, dynamic>>> mapTemp = {
      'Déplacement': [], 'Achat': [], 'Communication': [], 'Activités': [],
    };
    for (final d in all) {
      final type = d['type'] as String? ?? '';
      if (mapTemp.containsKey(type)) mapTemp[type]!.add(d);
    }
    setState(() => depenses = mapTemp);
  }

  Map<String, double> _calculerTotaux() {
    double totalDeplacement = depenses['Déplacement']!.fold(0.0, (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0));
    double totalAchat = depenses['Achat']!.fold(0.0, (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0));
    double totalCommunication = depenses['Communication']!.fold(0.0, (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0));
    double totalActivites = depenses['Activités']!.fold(0.0, (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0));
    double totalGeneral = totalDeplacement + totalAchat + totalCommunication + totalActivites;
    return {
      'Déplacement': totalDeplacement,
      'Achat': totalAchat,
      'Communication': totalCommunication,
      'Activités': totalActivites,
      'General': totalGeneral,
      'Solde': totalRevenus - totalGeneral,
    };
  }

  List<Map<String, dynamic>> get _filteredDepenses {
    final list = depenses[sectionActive] ?? [];
    if (searchQuery.isEmpty) return list;
    final searchLower = searchQuery.toLowerCase();
    return list.where((item) {
      switch (sectionActive) {
        case 'Déplacement': return (item['lieu'] ?? '').toString().toLowerCase().contains(searchLower);
        case 'Achat': return (item['nomProduit'] ?? '').toString().toLowerCase().contains(searchLower);
        case 'Communication': return (item['sousType'] ?? '').toString().toLowerCase().contains(searchLower);
        case 'Activités': return (item['nomActivite'] ?? '').toString().toLowerCase().contains(searchLower) || (item['lieuActivite'] ?? '').toString().toLowerCase().contains(searchLower);
        default: return true;
      }
    }).toList();
  }

  // --- DESIGN MODERNISÉ ---

  Widget _buildTopHeader() {
    final totaux = _calculerTotaux();
    final solde = totaux['Solde'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.only(top: 50, bottom: 25, left: 20, right: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0163D2), Color(0xFF0056B8)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const Text("SOLDE DISPONIBLE", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text("${solde.toStringAsFixed(0)} Ar", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statHeaderItem("Revenus", totalRevenus, Colors.greenAccent),
              Container(width: 1, height: 30, color: Colors.white24),
              _statHeaderItem("Dépenses", totaux['General']!, Colors.orangeAccent),
            ],
          )
        ],
      ),
    );
  }

  Widget _statHeaderItem(String label, double val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text("${val.toStringAsFixed(0)} Ar", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildModernNavBar() {
    final sections = ['Déplacement', 'Achat', 'Communication', 'Activités'];
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 15),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: sections.map((s) {
          bool active = sectionActive == s;
          return GestureDetector(
            onTap: () => setState(() => sectionActive = s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF0163D2) : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: active ? Colors.transparent : Colors.grey.shade200),
              ),
              child: Center(
                child: Text(s, style: TextStyle(color: active ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDepenseItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.arrow_upward, color: Colors.red, size: 20),
        ),
        title: Text(
          sectionActive == 'Déplacement' ? "Vers ${item['lieu']}" :
          sectionActive == 'Achat' ? "${item['nomProduit']}" :
          sectionActive == 'Communication' ? "${item['sousType']}" : "${item['nomActivite']}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(item['date'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("-${item['montant']} Ar", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
            if (canEdit) Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(onTap: () => _openModal(item: item), child: const Icon(Icons.edit, size: 18, color: Colors.blue)),
              const SizedBox(width: 10),
              GestureDetector(onTap: () => _handleDelete(item['id']), child: const Icon(Icons.delete_outline, size: 18, color: Colors.red)),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDepenses;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Column(
        children: [
          _buildTopHeader(),
          _buildModernNavBar(),
          Expanded(
            child: filtered.isEmpty 
              ? Center(child: Text("Aucune dépense en $sectionActive"))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _buildDepenseItem(filtered[i]),
                ),
          ),
        ],
      ),
      floatingActionButton: canEdit ? FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0163D2),
        onPressed: () => _openModal(),
        label: const Text("Ajouter"),
        icon: const Icon(Icons.add),
      ) : null,
    );
  }

  // 🔥 FONCTIONS MANQUANTES - À AJOUTER

  void _resetForm() {
    setState(() {
      dateDepense = '';
      montantDepense = '';
      lieuDeplacement = '';
      nombreParticipants = '';
      nomProduit = '';
      membreAcheteur = '';
      typeCommunication = 'Crédit téléphone';
      nomActivite = '';
      dateDebutActivite = '';
      dateFinActivite = '';
      lieuActivite = '';
      editItem = null;
    });
  }

  void _openModal({Map<String, dynamic>? item}) {
    if (item != null) {
      // Mode édition
      setState(() {
        editItem = item;
        typeDepense = item['type'] ?? sectionActive;
        dateDepense = item['date'] ?? '';
        montantDepense = (item['montant'] ?? '').toString();
        
        if (typeDepense == 'Déplacement') {
          lieuDeplacement = item['lieu'] ?? '';
          nombreParticipants = (item['nombreParticipants'] ?? '').toString();
        } else if (typeDepense == 'Achat') {
          nomProduit = item['nomProduit'] ?? '';
          membreAcheteur = item['membreAcheteur'] ?? '';
        } else if (typeDepense == 'Communication') {
          typeCommunication = item['sousType'] ?? 'Crédit téléphone';
        } else if (typeDepense == 'Activités') {
          nomActivite = item['nomActivite'] ?? '';
          dateDebutActivite = item['dateDebut'] ?? '';
          dateFinActivite = item['dateFin'] ?? '';
          lieuActivite = item['lieuActivite'] ?? '';
        }
      });
    } else {
      // Mode ajout
      _resetForm();
      setState(() => typeDepense = sectionActive);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildModalContent(),
    );
  }

  Widget _buildModalContent() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0163D2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  editItem == null ? "Nouvelle dépense" : "Modifier dépense",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Formulaire
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildTextField("Date", dateDepense, (val) => setState(() => dateDepense = val), isDate: true),
                  const SizedBox(height: 15),
                  _buildTextField("Montant (Ar)", montantDepense, (val) => setState(() => montantDepense = val), isNumber: true),
                  const SizedBox(height: 15),
                  
                  // Champs spécifiques selon le type
                  if (typeDepense == 'Déplacement') ...[
                    _buildTextField("Lieu", lieuDeplacement, (val) => setState(() => lieuDeplacement = val)),
                    const SizedBox(height: 15),
                    _buildTextField("Nombre participants", nombreParticipants, (val) => setState(() => nombreParticipants = val), isNumber: true),
                  ],
                  
                  if (typeDepense == 'Achat') ...[
                    _buildTextField("Nom du produit", nomProduit, (val) => setState(() => nomProduit = val)),
                    const SizedBox(height: 15),
                    _buildMembreDropdown(),
                  ],
                  
                  if (typeDepense == 'Communication') ...[
                    _buildCommunicationDropdown(),
                  ],
                  
                  if (typeDepense == 'Activités') ...[
                    _buildTextField("Nom activité", nomActivite, (val) => setState(() => nomActivite = val)),
                    const SizedBox(height: 15),
                    _buildTextField("Date début", dateDebutActivite, (val) => setState(() => dateDebutActivite = val), isDate: true),
                    const SizedBox(height: 15),
                    _buildTextField("Date fin", dateFinActivite, (val) => setState(() => dateFinActivite = val), isDate: true),
                    const SizedBox(height: 15),
                    _buildTextField("Lieu", lieuActivite, (val) => setState(() => lieuActivite = val)),
                  ],
                  
                  const SizedBox(height: 30),
                  
                  // Bouton submit
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0163D2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        editItem == null ? "Enregistrer" : "Mettre à jour",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String value, Function(String) onChanged, {bool isDate = false, bool isNumber = false}) {
    return TextField(
      controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
      onChanged: onChanged,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      readOnly: isDate,
      onTap: isDate ? () => _pickDate(onSelected: onChanged, initial: value) : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: isDate ? const Icon(Icons.calendar_today) : null,
      ),
    );
  }

  Widget _buildMembreDropdown() {
    return DropdownButtonFormField<String>(
      value: membreAcheteur.isEmpty ? null : membreAcheteur,
      decoration: InputDecoration(
        labelText: "Membre acheteur",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: membres.map((m) {
        final name = "${m['name']} ${m['prenom'] ?? ''}";
        return DropdownMenuItem(value: name, child: Text(name));
      }).toList(),
      onChanged: (val) => setState(() => membreAcheteur = val ?? ''),
    );
  }

  Widget _buildCommunicationDropdown() {
    return DropdownButtonFormField<String>(
      value: typeCommunication,
      decoration: InputDecoration(
        labelText: "Type communication",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: ['Crédit téléphone', 'Internet', 'Autre'].map((t) {
        return DropdownMenuItem(value: t, child: Text(t));
      }).toList(),
      onChanged: (val) => setState(() => typeCommunication = val ?? 'Crédit téléphone'),
    );
  }

  Future<void> _pickDate({required Function(String) onSelected, String? initial}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onSelected("${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}");
    }
  }

  Future<void> _handleSubmit() async {
    if (dateDepense.isEmpty || montantDepense.isEmpty) {
      _showAlert("Erreur", "Veuillez remplir tous les champs obligatoires");
      return;
    }

    try {
      final montant = double.tryParse(montantDepense) ?? 0;
      
      if (editItem == null) {
        // Ajout
        await _depenseRepo.addDepense(
          type: typeDepense,
          date: dateDepense,
          montant: montant,
          lieu: lieuDeplacement,
          nombreParticipants: int.tryParse(nombreParticipants),
          nomProduit: nomProduit,
          membreAcheteur: membreAcheteur,
          sousType: typeCommunication,
          nomActivite: nomActivite,
          dateDebut: dateDebutActivite,
          dateFin: dateFinActivite,
          lieuActivite: lieuActivite,
        );
        
        // Historique
        await _historiqueRepo.addHistorique(
          typeOperation: 'Dépense',
          operation: 'Ajout',
          details: 'Dépense $typeDepense ajoutée',
          montant: montant,
        );
      } else {
        // Modification
        await _depenseRepo.updateDepense(
          id: editItem!['id'],
          type: typeDepense,
          date: dateDepense,
          montant: montant,
          lieu: lieuDeplacement,
          nombreParticipants: int.tryParse(nombreParticipants),
          nomProduit: nomProduit,
          membreAcheteur: membreAcheteur,
          sousType: typeCommunication,
          nomActivite: nomActivite,
          dateDebut: dateDebutActivite,
          dateFin: dateFinActivite,
          lieuActivite: lieuActivite,
        );
      }

      await _loadDepensesFromDB();
      if (mounted) {
        Navigator.pop(context);
        _showAlert("Succès", editItem == null ? "Dépense ajoutée" : "Dépense modifiée");
      }
    } catch (e) {
      _showAlert("Erreur", e.toString());
    }
  }

  Future<void> _handleDelete(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmation"),
        content: const Text("Voulez-vous vraiment supprimer cette dépense ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _depenseRepo.deleteDepense(id);
        await _loadDepensesFromDB();
        _showAlert("Succès", "Dépense supprimée");
      } catch (e) {
        _showAlert("Erreur", e.toString());
      }
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}