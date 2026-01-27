import 'package:flutter/material.dart';
import '../database/historique_repository.dart';

class HistoriqueScreen extends StatefulWidget {
  const HistoriqueScreen({Key? key}) : super(key: key);

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  final _historiqueRepo = HistoriqueRepository();
  
  List<Map<String, dynamic>> historique = [];
  bool isLoading = false;
  String filterType = 'tous'; // tous, revenu, dépense

  @override
  void initState() {
    super.initState();
    loadHistorique();
  }

  Future<void> loadHistorique() async {
    try {
      if (!mounted) return;
      setState(() => isLoading = true);

      final data = await _historiqueRepo.getHistorique();

      if (!mounted) return;
      setState(() {
        historique = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint('Erreur lors du chargement de l\'historique: $e');
      _showAlert('Erreur', 'Impossible de charger l\'historique');
    }
  }

  List<Map<String, dynamic>> get _filteredHistorique {
    if (filterType == 'tous') return historique;
    
    return historique.where((item) {
      final type = item['typeOperation']?.toString().toLowerCase() ?? '';
      if (filterType == 'revenu') {
        return type == 'revenu';
      } else if (filterType == 'dépense') {
        return type == 'dépense' || type == 'depense';
      }
      return true;
    }).toList();
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
          )
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilterChip(
            label: const Text('Tous'),
            selected: filterType == 'tous',
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  filterType = 'tous';
                });
              }
            },
            selectedColor: Colors.blue.shade100,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Revenus'),
            selected: filterType == 'revenu',
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  filterType = 'revenu';
                });
              }
            },
            selectedColor: Colors.green.shade100,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Dépenses'),
            selected: filterType == 'dépense',
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  filterType = 'dépense';
                });
              }
            },
            selectedColor: Colors.red.shade100,
          ),
        ],
      ),
    );
  }

  Widget _buildStatistiques() {
    final totalRevenus = historique.where((item) {
      final type = item['typeOperation']?.toString().toLowerCase() ?? '';
      final operation = item['operation']?.toString().toLowerCase() ?? '';
      return type == 'revenu' && operation == 'ajout';
    }).fold<double>(0.0, (sum, item) {
      return sum + ((item['montant'] as num?)?.toDouble() ?? 0);
    });

    final totalDepenses = historique.where((item) {
      final type = item['typeOperation']?.toString().toLowerCase() ?? '';
      final operation = item['operation']?.toString().toLowerCase() ?? '';
      return (type == 'dépense' || type == 'depense') && operation == 'ajout';
    }).fold<double>(0.0, (sum, item) {
      return sum + ((item['montant'] as num?)?.toDouble() ?? 0);
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              'Résumé des opérations',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    label: 'Ajouts Revenus',
                    montant: totalRevenus,
                    color: Colors.green,
                    icon: Icons.add_circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    label: 'Ajouts Dépenses',
                    montant: totalDepenses,
                    color: Colors.red,
                    icon: Icons.remove_circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCountCard(
                    label: 'Total opérations',
                    count: historique.length,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required double montant,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${montant.toStringAsFixed(0)} Ar',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountCard({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoriqueItem(Map<String, dynamic> item) {
    final typeOperation = item['typeOperation']?.toString().toLowerCase() ?? 'inconnu';
    final operation = item['operation'] ?? '';
    final montant = (item['montant'] as num?)?.toDouble() ?? 0;
    final details = item['details'] ?? '';
    final dateCreation = item['dateOperation'] ?? '';

    IconData icon;
    Color color;
    String typeLabel;

    if (typeOperation == 'revenu') {
      icon = Icons.arrow_downward;
      color = Colors.green;
      typeLabel = 'Revenu';
    } else {
      icon = Icons.arrow_upward;
      color = Colors.red;
      typeLabel = 'Dépense';
    }

    // Icône selon l'opération
    IconData operationIcon;
    if (operation.toLowerCase() == 'ajout') {
      operationIcon = Icons.add_circle_outline;
    } else if (operation.toLowerCase() == 'modification') {
      operationIcon = Icons.edit;
    } else if (operation.toLowerCase() == 'suppression') {
      operationIcon = Icons.delete;
    } else {
      operationIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  operationIcon,
                  size: 14,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          '$typeLabel - ${operation.toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Date: $dateCreation',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${montant.toStringAsFixed(0)} Ar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Historique'),
      //   backgroundColor: const Color(0xFF0163D2),
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.refresh),
      //       onPressed: loadHistorique,
      //       tooltip: 'Actualiser',
      //     ),
      //   ],
      // ),
      body: RefreshIndicator(
        onRefresh: loadHistorique,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildStatistiques(),
              _buildFilterChips(),
              const SizedBox(height: 8),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredHistorique.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  filterType == 'tous'
                                      ? 'Aucun historique pour le moment'
                                      : 'Aucun ${filterType} dans l\'historique',
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Les opérations apparaîtront ici',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredHistorique.length,
                            itemBuilder: (context, index) =>
                                _buildHistoriqueItem(_filteredHistorique[index]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}