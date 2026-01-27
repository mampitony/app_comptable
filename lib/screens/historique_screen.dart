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
  String filterType = 'tous';

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
      _showAlert('Erreur', 'Impossible de charger l\'historique');
    }
  }

  List<Map<String, dynamic>> get _filteredHistorique {
    if (filterType == 'tous') return historique;
    return historique.where((item) {
      final type = item['typeOperation']?.toString().toLowerCase() ?? '';
      if (filterType == 'revenu') return type == 'revenu';
      if (filterType == 'dépense')
        return type == 'dépense' || type == 'depense';
      return true;
    }).toList();
  }

  // --- UI COMPONENTS ---

  Widget _buildHeaderStats() {
    final totalRevenus = historique
        .where((item) {
          final type = item['typeOperation']?.toString().toLowerCase() ?? '';
          final operation = item['operation']?.toString().toLowerCase() ?? '';
          return type == 'revenu' && operation == 'ajout';
        })
        .fold<double>(
          0.0,
          (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0),
        );

    final totalDepenses = historique
        .where((item) {
          final type = item['typeOperation']?.toString().toLowerCase() ?? '';
          final operation = item['operation']?.toString().toLowerCase() ?? '';
          return (type == 'dépense' || type == 'depense') &&
              operation == 'ajout';
        })
        .fold<double>(
          0.0,
          (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0),
        );

    return Container(
      padding: const EdgeInsets.only(top: 40, bottom: 25, left: 20, right: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0163D2),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0163D2).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "MON RÉSUMÉ",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                "Revenus",
                totalRevenus,
                Icons.add_circle_outline,
                Colors.greenAccent,
              ),
              Container(width: 1, height: 45, color: Colors.white24),
              _buildStatItem(
                "Dépenses",
                totalDepenses,
                Icons.remove_circle_outline,
                Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "${amount.toStringAsFixed(0)} Ar",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _buildFilterButton("Tous", "tous"),
          _buildFilterButton("Revenus", "revenu"),
          _buildFilterButton("Dépenses", "dépense"),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String type) {
    bool isSelected = filterType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => filterType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF0163D2)
                    : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> item) {
    final type = item['typeOperation']?.toString().toLowerCase() ?? 'inconnu';
    final isRevenu = type == 'revenu';
    final color = isRevenu ? Colors.green.shade600 : Colors.red.shade600;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isRevenu ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          item['details'] ?? 'Opération sans nom',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          item['dateOperation'] ?? '',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        ),
        trailing: Text(
          "${isRevenu ? '+' : '-'} ${item['montant']} Ar",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Column(
        children: [
          _buildHeaderStats(),
          _buildFilterBar(),
          // 🔥 Section "Total Opérations" ajoutée ici
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Historique",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${_filteredHistorique.length} total",
                    style: TextStyle(
                      color: const Color(0xFF0163D2),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredHistorique.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: loadHistorique,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 0, bottom: 20),
                      itemCount: _filteredHistorique.length,
                      itemBuilder: (context, index) =>
                          _buildTransactionItem(_filteredHistorique[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: 300,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 70,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 15),
            Text(
              "Aucune donnée disponible",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAlert(String title, String message) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
