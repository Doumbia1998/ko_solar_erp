import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/journal_entry.dart';
import '../models/account.dart';
import '../services/pdf_service.dart';

class ReconciliationScreen extends StatefulWidget {
  const ReconciliationScreen({super.key});

  @override
  State<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends State<ReconciliationScreen> {
  Account? _selectedAccount;
  String _filter = 'Non rapprochées';
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');
  DateTime _reconciliationDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapprochement de trésorerie'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedAccount != null)
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () => _printReport(service),
              tooltip: 'Imprimer l\'état de rapprochement',
            ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar gauche
          Container(
            width: 200,
            color: Colors.grey.shade100,
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Mouvements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                _buildSidebarItem('Non rapprochées', Icons.radio_button_unchecked),
                _buildSidebarItem('Rapprochées', Icons.check_circle_outline),
                _buildSidebarItem('Toutes les écritures', Icons.list),
              ],
            ),
          ),
          // Contenu Principal
          Expanded(
            child: Column(
              children: [
                _buildHeader(service),
                Expanded(child: _buildEntriesList(service)),
                _buildFooter(service),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(String label, IconData icon) {
    bool selected = _filter == label;
    return ListTile(
      leading: Icon(icon, size: 18, color: selected ? Colors.green : Colors.grey),
      title: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      onTap: () => setState(() => _filter = label),
      dense: true,
      selected: selected,
    );
  }

  Widget _buildHeader(FirestoreService service) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade200,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: StreamBuilder<List<Account>>(
                  stream: service.getAccounts(),
                  builder: (context, snapshot) {
                    final accounts = (snapshot.data ?? [])
                        .where((a) => a.nature == 'Banque' || a.nature == 'Caisse')
                        .toList();
                    return DropdownButtonFormField<Account>(
                      value: _selectedAccount,
                      decoration: const InputDecoration(labelText: 'Compte de trésorerie', border: OutlineInputBorder(), isDense: true),
                      items: accounts.map((a) => DropdownMenuItem(value: a, child: Text('${a.code} - ${a.label}'))).toList(),
                      onChanged: (val) => setState(() => _selectedAccount = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _reconciliationDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _reconciliationDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date de rapprochement', border: OutlineInputBorder(), isDense: true),
                    child: Text(DateFormat('dd/MM/yy').format(_reconciliationDate)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBalancesRow(service),
        ],
      ),
    );
  }

  Widget _buildBalancesRow(FirestoreService service) {
    if (_selectedAccount == null) return const SizedBox.shrink();

    return StreamBuilder<List<JournalEntry>>(
      stream: service.getJournalEntries(),
      builder: (context, snapshot) {
        final allEntries = (snapshot.data ?? []).where((e) => e.accountCode == _selectedAccount!.code).toList();
        final reconciled = allEntries.where((e) => e.isReconciled).toList();
        final unreconciled = allEntries.where((e) => !e.isReconciled).toList();

        double soldeCompta = reconciled.fold(0, (sum, e) => sum + (e.debit - e.credit));
        double cumulUnreconciled = unreconciled.fold(0, (sum, e) => sum + (e.debit - e.credit));

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceItem('Solde comptable rapproché', soldeCompta),
              _buildBalanceItem('Cumul non rapproché', cumulUnreconciled),
              _buildBalanceItem('Solde relevé théorique', soldeCompta + cumulUnreconciled, color: Colors.blue.shade900),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceItem(String label, double value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text('${_currencyFormat.format(value)} F', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ],
    );
  }

  Widget _buildEntriesList(FirestoreService service) {
    if (_selectedAccount == null) return const Center(child: Text('Sélectionnez un compte pour commencer le rapprochement'));

    return StreamBuilder<List<JournalEntry>>(
      stream: service.getJournalEntries(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var entries = snapshot.data!.where((e) => e.accountCode == _selectedAccount!.code).toList();

        if (_filter == 'Non rapprochées') {
          entries = entries.where((e) => !e.isReconciled).toList();
        } else if (_filter == 'Rapprochées') {
          entries = entries.where((e) => e.isReconciled).toList();
        }

        if (entries.isEmpty) return const Center(child: Text('Aucun mouvement trouvé pour ce compte.'));

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            headingRowHeight: 35,
            columns: const [
              DataColumn(label: Text('P', style: TextStyle(fontSize: 12))),
              DataColumn(label: Text('Date', style: TextStyle(fontSize: 12))),
              DataColumn(label: Text('N° Pièce', style: TextStyle(fontSize: 12))),
              DataColumn(label: Text('Libellé', style: TextStyle(fontSize: 12))),
              DataColumn(label: Text('Lettrage', style: TextStyle(fontSize: 12))),
              DataColumn(label: Text('Débit', style: TextStyle(fontSize: 12))),
              DataColumn(label: Text('Crédit', style: TextStyle(fontSize: 12))),
            ],
            rows: entries.map((e) => DataRow(
              selected: e.isReconciled,
              cells: [
                DataCell(
                  Checkbox(
                    value: e.isReconciled,
                    onChanged: (val) {
                      service.updateReconciliationStatus(e.id, val!, val ? _reconciliationDate : null);
                    },
                    activeColor: Colors.green,
                  )
                ),
                DataCell(Text(DateFormat('dd/MM/yy').format(e.date), style: const TextStyle(fontSize: 11))),
                DataCell(Text(e.reference, style: const TextStyle(fontSize: 11))),
                DataCell(Text(e.label, style: const TextStyle(fontSize: 11))),
                DataCell(
                  InkWell(
                    onTap: () => _showLetteringDialog(context, service, e),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                      child: Text(e.lettering ?? '---', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                  )
                ),
                DataCell(Text(e.debit > 0 ? _currencyFormat.format(e.debit) : '', style: const TextStyle(fontSize: 11))),
                DataCell(Text(e.credit > 0 ? _currencyFormat.format(e.credit) : '', style: const TextStyle(fontSize: 11))),
              ],
            )).toList(),
          ),
        );
      },
    );
  }

  void _showLetteringDialog(BuildContext context, FirestoreService service, JournalEntry entry) {
    final controller = TextEditingController(text: entry.lettering);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lettrage manuel'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Code de lettrage (ex: A, B...)'),
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              service.updateLettering(entry.id, controller.text.toUpperCase());
              Navigator.pop(context);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _printReport(FirestoreService service) async {
    final entries = await service.getJournalEntries().first;
    var filtered = entries.where((e) => e.accountCode == _selectedAccount!.code).toList();

    if (_filter == 'Non rapprochées') {
      filtered = filtered.where((e) => !e.isReconciled).toList();
    } else if (_filter == 'Rapprochées') {
      filtered = filtered.where((e) => e.isReconciled).toList();
    }

    PdfService.generateReconciliationReport(
      account: _selectedAccount!,
      date: _reconciliationDate,
      entries: filtered,
      filter: _filter.toUpperCase(),
    );
  }

  Widget _buildFooter(FirestoreService service) {
    if (_selectedAccount == null) return const SizedBox.shrink();

    return StreamBuilder<List<JournalEntry>>(
      stream: service.getJournalEntries(),
      builder: (context, snapshot) {
        final entries = (snapshot.data ?? []).where((e) => e.accountCode == _selectedAccount!.code).toList();
        var filtered = entries;
        if (_filter == 'Non rapprochées') filtered = entries.where((e) => !e.isReconciled).toList();
        if (_filter == 'Rapprochées') filtered = entries.where((e) => e.isReconciled).toList();

        double totalDebit = filtered.fold(0, (sum, e) => sum + e.debit);
        double totalCredit = filtered.fold(0, (sum, e) => sum + e.credit);

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Total des écritures affichées : ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 40),
              _buildTotalColumn('Débit', totalDebit),
              const SizedBox(width: 40),
              _buildTotalColumn('Crédit', totalCredit),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalColumn(String label, double val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10)),
        Text(_currencyFormat.format(val), style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
