import 'package:flutter/material.dart';

// Repositories
import '../database/depense_repository.dart';
import '../database/revenu_repository.dart';
import '../database/user_repository.dart';
import '../database/historique_repository.dart';

class DepenseScreen extends StatefulWidget {
  final bool canEdit; // ✅ contrôle des droits
  final String? userName; // Nom de l'utilisateur
  final String? userRole; // Rôle de l'utilisateur
  final String? profileImage; // Image de profil de l'utilisateur

  const DepenseScreen({
    Key? key,
    required this.canEdit, // Maintenant obligatoire
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

  // Pour édition
  Map<String, dynamic>? editItem;

  // Dépenses organisées par type
  Map<String, List<Map<String, dynamic>>> depenses = {
    'Déplacement': [],
    'Achat': [],
    'Communication': [],
    'Activités': [],
  };

  // Utiliser le canEdit passé en paramètre
  bool get canEdit => widget.canEdit;

  @override
  void initState() {
    super.initState();
    _initDepenses();
  }

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
    try {
      final users = await _userRepo.getAllMembers();
      setState(() {
        membres = users;
      });
    } catch (e) {
      debugPrint("Erreur chargement membres: $e");
    }
  }

  Future<void> _loadTotalRevenus() async {
    try {
      final total = await _revenuRepo.getTotalRevenus();
      setState(() {
        totalRevenus = total;
      });
    } catch (e) {
      debugPrint("Erreur chargement total revenus: $e");
      setState(() {
        totalRevenus = 0;
      });
    }
  }

  Future<void> _loadDepensesFromDB() async {
    try {
      final all = await _depenseRepo.getAllDepenses();

      final Map<String, List<Map<String, dynamic>>> mapTemp = {
        'Déplacement': [],
        'Achat': [],
        'Communication': [],
        'Activités': [],
      };

      for (final d in all) {
        final type = d['type'] as String? ?? '';
        if (mapTemp.containsKey(type)) {
          mapTemp[type]!.add(d);
        }
      }

      setState(() {
        depenses = mapTemp;
      });
    } catch (e) {
      debugPrint("Erreur chargement dépenses: $e");
    }
  }

  Map<String, double> _calculerTotaux() {
    double totalDeplacement = depenses['Déplacement']!.fold(
      0.0,
      (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0),
    );
    double totalAchat = depenses['Achat']!.fold(
      0.0,
      (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0),
    );
    double totalCommunication = depenses['Communication']!.fold(
      0.0,
      (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0),
    );
    double totalActivites = depenses['Activités']!.fold(
      0.0,
      (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0),
    );

    double totalGeneral =
        totalDeplacement + totalAchat + totalCommunication + totalActivites;
    double soldeRestant = totalRevenus - totalGeneral;

    return {
      'Déplacement': totalDeplacement,
      'Achat': totalAchat,
      'Communication': totalCommunication,
      'Activités': totalActivites,
      'General': totalGeneral,
      'Solde': soldeRestant,
    };
  }

  Map<String, dynamic> _peutEffectuerDepense(
    double montant,
    Map<String, double> totaux,
  ) {
    if (totalRevenus == 0) {
      return {
        'possible': false,
        'message':
            'Vous ne pouvez pas effectuer cette dépense car votre compte est vide',
      };
    }
    if (montant > (totaux['Solde'] ?? 0)) {
      return {
        'possible': false,
        'message':
            'Solde insuffisant. Montant disponible: ${(totaux['Solde'] ?? 0).toStringAsFixed(0)} Ar',
      };
    }
    return {'possible': true, 'message': ''};
  }

  List<Map<String, dynamic>> get _filteredDepenses {
    final list = depenses[sectionActive] ?? [];
    if (searchQuery.isEmpty) return list;
    final searchLower = searchQuery.toLowerCase();
    return list.where((item) {
      switch (sectionActive) {
        case 'Déplacement':
          return (item['lieu'] ?? '').toString().toLowerCase().contains(
            searchLower,
          );
        case 'Achat':
          return (item['nomProduit'] ?? '').toString().toLowerCase().contains(
            searchLower,
          );
        case 'Communication':
          return (item['sousType'] ?? '').toString().toLowerCase().contains(
            searchLower,
          );
        case 'Activités':
          return (item['nomActivite'] ?? '').toString().toLowerCase().contains(
                searchLower,
              ) ||
              (item['lieuActivite'] ?? '').toString().toLowerCase().contains(
                searchLower,
              );
        default:
          return true;
      }
    }).toList();
  }

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
      typeDepense = sectionActive;
    });
  }

  void _openModal({Map<String, dynamic>? item}) {
    if (!canEdit) {
      _showAlert(
        'Accès refusé',
        'Seuls le Trésorier et le Commissaire au compte peuvent modifier les dépenses.',
      );
      return;
    }

    if (item != null) {
      setState(() {
        editItem = item;
        typeDepense = item['type'] ?? 'Déplacement';
        dateDepense = item['date'] ?? '';
        montantDepense = (item['montant']?.toString() ?? '');

        if (typeDepense == 'Déplacement') {
          lieuDeplacement = item['lieu'] ?? '';
          nombreParticipants = (item['nombreParticipants']?.toString() ?? '');
        } else if (typeDepense == 'Achat') {
          nomProduit = item['nomProduit'] ?? '';
          membreAcheteur = (item['membreAcheteurId']?.toString() ?? '');
        } else if (typeDepense == 'Communication') {
          typeCommunication = item['typeCommunication'] ?? 'Crédit téléphone';
        } else if (typeDepense == 'Activités') {
          nomActivite = item['nomActivite'] ?? '';
          dateDebutActivite = item['dateDebut'] ?? '';
          dateFinActivite = item['dateFin'] ?? '';
          lieuActivite = item['lieuActivite'] ?? '';
        }
      });
    } else {
      _resetForm();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: _buildModalContent(),
      ),
    );
  }

  Future<void> _pickDate({
    required Function(String) onSelected,
    String? initial,
  }) async {
    DateTime now = DateTime.now();
    DateTime initialDate = now;
    if (initial != null && initial.isNotEmpty) {
      try {
        final parts = initial.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          initialDate = DateTime(year, month, day);
        }
      } catch (_) {}
    }

    final result = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (result != null) {
      final formatted =
          '${result.day.toString().padLeft(2, '0')}/${result.month.toString().padLeft(2, '0')}/${result.year}';
      onSelected(formatted);
    }
  }

  Future<void> _handleSubmit() async {
    if (!canEdit) {
      _showAlert(
        'Accès refusé',
        'Seuls le Trésorier et le Commissaire au compte peuvent modifier les dépenses.',
      );
      return;
    }

    try {
      final totaux = _calculerTotaux();
      final montant = double.tryParse(montantDepense.replaceAll(',', '.')) ?? 0;
      final verification = _peutEffectuerDepense(montant, totaux);
      if (verification['possible'] == false) {
        _showAlert('Erreur', verification['message']);
        return;
      }

      if (dateDepense.isEmpty || montantDepense.isEmpty) {
        _showAlert(
          'Erreur',
          'Veuillez remplir les champs obligatoires (date et montant)',
        );
        return;
      }

      Map<String, dynamic> nouvelleDepense = {};
      final bool isEdit = editItem != null;
      String operation = isEdit ? 'modification' : 'ajout';
      String details = '';

      if (typeDepense == 'Déplacement') {
        if (lieuDeplacement.isEmpty || nombreParticipants.isEmpty) {
          _showAlert(
            'Erreur',
            'Veuillez remplir tous les champs pour le déplacement',
          );
          return;
        }
        final nbPart = int.tryParse(nombreParticipants) ?? 0;
        if (nbPart <= 0) {
          _showAlert(
            'Erreur',
            'Le nombre de participants doit être supérieur à 0.',
          );
          return;
        }

        if (isEdit) {
          await _depenseRepo.updateDepense(
            id: editItem!['id'] as int,
            type: 'Déplacement',
            date: dateDepense,
            montant: montant,
            lieu: lieuDeplacement,
            nombreParticipants: nbPart,
            sousType: 'Déplacement',
          );
          nouvelleDepense = {
            ...editItem!,
            'type': 'Déplacement',
            'date': dateDepense,
            'montant': montant,
            'lieu': lieuDeplacement,
            'nombreParticipants': nbPart,
            'sousType': 'Déplacement',
          };
        } else {
          final id = await _depenseRepo.addDepense(
            type: 'Déplacement',
            date: dateDepense,
            montant: montant,
            lieu: lieuDeplacement,
            nombreParticipants: nbPart,
            sousType: 'Déplacement',
          );
          nouvelleDepense = {
            'id': id,
            'type': 'Déplacement',
            'date': dateDepense,
            'montant': montant,
            'lieu': lieuDeplacement,
            'nombreParticipants': nbPart,
            'sousType': 'Déplacement',
          };
        }

        details =
            'Déplacement à $lieuDeplacement - $nombreParticipants participants';
      } else if (typeDepense == 'Achat') {
        if (nomProduit.isEmpty || membreAcheteur.isEmpty) {
          _showAlert(
            'Erreur',
            'Veuillez remplir tous les champs pour l\'achat',
          );
          return;
        }

        final membre = membres.firstWhere(
          (m) => m['id'].toString() == membreAcheteur,
          orElse: () => {},
        );
        final membreNom = '${membre['name'] ?? ''} ${membre['prenom'] ?? ''}'
            .trim();

        if (isEdit) {
          await _depenseRepo.updateDepense(
            id: editItem!['id'] as int,
            type: 'Achat',
            date: dateDepense,
            montant: montant,
            nomProduit: nomProduit,
            membreAcheteurId: int.tryParse(membreAcheteur),
            membreAcheteur: membreNom,
            sousType: 'Achat',
          );
          nouvelleDepense = {
            ...editItem!,
            'type': 'Achat',
            'date': dateDepense,
            'montant': montant,
            'nomProduit': nomProduit,
            'membreAcheteur': membreNom,
            'membreAcheteurId': int.tryParse(membreAcheteur),
            'sousType': 'Achat',
          };
        } else {
          final id = await _depenseRepo.addDepense(
            type: 'Achat',
            date: dateDepense,
            montant: montant,
            nomProduit: nomProduit,
            membreAcheteurId: int.tryParse(membreAcheteur),
            membreAcheteur: membreNom,
            sousType: 'Achat',
          );
          nouvelleDepense = {
            'id': id,
            'type': 'Achat',
            'date': dateDepense,
            'montant': montant,
            'nomProduit': nomProduit,
            'membreAcheteur': membreNom,
            'membreAcheteurId': int.tryParse(membreAcheteur),
            'sousType': 'Achat',
          };
        }

        details = 'Achat: $nomProduit - Acheté par: $membreNom';
      } else if (typeDepense == 'Communication') {
        if (isEdit) {
          await _depenseRepo.updateDepense(
            id: editItem!['id'] as int,
            type: 'Communication',
            date: dateDepense,
            montant: montant,
            typeCommunication: typeCommunication,
            sousType: typeCommunication,
          );
          nouvelleDepense = {
            ...editItem!,
            'type': 'Communication',
            'date': dateDepense,
            'montant': montant,
            'typeCommunication': typeCommunication,
            'sousType': typeCommunication,
          };
        } else {
          final id = await _depenseRepo.addDepense(
            type: 'Communication',
            date: dateDepense,
            montant: montant,
            typeCommunication: typeCommunication,
            sousType: typeCommunication,
          );
          nouvelleDepense = {
            'id': id,
            'type': 'Communication',
            'date': dateDepense,
            'montant': montant,
            'typeCommunication': typeCommunication,
            'sousType': typeCommunication,
          };
        }

        details = 'Communication: $typeCommunication';
      } else if (typeDepense == 'Activités') {
        if (nomActivite.isEmpty ||
            dateDebutActivite.isEmpty ||
            dateFinActivite.isEmpty ||
            lieuActivite.isEmpty) {
          _showAlert(
            'Erreur',
            'Veuillez remplir tous les champs pour l\'activité',
          );
          return;
        }

        if (isEdit) {
          await _depenseRepo.updateDepense(
            id: editItem!['id'] as int,
            type: 'Activités',
            date: dateDepense,
            montant: montant,
            nomActivite: nomActivite,
            dateDebut: dateDebutActivite,
            dateFin: dateFinActivite,
            lieuActivite: lieuActivite,
            sousType: 'Activité',
          );
          nouvelleDepense = {
            ...editItem!,
            'type': 'Activités',
            'date': dateDepense,
            'montant': montant,
            'nomActivite': nomActivite,
            'dateDebut': dateDebutActivite,
            'dateFin': dateFinActivite,
            'lieuActivite': lieuActivite,
            'sousType': 'Activité',
          };
        } else {
          final id = await _depenseRepo.addDepense(
            type: 'Activités',
            date: dateDepense,
            montant: montant,
            nomActivite: nomActivite,
            dateDebut: dateDebutActivite,
            dateFin: dateFinActivite,
            lieuActivite: lieuActivite,
            sousType: 'Activité',
          );
          nouvelleDepense = {
            'id': id,
            'type': 'Activités',
            'date': dateDepense,
            'montant': montant,
            'nomActivite': nomActivite,
            'dateDebut': dateDebutActivite,
            'dateFin': dateFinActivite,
            'lieuActivite': lieuActivite,
            'sousType': 'Activité',
          };
        }

        details = 'Activité: $nomActivite - Lieu: $lieuActivite';
      }

      // ✅ Historique avec dateOperation et createdAt
      await _historiqueRepo.addHistorique(
        typeOperation: 'dépense',
        operation: operation,
        details: details,
        montant: montant,
        typeElement: 'depense',
        elementId: (nouvelleDepense['id'] as int?),
      );

      setState(() {
        depenses[typeDepense] = depenses[typeDepense]!
            .where((item) => isEdit ? item['id'] != editItem!['id'] : true)
            .toList();
        depenses[typeDepense] = [...depenses[typeDepense]!, nouvelleDepense];
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      _resetForm();
      await _loadTotalRevenus();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Dépense modifiée avec succès'
                : 'Dépense ajoutée avec succès',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showAlert('Erreur', 'Une erreur est survenue lors de la sauvegarde: $e');
    }
  }

  Future<void> _handleDelete(dynamic id) async {
    if (!canEdit) {
      _showAlert(
        'Accès refusé',
        'Seuls le Trésorier et le Commissaire au compte peuvent supprimer des dépenses.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette dépense ?',
        ),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      final depenseASupprimer = depenses[sectionActive]!.firstWhere(
        (item) => item['id'] == id,
      );

      await _depenseRepo.deleteDepense(id as int);

      await _historiqueRepo.addHistorique(
        typeOperation: 'dépense',
        operation: 'suppression',
        details:
            'Suppression dépense ${depenseASupprimer['type']} du ${depenseASupprimer['date']}',
        montant: (depenseASupprimer['montant'] as num?)?.toDouble() ?? 0,
        typeElement: 'depense',
        elementId: id as int?,
      );

      setState(() {
        depenses[sectionActive] = depenses[sectionActive]!
            .where((item) => item['id'] != id)
            .toList();
      });

      await _loadTotalRevenus();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dépense supprimée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showAlert('Erreur', 'Impossible de supprimer la dépense: $e');
    }
  }

  void _showAlert(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
    final totaux = _calculerTotaux();
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              'État des Finances',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTotalItem(
                  label: 'Total Revenus',
                  montant: '${totalRevenus.toStringAsFixed(0)} Ar',
                  positif: true,
                ),
                _buildTotalItem(
                  label: 'Total Dépenses',
                  montant: '${(totaux['General'] ?? 0).toStringAsFixed(0)} Ar',
                  positif: false,
                ),
                _buildSoldeItem(
                  solde: '${(totaux['Solde'] ?? 0).toStringAsFixed(0)} Ar',
                  positif: (totaux['Solde'] ?? 0) >= 0,
                ),
              ],
            ),
            const Divider(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Détail des Dépenses:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            _buildDetailLine(
              'Déplacements:',
              '${(totaux['Déplacement'] ?? 0).toStringAsFixed(0)} Ar',
            ),
            _buildDetailLine(
              'Achats:',
              '${(totaux['Achat'] ?? 0).toStringAsFixed(0)} Ar',
            ),
            _buildDetailLine(
              'Communication:',
              '${(totaux['Communication'] ?? 0).toStringAsFixed(0)} Ar',
            ),
            _buildDetailLine(
              'Activités:',
              '${(totaux['Activités'] ?? 0).toStringAsFixed(0)} Ar',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalItem({
    required String label,
    required String montant,
    required bool positif,
  }) {
    return Container(
      width: (MediaQuery.of(context).size.width - 64) / 2,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            montant,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: positif ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoldeItem({required String solde, required bool positif}) {
    return Container(
      width: MediaQuery.of(context).size.width - 48,
      decoration: BoxDecoration(
        color: positif ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          const Text(
            'Solde Disponible',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            solde,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: positif ? Colors.green : Colors.red,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailLine(String label, String montant) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          montant,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildNavBar() {
    final sections = ['Déplacement', 'Achat', 'Communication', 'Activités'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: sections.map((section) {
          final active = sectionActive == section;
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  sectionActive = section;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF0163d2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  section,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ✅ FORMULAIRE MODAL COMPLET
  Widget _buildModalContent() {
    final bool isEdit = editItem != null;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isEdit ? 'Modifier une dépense' : 'Ajouter une dépense',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),

          // Sélection du type de dépense
          DropdownButtonFormField<String>(
            value: typeDepense,
            items: const [
              DropdownMenuItem(
                value: 'Déplacement',
                child: Text('Déplacement'),
              ),
              DropdownMenuItem(value: 'Achat', child: Text('Achat')),
              DropdownMenuItem(
                value: 'Communication',
                child: Text('Communication'),
              ),
              DropdownMenuItem(value: 'Activités', child: Text('Activités')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  typeDepense = val;
                });
              }
            },
            decoration: const InputDecoration(
              labelText: 'Type de dépense',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Date
          InkWell(
            onTap: () => _pickDate(
              onSelected: (date) {
                setState(() {
                  dateDepense = date;
                });
              },
              initial: dateDepense,
            ),
            child: IgnorePointer(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  suffixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: dateDepense),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Montant
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Montant en Ariary *',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            initialValue: montantDepense,
            onChanged: (val) {
              setState(() {
                montantDepense = val;
              });
            },
          ),
          const SizedBox(height: 12),

          // Champs spécifiques selon le type
          if (typeDepense == 'Déplacement') ...[
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Lieu du déplacement *',
                border: OutlineInputBorder(),
              ),
              initialValue: lieuDeplacement,
              onChanged: (val) {
                setState(() {
                  lieuDeplacement = val;
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Nombre de participants *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              initialValue: nombreParticipants,
              onChanged: (val) {
                setState(() {
                  nombreParticipants = val;
                });
              },
            ),
          ] else if (typeDepense == 'Achat') ...[
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Nom du produit *',
                border: OutlineInputBorder(),
              ),
              initialValue: nomProduit,
              onChanged: (val) {
                setState(() {
                  nomProduit = val;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: membreAcheteur.isEmpty ? null : membreAcheteur,
              items: membres.map((membre) {
                return DropdownMenuItem<String>(
                  value: membre['id'].toString(),
                  child: Text('${membre['name']} ${membre['prenom'] ?? ''}'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    membreAcheteur = val;
                  });
                }
              },
              decoration: const InputDecoration(
                labelText: 'Membre acheteur *',
                border: OutlineInputBorder(),
              ),
            ),
          ] else if (typeDepense == 'Communication') ...[
            DropdownButtonFormField<String>(
              value: typeCommunication,
              items: const [
                DropdownMenuItem(
                  value: 'Crédit téléphone',
                  child: Text('Crédit téléphone'),
                ),
                DropdownMenuItem(value: 'Internet', child: Text('Internet')),
                DropdownMenuItem(value: 'Autre', child: Text('Autre')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    typeCommunication = val;
                  });
                }
              },
              decoration: const InputDecoration(
                labelText: 'Type de communication',
                border: OutlineInputBorder(),
              ),
            ),
          ] else if (typeDepense == 'Activités') ...[
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Nom de l\'activité *',
                border: OutlineInputBorder(),
              ),
              initialValue: nomActivite,
              onChanged: (val) {
                setState(() {
                  nomActivite = val;
                });
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _pickDate(
                onSelected: (date) {
                  setState(() {
                    dateDebutActivite = date;
                  });
                },
                initial: dateDebutActivite,
              ),
              child: IgnorePointer(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Date début *',
                    suffixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: dateDebutActivite),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _pickDate(
                onSelected: (date) {
                  setState(() {
                    dateFinActivite = date;
                  });
                },
                initial: dateFinActivite,
              ),
              child: IgnorePointer(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Date fin *',
                    suffixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: dateFinActivite),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Lieu de l\'activité *',
                border: OutlineInputBorder(),
              ),
              initialValue: lieuActivite,
              onChanged: (val) {
                setState(() {
                  lieuActivite = val;
                });
              },
            ),
          ],

          const SizedBox(height: 20),

          // Boutons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                child: const Text('Annuler'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetForm();
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0163d2),
                ),
                child: Text(isEdit ? 'Modifier' : 'Ajouter'),
                onPressed: _handleSubmit,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final type = item['type'];
    final montant = (item['montant'] as num?)?.toDouble() ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (type == 'Déplacement') ...[
                    Text(
                      'Déplacement à ${item['lieu'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${montant.toStringAsFixed(0)} Ar',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text('Date: ${item['date'] ?? ''}'),
                    Text(
                      'Participants: ${item['nombreParticipants'] ?? 0} personnes',
                    ),
                  ] else if (type == 'Achat') ...[
                    Text(
                      'Achat: ${item['nomProduit'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${montant.toStringAsFixed(0)} Ar',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text('Date: ${item['date'] ?? ''}'),
                    Text('Acheté par: ${item['membreAcheteur'] ?? ''}'),
                  ] else if (type == 'Communication') ...[
                    Text(
                      'Communication: ${item['sousType'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${montant.toStringAsFixed(0)} Ar',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text('Date: ${item['date'] ?? ''}'),
                  ] else if (type == 'Activités') ...[
                    Text(
                      'Activité: ${item['nomActivite'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${montant.toStringAsFixed(0)} Ar',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text('Lieu: ${item['lieuActivite'] ?? ''}'),
                    Text(
                      'Période: ${item['dateDebut'] ?? ''} au ${item['dateFin'] ?? ''}',
                    ),
                    Text('Date paiement: ${item['date'] ?? ''}'),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                if (widget.canEdit)
                  TextButton(
                    child: const Text(
                      'Modifier',
                      style: TextStyle(color: Colors.blue),
                    ),
                    onPressed: () => _openModal(item: item),
                  ),
                if (widget.canEdit)
                  TextButton(
                    child: const Text(
                      'Supprimer',
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () => _handleDelete(item['id']),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildNavBar(),
            _buildTotalSection(),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() {
                  searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                child: Text('Ajouter $sectionActive'),
                onPressed: widget.canEdit ? () => _openModal() : null,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filteredDepenses.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucune dépense trouvée',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadDepensesFromDB();
                        await _loadTotalRevenus();
                      },
                      child: ListView.builder(
                        itemCount: _filteredDepenses.length,
                        itemBuilder: (context, index) =>
                            _buildItem(_filteredDepenses[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
