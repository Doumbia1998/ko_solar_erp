import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/tier.dart';
import '../models/transaction.dart';
import '../models/payment.dart';
import '../models/journal_entry.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';

class TierDetailScreen extends StatefulWidget {
  final Tier tier;
  const TierDetailScreen({super.key, required this.tier});

  @override
  State<TierDetailScreen> createState() => _TierDetailScreenState();
}

class _TierDetailScreenState extends State<TierDetailScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tier.name.toUpperCase()),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<AppTransaction>>(
        stream: service.getTransactions(),
        builder: (context, snapshotTrans) {
          return StreamBuilder<List<Payment>>(
            stream: service.getPayments(tierId: widget.tier.id),
            builder: (context, snapshotPay) {
              return StreamBuilder<List<JournalEntry>>(
                stream: service.getJournalEntries(),
                builder: (context, snapshotJournal) {
                  if (!snapshotTrans.hasData || !snapshotPay.hasData || !snapshotJournal.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final myTxs = snapshotTrans.data!.where((t) => t.tierId == widget.tier.id).toList();
                  final myPays = snapshotPay.data!;
                  final myJournals = snapshotJournal.data!.where((j) => j.tierId == widget.tier.id).toList();

                  // Le calcul de netToPay dans le modèle gère déjà le signe négatif pour les retours
                  double totalFacture = myTxs.fold(0.0, (sum, t) => sum + t.netToPay);
                  double totalRegle = 0;

                  // 1. Somme des règlements via le module
                  totalRegle += myPays.fold(0.0, (sum, p) => sum + p.amount);

                  // 2. Somme des règlements via le journal (Compta)
                  for (var j in myJournals) {
                    bool isDuplicate = myPays.any((p) => p.invoiceNumber == j.reference || p.reference.contains(j.reference));
                    if (!isDuplicate) {
                      totalRegle += (widget.tier.type == TierType.client ? j.credit : j.debit);
                    }
                  }

                  // 3. Acomptes orphelins (sécurité)
                  for (var t in myTxs) {
                    if (t.amountPaid > 0 && t.type != TransactionType.saleReturn && t.type != TransactionType.purchaseReturn) {
                      bool counted = myPays.any((p) => p.invoiceNumber == t.invoiceNumber) ||
                                     myJournals.any((j) => j.reference == t.invoiceNumber);
                      if (!counted) totalRegle += t.amountPaid;
                    }
                  }

                  double resteAPayer = totalFacture - totalRegle;

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        width: double.infinity,
                        color: Colors.blue.shade50,
                        child: Column(
                          children: [
                            _buildSummaryRow('Total Facturé (Net)', totalFacture),
                            _buildSummaryRow('Total Réglé', totalRegle, color: Colors.green),
                            const Divider(),
                            _buildSummaryRow('RESTE À PAYER', resteAPayer, isBold: true, color: resteAPayer > 10 ? Colors.red : Colors.green),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('HISTORIQUE DES OPÉRATIONS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: myTxs.length,
                          itemBuilder: (context, index) {
                            final t = myTxs[index];
                            final isReturn = t.type == TransactionType.saleReturn || t.type == TransactionType.purchaseReturn;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: Icon(
                                  isReturn ? Icons.assignment_return : (t.type == TransactionType.sale ? Icons.arrow_upward : Icons.arrow_downward),
                                  color: isReturn ? Colors.red : (t.type == TransactionType.sale ? Colors.blue : Colors.green)
                                ),
                                title: Text('${isReturn ? "RETOUR" : (t.type == TransactionType.sale ? "VENTE" : "ACHAT")} ${t.invoiceNumber}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Date : ${DateFormat('dd/MM/yy').format(t.date)}'),
                                    if (t.dueDate != null) Text('Échéance : ${DateFormat('dd/MM/yy').format(t.dueDate!)}', style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                trailing: Text(
                                  '${isReturn ? "-" : ""}${_currencyFormat.format(t.netToPay.abs())} F',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isReturn ? Colors.red : Colors.black)
                                ),
                                onTap: () => PdfService.generateInvoice(t, allTierPayments: myPays, allTierTransactions: myTxs),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isBold = false, Color color = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 16 : 14)),
          Text('${_currencyFormat.format(value)} FCFA',
               style: TextStyle(fontWeight: FontWeight.bold, fontSize: isBold ? 20 : 14, color: color)),
        ],
      ),
    );
  }
}
