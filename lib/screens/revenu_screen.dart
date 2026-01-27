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

  bool get canEdit => widget.canEdit;

  @override
  void initState() {
    super.initState();
    loadRevenus();
    loadMembres();
  }

  Future<void> loadMembres() async {
    try {
      final data = await _userRepo.getAllUsers();
      if (!mounted) return;
      setState(() {
        membres = data;
      });
      debugPrint('✅ Membres chargés: ${membres.length}');
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des membres: $e');
    }
  }

  Future<void> loadRevenus() async {
    try {
      if (!mounted) return;
      setState(() => isLoading = true);

      final data = await _revenuRepo.getAllRevenus();
      final total = await _revenuRepo.getTotalRevenus();

      if (!mounted) return;
      setState(() {
        revenus = data;
        totalRevenus = total;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint('Erreur lors du chargement des revenus: $e');
      _showAlert('Erreur', 'Impossible de charger les revenus');
    }
  }

  Future<void> _pickDate(StateSetter setModalState) async {
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (result != null) {
      setModalState(() {});
      setState(() {});
    }
  }

  void _openModal({Map<String, dynamic>? item}) {
    if (!canEdit) {
      _showAlert(
        'Accès refusé',
        'Seuls le Trésorier et le Commissaire au compte peuvent ajouter/modifier des revenus.',
      );
      return;
    }

    // Variables locales pour le modal
    String dateRevenu = '';
    String montantRevenu = '';
    String typeRevenu = 'Cotisation';
    String typeCotisation = 'Mensuel';
    int? membreId;
    String? membreNom;
    String description = '';

    if (item != null) {
      dateRevenu = item['date'] ?? '';
      montantRevenu = item['montant'].toString();
      typeRevenu = item['type'] ?? 'Cotisation';
      // Essayer d'extraire le type de cotisation du motif
      final motif = item['motif'] ?? '';
      if (motif.contains('Mensuel')) {
        typeCotisation = 'Mensuel';
      } else if (motif.contains('Annuel')) {
        typeCotisation = 'Annuel';
      } else if (motif.contains('Autre')) {
        typeCotisation = 'Autre';
      }
      description = motif;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item != null ? 'Modifier un revenu' : 'Ajouter un revenu',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date
                    InkWell(
                      onTap: () async {
                        final result = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (result != null) {
                          setModalState(() {
                            dateRevenu =
                                '${result.day.toString().padLeft(2, '0')}/${result.month.toString().padLeft(2, '0')}/${result.year}';
                          });
                        }
                      },
                      child: IgnorePointer(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Date *',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          controller: TextEditingController(text: dateRevenu),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Type de revenu
                    DropdownButtonFormField<String>(
                      value: typeRevenu,
                      items: const [
                        DropdownMenuItem(
                          value: 'Cotisation',
                          child: Text('Cotisation'),
                        ),
                        DropdownMenuItem(value: 'Don', child: Text('Don')),
                        DropdownMenuItem(
                          value: 'Subvention',
                          child: Text('Subvention'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            typeRevenu = val;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Type de revenu *',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Type de cotisation (visible uniquement si type = Cotisation)
                    if (typeRevenu == 'Cotisation') ...[
                      DropdownButtonFormField<String>(
                        value: typeCotisation,
                        items: const [
                          DropdownMenuItem(
                            value: 'Mensuel',
                            child: Text('Mensuel'),
                          ),
                          DropdownMenuItem(
                            value: 'Annuel',
                            child: Text('Annuel'),
                          ),
                          DropdownMenuItem(
                            value: 'Autre',
                            child: Text('Autre'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              typeCotisation = val;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Type de cotisation *',
                          prefixIcon: Icon(Icons.calendar_view_month),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Sélection du membre - ✅ CORRECTION ICI
                      DropdownButtonFormField<int>(
                        value: membreId,
                        isExpanded: true, // ✅ AJOUT IMPORTANT
                        decoration: const InputDecoration(
                          labelText: 'Sélectionner un membre *',
                          prefixIcon: Icon(Icons.person),
                        ),
                        hint: Text(
                          membres.isEmpty
                              ? 'Aucun membre disponible'
                              : 'Choisir un membre',
                        ),
                        items: membres.isEmpty
                            ? null
                            : membres.map((membre) {
                                return DropdownMenuItem<int>(
                                  value: membre['id'],
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min, // ✅ AJOUT
                                    children: [
                                      // Photo de profil miniature
                                      if (membre['profileImage'] != null &&
                                          (membre['profileImage'] as String)
                                              .isNotEmpty)
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundImage: FileImage(
                                            File(membre['profileImage']),
                                          ),
                                        )
                                      else
                                        const CircleAvatar(
                                          radius: 12,
                                          child: Icon(Icons.person, size: 12),
                                        ),
                                      const SizedBox(width: 8),
                                      Flexible( // ✅ CHANGÉ de Expanded à Flexible
                                        child: Text(
                                          '${membre['name'] ?? ''} ${membre['prenom'] ?? ''}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        onChanged: membres.isEmpty
                            ? null
                            : (val) {
                                if (val != null) {
                                  setModalState(() {
                                    membreId = val;
                                    final membre = membres.firstWhere(
                                      (m) => m['id'] == val,
                                      orElse: () => {},
                                    );
                                    membreNom =
                                        '${membre['name'] ?? ''} ${membre['prenom'] ?? ''}';
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 12),

                      // Message si aucun membre
                      if (membres.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: Colors.orange[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Aucun membre enregistré. Ajoutez des membres d\'abord.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],

                    // Montant
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Montant en Ariary *',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: montantRevenu,
                      onChanged: (val) => montantRevenu = val,
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Description/Motif',
                        prefixIcon: Icon(Icons.note),
                      ),
                      initialValue: description,
                      maxLines: 2,
                      onChanged: (val) => description = val,
                    ),
                    const SizedBox(height: 20),

                    // Boutons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: const Text('Annuler'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          child: Text(item != null ? 'Modifier' : 'Ajouter'),
                          onPressed: () async {
                            final montant =
                                double.tryParse(
                                  montantRevenu.replaceAll(',', '.'),
                                ) ??
                                0;

                            // Validation
                            if (dateRevenu.isEmpty || montantRevenu.isEmpty) {
                              _showAlert(
                                'Erreur',
                                'Veuillez remplir tous les champs obligatoires',
                              );
                              return;
                            }

                            // Validation spécifique pour les cotisations
                            if (typeRevenu == 'Cotisation' &&
                                membreId == null) {
                              _showAlert(
                                'Erreur',
                                'Veuillez sélectionner un membre pour la cotisation',
                              );
                              return;
                            }

                            try {
                              // Préparer le motif avec les nouvelles infos
                              String motifComplet = description;
                              if (typeRevenu == 'Cotisation') {
                                motifComplet =
                                    'Cotisation $typeCotisation - Membre: $membreNom${description.isNotEmpty ? ' - $description' : ''}';
                              }

                              if (item != null) {
                                await _revenuRepo.updateRevenu(
                                  id: item['id'],
                                  type: typeRevenu,
                                  date: dateRevenu,
                                  montant: montant,
                                  motif: motifComplet,
                                );
                              } else {
                                await _revenuRepo.addRevenu(
                                  type: typeRevenu,
                                  date: dateRevenu,
                                  montant: montant,
                                  motif: motifComplet,
                                );
                              }

                              if (!mounted) return;
                              Navigator.of(context).pop();
                              await loadRevenus();

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    item != null
                                        ? 'Revenu modifié avec succès'
                                        : 'Revenu ajouté avec succès',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              _showAlert(
                                'Erreur',
                                'Une erreur est survenue: $e',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteRevenu(Map<String, dynamic> item) async {
    if (!canEdit) {
      _showAlert(
        'Accès refusé',
        'Seuls le Trésorier et le Commissaire au compte peuvent supprimer des revenus.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce revenu ?'),
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
      await _revenuRepo.deleteRevenu(item['id']);

      if (!mounted) return;
      await loadRevenus();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revenu supprimé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showAlert('Erreur', 'Impossible de supprimer le revenu: $e');
    }
  }

  Widget _buildRevenuItem(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(Icons.attach_money, color: Colors.green.shade700),
        ),
        title: Text(
          '${item['type']} - ${item['montant']} Ar',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Date: ${item['date']}\n${item['motif'] ?? 'Aucune description'}',
        ),
        isThreeLine: true,
        trailing: canEdit
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openModal(item: item);
                  } else if (value == 'delete') {
                    _deleteRevenu(item);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Modifier'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Future<void> _showAlert(String title, String message) async {
    if (!mounted) return;

    return showDialog<void>(
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

  Widget _buildProfileAvatar() {
    final profileImagePath = widget.profileImage;

    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: FileImage(File(profileImagePath)),
        backgroundColor: Colors.transparent,
      );
    } else {
      return const CircleAvatar(
        radius: 24,
        backgroundColor: Color(0xFF0163D2),
        child: Icon(Icons.person, color: Colors.white, size: 28),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.userName ?? 'Utilisateur';
    final userRole = widget.userRole ?? '';

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              color: Colors.blue.shade50,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildProfileAvatar(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            userRole,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canEdit)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Droits d\'édition',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Lecture seule',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.green,
                  size: 32,
                ),
                title: const Text(
                  'Total Revenus',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  '${totalRevenus.toStringAsFixed(0)} Ar',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            if (canEdit) const SizedBox(height: 8),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : revenus.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.attach_money,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucun revenu enregistré',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: revenus.length,
                          itemBuilder: (context, index) =>
                              _buildRevenuItem(revenus[index]),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF0163D2),
              child: const Icon(Icons.add),
              onPressed: () => _openModal(),
            )
          : null,
    );
  }
}