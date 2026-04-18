import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/journal_entry.dart';

import '../services/pdf_service.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  String _searchQuery = "";
  String _selectedJournal = "TOUS";
  final List<String> _journals = ['TOUS', 'ACH', 'VEN', 'BQ', 'CAI'];

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journaux Comptables'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<List<JournalEntry>>(
            stream: service.getJournalEntries(),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? [];
              return PopupMenuButton<String>(
                icon: const Icon(Icons.print),
                onSelected: (val) {
                  if (val == 'balance') PdfService.generateTrialBalance(entries);
                  if (val == 'aged') PdfService.generateAgedBalance(entries);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'balance', child: Text('Balance des Comptes')),
                  const PopupMenuItem(value: 'aged', child: Text('Balance Agée (Créances)')),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _selectedJournal,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _journals.map((j) => DropdownMenuItem(value: j, child: Text(j))).toList(),
                    onChanged: (val) => setState(() => _selectedJournal = val!),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<JournalEntry>>(
              stream: service.getJournalEntries(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                var entries = snapshot.data ?? [];
                
                // Filtre par journal
                if (_selectedJournal != "TOUS") {
                  entries = entries.where((e) => e.journalCode == _selectedJournal).toList();
                }

                // Recherche
                if (_searchQuery.isNotEmpty) {
                  entries = entries.where((e) => 
                    e.label.toLowerCase().contains(_searchQuery) || 
                    e.accountLabel.toLowerCase().contains(_searchQuery) ||
                    e.accountCode.contains(_searchQuery)
                  ).toList();
                }

                if (entries.isEmpty) return const Center(child: Text('Aucune écriture comptable'));

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('Jnl')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Compte')),
                      DataColumn(label: Text('Libellé')),
                      DataColumn(label: Text('Débit')),
                      DataColumn(label: Text('Crédit')),
                    ],
                    rows: entries.map((e) => DataRow(cells: [
                      DataCell(Text(e.journalCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                      DataCell(Text(DateFormat('dd/MM').format(e.date))),
                      DataCell(Text(e.accountCode)),
                      DataCell(Text(e.label.length > 20 ? "${e.label.substring(0, 17)}..." : e.label)),
                      DataCell(Text(e.debit > 0 ? NumberFormat('#,###').format(e.debit) : '')),
                      DataCell(Text(e.credit > 0 ? NumberFormat('#,###').format(e.credit) : '')),
                    ])).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
