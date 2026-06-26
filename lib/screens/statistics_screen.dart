import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../models/transaction.dart';
import '../models/product.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  DateTimeRange? _selectedDateRange;
  final currencyFormat = NumberFormat('#,###', 'fr_FR');

  @override
  void initState() {
    super.initState();
    // Par défaut : le mois en cours
    _selectedDateRange = DateTimeRange(
      start: DateTime(DateTime.now().year, DateTime.now().month, 1),
      end: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse des Marges & Profits'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: StreamBuilder<List<AppTransaction>>(
        stream: firestoreService.getTransactions(type: TransactionType.sale),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final sales = snapshot.data!.where((s) => 
            s.date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
            s.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)))
          ).toList();

          return FutureBuilder<List<Product>>(
            future: firestoreService.getProducts().first,
            builder: (context, prodSnapshot) {
              if (!prodSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              final products = prodSnapshot.data!;

              // On crée une map pour un accès ultra-rapide aux produits par ID
              final productMap = {for (var p in products) p.id: p};
              
              double totalCA = 0;
              double totalCoutAchat = 0;

              for (var sale in sales) {
                totalCA += sale.netToPay;
                for (var item in sale.items) {
                  final prod = productMap[item.productId];
                  if (prod != null) {
                    totalCoutAchat += (prod.purchasePrice * item.quantity);
                  }
                }
              }

              double margeBrute = totalCA - totalCoutAchat;
              double pourcentageMarge = totalCA > 0 ? (margeBrute / totalCA) * 100 : 0;

              // Calcul des stats par produit pour le PDF
              Map<String, Map<String, dynamic>> productStatsMap = {};
              for (var sale in sales) {
                for (var item in sale.items) {
                  final prod = productMap[item.productId];
                  if (prod != null) {
                    final current = productStatsMap[prod.id] ?? {
                      'name': prod.name,
                      'qty': 0.0,
                      'ca': 0.0,
                      'cost': 0.0,
                    };
                    current['qty'] += item.quantity;
                    current['ca'] += (item.quantity * item.unitPrice) - item.discount;
                    current['cost'] += (prod.purchasePrice * item.quantity);
                    productStatsMap[prod.id] = current;
                  }
                }
              }

              final productStats = productStatsMap.values.map((s) {
                return {
                  ...s,
                  'margin': s['ca'] - s['cost'],
                };
              }).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildPeriodHeader(),
                    const SizedBox(height: 20),
                    _buildStatCard('CHIFFRE D\'AFFAIRE (VENTES)', totalCA, Colors.blue),
                    const SizedBox(height: 10),
                    _buildStatCard('COÛT DE REVIENT (ACHATS)', totalCoutAchat, Colors.orange),
                    const Divider(height: 40, thickness: 2),
                    _buildStatCard(
                      'MARGE BÉNÉFICIAIRE NETTE', 
                      margeBrute, 
                      margeBrute >= 0 ? Colors.green : Colors.red,
                      isBold: true,
                      subtitle: 'Soit ${pourcentageMarge.toStringAsFixed(1)}% de rentabilité'
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                            icon: const Icon(Icons.analytics),
                            label: const Text('Rapport Marges'),
                            onPressed: () => PdfService.generateProfitReport(
                              start: _selectedDateRange!.start,
                              end: _selectedDateRange!.end,
                              totalCA: totalCA,
                              totalCout: totalCoutAchat,
                              marge: margeBrute,
                              pourcentage: pourcentageMarge,
                              productStats: productStats,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                            icon: const Icon(Icons.leaderboard),
                            label: const Text('Palmarès Ventes'),
                            onPressed: () => PdfService.generateSalesRankingReport(
                              start: _selectedDateRange!.start,
                              end: _selectedDateRange!.end,
                              productStats: productStats,
                              grandTotalCA: totalCA,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildPeriodHeader() {
    final df = DateFormat('dd/MM/yyyy');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            "Période : ${df.format(_selectedDateRange!.start)} au ${df.format(_selectedDateRange!.end)}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double value, Color color, {bool isBold = false, String? subtitle}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '${currencyFormat.format(value)} FCFA',
              style: TextStyle(
                color: color, 
                fontSize: 24, 
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
            ]
          ],
        ),
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
