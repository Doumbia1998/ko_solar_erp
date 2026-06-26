import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/firestore_service.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'transaction_form_screen.dart';
import '../services/pdf_service.dart';
import '../services/whatsapp_service.dart';
import '../services/report_service.dart';
import '../models/journal_entry.dart';
import '../models/payment.dart';
import '../models/tier.dart';
import 'audit_logs_screen.dart';

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
  String _paymentStatusFilter = "Tous";

  @override
  void initState() {
    super.initState();
    _loadUser();
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
    return NumberFormat('#,###', 'fr_FR').format(amount.toInt()).replaceAll(',', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final isSale = widget.type == TransactionType.sale;
    final isQuote = widget.type == TransactionType.quote;
    
    Color color = const Color(0xFF1A237E);
    if (!isSale && !isQuote) color = const Color(0xFF00796B);
    if (isQuote) color = Colors.purple;

    String title = 'Achats';
    if (isSale) title = 'Ventes';
    if (isQuote) title = 'Devis';

    final isWeb = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.black),
            onPressed: _pickDateRange,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isWeb ? 1600 : double.infinity),
          padding: EdgeInsets.symmetric(horizontal: isWeb ? 30 : 0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!isQuote)
                      Row(
                        children: [
                          _statusFilterChip("Tous"),
                          _statusFilterChip("Impayée"),
                          _statusFilterChip("Commencée"),
                          _statusFilterChip("Payée"),
                          _statusFilterChip("Retour"),
                        ],
                      )
                    else
                      const SizedBox(),
                    Text(
                      "Période : ${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} au ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un client, N° facture...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                  ),
                ),
              ),
              StreamBuilder<List<AppTransaction>>(
                stream: firestoreService.getTransactions(type: widget.type),
                builder: (context, snapshot) {
                  var transactions = snapshot.data ?? [];
                  transactions = transactions.where((t) => 
                    t.date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                    t.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)))
                  ).toList();

                  double total = transactions.fold(0.0, (sum, t) => sum + t.netToPay);
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isQuote ? 'TOTAL DEVIS' : (isSale ? 'TOTAL CA VENTES' : 'TOTAL ACHATS'),
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${_formatAmount(total)} FCFA',
                              style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 22),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.print, color: Colors.white),
                              tooltip: 'Rapport détaillé',
                              onPressed: () => ReportService.generateDailyActivityReport(transactions, title),
                            ),
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                              onPressed: () => PdfService.generateGlobalTransactionReport(
                                type: title,
                                start: _selectedDateRange!.start,
                                end: _selectedDateRange!.end,
                                transactions: transactions,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: StreamBuilder<List<AppTransaction>>(
                  stream: firestoreService.getTransactions(),
                  builder: (context, snapshotTrans) {
                    return StreamBuilder<List<Payment>>(
                      stream: firestoreService.getPayments(),
                      builder: (context, snapshotPays) {
                        if (snapshotTrans.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        
                        var transactions = snapshotTrans.data ?? [];
                        final payments = snapshotPays.data ?? [];

                        transactions = transactions.where((t) {
                          bool isBaseType = t.type == widget.type;
                          bool isReturnType = false;
                          if (widget.type == TransactionType.sale) isReturnType = t.type == TransactionType.saleReturn;
                          if (widget.type == TransactionType.purchase) isReturnType = t.type == TransactionType.purchaseReturn;
                          return (isBaseType || isReturnType) &&
                            t.date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                            t.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
                        }).toList();

                        if (_searchQuery.isNotEmpty) {
                          transactions = transactions.where((t) => 
                            t.tierName.toLowerCase().contains(_searchQuery) || 
                            t.invoiceNumber.toLowerCase().contains(_searchQuery)
                          ).toList();
                        }

                        if (_paymentStatusFilter != "Tous") {
                          transactions = transactions.where((t) {
                            double net = t.netToPay;
                            double paid = payments.where((p) => p.invoiceNumber == t.invoiceNumber).fold(0.0, (sum, p) => sum + p.amount);
                            if (paid == 0) paid = t.amountPaid;
                            if (_paymentStatusFilter == "Impayée") return paid <= 0;
                            if (_paymentStatusFilter == "Payée") return paid >= (net - 5);
                            if (_paymentStatusFilter == "Commencée") return paid > 0 && paid < (net - 5);
                            if (_paymentStatusFilter == "Retour") return t.type == TransactionType.saleReturn || t.type == TransactionType.purchaseReturn;
                            return true;
                          }).toList();
                        }

                        if (transactions.isEmpty) return const Center(child: Text('Aucun document trouvé.'));

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final t = transactions[index];
                            double realTotalPaid = payments
                                .where((p) => p.invoiceNumber == t.invoiceNumber)
                                .fold(0.0, (sum, p) => sum + p.amount);
                            if (realTotalPaid == 0) realTotalPaid = t.amountPaid;

                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: _buildItem(t, color, isSale, firestoreService, realTotalPaid),
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
        label: Text('NOUVEAU $title', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _statusFilterChip(String status) {
    bool isSelected = _paymentStatusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(status, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        onSelected: (bool selected) => setState(() => _paymentStatusFilter = status),
        selectedColor: const Color(0xFF1A237E),
        backgroundColor: Colors.grey.shade200,
        checkmarkColor: Colors.white,
      ),
    );
  }

  Widget _buildItem(AppTransaction t, Color color, bool isSale, FirestoreService firestoreService, double paidAmount) {
    final isQuote = t.type == TransactionType.quote;
    final isReturn = t.type == TransactionType.saleReturn || t.type == TransactionType.purchaseReturn;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: (isReturn ? Colors.red : color).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(isQuote ? Icons.request_quote : (isReturn ? Icons.assignment_return : (isSale ? Icons.shopping_bag : Icons.shopping_cart)), color: isReturn ? Colors.red : color, size: 24),
            ),
            title: Row(
              children: [
                Expanded(child: Text('${isQuote ? "Devis" : (isReturn ? "Retour" : (isSale ? "Vente" : "Achat"))} ${t.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                const SizedBox(width: 10),
                _buildPaymentStatusChip(t, paidAmount),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.tierName.toUpperCase(), style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13)),
                Row(
                  children: [
                    Text(DateFormat('dd/MM/yyyy HH:mm').format(t.date), style: const TextStyle(fontSize: 11)),
                    if (t.createdBy.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text('Fait par: ${t.createdBy}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                    ],
                  ],
                ),
                if (t.dueDate != null && paidAmount < t.netToPay - 10)
                  Text('Échéance : ${DateFormat('dd/MM/yy').format(t.dueDate!)}', style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: isMobile ? null : Text('${_formatAmount(t.netToPay)} F', style: TextStyle(fontWeight: FontWeight.bold, color: isReturn ? Colors.red : color, fontSize: 16)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionFormScreen(type: widget.type, transaction: t))),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isMobile) Text('${_formatAmount(t.netToPay)} F', style: TextStyle(fontWeight: FontWeight.bold, color: isReturn ? Colors.red : color, fontSize: 14)) else const SizedBox(),
                _buildActionButtons(t, firestoreService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusChip(AppTransaction t, double paidAmount) {
    if (t.type == TransactionType.quote) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purple, width: 1)),
        child: const Text("BROUILLON", style: TextStyle(color: Colors.purple, fontSize: 9, fontWeight: FontWeight.bold)),
      );
    }
    String text; Color c; double net = t.netToPay;
    if (t.type == TransactionType.saleReturn || t.type == TransactionType.purchaseReturn) {
      text = "Retourné"; c = Colors.red;
    } else {
      if (paidAmount <= 0) { text = "Impayée"; c = Colors.red; }
      else if (paidAmount >= (net - 5)) { text = "Payée"; c = Colors.green; }
      else { text = "Commencée"; c = Colors.orange; }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: c, width: 1)),
      child: Text(text.toUpperCase(), style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButtons(AppTransaction t, FirestoreService firestoreService) {
    final isQuote = t.type == TransactionType.quote;
    final isAdminOrManager = _currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.manager;
    final canDelete = isAdminOrManager || _currentUser?.canDeleteSales == true;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isQuote) IconButton(icon: const Icon(Icons.check_circle, color: Colors.green, size: 22), tooltip: 'Valider', onPressed: () => _showConvertDialog(context, firestoreService, t)),
        IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), tooltip: 'Modifier', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionFormScreen(type: widget.type, transaction: t)))),
        IconButton(icon: const Icon(Icons.share, color: Colors.teal, size: 20), tooltip: 'WhatsApp', onPressed: () => WhatsAppService.sendTransactionToWhatsApp(t, t.tierId)),
        IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20), tooltip: 'Facture PDF', onPressed: () => PdfService.generateInvoice(t)),
        if (!isQuote && t.type != TransactionType.saleReturn && t.type != TransactionType.purchaseReturn)
          IconButton(
            icon: const Icon(Icons.assignment_return, color: Colors.orange, size: 20),
            tooltip: 'Effectuer un Retour',
            onPressed: () => _showPartialReturnDialog(context, firestoreService, t),
          ),
        if (!isQuote)
          IconButton(
            icon: const Icon(Icons.local_shipping, color: Colors.blueGrey, size: 20),
            tooltip: 'Bon de Livraison',
            onPressed: () => PdfService.generateDeliveryNote(t)
          ),
        if (isAdminOrManager && !isQuote)
          IconButton(
            icon: Icon(Icons.account_balance, color: t.isPosted ? Colors.grey : Colors.teal, size: 20),
            tooltip: t.isPosted ? 'Déjà comptabilisé' : 'Transférer en Compta',
            onPressed: t.isPosted ? null : () => _transferToAccounting(context, firestoreService, t),
          ),
        if (canDelete) IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), tooltip: 'Supprimer', onPressed: () => _confirmDelete(context, () => firestoreService.deleteTransaction(t.id, _currentUser?.displayName ?? 'Admin'))),
      ],
    );
  }

  void _showPartialReturnDialog(BuildContext context, FirestoreService service, AppTransaction tx) {
    // Créer une copie des articles pour gérer les quantités à retourner
    final Map<String, int> returnQuantities = {};
    for (var item in tx.items) {
      returnQuantities[item.productId] = 0;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Retour sur Facture ${tx.invoiceNumber}'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Saisissez les quantités à retourner pour chaque article :', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  ...tx.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(item.productName.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          Text('(${item.quantity} vendus)', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              initialValue: '0',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                              onChanged: (val) {
                                int q = int.tryParse(val) ?? 0;
                                if (q > item.quantity) q = item.quantity;
                                returnQuantities[item.productId] = q;
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  // Vérifier si au moins un article est retourné
                  if (returnQuantities.values.every((q) => q == 0)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez saisir au moins une quantité à retourner.')));
                    return;
                  }

                  Navigator.pop(context);

                  final List<TransactionItem> returnItems = [];
                  double returnHT = 0;

                  for (var item in tx.items) {
                    int q = returnQuantities[item.productId] ?? 0;
                    if (q > 0) {
                      double unitTotal = (q * item.unitPrice);
                      // On proratise la remise
                      double proratedDiscount = (item.discount / item.quantity) * q;
                      returnItems.add(TransactionItem(
                        productId: item.productId,
                        productName: item.productName,
                        quantity: q,
                        unitPrice: item.unitPrice,
                        discount: proratedDiscount,
                      ));
                      returnHT += (unitTotal - proratedDiscount);
                    }
                  }

                  final returnTx = AppTransaction(
                    id: '',
                    invoiceNumber: 'RET-${tx.invoiceNumber}-${DateFormat('HHmm').format(DateTime.now())}',
                    date: DateTime.now(),
                    tierId: tx.tierId,
                    tierName: tx.tierName,
                    type: tx.type == TransactionType.sale ? TransactionType.saleReturn : TransactionType.purchaseReturn,
                    items: returnItems,
                    totalHT: returnHT,
                    amountPaid: 0,
                    paymentMethod: tx.paymentMethod,
                    warehouseId: tx.warehouseId,
                    destination: tx.destination,
                    transportFees: 0, // Pas de transport sur un retour
                    addTransport: false,
                    createdBy: _currentUser?.displayName ?? 'Admin',
                  );

                  await service.addTransaction(returnTx, _currentUser?.displayName ?? 'Admin');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Facture de retour générée !'), backgroundColor: Colors.green));
                },
                child: const Text('VALIDER LE RETOUR', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showConvertDialog(BuildContext context, FirestoreService service, AppTransaction quote) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider le Devis'),
        content: const Text('Voulez-vous transformer ce devis en Facture de Vente ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () async {
            Navigator.pop(context);
            await service.convertQuoteToSale(quote, _currentUser?.displayName ?? 'Admin');
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devis converti !'), backgroundColor: Colors.green));
          }, child: const Text('CONFIRMER', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  void _transferToAccounting(BuildContext context, FirestoreService service, AppTransaction t) async {
    final journalCode = widget.type == TransactionType.sale ? 'VEN' : 'ACH';
    final String tierAccount = widget.type == TransactionType.sale ? '411100' : '401100';
    final String tierLabel = widget.type == TransactionType.sale ? 'Clients' : 'Fournisseurs';
    String htAccount = widget.type == TransactionType.sale ? '701100' : '601100';
    String htLabel = widget.type == TransactionType.sale ? 'Ventes de marchandises' : 'Achats de marchandises';

    if (t.items.isNotEmpty) {
      final allProducts = await service.getProducts().first;
      final prod = allProducts.firstWhere((p) => p.id == t.items.first.productId);
      if (widget.type == TransactionType.sale) {
        htAccount = prod.compteVente;
      } else {
        htAccount = prod.compteAchat;
      }
    }

    final entry1 = JournalEntry(
      id: '', date: t.date, label: '${widget.type == TransactionType.sale ? "Vente" : "Achat"} Facture ${t.invoiceNumber}',
      accountCode: tierAccount, accountLabel: tierLabel,
      debit: widget.type == TransactionType.sale ? t.totalHT : 0,
      credit: widget.type == TransactionType.purchase ? t.totalHT : 0,
      reference: t.invoiceNumber, journalCode: journalCode, tierId: t.tierId, tierName: t.tierName,
    );

    final entry2 = JournalEntry(
      id: '', date: t.date, label: '${widget.type == TransactionType.sale ? "Vente" : "Achat"} Facture ${t.invoiceNumber}',
      accountCode: htAccount, accountLabel: htLabel,
      debit: widget.type == TransactionType.purchase ? t.totalHT : 0,
      credit: widget.type == TransactionType.sale ? t.totalHT : 0,
      reference: t.invoiceNumber, journalCode: journalCode,
    );

    await service.addJournalEntry(entry1);
    await service.addJournalEntry(entry2);
    await service.updateTransactionStatus(t.id, true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transféré en comptabilité avec succès')));
    }
  }

  void _confirmDelete(BuildContext context, VoidCallback onDelete) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Supprimer"), content: const Text("Voulez-vous supprimer ce document ?"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Non")), TextButton(onPressed: () { onDelete(); Navigator.pop(context); }, child: const Text("Oui", style: TextStyle(color: Colors.red)))]));
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)), initialDateRange: _selectedDateRange);
    if (picked != null) setState(() => _selectedDateRange = picked);
  }
}
