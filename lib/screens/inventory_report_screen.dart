import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../models/product.dart';
import '../models/warehouse.dart';

class InventoryReportScreen extends StatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  State<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends State<InventoryReportScreen> {
  Product? _selectedProduct;
  final _currencyFormat = NumberFormat('#,###', 'fr_FR');

  void _printPdf(List<Product> products, double totalValue) {
    final pdfData = products.map((p) => {
      'name': p.name.toUpperCase(),
      'qty': p.totalQuantity,
      'price': p.purchasePrice,
      'total': p.totalQuantity * p.purchasePrice,
    }).toList();
    PdfService.generateInventoryReport(pdfData, totalValue);
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventaire Valorisé'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<List<Product>>(
            stream: firestoreService.getProducts(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              var products = snapshot.data!;
              if (_selectedProduct != null) {
                products = products.where((p) => p.id == _selectedProduct!.id).toList();
              }
              double totalValue = products.fold(0, (sum, p) => sum + (p.totalQuantity * p.purchasePrice));
              
              return IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => _printPdf(products, totalValue),
                tooltip: 'Imprimer PDF',
              );
            }
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtre Produit
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: StreamBuilder<List<Product>>(
              stream: firestoreService.getProducts(),
              builder: (context, snapshot) {
                final products = snapshot.data ?? [];
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedProduct?.id,
                        isExpanded: true,
                        hint: const Text('Sélectionner un produit (Tous)'),
                        onChanged: (id) {
                          setState(() {
                            _selectedProduct = id == null ? null : products.firstWhere((p) => p.id == id);
                          });
                        },
                        items: [
                          const DropdownMenuItem(value: null, child: Text('TOUS LES PRODUITS')),
                          ...products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name.toUpperCase()))),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: firestoreService.getProducts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var products = snapshot.data!;
                if (_selectedProduct != null) {
                  products = products.where((p) => p.id == _selectedProduct!.id).toList();
                }

                double totalValue = products.fold(0, (sum, p) => sum + (p.totalQuantity * p.purchasePrice));

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('VALEUR TOTALE :', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('${_currencyFormat.format(totalValue)} FCFA', 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.yellow, fontSize: 18)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final p = products[index];
                          final val = p.totalQuantity * p.purchasePrice;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 2,
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade50,
                                child: Text(p.name[0].toUpperCase(), style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(p.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Stock: ${p.totalQuantity} | P.A: ${_currencyFormat.format(p.purchasePrice)} F'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Valeur', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text('${_currencyFormat.format(val)} F', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                              children: [
                                const Divider(),
                                FutureBuilder<List<Warehouse>>(
                                  future: firestoreService.getWarehouses().first,
                                  builder: (context, wSnap) {
                                    final warehouses = wSnap.data ?? [];
                                    return Column(
                                      children: warehouses.map((w) {
                                        return FutureBuilder<int>(
                                          future: firestoreService.getWarehouseStock(p.id, w.id),
                                          builder: (context, sSnap) {
                                            final qty = sSnap.data ?? 0;
                                            if (qty == 0) return const SizedBox.shrink();
                                            return ListTile(
                                              dense: true,
                                              leading: const Icon(Icons.warehouse_outlined, size: 20, color: Colors.orange),
                                              title: Text(w.name),
                                              trailing: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                                                child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                              ),
                                            );
                                          },
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
