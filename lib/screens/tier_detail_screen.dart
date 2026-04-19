import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/tier.dart';
import '../models/transaction.dart';
import '../models/payment.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';

class TierDetailScreen extends StatefulWidget {
  final Tier tier;
  const TierDetailScreen({super.key, required this.tier});

  @override
  State<TierDetailScreen> createState() => _TierDetailScreenState();
}

class _TierDetailScreenState extends State<TierDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tier.name.toUpperCase()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Utilisation d'un seul StreamBuilder combiné ou de deux StreamBuilders imbriqués
          StreamBuilder<List<AppTransaction>>(
            stream: firestoreService.getTransactions(),
            builder: (context, snapshotTrans) {
              return StreamBuilder<List<Payment>>(
                stream: firestoreService.getPayments(tierId: widget.tier.id),
                builder: (context, snapshotPay) {
                  double totalDu = 0;
                  double dejaPaye = 0;
                  
                  if (snapshotTrans.hasData) {
                    final transactions = snapshotTrans.data!.where((t) => t.tierId == widget.tier.id).toList();
                    totalDu = transactions.fold(0.0, (sum, t) => sum + t.netToPay);
                    dejaPaye = transactions.fold(0.0, (sum, t) => sum + t.amountPaid);
                  }
                  
                  if (snapshotPay.hasData) {
                    dejaPaye += snapshotPay.data!.fold(0.0, (sum, p) => sum + p.amount);
                  }

                  return Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    color: Colors.blue[50],
                    child: Column(
                      children: [
                        _buildDetailRow('Total dû (Net)', '${NumberFormat('#,###', 'fr_FR').format(totalDu)} FCFA'),
                        _buildDetailRow('Payé', '${NumberFormat('#,###', 'fr_FR').format(dejaPaye)} FCFA'),
                        _buildDetailRow('Reste à Payer', '${NumberFormat('#,###', 'fr_FR').format(totalDu - dejaPaye)} FCFA', isBold: true),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => _showPaymentDialog(context, firestoreService),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Effectuer un règlement', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 20),
          const Text('HISTORIQUE DES OPÉRATIONS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          Expanded(
            child: StreamBuilder<List<AppTransaction>>(
              stream: firestoreService.getTransactions(),
              builder: (context, snapshotTrans) {
                return StreamBuilder<List<Payment>>(
                  stream: firestoreService.getPayments(tierId: widget.tier.id),
                  builder: (context, snapshotPay) {
                    if (snapshotTrans.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    
                    final transactions = snapshotTrans.data?.where((t) => t.tierId == widget.tier.id).toList() ?? [];
                    final payments = snapshotPay.data ?? [];
                    
                    if (transactions.isEmpty) return const Center(child: Text('Aucune opération enregistrée'));

                    return ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final t = transactions[index];
                        
                        // Calcul du payé pour CETTE facture spécifique
                        double payeFacture = t.amountPaid; // Acompte initial
                        payeFacture += payments
                            .where((p) => p.invoiceNumber == t.invoiceNumber)
                            .fold(0.0, (sum, p) => sum + p.amount);
                        
                        double soldeFacture = t.netToPay - payeFacture;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ExpansionTile(
                            leading: Icon(t.type == TransactionType.sale ? Icons.arrow_upward : Icons.arrow_downward, 
                                         color: t.type == TransactionType.sale ? Colors.blue : Colors.green),
                            title: Text('${t.invoiceNumber} | Solde: ${NumberFormat('#,###').format(soldeFacture)} F', 
                                        style: TextStyle(fontWeight: FontWeight.bold, color: soldeFacture > 0 ? Colors.red : Colors.green)),
                            subtitle: Text('Total: ${NumberFormat('#,###').format(t.netToPay)} F | Date: ${DateFormat('dd/MM/yy').format(t.date)}'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (t.destination.isNotEmpty)
                                      Text('Destination: ${t.destination}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                                    const Divider(),
                                    const Text('Détail des règlements :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(height: 5),
                                    Text('• Acompte initial : ${NumberFormat('#,###').format(t.amountPaid)} F'),
                                    ...payments.where((p) => p.invoiceNumber == t.invoiceNumber).map((p) => 
                                      Text('• ${DateFormat('dd/MM/yy').format(p.date)} (${p.method}) : ${NumberFormat('#,###').format(p.amount)} F')
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Fait par : ${t.createdBy}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                                        ElevatedButton.icon(
                                          onPressed: () => PdfService.generateInvoice(t, payments: payments),
                                          icon: const Icon(Icons.picture_as_pdf, size: 16),
                                          label: const Text('Facture PDF', style: TextStyle(fontSize: 12)),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
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
    );
  }

  void _showPaymentDialog(BuildContext context, FirestoreService service) async {
    final amountController = TextEditingController();
    final motifController = TextEditingController();
    String mode = 'Espèces';
    
    // Récupérer les factures et les règlements pour calculer les restes à payer
    final allTransactions = await service.getTransactions().first;
    final myTransactions = allTransactions.where((t) => t.tierId == widget.tier.id).toList();
    final myPayments = await service.getPayments(tierId: widget.tier.id).first;
    
    String? selectedInvoice;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouveau Règlement', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lier à une facture (Optionnel)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Toutes les factures (Global)'),
                  value: selectedInvoice,
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Règlement Global')),
                    ...myTransactions.map((t) {
                      double paye = t.amountPaid + myPayments.where((p) => p.invoiceNumber == t.invoiceNumber).fold(0.0, (sum, p) => sum + p.amount);
                      double reste = t.netToPay - paye;
                      return DropdownMenuItem(
                        value: t.invoiceNumber, 
                        child: Text('${t.invoiceNumber} (Total: ${NumberFormat('#,###').format(t.netToPay)} F | Reste: ${NumberFormat('#,###').format(reste)} F)')
                      );
                    }),
                  ],
                  onChanged: (val) => setDialogState(() => selectedInvoice = val),
                ),
                const SizedBox(height: 20),
                const Text('Montant', style: TextStyle(color: Colors.grey, fontSize: 12)),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '0', border: UnderlineInputBorder()),
                ),
                const SizedBox(height: 20),
                const Text('Mode', style: TextStyle(color: Colors.blue, fontSize: 12)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: mode,
                  items: ['Espèces', 'Chèque', 'Virement', 'Mobile Money'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setDialogState(() => mode = val!),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: motifController,
                  decoration: const InputDecoration(labelText: 'Référence / Motif', border: UnderlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final user = await authService.getAppUser((await authService.user.first)!.uid);

                  final payment = Payment(
                    id: '',
                    tierId: widget.tier.id,
                    tierName: widget.tier.name,
                    tierType: widget.tier.type,
                    amount: double.tryParse(amountController.text.replaceAll(' ', '')) ?? 0,
                    date: DateTime.now(),
                    method: mode,
                    reference: motifController.text,
                    invoiceNumber: selectedInvoice, // On lie le règlement à la facture choisie
                  );
                  await service.addPayment(payment, user?.displayName ?? 'Inconnu');
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                shape: const StadiumBorder(),
              ),
              child: const Text('Valider', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isBold ? 16 : 14)),
        ],
      ),
    );
  }
}
