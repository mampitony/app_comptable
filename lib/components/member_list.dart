// lib/components/member_list.dart
import 'package:flutter/material.dart';
import 'package:app_comptable/components/member_card.dart';
import 'package:app_comptable/database/firebase_user_repository.dart';
import 'package:app_comptable/services/image_upload_service.dart';

class MemberList extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final Function(Map<String, dynamic>) onEdit;
  final Function(String) onDelete;
  final bool isAdminPrincipal;
  final Function(String)? onPromoteAdminGestion;
  final Function(String)? onRemoveAdminGestionRole;

const MemberList({
  Key? key,
  required this.members,
  required this.onEdit,
  required this.onDelete,
  required this.isAdminPrincipal,
  this.onPromoteAdminGestion,
  this.onRemoveAdminGestionRole,
}) : super(key: key);

  @override
  State<MemberList> createState() => _MemberListState();
}

class _MemberListState extends State<MemberList> {
  String searchQuery = '';
  String? filtreNiveau;
  String? filtreEtablissement;

  static const List<String> niveaux = ['L1', 'L2', 'L3', 'M1', 'M2'];
  static const List<String> etablissements = [
    'ENI', 'ENS', 'EMIT', 'Fac Sciences',
    'Fac Médecine', 'FLSH', 'ISTE',
  ];

  List<Map<String, dynamic>> get _filtered {
    return widget.members.where((member) {
      final name = (member['name'] ?? '').toString().toLowerCase();
      final email = (member['email'] ?? '').toString().toLowerCase();
      final prenom = (member['prenom'] ?? '').toString().toLowerCase();
      final tel = (member['telephone'] ?? '').toString();
      final query = searchQuery.toLowerCase();
      final matchSearch = name.contains(query) ||
          email.contains(query) ||
          prenom.contains(query) ||
          tel.contains(searchQuery);

      final matchNiveau = filtreNiveau == null ||
          (member['niveau'] ?? '').toString() == filtreNiveau;
      final matchEtab = filtreEtablissement == null ||
          (member['etablissement'] ?? '').toString() == filtreEtablissement;

      return matchSearch && matchNiveau && matchEtab;
    }).toList();
  }

  bool get _filtreActif => filtreNiveau != null || filtreEtablissement != null;

