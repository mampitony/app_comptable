import 'package:flutter/material.dart';
import 'dart:io';
import '../database/firebase_revenu_repository.dart';
import '../database/firebase_user_repository.dart';
import '../components/description_montant_fields.dart'; // 🔥 AJOUT : description + montant auto
import '../services/description_calculator.dart';
import '../components/form_style.dart';

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
  final FirebaseRevenuRepository _revenuRepo = FirebaseRevenuRepository();
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();

  List<Map<String, dynamic>> revenus = [];
  List<Map<String, dynamic>> membres = [];
  double totalRevenus = 0;
  bool isLoading = false;

  String searchQuery = '';
  String filtreType = 'Tous';
  String filtreOrdre = 'Récent';
  int? filtreMois;
  int? filtreAnnee;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      if (mounted) setState(() => isLoading = true);
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
      if (mounted) setState(() => isLoading = false);
      _showAlert('Erreur', 'Impossible de charger les données');
    }
  }

  List<Map<String, dynamic>> get _filteredRevenus {
    List<Map<String, dynamic>> result = List.from(revenus);

    if (filtreType != 'Tous') {
      result = result.where((r) => r['type'] == filtreType).toList();
    }

    if (filtreMois != null || filtreAnnee != null) {
      result = result.where((r) {
        final dateStr = r['date']?.toString() ?? '';
        if (dateStr.contains('/')) {
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            final mois = int.tryParse(parts[1]);
            final annee = int.tryParse(parts[2]);
            if (filtreMois != null && mois != filtreMois) return false;
            if (filtreAnnee != null && annee != filtreAnnee) return false;
            return true;
          }
        }
        if (dateStr.contains('-')) {
          final p = dateStr.split('-');
          if (p.length == 3) {
            final annee = int.tryParse(p[0]);
            final mois = int.tryParse(p[1]);
            if (filtreMois != null && mois != filtreMois) return false;
            if (filtreAnnee != null && annee != filtreAnnee) return false;
            return true;
          }
        }
        return true;
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((r) {
        final type = (r['type'] ?? '').toString().toLowerCase();
        final motif = (r['motif'] ?? '').toString().toLowerCase();
        final date = (r['date'] ?? '').toString().toLowerCase();
        final montant = (r['montant'] ?? '').toString().toLowerCase();
        return type.contains(q) || motif.contains(q) || date.contains(q) || montant.contains(q);
      }).toList();
    }

    result.sort((a, b) {
      final dateA = _parseDate(a['date']?.toString() ?? '');
      final dateB = _parseDate(b['date']?.toString() ?? '');
      if (dateA == null || dateB == null) return 0;
      return filtreOrdre == 'Récent'
          ? dateB.compareTo(dateA)
          : dateA.compareTo(dateB);
    });

    return result;
  }

  DateTime? _parseDate(String dateStr) {
    try {
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      }
      if (dateStr.contains('-')) return DateTime.parse(dateStr);
    } catch (_) {}
    return null;
  }

  /// Indique si un filtre actif est en place (hors type = Tous)
  bool get _hasActiveFilter =>
      filtreType != 'Tous' ||
      filtreOrdre != 'Récent' ||
      filtreMois != null ||
      filtreAnnee != null;

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildTopHeader(bool isSmallScreen) {
    final filtered = _filteredRevenus;

    return Container(
      padding: EdgeInsets.only(
        top: isSmallScreen ? 40 : 50,
        bottom: isSmallScreen ? 20 : 25,
        left: isSmallScreen ? 16 : 20,
        right: isSmallScreen ? 16 : 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Text(
            "SOLDE TOTAL ENTRANT",
            style: TextStyle(
              color: Colors.white70,
              fontSize: isSmallScreen ? 10 : 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: isSmallScreen ? 4 : 6),
          Text(
            "${totalRevenus.toStringAsFixed(0)} Ar",
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 28 : 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isSmallScreen ? 15 : 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statHeaderItem(
                "Transactions",
                filtered.length.toDouble(),
                Colors.greenAccent,
                isSmallScreen,
                isCount: true,
              ),
              Container(width: 1, height: isSmallScreen ? 25 : 30, color: Colors.white24),
              _statHeaderItem(
                "Total",
                totalRevenus,
                Colors.lightBlueAccent,
                isSmallScreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statHeaderItem(
    String label,
    double val,
    Color color,
    bool isSmallScreen, {
    bool isCount = false,
  }) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white60, fontSize: isSmallScreen ? 11 : 13)),
        Text(
          isCount ? "${val.toInt()}" : "${val.toStringAsFixed(0)} Ar",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 14 : 17,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BARRE DE RECHERCHE + ICÔNE FILTRE
  // ============================================================
  Widget _buildSearchBar(bool isSmallScreen) {
    return Row(
      children: [
        // Champ de recherche
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => searchQuery = val),
              style: TextStyle(fontSize: isSmallScreen ? 14 : 15),
              decoration: InputDecoration(
                hintText: "Rechercher par type, motif, date...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: isSmallScreen ? 13 : 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0D47A1)),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Bouton filtre avec badge si filtre actif
        GestureDetector(
          onTap: _showFilterBottomSheet,
          child: Container(
            width: isSmallScreen ? 46 : 52,
            height: isSmallScreen ? 46 : 52,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _hasActiveFilter ? const Color(0xFF0D47A1) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: _hasActiveFilter ? Colors.white : const Color(0xFF0D47A1),
                  size: isSmallScreen ? 22 : 24,
                ),
                // Badge rouge si filtre actif
                if (_hasActiveFilter)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTTOM SHEET FILTRE
  // ============================================================
  void _showFilterBottomSheet() {
    // Valeurs temporaires
    String tempType = filtreType;
    String tempOrdre = filtreOrdre;
    int? tempMois = filtreMois;
    int? tempAnnee = filtreAnnee;

    final anneeActuelle = DateTime.now().year;
    final annees = List.generate(10, (i) => anneeActuelle - i);
    const moisNoms = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Titre
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Filtres",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          tempType = 'Tous';
                          tempOrdre = 'Récent';
                          tempMois = null;
                          tempAnnee = null;
                        });
                      },
                      child: const Text(
                        "Réinitialiser",
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // --- Tri ---
                _sectionLabel("Trier par"),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _filterOptionTile(
                      icon: Icons.arrow_downward_rounded,
                      label: "Récent d'abord",
                      selected: tempOrdre == 'Récent',
                      onTap: () => setSheetState(() => tempOrdre = 'Récent'),
                    ),
                    const SizedBox(width: 10),
                    _filterOptionTile(
                      icon: Icons.arrow_upward_rounded,
                      label: "Ancien d'abord",
                      selected: tempOrdre == 'Ancien',
                      onTap: () => setSheetState(() => tempOrdre = 'Ancien'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // --- Type ---
                _sectionLabel("Type de revenu"),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Tous', 'Cotisation', 'Don', 'Subvention', 'Activité', 'Autre']
                      .map((t) => GestureDetector(
                            onTap: () => setSheetState(() => tempType = t),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: tempType == t ? const Color(0xFF0D47A1) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: tempType == t ? const Color(0xFF0D47A1) : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: tempType == t ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),

                // --- Date ---
                _sectionLabel("Filtrer par date"),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Mois
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: tempMois,
                            hint: const Text("Mois", style: TextStyle(fontSize: 13)),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text("Tous les mois")),
                              ...List.generate(12, (i) => DropdownMenuItem<int?>(
                                value: i + 1,
                                child: Text(moisNoms[i], style: const TextStyle(fontSize: 13)),
                              )),
                            ],
                            onChanged: (val) => setSheetState(() => tempMois = val),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Année
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: tempAnnee,
                            hint: const Text("Année", style: TextStyle(fontSize: 13)),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text("Toutes")),
                              ...annees.map((a) => DropdownMenuItem<int?>(
                                value: a,
                                child: Text("$a", style: const TextStyle(fontSize: 13)),
                              )),
                            ],
                            onChanged: (val) => setSheetState(() => tempAnnee = val),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Bouton Appliquer
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      setState(() {
                        filtreType = tempType;
                        filtreOrdre = tempOrdre;
                        filtreMois = tempMois;
                        filtreAnnee = tempAnnee;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      "Appliquer les filtres",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _filterOptionTile({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0D47A1).withOpacity(0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF0D47A1) : Colors.grey.shade200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? const Color(0xFF0D47A1) : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? const Color(0xFF0D47A1) : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RÉSUMÉ DES FILTRES ACTIFS (chips condensés sous la recherche)
  // ============================================================
  Widget _buildActiveFiltersSummary(bool isSmallScreen) {
    final List<Widget> chips = [];

    if (filtreType != 'Tous') {
      chips.add(_activeBadge(filtreType, () => setState(() => filtreType = 'Tous'), isSmallScreen));
    }
    if (filtreOrdre != 'Récent') {
      chips.add(_activeBadge("Ancien d'abord", () => setState(() => filtreOrdre = 'Récent'), isSmallScreen));
    }

    const moisNoms = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    if (filtreMois != null && filtreAnnee != null) {
      chips.add(_activeBadge(
        "${moisNoms[filtreMois! - 1]} $filtreAnnee",
        () => setState(() { filtreMois = null; filtreAnnee = null; }),
        isSmallScreen,
      ));
    } else if (filtreMois != null) {
      chips.add(_activeBadge(
        moisNoms[filtreMois! - 1],
        () => setState(() => filtreMois = null),
        isSmallScreen,
      ));
    } else if (filtreAnnee != null) {
      chips.add(_activeBadge(
        "$filtreAnnee",
        () => setState(() => filtreAnnee = null),
        isSmallScreen,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      ),
    );
  }

  Widget _activeBadge(String label, VoidCallback onRemove, bool isSmallScreen) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 10 : 12,
        vertical: isSmallScreen ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 13, color: Color(0xFF0D47A1)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD REVENU
  // ============================================================
  Widget _buildRevenuCard(Map<String, dynamic> item, bool isSmallScreen) {
    bool isCotisation = item['type'] == 'Cotisation';
    bool isActivite = item['type'] == 'Activité';
    bool isAutre = item['type'] == 'Autre';

    IconData iconData;
    Color iconColor;
    Color bgColor;

    if (isCotisation) {
      iconData = Icons.people_alt;
      iconColor = Colors.blue;
      bgColor = Colors.blue.shade50;
    } else if (isActivite) {
      iconData = Icons.event;
      iconColor = Colors.orange;
      bgColor = Colors.orange.shade50;
    } else if (isAutre) {
      iconData = Icons.category;
      iconColor = Colors.purple;
      bgColor = Colors.purple.shade50;
    } else {
      iconData = Icons.volunteer_activism;
      iconColor = Colors.green;
      bgColor = Colors.green.shade50;
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
        vertical: isSmallScreen ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(isSmallScreen ? 10 : 12),
        leading: CircleAvatar(
          backgroundColor: bgColor,
          child: Icon(iconData, color: iconColor, size: isSmallScreen ? 20 : 22),
        ),
        title: Text(
          item['type'] ?? '',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 13 : 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "${item['date']}\n${item['motif'] ?? ''}",
            style: TextStyle(color: Colors.grey.shade600, fontSize: isSmallScreen ? 11 : 13),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "+ ${item['montant']} Ar",
              style: TextStyle(
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 13 : 16,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showDetailDialog(item),
                  child: Icon(Icons.info_outline, color: Colors.grey, size: isSmallScreen ? 18 : 20),
                ),
                if (widget.canEdit) ...[
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  GestureDetector(
                    onTap: () => _openModal(item: item),
                    child: Icon(Icons.edit_note, color: Colors.blue, size: isSmallScreen ? 18 : 20),
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  GestureDetector(
                    onTap: () => _deleteRevenu(item),
                    child: Icon(Icons.delete_sweep, color: Colors.redAccent, size: isSmallScreen ? 18 : 20),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TABLEAU COMPACT DES REVENUS
  // ============================================================
  // Format : 1960100.0 -> "1 960 100" (purement visuel)
  String _fmtMontant(dynamic v) {
    final n = num.tryParse(v?.toString() ?? '');
    if (n == null) return v?.toString() ?? '0';
    final isInt = n == n.roundToDouble();
    final raw = isInt ? n.round().toString() : n.toStringAsFixed(2);
    final parts = raw.split('.');
    final grouped = parts[0]
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
    return parts.length > 1 ? '$grouped,${parts[1]}' : grouped;
  }

  _RevenuTypeStyle _typeStyle(String type) {
    switch (type) {
      case 'Cotisation':
        return _RevenuTypeStyle(Icons.people_alt, Colors.blue, Colors.blue.shade50);
      case 'Activité':
        return _RevenuTypeStyle(Icons.event, Colors.orange, Colors.orange.shade50);
      case 'Autre':
        return _RevenuTypeStyle(Icons.category, Colors.purple, Colors.purple.shade50);
      case 'Subvention':
        return _RevenuTypeStyle(Icons.account_balance, Colors.teal, Colors.teal.shade50);
      default: // Don
        return _RevenuTypeStyle(Icons.volunteer_activism, Colors.green, Colors.green.shade50);
    }
  }

  Widget _buildRevenuTable(List<Map<String, dynamic>> items, bool isSmallScreen) {
    final dateW = isSmallScreen ? 68.0 : 92.0;
    const montantW = 104.0;

    Widget headCell(String t, {TextAlign align = TextAlign.left}) => Text(
          t,
          textAlign: align,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Colors.blueGrey.shade400,
          ),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // En-tête du tableau
            Container(
              color: const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(width: dateW, child: headCell('DATE')),
                  Expanded(child: headCell('TYPE')),
                  SizedBox(width: montantW, child: headCell('MONTANT', align: TextAlign.right)),
                  const SizedBox(width: 30),
                ],
              ),
            ),
            for (int i = 0; i < items.length; i++)
              _buildRevenuRow(items[i], dateW, montantW, last: i == items.length - 1),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenuRow(
    Map<String, dynamic> item,
    double dateW,
    double montantW, {
    required bool last,
  }) {
    final type = item['type']?.toString() ?? '';
    final st = _typeStyle(type);

    return InkWell(
      onTap: () => _showDetailDialog(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: dateW,
              child: Text(
                item['date']?.toString() ?? '',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: st.bg,
                    child: Icon(st.icon, color: st.color, size: 15),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: montantW,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '+${_fmtMontant(item['montant'])} Ar',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const SizedBox(
              width: 24,
              child: Icon(Icons.info_outline, color: Color(0xFF0163D2), size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOG DÉTAIL
  // ============================================================
  void _showDetailDialog(Map<String, dynamic> item) {
    final type = item['type'] ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF0D47A1)),
            const SizedBox(width: 8),
            Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow("Date", item['date']?.toString() ?? '-'),
              _buildDetailRow("Montant", "${_fmtMontant(item['montant'])} Ar"),
              if ((item['motif'] ?? '').toString().isNotEmpty)
                _buildDetailRow("Motif", item['motif'].toString()),
              // 🔥 AJOUT : description complète (une ligne par élément)
              if ((item['description'] ?? '').toString().trim().isNotEmpty)
                _buildDetailRow("Description", item['description'].toString()),
              if (type == 'Activité') ...[
                if ((item['nomActivite'] ?? '').toString().isNotEmpty)
                  _buildDetailRow("Activité", item['nomActivite'].toString()),
                if ((item['dateDebut'] ?? '').toString().isNotEmpty)
                  _buildDetailRow("Date début", item['dateDebut'].toString()),
                if ((item['dateFin'] ?? '').toString().isNotEmpty)
                  _buildDetailRow("Date fin", item['dateFin'].toString()),
                if ((item['lieu'] ?? '').toString().isNotEmpty)
                  _buildDetailRow("Lieu", item['lieu'].toString()),
              ],
              if (type == 'Autre') ...[
                if ((item['nomEvenement'] ?? '').toString().isNotEmpty)
                  _buildDetailRow("Événement", item['nomEvenement'].toString()),
              ],
              if (type == 'Cotisation') ...[
                if ((item['membreId'] ?? '').toString().isNotEmpty)
                  _buildDetailRow("Membre ID", item['membreId'].toString()),
              ],
            ],
          ),
        ),
        actions: [
          if (widget.canEdit) ...[
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _deleteRevenu(item);
              },
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
              label: const Text("Supprimer", style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _openModal(item: item);
              },
              icon: const Icon(Icons.edit_note, color: Color(0xFF0163D2), size: 20),
              label: const Text("Modifier", style: TextStyle(color: Color(0xFF0163D2))),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Fermer", style: TextStyle(color: Color(0xFF0D47A1))),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              "$label :",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D47A1),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD PRINCIPAL
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final filtered = _filteredRevenus;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Column(
        children: [
          _buildTopHeader(isSmallScreen),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 20,
                  vertical: isSmallScreen ? 12 : 16,
                ),
                children: [
                  // Recherche + icône filtre
                  _buildSearchBar(isSmallScreen),

                  // Badges filtres actifs
                  _buildActiveFiltersSummary(isSmallScreen),

                  const SizedBox(height: 8),

                  // Titre + compteur
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Historique Récent",
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
                          "${filtered.length} résultat(s)",
                          style: TextStyle(
                            color: const Color(0xFF0D47A1),
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 11 : 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 15),

                  // Liste
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (filtered.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          Icon(Icons.search_off, size: isSmallScreen ? 55 : 65, color: Colors.grey.shade300),
                          SizedBox(height: isSmallScreen ? 10 : 12),
                          Text(
                            _hasActiveFilter || searchQuery.isNotEmpty
                                ? "Aucun résultat pour ce filtre"
                                : "Aucun revenu trouvé",
                            style: TextStyle(color: Colors.grey.shade500, fontSize: isSmallScreen ? 14 : 15),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildRevenuTable(filtered, isSmallScreen),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF0D47A1),
              onPressed: () => _openModal(),
              label: Text("Nouveau Revenu", style: TextStyle(fontSize: isSmallScreen ? 13 : 15)),
              icon: Icon(Icons.add, size: isSmallScreen ? 20 : 24),
            )
          : null,
    );
  }

  // ============================================================
  // MODAL AJOUT / MODIFICATION
  // ============================================================
  void _openModal({Map<String, dynamic>? item}) {
    if (!widget.canEdit) return;

    String dateRevenu = item?['date'] ?? '';
    String montantRevenu = item?['montant']?.toString() ?? '';
    String typeRevenu = item?['type'] ?? 'Cotisation';
    String typeCotisation = 'Mensuel';
    String autreCotisation = '';
    String? membreId;
    String? membreNom;
    String nomAuteurDon = '';
    String nomSubvention = '';
    String dateDebutActivite = '';
    String dateFinActivite = '';
    String nomActivite = '';
    String lieuActivite = '';
    String nomEvenement = '';
    // 🔥 AJOUT : description commune à tous les types (relue à la modification)
    String descriptionRevenu = item?['description']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Stack(
              children: [
                const Positioned(top: 0, left: 0, child: FormWave()),
                Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FormStyle.sheetHeader(
                    title: item != null ? 'Modifier l\'entrée' : 'Ajouter un revenu',
                  ),

                  // Date
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: dateRevenu),
                    decoration: FormStyle.input(label: "Date *", icon: Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setModalState(() => dateRevenu = "${picked.day}/${picked.month}/${picked.year}");
                      }
                    },
                  ),
                  const SizedBox(height: 15),

                  // Type
                  DropdownButtonFormField<String>(
                    value: typeRevenu,
                    decoration: FormStyle.input(label: "Type de revenu", icon: Icons.sell_outlined),
                    items: ['Cotisation', 'Don', 'Subvention', 'Activité', 'Autre']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setModalState(() {
                      typeRevenu = val!;
                      typeCotisation = 'Mensuel'; autreCotisation = '';
                      nomAuteurDon = '';
                      nomSubvention = '';
                      dateDebutActivite = ''; dateFinActivite = '';
                      nomActivite = ''; lieuActivite = '';
                      nomEvenement = '';
                    }),
                  ),

                  // ========== COTISATION ==========
                  if (typeRevenu == 'Cotisation') ...[
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: membreId,
                      hint: const Text("Sélectionner le membre"),
                      decoration: FormStyle.input(icon: Icons.person_outline),
                      items: membres.map((m) => DropdownMenuItem<String>(
                        value: m['id'].toString(),
                        child: Text("${m['name']} ${m['prenom'] ?? ''}"),
                      )).toList(),
                      onChanged: (val) {
                        final m = membres.firstWhere((e) => e['id'].toString() == val);
                        setModalState(() {
                          membreId = val;
                          membreNom = "${m['name']} ${m['prenom'] ?? ''}";
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: typeCotisation,
                      decoration: FormStyle.input(label: "Type de cotisation", icon: Icons.repeat_rounded),
                      items: ['Mensuel', 'Annuel', 'Droit d\'adhésion', 'Autre']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setModalState(() => typeCotisation = val!),
                    ),
                    if (typeCotisation == 'Autre') ...[
                      const SizedBox(height: 15),
                      TextField(
                        decoration: FormStyle.input(label: "Préciser le type de cotisation", icon: Icons.edit),
                        onChanged: (val) => autreCotisation = val,
                      ),
                    ],
                  ],

                  // ========== DON ==========
                  if (typeRevenu == 'Don') ...[
                    const SizedBox(height: 15),
                    TextField(
                      decoration: FormStyle.input(label: "Nom de l'auteur du don *", icon: Icons.person),
                      onChanged: (val) => nomAuteurDon = val,
                    ),
                  ],

                  // ========== SUBVENTION ==========
                  if (typeRevenu == 'Subvention') ...[
                    const SizedBox(height: 15),
                    TextField(
                      decoration: FormStyle.input(label: "Nom de la subvention *", icon: Icons.business),
                      onChanged: (val) => nomSubvention = val,
                    ),
                  ],

                  // ========== ACTIVITÉ ==========
                  if (typeRevenu == 'Activité') ...[
                    const SizedBox(height: 15),
                    TextField(
                      readOnly: true,
                      controller: TextEditingController(text: dateDebutActivite),
                      decoration: FormStyle.input(label: "Date de début *", icon: Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context, initialDate: DateTime.now(),
                          firstDate: DateTime(2020), lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setModalState(() => dateDebutActivite =
                              "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}");
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      readOnly: true,
                      controller: TextEditingController(text: dateFinActivite),
                      decoration: FormStyle.input(label: "Date de fin *", icon: Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context, initialDate: DateTime.now(),
                          firstDate: DateTime(2020), lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setModalState(() => dateFinActivite =
                              "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}");
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      decoration: FormStyle.input(label: "Nom de l'activité *", icon: Icons.event),
                      onChanged: (val) => nomActivite = val,
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      decoration: FormStyle.input(label: "Lieu *", icon: Icons.location_on),
                      onChanged: (val) => lieuActivite = val,
                    ),
                  ],

                  // ========== AUTRE ==========
                  if (typeRevenu == 'Autre') ...[
                    const SizedBox(height: 15),
                    TextField(
                      decoration: FormStyle.input(label: "Nom de l'événement *", icon: Icons.label),
                      onChanged: (val) => nomEvenement = val,
                    ),
                  ],

                  const SizedBox(height: 15),

                  // 🔥 AJOUT : Description (tous les types) + Montant.
                  // Les prix écrits dans la description (« nom : prix »)
                  // sont additionnés automatiquement dans le montant.
                  DescriptionMontantFields(
                    key: const ValueKey('description-montant'),
                    initialDescription: descriptionRevenu,
                    initialMontant: montantRevenu,
                    descriptionLabel: typeRevenu == 'Autre'
                        ? "Description *"
                        : "Description (optionnel)",
                    montantLabel: "Montant (Ar) *",
                    spacing: 15,
                    showIcons: true,
                    onDescriptionChanged: (v) => descriptionRevenu = v,
                    onMontantChanged: (v) => montantRevenu = v,
                  ),
                  const SizedBox(height: 30),

                  FormStyle.saveButton(
                    label: "Enregistrer",
                    onPressed: () {
                        // Le « motif » (affiché dans la liste) garde la
                        // description sur UNE ligne, comme avant.
                        final descriptionLigne =
                            DescriptionCalculator.flatten(descriptionRevenu);
                        _submitData(
                          item?['id'], typeRevenu, dateRevenu, montantRevenu,
                          membreNom, membreId, typeCotisation, autreCotisation,
                          nomAuteurDon, descriptionLigne, nomSubvention, descriptionLigne,
                          dateDebutActivite, dateFinActivite, nomActivite, lieuActivite,
                          descriptionLigne, nomEvenement, descriptionLigne,
                          description: descriptionRevenu,
                        );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // SAUVEGARDE
  // ============================================================
  Future<void> _submitData(
    dynamic id, String type, String date, String montantStr,
    String? membreNom, String? membreId, String typeCotisation, String autreCotisation,
    String nomAuteurDon, String descriptionDon, String nomSubvention, String descriptionSubvention,
    String dateDebutActivite, String dateFinActivite, String nomActivite,
    String lieuActivite, String descriptionActivite, String nomEvenement, String descriptionAutre, {
    String description = '', // 🔥 AJOUT : description complète (plusieurs lignes)
  }) async {
    if (date.isEmpty || montantStr.isEmpty) { _showAlert("Erreur", "Date et montant sont obligatoires"); return; }
    if (type == 'Cotisation' && membreNom == null) { _showAlert("Erreur", "Veuillez sélectionner un membre"); return; }
    if (type == 'Cotisation' && typeCotisation == 'Autre' && autreCotisation.trim().isEmpty) { _showAlert("Erreur", "Veuillez préciser le type de cotisation"); return; }
    if (type == 'Don' && nomAuteurDon.trim().isEmpty) { _showAlert("Erreur", "Le nom de l'auteur du don est obligatoire"); return; }
    if (type == 'Subvention' && nomSubvention.trim().isEmpty) { _showAlert("Erreur", "Le nom de la subvention est obligatoire"); return; }
    if (type == 'Activité') {
      if (dateDebutActivite.trim().isEmpty) { _showAlert("Erreur", "La date de début est obligatoire"); return; }
      if (dateFinActivite.trim().isEmpty) { _showAlert("Erreur", "La date de fin est obligatoire"); return; }
      if (nomActivite.trim().isEmpty) { _showAlert("Erreur", "Le nom de l'activité est obligatoire"); return; }
      if (lieuActivite.trim().isEmpty) { _showAlert("Erreur", "Le lieu est obligatoire"); return; }
    }
    if (type == 'Autre') {
      if (nomEvenement.trim().isEmpty) { _showAlert("Erreur", "Le nom de l'événement est obligatoire"); return; }
      if (descriptionAutre.trim().isEmpty) { _showAlert("Erreur", "La description est obligatoire"); return; }
    }

    double montant = double.tryParse(montantStr) ?? 0;
    String motifFinal = '';
    if (type == 'Cotisation') { String tcF = typeCotisation == 'Autre' ? autreCotisation : typeCotisation; motifFinal = "Cotisation $tcF - $membreNom"; }
    else if (type == 'Don') { motifFinal = "Don de $nomAuteurDon${descriptionDon.isNotEmpty ? ' - $descriptionDon' : ''}"; }
    else if (type == 'Subvention') { motifFinal = "Subvention: $nomSubvention${descriptionSubvention.isNotEmpty ? ' - $descriptionSubvention' : ''}"; }
    else if (type == 'Activité') { motifFinal = "Activité: $nomActivite - Lieu: $lieuActivite - Du $dateDebutActivite au $dateFinActivite${descriptionActivite.isNotEmpty ? ' - $descriptionActivite' : ''}"; }
    else if (type == 'Autre') { motifFinal = "Événement: $nomEvenement - $descriptionAutre"; }

    try {
      if (id != null) {
        await _revenuRepo.updateRevenu(
          id: id.toString(), type: type, date: date, montant: montant, motif: motifFinal,
          membreId: membreId, nomActivite: type == 'Activité' ? nomActivite : null,
          dateDebut: type == 'Activité' ? dateDebutActivite : null,
          dateFin: type == 'Activité' ? dateFinActivite : null,
          lieu: type == 'Activité' ? lieuActivite : null,
          nomEvenement: type == 'Autre' ? nomEvenement : null,
          description: description.trim().isEmpty ? null : description.trim(),
        );
      } else {
        await _revenuRepo.addRevenu(
          type: type, date: date, montant: montant, motif: motifFinal,
          membreId: membreId, nomActivite: type == 'Activité' ? nomActivite : null,
          dateDebut: type == 'Activité' ? dateDebutActivite : null,
          dateFin: type == 'Activité' ? dateFinActivite : null,
          lieu: type == 'Activité' ? lieuActivite : null,
          nomEvenement: type == 'Autre' ? nomEvenement : null,
          description: description.trim().isEmpty ? null : description.trim(),
        );
      }
      if (mounted) {
        Navigator.pop(context);
        _showAlert("Succès", id != null ? "Revenu modifié" : "Revenu ajouté");
        loadRevenus();
      }
    } catch (e) {
      _showAlert("Erreur", e.toString());
    }
  }

  // ============================================================
  // SUPPRESSION
  // ============================================================
  Future<void> _deleteRevenu(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirmation"),
        content: const Text("Voulez-vous vraiment supprimer ce revenu ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _revenuRepo.deleteRevenu(item['id']);
        _showAlert("Succès", "Revenu supprimé");
        loadRevenus();
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
        ],
      ),
    );
  }
}

class _RevenuTypeStyle {
  final IconData icon;
  final Color color;
  final Color bg;
  const _RevenuTypeStyle(this.icon, this.color, this.bg);
}
