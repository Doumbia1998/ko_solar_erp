import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../models/transaction.dart';
import '../models/tier.dart';
import '../models/payment.dart';

class AgedBalanceScreen extends StatefulWidget {
  const AgedBalanceScreen({super.key});

  @override
  State<AgedBalanceScreen> createState() => _AgedBalanceScreenState();
}

class _AgedBalanceScreenState extends State<AgedBalanceScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Génération Balance Agée'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text('Balance Agée des Clients', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('Ce rapport calcule les soldes impayés globaux de chaque client classés par ancienneté de la dette.', textAlign: TextAlign.center),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 300,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _generateAgedBalance(service),
                icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.picture_as_pdf),
                label: const Text('GÉNÉRER LE PDF'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _generateAgedBalance(FirestoreService service) async {
    setState(() => _isLoading = true);
    try {
      final clients = await service.getTiers(TierType.client).first;
      final txs = await service.getTransactions(type: TransactionType.sale).first;
      final pays = await service.getPayments().first;
      final now = DateTime.now();

      List<Map<String, dynamic>> agedData = [];

      for (var c in clients) {
        double totalClient = 0;
        double notDue = 0;
        double b1 = 0; // 1-15j
        double b2 = 0; // 16-30j
        double b3 = 0; // 31-45j
        double b4 = 0; // 46+ j

        final clientTxs = txs.where((t) => t.tierId == c.id).toList();
        final clientPays = pays.where((p) => p.tierId == c.id).toList();
        double totalPaid = clientPays.fold(0.0, (sum, p) => sum + p.amount);

        // On trie les factures par date croissante pour imputer les paiements (FIFO)
        clientTxs.sort((a, b) => a.date.compareTo(b.date));

        for (var t in clientTxs) {
          double amountToImpute = t.netToPay;
          if (totalPaid >= amountToImpute) {
            totalPaid -= amountToImpute;
            continue; // Facture déjà payée
          } else {
            double remaining = amountToImpute - totalPaid;
            totalPaid = 0; // Tout le crédit est utilisé

            totalClient += remaining;
            int days = now.difference(t.dueDate ?? t.date).inDays;

            if (days <= 0) notDue += remaining;
            else if (days <= 15) b1 += remaining;
            else if (days <= 30) b2 += remaining;
            else if (days <= 45) b3 += remaining;
            else b4 += remaining;
          }
        }

        if (totalClient > 10) {
          agedData.add({
            'code': c.compteTiers,
            'name': c.name,
            'total': totalClient,
            'notDue': notDue,
            '1-15': b1,
            '16-30': b2,
            '31-45': b3,
            '46+': b4,
          });
        }
      }

      if (agedData.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun impayé global trouvé.')));
      } else {
        await PdfService.generateAgedBalance(type: 'client', agedData: agedData);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