  // ============================================================
  // BOTTOM SHEET FILTRE
  // ============================================================
  void _showFiltreSheet(bool isSmallScreen) {
    String? tempNiveau = filtreNiveau;
    String? tempEtab = filtreEtablissement;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Filtrer les membres",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () => setSheetState(() {
                        tempNiveau = null;
                        tempEtab = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text("Réinitialiser",
                            style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text("NIVEAU",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: niveaux.map((n) {
                    final selected = tempNiveau == n;
                    return GestureDetector(
                      onTap: () => setSheetState(() => tempNiveau = selected ? null : n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF0163D2) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? const Color(0xFF0163D2) : Colors.grey.shade300),
                        ),
                        child: Text(n,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.grey.shade700,
                              fontWeight: FontWeight.w600, fontSize: 13,
                            )),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                const Text("ÉTABLISSEMENT",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: etablissements.map((e) {
                    final selected = tempEtab == e;
                    return GestureDetector(
                      onTap: () => setSheetState(() => tempEtab = selected ? null : e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF0163D2) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? const Color(0xFF0163D2) : Colors.grey.shade300),
                        ),
                        child: Text(e,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.grey.shade700,
                              fontWeight: FontWeight.w600, fontSize: 13,
                            )),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0163D2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      setState(() {
                        filtreNiveau = tempNiveau;
                        filtreEtablissement = tempEtab;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text("Appliquer les filtres",
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
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
  // DIALOG DÉTAIL — CORRIGÉ : affiche TOUS les champs disponibles
  // ============================================================
  void _showDetailDialog(BuildContext context, Map<String, dynamic> item) {
    // Debug : afficher toutes les clés disponibles
    debugPrint('📋 Clés membre: ${item.keys.toList()}');
    debugPrint('📋 Valeurs: $item');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            _buildAvatar(item, radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['name'] ?? ''} ${item['prenom'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (FirebaseUserRepository.rolesLabel(item).isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0163D2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        FirebaseUserRepository.rolesLabel(item),
                        style: const TextStyle(
                          color: Color(0xFF0163D2),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 20),

                // ---- CHAMPS DE BASE — toujours affichés ----
                _detailRow(Icons.email_outlined, "Email", item['email']),
                _detailRow(Icons.phone_outlined, "Téléphone", item['telephone']),
                _detailRow(Icons.cake_outlined, "Naissance", item['dateNaissance']),

                // ---- STATUT MEMBRE ----
                _detailRow(Icons.person_pin_outlined, "Statut", item['statusMembre']),

                // ---- CHAMPS ÉTUDIANT ----
                // On affiche ces champs s'ils existent, peu importe statusMembre
                if (_hasValue(item['etablissement'])) ...[
                  const SizedBox(height: 6),
                  _sectionLabel("Informations académiques"),
                  _detailRow(Icons.school_outlined, "Établissement", item['etablissement']),
                  _detailRow(Icons.grade_outlined, "Mention", item['mention']),
                  _detailRow(Icons.stacked_bar_chart, "Niveau", item['niveau']),
                ],

                // ---- CHAMPS PROFESSIONNEL ----
                if (_hasValue(item['profession']) || _hasValue(item['secteurActivite'])) ...[
                  const SizedBox(height: 6),
                  _sectionLabel("Informations professionnelles"),
                  _detailRow(Icons.work_outline, "Profession", item['profession']),
                  _detailRow(Icons.business_center_outlined, "Secteur", item['secteurActivite']),
                ],

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        actions: [
          // 🔥 CORRIGÉ : mêmes conditions que la ligne de liste — basées
          // sur `adminRole` via le repository, et réservées à l'admin
          // principal, plutôt que sur une comparaison figée de `role`.
          if (widget.isAdminPrincipal &&
              !FirebaseUserRepository.isAdminGestion(item) &&
              !FirebaseUserRepository.isAdminPrincipal(item) &&
              widget.onPromoteAdminGestion != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onPromoteAdminGestion!(item['id'].toString());
              },
              icon: const Icon(Icons.admin_panel_settings, size: 18),
              label: const Text("Autoriser Admin gestion"),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),

          if (widget.isAdminPrincipal &&
              FirebaseUserRepository.isAdminGestion(item) &&
              widget.onRemoveAdminGestionRole != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onRemoveAdminGestionRole!(item['id'].toString());
              },
              icon: const Icon(Icons.remove_moderator, size: 18),
              label: const Text("Retirer rôle Admin"),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),

          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MemberCard(member: item)),
              );
            },
            icon: const Icon(Icons.credit_card, size: 18),
            label: const Text("Carte"),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onEdit(item);
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text("Modifier"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0163D2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // Vérifie si un champ a une valeur non nulle et non vide
  bool _hasValue(dynamic value) {
    if (value == null) return false;
    final str = value.toString().trim();
    return str.isNotEmpty && str != 'null';
  }

  // Label de section dans le dialog
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, dynamic value) {
    if (!_hasValue(value)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF0163D2)),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              "$label :",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString().trim(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> item, {double radius = 20}) {
    final img = item['profileImage'] as String?;
    // 🔥 CORRIGÉ : FileImage seul ne fonctionnait plus une fois la photo
    // hébergée sur ImgBB (URL). resolveImageProvider gère les deux cas.
    final provider = ImageUploadService.resolveImageProvider(img);
    if (provider != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: provider,
        onBackgroundImageError: (exception, stackTrace) {},
      );
    }
    final name = (item['name'] ?? 'U').toString();
    final prenom = (item['prenom'] ?? '').toString();
    final initials = (name.isNotEmpty ? name[0] : 'U') +
        (prenom.isNotEmpty ? prenom[0] : '');
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF0163D2),
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirmation"),
        content: Text("Voulez-vous vraiment supprimer ${item['name']} ${item['prenom']} ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete(item['id'] .toString());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Column(
      children: [
        // ---- Recherche + Filtre ----
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  // 🔥 CORRIGÉ : fond figé en blanc — invisible avec un
                  // texte de recherche devenu clair en mode sombre.
                  // `cardColor` suit déjà le thème (blanc en clair,
                  // gris foncé en sombre).
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                ),
                child: TextField(
                  // 🔥 AJOUT : couleur de texte explicite (même correction
                  // que l'écran de connexion — l'héritage implicite depuis
                  // le thème ne suffisait pas).
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un membre...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF0163D2)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _showFiltreSheet(isSmallScreen),
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: _filtreActif ? const Color(0xFF0163D2) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.tune_rounded,
                        color: _filtreActif ? Colors.white : const Color(0xFF0163D2), size: 22),
                    if (_filtreActif)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ---- Chips filtres actifs ----
        if (_filtreActif)
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                if (filtreNiveau != null)
                  _buildActiveChip("Niveau : $filtreNiveau", () => setState(() => filtreNiveau = null)),
                if (filtreEtablissement != null)
                  _buildActiveChip("Étab. : $filtreEtablissement", () => setState(() => filtreEtablissement = null)),
              ],
            ),
          ),
        if (_filtreActif) const SizedBox(height: 10),

        // ---- Compteur ----
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text(
              "${filtered.length} membre(s)",
              style: const TextStyle(color: Color(0xFF0163D2), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ============================================================
        // TABLEAU CORRIGÉ — 3 colonnes seulement pour tenir sur l'écran
        // Tap sur la ligne = ouvre le détail
        // Icône poubelle à droite = supprime
        // ============================================================
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 70, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text(
                        _filtreActif ? 'Aucun membre pour ce filtre' : 'Aucun membre trouvé',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                      ),
                      if (_filtreActif) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => setState(() { filtreNiveau = null; filtreEtablissement = null; }),
                          child: const Text("Effacer les filtres",
                              style: TextStyle(color: Color(0xFF0163D2), fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildMemberRow(context, item, isSmallScreen);
                  },
                ),
        ),
      ],
    );
  }

  // ============================================================
  // LIGNE MEMBRE — remplace DataTable pour éviter le débordement
  // ============================================================
  Widget _buildMemberRow(BuildContext context, Map<String, dynamic> item, bool isSmallScreen) {
    return InkWell(
      onTap: () => _showDetailDialog(context, item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(item, radius: isSmallScreen ? 20 : 22),
            SizedBox(width: isSmallScreen ? 10 : 14),

            // Prénom uniquement (premier prénom) + rôle en sous-titre
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // ✅ Affiche seulement le premier mot du prénom
                    _firstPrenom(item),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 13 : 14,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['role'] == null
                        ? '-'
                        : FirebaseUserRepository.rolesLabel(item),
                    style: TextStyle(
                      color: const Color(0xFF0163D2),
                      fontSize: isSmallScreen ? 11 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),

            // Niveau (badge compact) si disponible
            if (_hasValue(item['niveau']))
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  item['niveau'].toString(),
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: isSmallScreen ? 10 : 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Actions administrateur gestion membre — réservées à
            // l'administrateur principal (widget.isAdminPrincipal).
            //
            // 🔥 CORRIGÉ : l'ancienne condition comparait item['role'] à
            // 'membre'/'admin_gestion_membre' en dur. Avec la séparation
            // role/adminRole, la fonction d'un membre éligible peut être
            // n'importe quoi ("Trésorier", "Président", "Membre", ...) —
            // seul le champ adminRole indique le droit d'administration.
            // On utilise donc les helpers du repository.
            if (widget.isAdminPrincipal &&
                !FirebaseUserRepository.isAdminGestion(item) &&
                !FirebaseUserRepository.isAdminPrincipal(item) &&
                widget.onPromoteAdminGestion != null)
              GestureDetector(
                onTap: () => widget.onPromoteAdminGestion!(item['id'].toString()),
                child: const Icon(Icons.admin_panel_settings,
                    color: Colors.orange),
              ),

            if (widget.isAdminPrincipal &&
                FirebaseUserRepository.isAdminGestion(item) &&
                widget.onRemoveAdminGestionRole != null)
              GestureDetector(
                onTap: () =>
                    widget.onRemoveAdminGestionRole!(item['id'].toString()),
                child: const Icon(Icons.remove_moderator,
                    color: Colors.redAccent),
              ),

            // Bouton supprimer
            GestureDetector(
              onTap: () => _confirmDelete(context, item),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete_outline, color: Colors.redAccent, size: isSmallScreen ? 17 : 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Retourne "NOM Prénom1" — juste le premier prénom pour éviter le débordement
  String _firstPrenom(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString().trim();
    final prenomFull = (item['prenom'] ?? '').toString().trim();
    // Prend seulement le premier mot du prénom
    final prenomCourt = prenomFull.split(' ').first;
    return '$name $prenomCourt';
  }

  Widget _buildActiveChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0163D2).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0163D2).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF0163D2), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Color(0xFF0163D2)),
          ),
        ],
      ),
    );
  }
}