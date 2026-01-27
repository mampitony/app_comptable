// lib/components/member_list.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:app_comptable/components/member_card.dart';

class MemberList extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;

  const MemberList({
    Key? key,
    required this.members,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<MemberList> createState() => _MemberListState();
}

class _MemberListState extends State<MemberList> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredMembers = widget.members.where((member) {
      final name = (member['name'] ?? '').toString().toLowerCase();
      final email = (member['email'] ?? '').toString().toLowerCase();
      final prenom = (member['prenom'] ?? '').toString().toLowerCase();
      final tel = (member['telephone'] ?? '').toString();
      final query = searchQuery.toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          prenom.contains(query) ||
          tel.contains(searchQuery);
    }).toList();

    return Column(
      children: [
        // Barre de recherche
        TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher un membre...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (v) {
            setState(() => searchQuery = v);
          },
        ),
        const SizedBox(height: 15),
        
        // Liste des membres
        Expanded(
          child: filteredMembers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: Colors.grey),
                      SizedBox(height: 10),
                      Text(
                        'Aucun membre trouvé',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    final item = filteredMembers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          children: [
                            // Avatar
                            if (item['profileImage'] != null &&
                                (item['profileImage'] as String).isNotEmpty)
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: FileImage(
                                  File(item['profileImage']),
                                ),
                              )
                            else
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: const Color(0xFF0163D2),
                                child: Text(
                                  ((item['name'] ?? 'U')[0] +
                                          (item['prenom'] ?? '')[0])
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            
                            const SizedBox(width: 15),
                            
                            // Informations du membre
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
                                  const SizedBox(height: 4),
                                  Text(
                                    item['role'] ?? '',
                                    style: const TextStyle(
                                      color: Color(0xFF0163D2),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['email'] ?? '',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item['etablissement'] ?? ''} - ${item['niveau'] ?? ''} - ${item['mention'] ?? ''}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['telephone'] ?? '',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Boutons d'action
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            MemberCard(member: item),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.credit_card),
                                  color: Colors.green,
                                  iconSize: 20,
                                  tooltip: 'Voir la carte',
                                ),
                                IconButton(
                                  onPressed: () => widget.onEdit(item),
                                  icon: const Icon(Icons.edit),
                                  color: Colors.blue,
                                  iconSize: 20,
                                  tooltip: 'Modifier',
                                ),
                                IconButton(
                                  onPressed: () =>
                                      widget.onDelete(item['id'] as int),
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red,
                                  iconSize: 20,
                                  tooltip: 'Supprimer',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}