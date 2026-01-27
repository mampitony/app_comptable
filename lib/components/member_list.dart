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
        TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher un membre...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (v) {
            setState(() => searchQuery = v);
          },
        ),
        const SizedBox(height: 10),
        Expanded(
          child: filteredMembers.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun membre trouvé',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    final item = filteredMembers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (item['profileImage'] != null &&
                              (item['profileImage'] as String).isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundImage: FileImage(
                                  File(item['profileImage']),
                                ),
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item['name'] ?? ''} ${item['prenom'] ?? ''} (${item['role'] ?? ''})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['email'] ?? '',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item['etablissement'] ?? ''} - ${item['niveau'] ?? ''} - ${item['mention'] ?? ''}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['telephone'] ?? '',
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
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          MemberCard(member: item),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.credit_card, size: 16),
                                label: const Text('Carte'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.green,
                                ),
                              ),
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
