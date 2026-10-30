import 'package:flutter/material.dart';
import '../database/firebase_historique_repository.dart';

class HistoriqueScreen extends StatefulWidget {
  const HistoriqueScreen({Key? key}) : super(key: key);

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  final FirebaseHistoriqueRepository _historiqueRepo = FirebaseHistoriqueRepository();
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

  Widget _buildHeaderStats(bool isSmallScreen) {
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
      padding: EdgeInsets.only(
        top: isSmallScreen ? 35 : 40,
        bottom: isSmallScreen ? 20 : 25,
        left: isSmallScreen ? 16 : 20,
        right: isSmallScreen ? 16 : 20,
      ),
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
          Text(
            "MON RÉSUMÉ",
            style: TextStyle(
              color: Colors.white70,
              fontSize: isSmallScreen ? 11 : 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: isSmallScreen ? 12 : 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                "Revenus",
                totalRevenus,
                Icons.add_circle_outline,
                Colors.greenAccent,
                isSmallScreen,
              ),
              Container(
                width: 1,
                height: isSmallScreen ? 40 : 45,
                color: Colors.white24,
              ),
              _buildStatItem(
                "Dépenses",
                totalDepenses,
                Icons.remove_circle_outline,
                Colors.orangeAccent,
                isSmallScreen,
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
    bool isSmallScreen,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: isSmallScreen ? 16 : 18),
            SizedBox(width: isSmallScreen ? 5 : 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 13 : 15,
              ),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 6 : 8),
        Text(
          "${amount.toStringAsFixed(0)} Ar",
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 18 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
        vertical: isSmallScreen ? 12 : 15,
      ),
      padding: EdgeInsets.all(isSmallScreen ? 4 : 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _buildFilterButton("Tous", "tous", isSmallScreen),
          _buildFilterButton("Revenus", "revenu", isSmallScreen),
          _buildFilterButton("Dépenses", "dépense", isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String type, bool isSmallScreen) {
    bool isSelected = filterType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => filterType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 10),
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
                fontSize: isSmallScreen ? 13 : 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    Map<String, dynamic> item,
    bool isSmallScreen,
  ) {
    final type = item['typeOperation']?.toString().toLowerCase() ?? 'inconnu';
    final isRevenu = type == 'revenu';
    final color = isRevenu ? Colors.green.shade600 : Colors.red.shade600;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
        vertical: isSmallScreen ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 15,
          vertical: isSmallScreen ? 6 : 8,
        ),
        leading: Container(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isRevenu ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: isSmallScreen ? 18 : 20,
          ),
        ),
        title: Text(
          item['details'] ?? 'Opération sans nom',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 13 : 15,
            color: const Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          item['dateOperation'] ?? '',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: isSmallScreen ? 10 : 12,
          ),
        ),
        trailing: Text(
          "${isRevenu ? '+' : '-'} ${item['montant']} Ar",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 13 : 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Column(
        children: [
          _buildHeaderStats(isSmallScreen),
          _buildFilterBar(isSmallScreen),
          
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 20 : 25,
              vertical: isSmallScreen ? 4 : 5,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Historique",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 19,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 10,
                    vertical: isSmallScreen ? 3 : 4,
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
                      fontSize: isSmallScreen ? 11 : 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 10),
          
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredHistorique.isEmpty
                    ? _buildEmptyState(isSmallScreen)
                    : RefreshIndicator(
                        onRefresh: loadHistorique,
                        child: ListView.builder(
                          padding: EdgeInsets.only(
                            top: 0,
                            bottom: isSmallScreen ? 16 : 20,
                          ),
                          itemCount: _filteredHistorique.length,
                          itemBuilder: (context, index) =>
                              _buildTransactionItem(
                            _filteredHistorique[index],
                            isSmallScreen,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isSmallScreen) {
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
              size: isSmallScreen ? 60 : 70,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: isSmallScreen ? 12 : 15),
            Text(
              "Aucune donnée disponible",
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: isSmallScreen ? 14 : 16,
              ),
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