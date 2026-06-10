import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/journal_entry.dart';
import 'journal_form_screen.dart';
import '../services/pdf_service.dart';
import '../models/tier.dart';
import 'tier_detail_screen.dart';

class JournalEntriesScreen extends StatelessWidget {
  final String journalCode;
  final String journalName;
  final DateTime month;

  const JournalEntriesScreen({
    super.key,
    required this.journalCode,
    required this.journalName,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);
    final monthStr = DateFormat('MMMM yyyy', 'fr_FR').format(month);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(journalName, style: const TextStyle(fontSize: 16)),
            Text(monthStr.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<List<JournalEntry>>(
            stream: service.getJournalEntries(),
            builder: (context, snapshot) {
              final entries = (snapshot.data ?? []).where((e) => 
                e.journalCode == journalCode && 
                e.date.month == month.month && 
                e.date.year == month.year
              ).toList();
              
              return IconButton(
                icon: const Icon(Icons.print),
                onPressed: () => PdfService.generateTrialBalance(entries),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A237E),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => JournalFormScreen(
          initialJournalCode: journalCode,
          initialDate: DateTime(month.year, month.month, DateTime.now().day).isAfter(DateTime.now()) 
            ? month : DateTime(month.year, month.month, DateTime.now().day),
        ))),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<JournalEntry>>(
        stream: service.getJournalEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final allEntries = snapshot.data ?? [];
          final entries = allEntries.where((e) => 
            e.journalCode == journalCode && 
            e.date.month == month.month && 
            e.date.year == month.year
          ).toList();

          // Calcul des totaux
          double totalDebit = entries.fold(0, (sum, e) => sum + e.debit);
          double totalCredit = entries.fold(0, (sum, e) => sum + e.credit);

          return Column(
            children: [
              // Affichage des Totaux
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTotalInfo('TOTAL DÉBIT', totalDebit, Colors.blue),
                    _buildTotalInfo('TOTAL CRÉDIT', totalCredit, Colors.orange),
                    _buildTotalInfo('SOLDE', totalDebit - totalCredit, Colors.green),
                  ],
                ),
              ),
              Expanded(
                child: entries.isEmpty 
                  ? const Center(child: Text('Aucune écriture pour ce mois.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Jour')),
                            DataColumn(label: Text('N° Pièce')),
                            DataColumn(label: Text('Compte')),
                            DataColumn(label: Text('Libellé')),
                            DataColumn(label: Text('Débit')),
                            DataColumn(label: Text('Crédit')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: entries.map((e) => DataRow(cells: [
                            DataCell(Text(DateFormat('dd').format(e.date))),
                            DataCell(Text(e.reference)),
                            DataCell(Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(e.accountCode, style: const TextStyle(fontSize: 12)),
                                if (e.tierName != null) 
                                  InkWell(
                                    onTap: () async {
                                      final allTiers = await service.getTiers(null).first;
                                      try {
                                        final tier = allTiers.firstWhere((t) => t.id == e.tierId);
                                        if (context.mounted) {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => TierDetailScreen(tier: tier)));
                                        }
                                      } catch(_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de trouver la fiche client détaillée.')));
                                        }
                                      }
                                    },
                                    child: Text(e.tierName!.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                  ),
                              ],
                            )),
                            DataCell(Text(e.label)),
                            DataCell(Text(e.debit > 0 ? NumberFormat('#,###').format(e.debit) : '')),
                            DataCell(Text(e.credit > 0 ? NumberFormat('#,###').format(e.credit) : '')),
                            DataCell(Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => JournalFormScreen(existingEntry: e))),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  onPressed: () => _confirmDelete(context, service, e.id),
                                ),
                              ],
                            )),
                          ])).toList(),
                        ),
                      ),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTotalInfo(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        Text(NumberFormat('#,###').format(value.abs()) + (value < 0 ? ' (C)' : ''), 
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  void _confirmDelete(BuildContext context, FirestoreService service, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'écriture ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(onPressed: () { service.deleteJournalEntry(id); Navigator.pop(context); }, child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
