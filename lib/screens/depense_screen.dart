import 'package:flutter/material.dart';

import '../database/firebase_depense_repository.dart';
import '../database/firebase_revenu_repository.dart';
import '../database/firebase_user_repository.dart';
import '../database/firebase_historique_repository.dart';
import '../components/description_montant_fields.dart'; // 🔥 AJOUT : description + montant auto
import '../services/description_calculator.dart';
import '../components/form_style.dart';

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
  String searchQuery = '';
  String filtreCategorie = 'Toutes';
  String filtreOrdre = 'Récent';
  int? filtreMois;
  int? filtreAnnee;
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _categories = [
    'Déplacement',
    'Achat',
    'Communication',
    'Activités',
    'Autre',
  ];

  final FirebaseDepenseRepository _depenseRepo = FirebaseDepenseRepository();
  final FirebaseRevenuRepository _revenuRepo = FirebaseRevenuRepository();
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();
  final FirebaseHistoriqueRepository _historiqueRepo = FirebaseHistoriqueRepository();

  List<Map<String, dynamic>> membres = [];
  double totalRevenus = 0;

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
  String descriptionDepense = '';

  Map<String, dynamic>? editItem;

  Map<String, List<Map<String, dynamic>>> depenses = {
    'Déplacement': [],
    'Achat': [],
    'Communication': [],
    'Activités': [],
    'Autre': [],
  };

  bool get canEdit => widget.canEdit;

  @override
  void initState() {
    super.initState();
    _initDepenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    if (mounted) setState(() => membres = users);
  }

  Future<void> _loadTotalRevenus() async {
    final total = await _revenuRepo.getTotalRevenus();
    if (mounted) setState(() => totalRevenus = total);
  }

  Future<void> _loadDepensesFromDB() async {
    final all = await _depenseRepo.getAllDepenses();
    final Map<String, List<Map<String, dynamic>>> mapTemp = {
      'Déplacement': [],
      'Achat': [],
      'Communication': [],
      'Activités': [],
      'Autre': [],
    };
    for (final d in all) {
      final type = d['type'] as String? ?? '';
      if (mapTemp.containsKey(type)) mapTemp[type]!.add(d);
    }
    if (mounted) setState(() => depenses = mapTemp);
  }

  // CORRECTION : tous les ! remplacés par ?? []
  Map<String, double> _calculerTotaux() {
    double totalDeplacement = (depenses['Déplacement'] ?? []).fold(0.0, (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0));
    double totalAchat = (depenses['Achat'] ?? []).fold(0.0, (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0));
    double totalCommunication = (depenses['Communication'] ?? []).fold(0.0, (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0));
    double totalActivites = (depenses['Activités'] ?? []).fold(0.0, (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0));
    double totalAutre = (depenses['Autre'] ?? []).fold(0.0, (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0));
    double totalGeneral = totalDeplacement + totalAchat + totalCommunication + totalActivites + totalAutre;
    return {
      'Déplacement': totalDeplacement,
      'Achat': totalAchat,
      'Communication': totalCommunication,
      'Activités': totalActivites,
      'Autre': totalAutre,
      'General': totalGeneral,
      'Solde': totalRevenus - totalGeneral,
    };
  }

  // Toutes les dépenses, toutes catégories confondues
  List<Map<String, dynamic>> get _allDepenses =>
      [for (final c in _categories) ...(depenses[c] ?? [])];

  List<Map<String, dynamic>> get _filteredDepenses {
    List<Map<String, dynamic>> result = List.from(_allDepenses);

    if (filtreCategorie != 'Toutes') {
      result = result.where((d) => d['type'] == filtreCategorie).toList();
    }

    if (filtreMois != null || filtreAnnee != null) {
      result = result.where((d) {
        final dt = _parseDate(d['date']?.toString() ?? '');
        if (dt == null) return true;
        if (filtreMois != null && dt.month != filtreMois) return false;
        if (filtreAnnee != null && dt.year != filtreAnnee) return false;
        return true;
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((d) {
        final champs = [
          d['type'],
          _titreDepense(d),
          d['lieu'],
          d['nomProduit'],
          d['sousType'],
          d['nomActivite'],
          d['lieuActivite'],
          d['membreAcheteur'],
          d['description'],
          d['date'],
          d['montant'],
        ];
        return champs.any((c) => (c ?? '').toString().toLowerCase().contains(q));
      }).toList();
    }

    result.sort((a, b) {
      final dateA = _parseDate(a['date']?.toString() ?? '');
      final dateB = _parseDate(b['date']?.toString() ?? '');
      if (dateA == null || dateB == null) return 0;
      return filtreOrdre == 'Récent' ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
    });

    return result;
  }

  DateTime? _parseDate(String dateStr) {
    try {
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      }
      if (dateStr.contains('-')) return DateTime.parse(dateStr);
    } catch (_) {}
    return null;
  }

  bool get _hasActiveFilter =>
      filtreCategorie != 'Toutes' ||
      filtreOrdre != 'Récent' ||
      filtreMois != null ||
      filtreAnnee != null;

  String _titreDepense(Map<String, dynamic> item) {
    switch (item['type']) {
      case 'Déplacement':
        return "Vers ${item['lieu'] ?? ''}";
      case 'Achat':
        return "${item['nomProduit'] ?? ''}";
      case 'Communication':
        return "${item['sousType'] ?? ''}";
      case 'Activités':
        return "${item['nomActivite'] ?? ''}";
      case 'Autre':
        return DescriptionCalculator.firstLine(
          (item['description'] ?? '').toString(),
          fallback: 'Autre dépense',
        );
      default:
        return 'Dépense';
    }
  }

  // --- DESIGN ---

  Widget _buildTopHeader(bool isSmallScreen) {
    final totaux = _calculerTotaux();
    final solde = totaux['Solde'] ?? 0;

    return Container(
      padding: EdgeInsets.only(
        top: isSmallScreen ? 40 : 50,
        bottom: isSmallScreen ? 20 : 25,
        left: isSmallScreen ? 16 : 20,
        right: isSmallScreen ? 16 : 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0163D2), Color(0xFF0056B8)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Text(
            "SOLDE DISPONIBLE",
            style: TextStyle(
              color: Colors.white70,
              fontSize: isSmallScreen ? 10 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isSmallScreen ? 4 : 6),
          Text(
            "${solde.toStringAsFixed(0)} Ar",
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
              _statHeaderItem("Revenus", totalRevenus, Colors.greenAccent, isSmallScreen),
              Container(width: 1, height: isSmallScreen ? 25 : 30, color: Colors.white24),
              _statHeaderItem("Dépenses", totaux['General'] ?? 0, Colors.orangeAccent, isSmallScreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statHeaderItem(String label, double val, Color color, bool isSmallScreen) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white60, fontSize: isSmallScreen ? 11 : 13),
        ),
        Text(
          "${val.toStringAsFixed(0)} Ar",
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
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => searchQuery = val),
              style: TextStyle(fontSize: isSmallScreen ? 14 : 15),
              decoration: InputDecoration(
                hintText: "Rechercher par catégorie, lieu, date...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: isSmallScreen ? 13 : 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0163D2)),
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
        GestureDetector(
          onTap: _showFilterBottomSheet,
          child: Container(
            width: isSmallScreen ? 46 : 52,
            height: isSmallScreen ? 46 : 52,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _hasActiveFilter ? const Color(0xFF0163D2) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8)],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: _hasActiveFilter ? Colors.white : const Color(0xFF0163D2),
                  size: isSmallScreen ? 22 : 24,
                ),
                if (_hasActiveFilter)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
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
    String tempCategorie = filtreCategorie;
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Filtres",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      TextButton(
                        onPressed: () => setSheetState(() {
                          tempCategorie = 'Toutes';
                          tempOrdre = 'Récent';
                          tempMois = null;
                          tempAnnee = null;
                        }),
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

                  // --- Catégorie ---
                  _sectionLabel("Catégorie de dépense"),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Toutes', ..._categories]
                        .map((t) => GestureDetector(
                              onTap: () => setSheetState(() => tempCategorie = t),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: tempCategorie == t ? const Color(0xFF0163D2) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: tempCategorie == t ? const Color(0xFF0163D2) : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: tempCategorie == t ? Colors.white : Colors.grey.shade700,
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

                  FormStyle.saveButton(
                    label: "Appliquer les filtres",
                    onPressed: () {
                      setState(() {
                        filtreCategorie = tempCategorie;
                        filtreOrdre = tempOrdre;
                        filtreMois = tempMois;
                        filtreAnnee = tempAnnee;
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
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
    const blue = Color(0xFF0163D2);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? blue.withOpacity(0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? blue : Colors.grey.shade200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? blue : Colors.grey.shade500),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? blue : Colors.grey.shade600,
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

  // Résumé des filtres actifs sous la recherche
  Widget _buildActiveFiltersSummary(bool isSmallScreen) {
    final List<Widget> chips = [];

    if (filtreCategorie != 'Toutes') {
      chips.add(_activeBadge(filtreCategorie, () => setState(() => filtreCategorie = 'Toutes'), isSmallScreen));
    }
    if (filtreOrdre != 'Récent') {
      chips.add(_activeBadge("Ancien d'abord", () => setState(() => filtreOrdre = 'Récent'), isSmallScreen));
    }

    const moisNoms = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    if (filtreMois != null && filtreAnnee != null) {
      chips.add(_activeBadge(
        "${moisNoms[filtreMois! - 1]} $filtreAnnee",
        () => setState(() {
          filtreMois = null;
          filtreAnnee = null;
        }),
        isSmallScreen,
      ));
    } else if (filtreMois != null) {
      chips.add(_activeBadge(moisNoms[filtreMois! - 1], () => setState(() => filtreMois = null), isSmallScreen));
    } else if (filtreAnnee != null) {
      chips.add(_activeBadge("$filtreAnnee", () => setState(() => filtreAnnee = null), isSmallScreen));
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
    const blue = Color(0xFF0163D2);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 10 : 12,
        vertical: isSmallScreen ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: isSmallScreen ? 11 : 12, fontWeight: FontWeight.w600, color: blue),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 13, color: blue),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLEAU COMPACT DES DÉPENSES
  // ============================================================
  // Format : 1960100.0 -> "1 960 100" (purement visuel)
  String _fmtMontant(dynamic v) {
    final n = num.tryParse(v?.toString() ?? '');
    if (n == null) return v?.toString() ?? '0';
    final isInt = n == n.roundToDouble();
    final raw = isInt ? n.round().toString() : n.toStringAsFixed(2);
    final parts = raw.split('.');
    final grouped = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
    return parts.length > 1 ? '$grouped,${parts[1]}' : grouped;
  }

  _DepenseTypeStyle _typeStyle(String type) {
    switch (type) {
      case 'Déplacement':
        return _DepenseTypeStyle(Icons.directions_car_filled_outlined, Colors.indigo, Colors.indigo.shade50);
      case 'Achat':
        return _DepenseTypeStyle(Icons.shopping_bag_outlined, Colors.orange, Colors.orange.shade50);
      case 'Communication':
        return _DepenseTypeStyle(Icons.phone_android, Colors.teal, Colors.teal.shade50);
      case 'Activités':
        return _DepenseTypeStyle(Icons.event, Colors.purple, Colors.purple.shade50);
      default: // Autre
        return _DepenseTypeStyle(Icons.category_outlined, Colors.blueGrey, Colors.blueGrey.shade50);
    }
  }

  Widget _buildDepenseTable(List<Map<String, dynamic>> items, bool isSmallScreen) {
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              color: const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(width: dateW, child: headCell('DATE')),
                  Expanded(child: headCell('LIBELLÉ')),
                  SizedBox(width: montantW, child: headCell('MONTANT', align: TextAlign.right)),
                  const SizedBox(width: 30),
                ],
              ),
            ),
            for (int i = 0; i < items.length; i++)
              _buildDepenseRow(items[i], dateW, montantW, last: i == items.length - 1),
          ],
        ),
      ),
    );
  }

  Widget _buildDepenseRow(
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    radius: 14,
                    backgroundColor: st.bg,
                    child: Icon(st.icon, color: st.color, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titreDepense(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: st.color),
                        ),
                      ],
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
                  '-${_fmtMontant(item['montant'])} Ar',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
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
  // DÉTAIL D'UNE DÉPENSE
  // ============================================================
  void _showDetailDialog(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? '';
    final st = _typeStyle(type);

    Widget row(String label, dynamic value) {
      final v = (value ?? '').toString();
      if (v.trim().isEmpty) return const SizedBox.shrink();
      return _buildDetailRow(label, v);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(st.icon, color: st.color),
            const SizedBox(width: 8),
            Expanded(child: Text(type, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              row("Date", item['date']),
              _buildDetailRow("Montant", "${_fmtMontant(item['montant'])} Ar"),
              if (type == 'Déplacement') ...[
                row("Lieu", item['lieu']),
                row("Participants", item['nombreParticipants']),
              ],
              if (type == 'Achat') ...[
                row("Produit", item['nomProduit']),
                row("Acheteur", item['membreAcheteur']),
              ],
              if (type == 'Communication') row("Type", item['sousType']),
              if (type == 'Activités') ...[
                row("Activité", item['nomActivite']),
                row("Date début", item['dateDebut']),
                row("Date fin", item['dateFin']),
                row("Lieu", item['lieuActivite']),
              ],
              row("Description", item['description']),
            ],
          ),
        ),
        actions: [
          if (canEdit) ...[
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _handleDelete(item['id']);
              },
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
              label: const Text("Supprimer", style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _openModal(item: item);
              },
              icon: const Icon(Icons.edit, color: Color(0xFF0163D2), size: 18),
              label: const Text("Modifier", style: TextStyle(color: Color(0xFF0163D2))),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Fermer", style: TextStyle(color: Color(0xFF0163D2))),
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
            width: 95,
            child: Text(
              "$label :",
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0163D2), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final filtered = _filteredDepenses;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Column(
        children: [
          _buildTopHeader(isSmallScreen),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _initDepenses,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 20,
                  vertical: isSmallScreen ? 12 : 16,
                ),
                children: [
                  _buildSearchBar(isSmallScreen),
                  _buildActiveFiltersSummary(isSmallScreen),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Historique récent",
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
                            color: const Color(0xFF0163D2),
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 11 : 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 15),
                  if (filtered.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          Icon(Icons.search_off, size: isSmallScreen ? 55 : 65, color: Colors.grey.shade300),
                          SizedBox(height: isSmallScreen ? 10 : 12),
                          Text(
                            _hasActiveFilter || searchQuery.isNotEmpty
                                ? "Aucun résultat pour ce filtre"
                                : "Aucune dépense trouvée",
                            style: TextStyle(color: Colors.grey.shade500, fontSize: isSmallScreen ? 14 : 15),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildDepenseTable(filtered, isSmallScreen),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF0163D2),
              onPressed: () => _openModal(),
              label: Text("Ajouter", style: TextStyle(fontSize: isSmallScreen ? 13 : 15)),
              icon: Icon(Icons.add, size: isSmallScreen ? 20 : 24),
            )
          : null,
    );
  }

  // CORRECTION : variables initialisées AVANT showModalBottomSheet
  void _openModal({Map<String, dynamic>? item}) {
    if (item != null) {
      typeDepense = item['type'] ?? 'Déplacement';
      dateDepense = item['date'] ?? '';
      montantDepense = (item['montant'] ?? '').toString();
      lieuDeplacement = item['lieu'] ?? '';
      nombreParticipants = (item['nombreParticipants'] ?? '').toString();
      nomProduit = item['nomProduit'] ?? '';
      membreAcheteur = item['membreAcheteur'] ?? '';
      typeCommunication = item['sousType'] ?? 'Crédit téléphone';
      nomActivite = item['nomActivite'] ?? '';
      dateDebutActivite = item['dateDebut'] ?? '';
      dateFinActivite = item['dateFin'] ?? '';
      lieuActivite = item['lieuActivite'] ?? '';
      descriptionDepense = item['description'] ?? '';
      editItem = item;
    } else {
      typeDepense = filtreCategorie != 'Toutes' ? filtreCategorie : 'Déplacement';
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
      descriptionDepense = '';
      editItem = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildModalContent(),
    );
  }

  Widget _buildModalContent() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: screenSize.height * 0.85,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Stack(
            children: [
              const Positioned(top: 0, left: 0, child: FormWave()),
              Column(
                children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(
                    isSmallScreen ? 16 : 20, 10, isSmallScreen ? 16 : 20, 0),
                child: FormStyle.sheetHeader(
                  title: editItem == null ? "Nouvelle dépense" : "Modifier dépense",
                  onClose: () => Navigator.pop(context),
                ),
              ),

              // Formulaire
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  child: Column(
                    children: [
                      // Date
                      _buildTextField(
                        "Date",
                        dateDepense,
                        (val) => setModalState(() => dateDepense = val),
                        isDate: true,
                        isSmallScreen: isSmallScreen,
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),

                      // Catégorie (choisie à l'ajout, verrouillée à la modification)
                      DropdownButtonFormField<String>(
                        value: typeDepense,
                        style: TextStyle(fontSize: isSmallScreen ? 14 : 16, color: Colors.black),
                        decoration: FormStyle.input(
                          label: "Catégorie",
                          labelFontSize: isSmallScreen ? 13 : 15,
                          icon: Icons.category_outlined,
                        ),
                        items: _categories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: editItem == null
                            ? (val) => setModalState(() {
                                  typeDepense = val ?? typeDepense;
                                  lieuDeplacement = '';
                                  nombreParticipants = '';
                                  nomProduit = '';
                                  membreAcheteur = '';
                                  typeCommunication = 'Crédit téléphone';
                                  nomActivite = '';
                                  dateDebutActivite = '';
                                  dateFinActivite = '';
                                  lieuActivite = '';
                                })
                            : null,
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),

                      // 🔥 AJOUT : Description (toutes les catégories) + Montant.
                      // Les prix écrits dans la description (« nom : prix »)
                      // sont additionnés automatiquement dans le montant.
                      DescriptionMontantFields(
                        key: const ValueKey('description-montant'),
                        initialDescription: descriptionDepense,
                        initialMontant: montantDepense,
                        descriptionLabel: typeDepense == 'Autre'
                            ? "Description de la dépense *"
                            : "Description (optionnel)",
                        montantLabel: "Montant (Ar)",
                        spacing: isSmallScreen ? 12 : 16,
                        fontSize: isSmallScreen ? 14 : 16,
                        labelFontSize: isSmallScreen ? 13 : 15,
                        onDescriptionChanged: (v) => descriptionDepense = v,
                        onMontantChanged: (v) => montantDepense = v,
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),

                      // ========== DÉPLACEMENT ==========
                      if (typeDepense == 'Déplacement') ...[
                        _buildTextField(
                          "Lieu",
                          lieuDeplacement,
                          (val) => setModalState(() => lieuDeplacement = val),
                          isSmallScreen: isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        _buildTextField(
                          "Nombre participants",
                          nombreParticipants,
                          (val) => setModalState(() => nombreParticipants = val),
                          isNumber: true,
                          isSmallScreen: isSmallScreen,
                        ),
                      ],

                      // ========== ACHAT ==========
                      if (typeDepense == 'Achat') ...[
                        _buildTextField(
                          "Nom du produit",
                          nomProduit,
                          (val) => setModalState(() => nomProduit = val),
                          isSmallScreen: isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        _buildMembreDropdown(isSmallScreen, setModalState),
                      ],

                      // ========== COMMUNICATION ==========
                      if (typeDepense == 'Communication') ...[
                        _buildCommunicationDropdown(isSmallScreen, setModalState),
                      ],

                      // ========== ACTIVITÉS ==========
                      if (typeDepense == 'Activités') ...[
                        _buildTextField(
                          "Nom activité",
                          nomActivite,
                          (val) => setModalState(() => nomActivite = val),
                          isSmallScreen: isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        _buildTextField(
                          "Date début",
                          dateDebutActivite,
                          (val) => setModalState(() => dateDebutActivite = val),
                          isDate: true,
                          isSmallScreen: isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        _buildTextField(
                          "Date fin",
                          dateFinActivite,
                          (val) => setModalState(() => dateFinActivite = val),
                          isDate: true,
                          isSmallScreen: isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        _buildTextField(
                          "Lieu",
                          lieuActivite,
                          (val) => setModalState(() => lieuActivite = val),
                          isSmallScreen: isSmallScreen,
                        ),
                      ],

                      // ========== AUTRE ==========
                      // (sa description est maintenant le champ commun du haut)

                      SizedBox(height: isSmallScreen ? 25 : 30),

                      // Bouton submit
                      FormStyle.saveButton(
                        label: editItem == null ? "Enregistrer" : "Mettre à jour",
                        onPressed: () => _handleSubmit(setModalState),
                      ),
                    ],
                  ),
                ),
              ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    String value,
    Function(String) onChanged, {
    bool isDate = false,
    bool isNumber = false,
    required bool isSmallScreen,
  }) {
    return TextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
      onChanged: onChanged,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      readOnly: isDate,
      onTap: isDate ? () => _pickDate(onSelected: onChanged, initial: value) : null,
      style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
      decoration: FormStyle.input(
        label: label,
        labelFontSize: isSmallScreen ? 13 : 15,
        icon: isDate ? Icons.calendar_today : _iconForLabel(label),
      ),
    );
  }

  // Icône du champ selon son libellé (purement visuel)
  IconData _iconForLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('lieu')) return Icons.location_on_outlined;
    if (l.contains('produit')) return Icons.shopping_bag_outlined;
    if (l.contains('participant')) return Icons.groups_outlined;
    if (l.contains('activité')) return Icons.event_outlined;
    return Icons.edit_outlined;
  }

  // CORRECTION : setModalState passé en paramètre pour mise à jour correcte du modal
  Widget _buildMembreDropdown(bool isSmallScreen, StateSetter setModalState) {
    return DropdownButtonFormField<String>(
      value: membreAcheteur.isEmpty ? null : membreAcheteur,
      style: TextStyle(fontSize: isSmallScreen ? 14 : 16, color: Colors.black),
      decoration: FormStyle.input(
        label: "Membre acheteur",
        labelFontSize: isSmallScreen ? 13 : 15,
        icon: Icons.person_outline,
      ),
      items: membres.map((m) {
        final name = "${m['name']} ${m['prenom'] ?? ''}";
        return DropdownMenuItem(value: name, child: Text(name));
      }).toList(),
      onChanged: (val) => setModalState(() => membreAcheteur = val ?? ''),
    );
  }

  Widget _buildCommunicationDropdown(bool isSmallScreen, StateSetter setModalState) {
    return DropdownButtonFormField<String>(
      value: typeCommunication,
      style: TextStyle(fontSize: isSmallScreen ? 14 : 16, color: Colors.black),
      decoration: FormStyle.input(
        label: "Type communication",
        labelFontSize: isSmallScreen ? 13 : 15,
        icon: Icons.forum_outlined,
      ),
      items: ['Crédit téléphone', 'Internet', 'Autre'].map((t) {
        return DropdownMenuItem(value: t, child: Text(t));
      }).toList(),
      onChanged: (val) => setModalState(() => typeCommunication = val ?? 'Crédit téléphone'),
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
      onSelected(
        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}",
      );
    }
  }

  // CORRECTION : setModalState passé pour éviter setState sur widget démonté
  Future<void> _handleSubmit(StateSetter setModalState) async {
    if (dateDepense.isEmpty || montantDepense.isEmpty) {
      _showAlert("Erreur", "Veuillez remplir tous les champs obligatoires");
      return;
    }

    if (typeDepense == 'Autre' && descriptionDepense.trim().isEmpty) {
      _showAlert("Erreur", "Veuillez saisir la description de la dépense");
      return;
    }

    try {
      final montant = double.tryParse(montantDepense) ?? 0;

      if (editItem == null) {
        await _depenseRepo.addDepense(
          type: typeDepense,
          date: dateDepense,
          montant: montant,
          lieu: lieuDeplacement.isEmpty ? null : lieuDeplacement,
          nombreParticipants: int.tryParse(nombreParticipants),
          nomProduit: nomProduit.isEmpty ? null : nomProduit,
          membreAcheteur: membreAcheteur.isEmpty ? null : membreAcheteur,
          sousType: typeCommunication,
          nomActivite: nomActivite.isEmpty ? null : nomActivite,
          dateDebut: dateDebutActivite.isEmpty ? null : dateDebutActivite,
          dateFin: dateFinActivite.isEmpty ? null : dateFinActivite,
          lieuActivite: lieuActivite.isEmpty ? null : lieuActivite,
          description: descriptionDepense.trim().isEmpty ? null : descriptionDepense.trim(),
        );

        await _historiqueRepo.addHistorique(
          typeOperation: 'dépense',
          operation: 'ajout',
          details: typeDepense == 'Autre'
              ? 'Autre dépense: ${DescriptionCalculator.firstLine(descriptionDepense)}'
              : 'Dépense $typeDepense ajoutée',
          montant: montant,
        );
      } else {
        await _depenseRepo.updateDepense(
          id: editItem!['id'],
          type: typeDepense,
          date: dateDepense,
          montant: montant,
          lieu: lieuDeplacement.isEmpty ? null : lieuDeplacement,
          nombreParticipants: int.tryParse(nombreParticipants),
          nomProduit: nomProduit.isEmpty ? null : nomProduit,
          membreAcheteur: membreAcheteur.isEmpty ? null : membreAcheteur,
          sousType: typeCommunication,
          nomActivite: nomActivite.isEmpty ? null : nomActivite,
          dateDebut: dateDebutActivite.isEmpty ? null : dateDebutActivite,
          dateFin: dateFinActivite.isEmpty ? null : dateFinActivite,
          lieuActivite: lieuActivite.isEmpty ? null : lieuActivite,
          description: descriptionDepense.trim().isEmpty ? null : descriptionDepense.trim(),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
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

class _DepenseTypeStyle {
  final IconData icon;
  final Color color;
  final Color bg;
  const _DepenseTypeStyle(this.icon, this.color, this.bg);
}
