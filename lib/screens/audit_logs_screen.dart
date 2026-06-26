import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  String _searchQuery = "";
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TRAÇABILITÉ DES ACTIONS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: _selectedDate != null ? Colors.yellow : Colors.white),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              setState(() => _selectedDate = picked);
            },
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.red),
              onPressed: () => setState(() => _selectedDate = null),
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher un utilisateur ou une action...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('audit_logs')
                  .orderBy('timestamp', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Erreur : ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var logs = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

                if (_searchQuery.isNotEmpty) {
                  logs = logs.where((log) {
                    final user = (log['userName'] ?? '').toString().toLowerCase();
                    final details = (log['details'] ?? '').toString().toLowerCase();
                    return user.contains(_searchQuery) || details.contains(_searchQuery);
                  }).toList();
                }

                if (_selectedDate != null) {
                  logs = logs.where((log) {
                    final ts = log['timestamp'] as Timestamp?;
                    if (ts == null) return false;
                    final d = ts.toDate();
                    return d.year == _selectedDate!.year && d.month == _selectedDate!.month && d.day == _selectedDate!.day;
                  }).toList();
                }

                if (logs.isEmpty) return const Center(child: Text('Aucune action trouvée.'));

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: logs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final timestamp = log['timestamp'] as Timestamp?;
                    final action = log['action'] ?? '';
                    final userName = log['userName'] ?? 'Inconnu';
                    final details = log['details'] ?? '';

                    IconData icon = Icons.info;
                    Color color = Colors.blue;

                    if (action.contains('delete')) {
                      icon = Icons.delete_forever;
                      color = Colors.red;
                    } else if (action.contains('add')) {
                      icon = Icons.add_circle;
                      color = Colors.green;
                    } else if (action.contains('update')) {
                      icon = Icons.edit;
                      color = Colors.orange;
                    }

                    return ListTile(
                      leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
                      title: Text(details, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('Par : ${userName.toUpperCase()}'),
                      trailing: Text(
                        timestamp != null ? DateFormat('dd/MM HH:mm').format(timestamp.toDate()) : '--',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
