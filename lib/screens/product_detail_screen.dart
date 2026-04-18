import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../services/firestore_service.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<AppTransaction>>(
        stream: firestoreService.getTransactions(type: TransactionType.sale),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final allSales = snapshot.data ?? [];
          // Filtrer les ventes qui contiennent ce produit
          final productSales = allSales.where((t) => t.items.any((i) => i.productId == product.id)).toList();
          
          double totalQtySold = 0;
          double totalRevenue = 0;
          double totalCost = 0;

          for (var sale in productSales) {
            for (var item in sale.items) {
              if (item.productId == product.id) {
                totalQtySold += item.quantity;
                totalRevenue += (item.quantity * item.unitPrice) - item.discount;
                totalCost += (item.quantity * product.purchasePrice);
              }
            }
          }

          double marge = totalRevenue - totalCost;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Quantités Vendues', totalQtySold.toStringAsFixed(0)),
                    _buildInfoRow('Chiffre d\'affaires', '${NumberFormat('#,###').format(totalRevenue)} FCFA'),
                    _buildInfoRow('Marge', '${NumberFormat('#,###').format(marge)} FCFA'),
                    _buildInfoRow('Stock Actuel', '${product.totalQuantity}'),
                  ],
                ),
              ),
              const Text('HISTORIQUE DES VENTES', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
              Expanded(
                child: productSales.isEmpty 
                  ? const Center(child: Text('Aucune vente enregistrée'))
                  : ListView.builder(
                      itemCount: productSales.length,
                      itemBuilder: (context, index) {
                        final sale = productSales[index];
                        final item = sale.items.firstWhere((i) => i.productId == product.id);
                        return ListTile(
                          title: Text(sale.tierName.toUpperCase()),
                          subtitle: Text(DateFormat('yyyy-MM-dd').format(sale.date)),
                          trailing: Text('${item.quantity} x ${NumberFormat('#,###').format(item.unitPrice)} FCFA', style: const TextStyle(fontSize: 12)),
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
