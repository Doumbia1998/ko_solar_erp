import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/transaction.dart';
import '../models/payment.dart';
import '../models/daily_closing.dart';

class DailyClosingScreen extends StatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  State<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends State<DailyClosingScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');
  final DateTime _today = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clôture de Journée'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<AppTransaction>>(
        stream: firestoreService.getTransactions(),
        builder: (context, snapshotTx) {
          return StreamBuilder<List<Payment>>(
            stream: firestoreService.getPayments(),
            builder: (context, snapshotPay) {
              if (snapshotTx.connectionState == ConnectionState.waiting || snapshotPay.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allTxs = snapshotTx.data ?? [];
              final allPayments = snapshotPay.data ?? [];

              // Filtrer pour AUJOURD'HUI
              final todayTxs = allTxs.where((t) => 
                t.date.year == _today.year && t.date.month == _today.month && t.date.day == _today.day).toList();
              
              final todayPayments = allPayments.where((p) => 
                p.date.year == _today.year && p.date.month == _today.month && p.date.day == _today.day).toList();

              double sales = todayTxs.where((t) => t.type == TransactionType.sale).fold(0, (sum, t) => sum + t.totalHT);
              double purchases = todayTxs.where((t) => t.type == TransactionType.purchase).fold(0, (sum, t) => sum + t.totalHT);
              
              double incomes = todayPayments.where((p) => p.tierType == 'client' || (p.amount > 0 && p.tierType == null)).fold(0, (sum, p) => sum + p.amount);
              double outcomes = todayPayments.where((p) => p.tierType == 'supplier').fold(0, (sum, p) => sum + p.amount);

              // Espèces uniquement pour la caisse physique
              double cashIncomes = todayPayments.where((p) => p.method == 'Espèces' && p.tierType == 'client').fold(0, (sum, p) => sum + p.amount);
              double cashOutcomes = todayPayments.where((p) => p.method == 'Espèces' && p.tierType == 'supplier').fold(0, (sum, p) => sum + p.amount);
              double netCash = cashIncomes - cashOutcomes;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Résumé du ${DateFormat('dd MMMM yyyy', 'fr_FR').format(_today)}', 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    _buildSummaryCard(
                      title: 'ACTIVITÉ COMMERCIALE',
                      color: Colors.blue.shade900,
                      items: [
                        _buildRow('Total Ventes HT', sales),
                        _buildRow('Total Achats HT', purchases),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    _buildSummaryCard(
                      title: 'FLUX DE TRÉSORERIE (TOUS MODES)',
                      color: Colors.green.shade900,
                      items: [
                        _buildRow('Total Encaissements', incomes),
                        _buildRow('Total Décaissements', outcomes),
                        const Divider(color: Colors.white54),
                        _buildRow('Solde Théorique Journalier', incomes - outcomes, isBold: true),
                      ],
                    ),
                    const SizedBox(height: 15),

                    _buildSummaryCard(
                      title: 'CAISSE PHYSIQUE (ESPÈCES)',
                      color: Colors.orange.shade900,
                      items: [
                        _buildRow('Entrées Espèces', cashIncomes),
                        _buildRow('Sorties Espèces', cashOutcomes),
                        const Divider(color: Colors.white54),
                        _buildRow('NET EN CAISSE', netCash, isBold: true),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmClosing(context, firestoreService, authService, sales, purchases, incomes, outcomes, netCash),
                        icon: const Icon(Icons.lock_clock),
                        label: const Text('EFFECTUER LA CLÔTURE ET VERROUILLER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade900,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Note: La clôture verrouille toutes les transactions et tous les règlements de la journée. Ils ne pourront plus être modifiés.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required Color color, required List<Widget> items}) {
    return Card(
      color: color,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text('${_currencyFormat.format(value)} FCFA', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _confirmClosing(BuildContext context, FirestoreService service, AuthService auth, double sales, double purchases, double incomes, double outcomes, double cash) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la clôture ?'),
        content: const Text('Toutes les opérations d\'aujourd\'hui seront définitivement verrouillées en comptabilité. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () async {
              final user = await auth.getAppUser((await auth.user.first)!.uid);
              final closing = DailyClosing(
                id: '',
                date: _today,
                totalSales: sales,
                totalPurchases: purchases,
                totalIncomes: incomes,
                totalOutcomes: outcomes,
                cashInHand: cash,
                closedBy: user?.displayName ?? 'Inconnu',
              );
              
              await service.performDailyClosing(closing);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clôture effectuée avec succès !'), backgroundColor: Colors.green));
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
            child: const Text('CLÔTURER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
