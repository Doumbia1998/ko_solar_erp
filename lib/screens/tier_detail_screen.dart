import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/tier.dart';
import '../models/transaction.dart';
import '../models/payment.dart';
import '../services/firestore_service.dart';

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
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final transactions = snapshot.data?.where((t) => t.tierId == widget.tier.id).toList() ?? [];
                
                if (transactions.isEmpty) return const Center(child: Text('Aucune opération enregistrée'));

                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    return ListTile(
                      leading: Icon(t.type == TransactionType.sale ? Icons.arrow_upward : Icons.arrow_downward, 
                                   color: t.type == TransactionType.sale ? Colors.blue : Colors.green),
                      title: Text(t.invoiceNumber),
                      subtitle: Text(DateFormat('dd/MM/yyyy').format(t.date)),
                      trailing: Text('${NumberFormat('#,###', 'fr_FR').format(t.netToPay)} F', style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, FirestoreService service) {
    final amountController = TextEditingController();
    final motifController = TextEditingController();
    String mode = 'Espèces';

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
                  items: ['Espèces', 'Chèque', 'Virement'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setDialogState(() => mode = val!),
                ),
                if (mode != 'Espèces') ...[
                  const SizedBox(height: 20),
                  TextField(
                    controller: motifController,
                    decoration: const InputDecoration(labelText: 'Motif / Banque', border: UnderlineInputBorder()),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  final payment = Payment(
                    id: '',
                    tierId: widget.tier.id,
                    tierName: widget.tier.name,
                    tierType: widget.tier.type,
                    amount: double.tryParse(amountController.text) ?? 0,
                    date: DateTime.now(),
                    method: mode,
                    reference: motifController.text,
                  );
                  await service.addPayment(payment);
                  Navigator.pop(context);
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
