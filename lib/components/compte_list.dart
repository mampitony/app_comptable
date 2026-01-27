import 'package:flutter/material.dart';

class CompteList extends StatefulWidget {
  final List<Map<String, dynamic>> comptes;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;

  const CompteList({
    Key? key,
    required this.comptes,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<CompteList> createState() => _CompteListState();
}

class _CompteListState extends State<CompteList> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredComptes = widget.comptes.where((compte) {
      final name = (compte['name'] ?? '').toString().toLowerCase();
      final motifs = (compte['motifs'] ?? '').toString().toLowerCase();
      final date = (compte['date'] ?? '').toString().toLowerCase();
      final montant = (compte['montant'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();

      return name.contains(query) ||
          motifs.contains(query) ||
          date.contains(query) ||
          montant.contains(query);
    }).toList();

    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher le nom...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (v) {
            setState(() => searchQuery = v);
          },
        ),
        const SizedBox(height: 10),
        Expanded(
          child: filteredComptes.isEmpty
              ? const Center(
                  child: Text(
                  'Aucun membre trouvé',
                  style: TextStyle(color: Colors.grey),
                ))
              : ListView.builder(
                  itemCount: filteredComptes.length,
                  itemBuilder: (context, index) {
                    final item = filteredComptes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item['name'] ?? ''} ${item['prenom'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['motifs'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item['motifs'] ?? ''} - ${item['nom'] ?? ''} - ${item['montant'] ?? ''}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['date'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              TextButton(
                                onPressed: () => widget.onEdit(item),
                                child: const Text(
                                  'Modifier',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    widget.onDelete(item['id'] as int),
                                child: const Text(
                                  'Supprimer',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
