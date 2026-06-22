import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import '../models/expense.dart';
import '../models/account.dart';
import '../models/journal_config.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _format = NumberFormat('#,###', 'fr_FR');
  final _labelController = TextEditingController();
  final _amountController = TextEditingController();
  Account? _selectedAccount;
  String? _selectedJournal;
  String _selectedMethod = 'Espèces';

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTION DES DÉPENSES'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Rapports des dépenses',
            onPressed: () => _showReportDialog(context, service),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<List<Expense>>(
        stream: service.getExpenses(),
        builder: (context, snapshot) {
          final expenses = snapshot.data ?? [];
          // Calcul du solde : les alimentations sont stockées avec un montant négatif dans notre logique
          // Solde = - somme de tous les montants (car dépense est positif et alimentation est négatif)
          double soldeCaisse = -expenses.fold(0.0, (sum, e) => sum + e.amount);

          return Column(
            children: [
              // Header Solde Caisse
              Container(
                padding: const EdgeInsets.all(20),
                color: const Color(0xFFE8EAF6),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SOLDE CAISSE DÉPENSES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        Text('${_format.format(soldeCaisse).replaceAll(',', ' ')} FCFA', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: soldeCaisse >= 0 ? Colors.green.shade800 : Colors.red)),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showAddFundDialog(context, service),
                      icon: const Icon(Icons.add_card),
                      label: const Text('ALIMENTER LA CAISSE'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                    ),
                  ],
                ),
              ),
              _buildAddForm(service),
              const Divider(thickness: 2),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('HISTORIQUE DES OPÉRATIONS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              ),
              Expanded(
                child: expenses.isEmpty
                  ? const Center(child: Text('Aucune opération enregistrée.'))
                  : ListView.builder(
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final e = expenses[index];
                        bool isFund = e.category == 'FOND_DE_CAISSE';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          color: isFund ? Colors.green.shade50 : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isFund ? Colors.green : Colors.redAccent,
                              child: Icon(isFund ? Icons.add : Icons.remove, color: Colors.white)
                            ),
                            title: Text(e.label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('Compte: ${e.accountCode} | Journal: ${e.journalCode}\nFait par: ${e.createdBy} le ${DateFormat('dd/MM/yy').format(e.date)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${isFund ? "+" : ""}${_format.format(e.amount.abs()).replaceAll(',', ' ')} F',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isFund ? Colors.green : Colors.red, fontSize: 16)),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                  onPressed: () => _confirmDelete(e),
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
      ),
    );
  }

  Widget _buildAddForm(FirestoreService service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NOUVELLE DÉPENSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A237E))),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _labelController,
                  decoration: const InputDecoration(labelText: 'Désignation de la dépense', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant Net', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance_wallet, color: Colors.red)),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<List<Account>>(
                  stream: service.getAccounts(),
                  builder: (context, snapshot) {
                    final accounts = (snapshot.data ?? []).where((a) => a.code.startsWith('6')).toList();
                    return DropdownButtonFormField<Account>(
                      value: _selectedAccount,
                      decoration: const InputDecoration(labelText: 'Compte de charge (Classe 6)', border: OutlineInputBorder()),
                      items: accounts.map((a) => DropdownMenuItem(value: a, child: Text('${a.code} - ${a.label}'))).toList(),
                      onChanged: (val) => setState(() => _selectedAccount = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: StreamBuilder<List<JournalConfig>>(
                  stream: service.getJournalConfigs(),
                  builder: (context, snapshot) {
                    final configs = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: _selectedJournal,
                      decoration: const InputDecoration(labelText: 'Journal', border: OutlineInputBorder()),
                      items: configs.map((c) => DropdownMenuItem(value: c.code, child: Text(c.code))).toList(),
                      onChanged: (val) => setState(() => _selectedJournal = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMethod,
                  decoration: const InputDecoration(labelText: 'Mode de règlement', border: OutlineInputBorder()),
                  items: ['Espèces', 'Chèque', 'Virement', 'Banque BIM SA'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _selectedMethod = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _saveExpense,
              icon: const Icon(Icons.check_circle, size: 24),
              label: const Text('VALIDER ET ENREGISTRER EN COMPTABILITÉ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
    );
  }

  void _saveExpense() async {
    if (_labelController.text.isEmpty || _amountController.text.isEmpty || _selectedAccount == null || _selectedJournal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires.')));
      return;
    }
    final auth = Provider.of<AuthService>(context, listen: false);
    final service = Provider.of<FirestoreService>(context, listen: false);
    final user = await auth.getAppUser((await auth.user.first)!.uid);

    final expense = Expense(
      id: '', date: DateTime.now(), label: _labelController.text,
      amount: double.tryParse(_amountController.text) ?? 0,
      category: 'DÉPENSE', accountCode: _selectedAccount!.code,
      journalCode: _selectedJournal!, paymentMethod: _selectedMethod,
      createdBy: user?.displayName ?? 'Admin',
    );
    await service.addExpense(expense);
    _labelController.clear(); _amountController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dépense enregistrée avec succès !'), backgroundColor: Colors.green));
  }

  void _showAddFundDialog(BuildContext context, FirestoreService service) {
    final amountCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    String? selectedJournal;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alimenter la Caisse (Entrée de fonds)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant à entrer')),
            const SizedBox(height: 10),
            TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Libellé (ex: Provision Hebdomadaire)')),
            const SizedBox(height: 10),
            StreamBuilder<List<JournalConfig>>(
              stream: service.getJournalConfigs(),
              builder: (context, snapshot) {
                final configs = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Journal'),
                  items: configs.map((c) => DropdownMenuItem(value: c.code, child: Text(c.code))).toList(),
                  onChanged: (val) => selectedJournal = val,
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () async {
              if (amountCtrl.text.isEmpty || selectedJournal == null) return;
              final auth = Provider.of<AuthService>(context, listen: false);
              final user = await auth.getAppUser((await auth.user.first)!.uid);
              await service.addCashFund(double.parse(amountCtrl.text), selectedJournal!, labelCtrl.text, user?.displayName ?? 'Admin');
              Navigator.pop(context);
            },
            child: const Text('VALIDER L\'ENTRÉE'),
          )
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, FirestoreService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sélectionner la période du rapport'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.date_range, color: Colors.blue),
              title: const Text('Choisir une période personnalisée'),
              subtitle: const Text('Date début au Date fin'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365))
                );
                if (picked != null) {
                  final exps = await service.getExpenses().first;
                  final filtered = exps.where((e) =>
                    e.date.isAfter(picked.start.subtract(const Duration(days: 1))) &&
                    e.date.isBefore(picked.end.add(const Duration(days: 1)))
                  ).toList();
                  PdfService.generateExpenseReport(filtered, 'Personnalisé', range: picked);
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.today, color: Colors.green),
              title: const Text('Rapport d\'aujourd\'hui'),
              onTap: () async {
                Navigator.pop(context);
                final exps = await service.getExpenses().first;
                final now = DateTime.now();
                final today = exps.where((e) => e.date.year == now.year && e.date.month == now.month && e.date.day == now.day).toList();
                PdfService.generateExpenseReport(today, 'Journalier');
              },
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER'))],
      ),
    );
  }

  void _confirmDelete(Expense e) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette opération ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () async {
              final auth = Provider.of<AuthService>(context, listen: false);
              final user = await auth.getAppUser((await auth.user.first)!.uid);
              await Provider.of<FirestoreService>(context, listen: false).deleteExpense(e.id, user?.displayName ?? 'Admin');
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    );
  }
}
