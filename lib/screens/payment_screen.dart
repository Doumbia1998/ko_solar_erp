import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/payment.dart';
import '../models/tier.dart';
import '../models/journal_entry.dart';
import '../services/pdf_service.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');
  String _searchQuery = "";
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTION DES RÈGLEMENTS'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Imprimer le rapport PDF',
            onPressed: () => _generatePaymentReport(context, firestoreService),
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
          ),
          if (_startDate != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => setState(() {
                _startDate = null;
                _endDate = null;
              }),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Clients'),
            Tab(text: 'Fournisseurs'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un tiers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Période: ${DateFormat('dd/MM/yy').format(_startDate!)} au ${DateFormat('dd/MM/yy').format(_endDate!)}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPaymentList(firestoreService, TierType.client),
                _buildPaymentList(firestoreService, TierType.supplier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF1A237E))), child: child!),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Widget _buildPaymentList(FirestoreService service, TierType type) {
    return StreamBuilder<List<Payment>>(
      stream: service.getPayments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        var list = snapshot.data?.where((p) => p.tierType == type).toList() ?? [];

        // Filtrage par recherche
        if (_searchQuery.isNotEmpty) {
          list = list.where((p) => p.tierName.toLowerCase().contains(_searchQuery)).toList();
        }

        // Filtrage par date
        if (_startDate != null && _endDate != null) {
          list = list.where((p) => p.date.isAfter(_startDate!.subtract(const Duration(days: 1))) && 
                                  p.date.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
        }

        double total = list.fold(0.0, (sum, p) => sum + p.amount);

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: type == TierType.client ? Colors.blue.shade900 : Colors.green.shade900,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TOTAL RÈGLEMENTS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text("${_currencyFormat.format(total)} FCFA", style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty 
                ? const Center(child: Text('Aucun règlement trouvé'))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final p = list[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: type == TierType.client ? Colors.blue[100] : Colors.green[100],
                          child: Icon(type == TierType.client ? Icons.arrow_downward : Icons.arrow_upward, 
                                     color: type == TierType.client ? Colors.blue : Colors.green),
                        ),
                        title: Text(p.tierName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${DateFormat('dd/MM/yyyy').format(p.date)} - ${p.method}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${_currencyFormat.format(p.amount)} F', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: Icon(
                                Icons.account_balance, 
                                color: p.isPosted ? Colors.grey : Colors.teal, 
                                size: 20
                              ),
                              tooltip: p.isPosted ? 'Déjà comptabilisé' : 'Comptabiliser',
                              onPressed: p.isPosted ? null : () => _transferPaymentToAccounting(context, service, p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => _confirmDelete(context, () => service.deletePayment(p.id)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        );
      },
    );
  }

  void _transferPaymentToAccounting(BuildContext context, FirestoreService service, Payment p) async {
    // Déterminer le journal (BQ pour Banque, CAI pour Espèces/Mobile)
    String journalCode = (p.method.toLowerCase().contains('banque') || p.method.toLowerCase().contains('virement')) ? 'BQ' : 'CAI';
    
    // Déterminer le compte de contrepartie (411 pour Client, 401 pour Fournisseur)
    String tiersAccount = p.tierType == TierType.client ? '411' : '401';
    
    // Déterminer le compte de trésorerie (521 pour Banque, 571 pour Caisse)
    String tresoAccount = journalCode == 'BQ' ? '521' : '571';
    String tresoLabel = journalCode == 'BQ' ? 'Banque' : 'Caisse';

    // Créer la ligne de trésorerie (521 ou 571)
    final tresoEntry = JournalEntry(
      id: '',
      date: p.date,
      label: 'Règlement ${p.tierName} (${p.method})',
      accountCode: tresoAccount,
      accountLabel: tresoLabel,
      debit: p.tierType == TierType.client ? p.amount : 0,
      credit: p.tierType == TierType.supplier ? p.amount : 0,
      reference: p.id,
      journalCode: journalCode,
    );

    // Créer la ligne de contrepartie (411 ou 401)
    final tiersEntry = JournalEntry(
      id: '',
      date: p.date,
      label: 'Contrepartie règlement ${p.tierName}',
      accountCode: tiersAccount,
      accountLabel: p.tierType == TierType.client ? 'Clients' : 'Fournisseurs',
      debit: p.tierType == TierType.supplier ? p.amount : 0,
      credit: p.tierType == TierType.client ? p.amount : 0,
      reference: p.id,
      journalCode: journalCode,
    );

    await service.addJournalEntry(tresoEntry);
    await service.addJournalEntry(tiersEntry);
    
    // Marquer le règlement comme comptabilisé
    await service.updatePaymentStatus(p.id, true);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Règlement comptabilisé (Débit/Crédit)')));
    }
  }

  Future<void> _generatePaymentReport(BuildContext context, FirestoreService service) async {
    final payments = await service.getPayments().first;
    List<Payment> filtered = payments;

    // Appliquer les mêmes filtres que l'affichage
    if (_startDate != null && _endDate != null) {
      filtered = payments.where((p) => 
        p.date.isAfter(_startDate!.subtract(const Duration(days: 1))) && 
        p.date.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
    } else {
      // Si pas de date, par défaut aujourd'hui
      final now = DateTime.now();
      filtered = payments.where((p) => 
        p.date.year == now.year && p.date.month == now.month && p.date.day == now.day).toList();
    }

    if (filtered.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun règlement à imprimer pour cette période')));
      }
      return;
    }
    
    // Appel du service PDF (On va créer cette méthode)
    // ignore: use_build_context_synchronously
    PdfService.generatePaymentReport(filtered, _startDate, _endDate);
  }

  void _confirmDelete(BuildContext context, VoidCallback onDelete) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer"),
        content: const Text("Voulez-vous supprimer ce règlement ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Non")),
          TextButton(onPressed: () { onDelete(); Navigator.pop(context); }, child: const Text("Oui", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
