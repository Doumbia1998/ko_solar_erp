import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/firestore_service.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'transaction_form_screen.dart';
import '../services/pdf_service.dart';
import '../services/whatsapp_service.dart';
import '../models/journal_entry.dart';
import '../models/payment.dart';
import '../models/tier.dart';

class TransactionListScreen extends StatefulWidget {
  final TransactionType type;
  const TransactionListScreen({super.key, required this.type});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String _searchQuery = "";
  AppUser? _currentUser;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadUser();
    // Par défaut, voir les 30 derniers jours
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
  }

  Future<void> _loadUser() async {
    final authService = context.read<AuthService>();
    final user = await authService.user.first;
    if (user != null) {
      final appUser = await authService.getAppUser(user.uid);
      if (mounted) setState(() => _currentUser = appUser);
    }
  }

  String _formatAmount(double amount) {
    return amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]} '
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final isSale = widget.type == TransactionType.sale;
    final isQuote = widget.type == TransactionType.quote;
    
    Color color = const Color(0xFF1A237E);
    if (!isSale && !isQuote) color = const Color(0xFF00796B); // Achats
    if (isQuote) color = Colors.purple;

    String title = 'Achats';
    if (isSale) title = 'Ventes';
    if (isQuote) title = 'Devis';

    final isAdminOrManager = _currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.manager;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.black),
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "Période : ${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} au ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    prefixIcon: const Icon(Icons.search),
                    border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
              ),
              StreamBuilder<List<AppTransaction>>(
                stream: firestoreService.getTransactions(type: widget.type),
                builder: (context, snapshot) {
                  var transactions = snapshot.data ?? [];
                  
                  // Filtrage par date
                  transactions = transactions.where((t) => 
                    t.date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                    t.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)))
                  ).toList();

                  double total = transactions.fold(0.0, (sum, t) => sum + t.netToPay);
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isQuote ? 'TOTAL DEVIS' : (isSale ? 'TOTAL CA VENTES' : 'TOTAL ACHATS'),
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${_formatAmount(total)} FCFA',
                                  style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 24),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 30),
                          onPressed: () {
                            PdfService.generateGlobalTransactionReport(
                              type: title,
                              start: _selectedDateRange!.start,
                              end: _selectedDateRange!.end,
                              transactions: transactions,
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: StreamBuilder<List<AppTransaction>>(
                  stream: firestoreService.getTransactions(type: widget.type),
                  builder: (context, snapshotTrans) {
                    return StreamBuilder<List<Payment>>(
                      stream: firestoreService.getPayments(),
                      builder: (context, snapshotPays) {
                        if (snapshotTrans.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        
                        var transactions = snapshotTrans.data ?? [];
                        final payments = snapshotPays.data ?? [];

                        // Filtrage par date
                        transactions = transactions.where((t) => 
                          t.date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                          t.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)))
                        ).toList();

                        if (_searchQuery.isNotEmpty) {
                          transactions = transactions.where((t) => 
                            t.tierName.toLowerCase().contains(_searchQuery) || 
                            t.invoiceNumber.toLowerCase().contains(_searchQuery)
                          ).toList();
                        }

                        if (transactions.isEmpty) return const Center(child: Text('Aucun historique disponible'));

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final t = transactions[index];
                            
                            double realTotalPaid = payments
                                .where((p) => p.invoiceNumber == t.invoiceNumber)
                                .fold(0.0, (sum, p) => sum + p.amount);
                            
                            if (realTotalPaid == 0) realTotalPaid = t.amountPaid;

                            final isMobile = MediaQuery.of(context).size.width < 600;

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: isMobile 
                                ? _buildMobileItem(t, color, isSale, isAdminOrManager, firestoreService, realTotalPaid)
                                : _buildDesktopItem(t, color, isSale, isAdminOrManager, firestoreService, realTotalPaid),
                            );
                          },
                        );
                      }
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionFormScreen(type: widget.type))),
        backgroundColor: color,
        label: Text('Nouveau $title', style: const TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPaymentStatusChip(AppTransaction t, double paidAmount) {
    if (t.type == TransactionType.quote) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple, width: 1),
        ),
        child: const Text("BROUILLON", style: TextStyle(color: Colors.purple, fontSize: 9, fontWeight: FontWeight.bold)),
      );
    }
    
    String text;
    Color color;
    double net = t.netToPay;
    
    if (paidAmount <= 0) {
      text = "Impayée";
      color = Colors.red;
    } else if (paidAmount >= (net - 5)) { 
      text = "Payée";
      color = Colors.green;
    } else {
      text = "Commencée";
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDesktopItem(AppTransaction t, Color color, bool isSale, bool isAdminOrManager, FirestoreService firestoreService, double paidAmount) {
    final isQuote = t.type == TransactionType.quote;
    final isSmallDesktop = MediaQuery.of(context).size.width < 900;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(isQuote ? Icons.request_quote : (isSale ? Icons.shopping_bag : Icons.shopping_cart), color: color),
      ),
      title: Row(
        children: [
          Text('${isQuote ? "Devis" : (isSale ? "Vente" : "Achat")} ${t.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          _buildPaymentStatusChip(t, paidAmount),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.tierName.toUpperCase(), style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('dd/MM/yyyy HH:mm').format(t.date), style: const TextStyle(fontSize: 12)),
              if (t.createdBy.isNotEmpty)
                Text('Fait par: ${t.createdBy}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
            ],
          ),
        ],
      ),
      trailing: SizedBox(
        width: isSmallDesktop ? 220 : 300, 
        child: Wrap(
          spacing: 0,
          alignment: WrapAlignment.end,
          children: [
            Text(
              '${_formatAmount(t.netToPay)} F',
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
            ),
            if (isQuote)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                tooltip: 'Convertir en Vente',
                onPressed: () => _showConvertDialog(context, firestoreService, t),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.share, color: Colors.teal, size: 20),
              tooltip: 'Partager sur WhatsApp',
              onPressed: () => _sendWhatsApp(context, firestoreService, t),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20), 
              onPressed: () => PdfService.generateInvoice(t)
            ),
            if (!isQuote)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.local_shipping, color: Colors.blueGrey, size: 20), 
              onPressed: () => PdfService.generateDeliveryNote(t)
            ),
            if (isAdminOrManager && !isQuote)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.account_balance, color: t.isPosted ? Colors.grey : Colors.teal, size: 20),
                onPressed: t.isPosted ? null : () => _transferToAccounting(context, firestoreService, t),
              ),
            if (isAdminOrManager)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () => _confirmDelete(context, () => firestoreService.deleteTransaction(t.id)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileItem(AppTransaction t, Color color, bool isSale, bool isAdminOrManager, FirestoreService firestoreService, double paidAmount) {
    final isQuote = t.type == TransactionType.quote;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isQuote ? Icons.request_quote : (isSale ? Icons.shopping_bag : Icons.shopping_cart), color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t.invoiceNumber} - ${t.tierName.toUpperCase()}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    _buildPaymentStatusChip(t, paidAmount),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Text('${_formatAmount(t.netToPay)} F', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
            ],
          ),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isQuote)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  onPressed: () => _showConvertDialog(context, firestoreService, t),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.share, color: Colors.teal, size: 20),
                onPressed: () => _sendWhatsApp(context, firestoreService, t),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20), 
                onPressed: () => PdfService.generateInvoice(t)
              ),
              if (!isQuote)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.local_shipping, color: Colors.blueGrey, size: 20), 
                onPressed: () => PdfService.generateDeliveryNote(t)
              ),
              if (isAdminOrManager)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _confirmDelete(context, () => firestoreService.deleteTransaction(t.id)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showConvertDialog(BuildContext context, FirestoreService service, AppTransaction quote) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider le Devis'),
        content: const Text('Voulez-vous transformer ce devis en Facture de Vente ?\n\nIl sera retiré des devis et apparaîtra dans les Ventes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              await service.convertQuoteToSale(quote, _currentUser?.displayName ?? 'Admin');
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devis converti en Facture avec succès !'), backgroundColor: Colors.green));
            }, 
            child: const Text('CONFIRMER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _sendWhatsApp(BuildContext context, FirestoreService service, AppTransaction t) async {
    // Récupérer le numéro du tiers
    final tiers = await service.getTiers(null).first;
    final tier = tiers.firstWhere((element) => element.id == t.tierId);
    
    if (tier.phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le client n\'a pas de numéro de téléphone.')));
      return;
    }

    try {
      await WhatsAppService.sendTransactionToWhatsApp(t, tier.phone);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _transferToAccounting(BuildContext context, FirestoreService service, AppTransaction t) async {
    final journalCode = widget.type == TransactionType.sale ? 'VEN' : 'ACH';
    
    final entry = JournalEntry(
      id: '',
      date: t.date,
      label: '${widget.type == TransactionType.sale ? "Vente" : "Achat"} Facture ${t.invoiceNumber}',
      accountCode: widget.type == TransactionType.sale ? '701' : '601',
      accountLabel: widget.type == TransactionType.sale ? 'Ventes de marchandises' : 'Achats de marchandises',
      debit: widget.type == TransactionType.purchase ? t.totalHT : 0,
      credit: widget.type == TransactionType.sale ? t.totalHT : 0,
      reference: t.id,
      journalCode: journalCode,
    );

    await service.addJournalEntry(entry);
    
    // Marquer la transaction comme comptabilisée
    await service.updateTransactionStatus(t.id, true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transféré en comptabilité avec succès')));
    }
  }

  void _confirmDelete(BuildContext context, VoidCallback onDelete) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer"),
        content: const Text("Voulez-vous supprimer ce document ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Non")),
          TextButton(onPressed: () { onDelete(); Navigator.pop(context); }, child: const Text("Oui", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) setState(() => _selectedDateRange = picked);
  }
}
