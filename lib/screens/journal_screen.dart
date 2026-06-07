import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/journal_entry.dart';
import 'journal_entries_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  String _currentFilter = 'Tous';
  
  final List<Map<String, String>> _journalTypes = [
    {'code': 'ACH', 'name': 'ACHATS'},
    {'code': 'VEN', 'name': 'VENTES'},
    {'code': 'BQ', 'name': 'BIM SA (BANQUE)'},
    {'code': 'PAIE', 'name': 'PAIE'},
    {'code': 'OD', 'name': 'OPERATIONS DIVERSES'},
    {'code': 'RAN', 'name': 'REPORT A NOUVEAU'},
    {'code': 'CAS', 'name': 'CAISSE SANOGO'},
    {'code': 'CAP', 'name': 'CAISSE PRINCIPAL'},
    {'code': 'CAD', 'name': 'CAISSE DES DEPENSES'},
  ];

  List<DateTime> _getMonths() {
    List<DateTime> months = [];
    DateTime now = DateTime.now();
    for (int i = 1; i <= 12; i++) {
      months.add(DateTime(now.year, i));
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);
    final months = _getMonths();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saisie des journaux'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => _showSyncDialog(context, service),
            icon: const Icon(Icons.sync, color: Colors.white),
            label: const Text('Mise à jour Gestion', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<List<JournalEntry>>(
        stream: service.getJournalEntries(),
        builder: (context, snapshot) {
          final allEntries = snapshot.data ?? [];
          
          return Row(
            children: [
              // Sidebar gauche
              Container(
                width: 200,
                color: Colors.grey.shade100,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  children: [
                    _buildSidebarItem('Tous', Icons.list),
                    _buildSidebarItem('Ouverts', Icons.folder_open),
                    _buildSidebarItem('Non ouverts', Icons.folder),
                    _buildSidebarItem('Clôturés', Icons.lock),
                  ],
                ),
              ),
              // Liste principale
              Expanded(
                child: Column(
                  children: [
                    Container(
                      color: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      child: const Row(
                        children: [
                          SizedBox(width: 30), // Pour l'icône crayon
                          Expanded(flex: 1, child: Text('Période', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 1, child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 3, child: Text('Intitulé du journal', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: months.length * _journalTypes.length,
                        itemBuilder: (context, index) {
                          int monthIdx = index ~/ _journalTypes.length;
                          int journalIdx = index % _journalTypes.length;
                          
                          DateTime month = months[monthIdx];
                          var journal = _journalTypes[journalIdx];
                          String periode = DateFormat('MMM.yy', 'fr_FR').format(month).toLowerCase();

                          // Logique OUVERT / NON OUVERT
                          bool isOpen = allEntries.any((e) => 
                            e.journalCode == journal['code'] && 
                            e.date.month == month.month && 
                            e.date.year == month.year
                          );

                          // Filtrage sidebar
                          if (_currentFilter == 'Ouverts' && !isOpen) return const SizedBox.shrink();
                          if (_currentFilter == 'Non ouverts' && isOpen) return const SizedBox.shrink();

                          return InkWell(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => JournalEntriesScreen(
                                journalCode: journal['code']!,
                                journalName: journal['name']!,
                                month: month,
                              )));
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 30,
                                    child: isOpen ? const Icon(Icons.edit, size: 16, color: Colors.blueGrey) : null,
                                  ),
                                  Expanded(flex: 1, child: Text(periode)),
                                  Expanded(flex: 1, child: Text(journal['code']!)),
                                  Expanded(flex: 3, child: Text(journal['name']!, style: const TextStyle(fontWeight: FontWeight.w500))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebarItem(String label, IconData icon) {
    bool selected = _currentFilter == label;
    return Container(
      color: selected ? Colors.white : Colors.transparent,
      child: ListTile(
        leading: Icon(icon, size: 18, color: selected ? const Color(0xFF1A237E) : Colors.grey),
        title: Text(label, style: TextStyle(fontSize: 13, color: selected ? Colors.black : Colors.grey.shade700, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        onTap: () => setState(() => _currentFilter = label),
        dense: true,
      ),
    );
  }

  void _showSyncDialog(BuildContext context, FirestoreService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mise à jour de la comptabilité'),
        content: const Text('Voulez-vous synchroniser toutes les ventes, achats et règlements de la gestion vers la comptabilité ?\n\nCela recréera les écritures manquantes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Synchronisation en cours...')));
              await service.syncManagementToAccounting();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comptabilité mise à jour !')));
            },
            child: const Text('Lancer la synchronisation'),
          ),
        ],
      ),
    );
  }
}
