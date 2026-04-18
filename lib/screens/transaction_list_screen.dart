import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/firestore_service.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'transaction_form_screen.dart';
import '../services/pdf_service.dart';
import '../models/journal_entry.dart';

class TransactionListScreen extends StatefulWidget {
  final TransactionType type;
  const TransactionListScreen({super.key, required this.type});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String _searchQuery = "";
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
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
    final color = isSale ? const Color(0xFF1A237E) : const Color(0xFF00796B);
    final title = isSale ? 'Ventes' : 'Achats';
    final isAdminOrManager = _currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.manager;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Rechercher par client ou facture...',
                    prefixIcon: const Icon(Icons.search),
                    border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
              ),
              StreamBuilder<List<AppTransaction>>(
                stream: firestoreService.getTransactions(type: widget.type),
                builder: (context, snapshot) {
                  final transactions = snapshot.data ?? [];
                  double total = transactions.fold(0.0, (sum, t) => sum + t.totalHT);
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 8, // Espace entre les lignes si ça wrap
                          children: [
                            Text(
                              isSale ? 'TOTAL CA VENTES' : 'TOTAL ACHATS',
                              style: const TextStyle(
                                color: Colors.white, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 16
                              ),
                            ),
                        Text(
                          '${_formatAmount(total)} FCFA',
                          style: const TextStyle(
                            color: Colors.yellow, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 20
                          ),
                        ),
                          ],
                        );
                      }
                    ),
                  );
                },
              ),
              Expanded(
                child: StreamBuilder<List<AppTransaction>>(
                  stream: firestoreService.getTransactions(type: widget.type),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    
                    var transactions = snapshot.data ?? [];
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
                        final isMobile = MediaQuery.of(context).size.width < 600;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: isMobile 
                            ? _buildMobileItem(t, color, isSale, isAdminOrManager, firestoreService)
                            : _buildDesktopItem(t, color, isSale, isAdminOrManager, firestoreService),
                        );
                      },
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
        label: Text('Nouvel ${isSale ? "Vente" : "Achat"}', style: const TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDesktopItem(AppTransaction t, Color color, bool isSale, bool isAdminOrManager, FirestoreService firestoreService) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(isSale ? Icons.shopping_bag : Icons.shopping_cart, color: color),
      ),
      title: Text('${isSale ? "Vente" : "Achat"} ${t.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
      trailing: Wrap(
        spacing: 8,
        children: [
          Text(
            '${_formatAmount(t.totalHT)} F',
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
          ),
          if (isAdminOrManager)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 22), 
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionFormScreen(type: widget.type, transaction: t))),
            ),
          IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22), onPressed: () => PdfService.generateInvoice(t)),
          if (isAdminOrManager)
            IconButton(
              icon: Icon(
                Icons.account_balance, 
                color: t.isPosted ? Colors.grey : Colors.teal, 
                size: 22
              ),
              tooltip: t.isPosted ? 'Déjà comptabilisé' : 'Comptabiliser',
              onPressed: t.isPosted ? null : () => _transferToAccounting(context, firestoreService, t),
            ),
          if (isAdminOrManager)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 22),
              onPressed: () => _confirmDelete(context, () => firestoreService.deleteTransaction(t.id)),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileItem(AppTransaction t, Color color, bool isSale, bool isAdminOrManager, FirestoreService firestoreService) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(isSale ? Icons.shopping_bag : Icons.shopping_cart, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${isSale ? "Vente" : "Achat"} ${t.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(t.tierName.toUpperCase(), style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
              Text(
                '${NumberFormat('#,###').format(t.totalHT)} F',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('dd/MM/yy HH:mm').format(t.date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  if (t.createdBy.isNotEmpty)
                    Text('Fait par: ${t.createdBy}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                ],
              ),
              Row(
                children: [
                  if (isAdminOrManager)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20), 
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionFormScreen(type: widget.type, transaction: t))),
                    ),
                  IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20), onPressed: () => PdfService.generateInvoice(t)),
                  if (isAdminOrManager)
                    IconButton(
                      icon: Icon(Icons.account_balance, color: t.isPosted ? Colors.grey : Colors.teal, size: 20),
                      onPressed: t.isPosted ? null : () => _transferToAccounting(context, firestoreService, t),
                    ),
                  if (isAdminOrManager)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _confirmDelete(context, () => firestoreService.deleteTransaction(t.id)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
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
}
