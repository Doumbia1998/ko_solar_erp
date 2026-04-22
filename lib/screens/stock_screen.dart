import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/product.dart';
import '../models/warehouse.dart';
import 'product_form_screen.dart';
import 'product_detail_screen.dart';
import 'stock_transfer_screen.dart';

class StockScreen extends StatefulWidget {
  final bool isSelectionMode;
  const StockScreen({super.key, this.isSelectionMode = false});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTION DES STOCKS'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: StreamBuilder<List<Product>>(
            stream: firestoreService.getProducts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              
              var products = snapshot.data ?? [];
              if (_searchQuery.isNotEmpty) {
                products = products.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
              }

              return StreamBuilder<List<Warehouse>>(
                stream: firestoreService.getWarehouses(),
                builder: (context, warehouseSnapshot) {
                  final warehouses = warehouseSnapshot.data ?? [];

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un article...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            
                            return FutureBuilder<Map<String, int>>(
                              future: _getProductStocks(firestoreService, product.id, warehouses),
                              builder: (context, stockSnapshot) {
                                final stockMap = stockSnapshot.data ?? {};
                                
                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade50,
                                      child: Text('${product.totalQuantity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(product.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: Text('PU: ${product.sellingPrice} FCFA | ${product.category}', style: const TextStyle(fontSize: 12)),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          children: [
                                            const Divider(),
                                            ...warehouses.map((w) {
                                              int qty = stockMap[w.id] ?? 0;
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.warehouse, size: 16, color: Colors.grey),
                                                        const SizedBox(width: 8),
                                                        Text(w.name, style: const TextStyle(fontSize: 13)),
                                                      ],
                                                    ),
                                                    Text('$qty', style: TextStyle(fontWeight: FontWeight.bold, color: qty > 0 ? Colors.blue : Colors.red)),
                                                  ],
                                                ),
                                              );
                                            }),
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                TextButton.icon(
                                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductFormScreen(product: product))),
                                                  icon: const Icon(Icons.edit, size: 16),
                                                  label: const Text('Modifier'),
                                                ),
                                                TextButton.icon(
                                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product))),
                                                  icon: const Icon(Icons.history, size: 16),
                                                  label: const Text('Détails'),
                                                ),
                                                if (widget.isSelectionMode)
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(context, product),
                                                    child: const Text('SÉLECTIONNER'),
                                                  ),
                                              ],
                                            )
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: widget.isSelectionMode ? null : Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "transfer",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StockTransferScreen())),
            backgroundColor: Colors.orange,
            child: const Icon(Icons.swap_horiz, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "add",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductFormScreen())),
            backgroundColor: const Color(0xFF1A237E),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<Map<String, int>> _getProductStocks(FirestoreService service, String productId, List<Warehouse> warehouses) async {
    Map<String, int> stockMap = {};
    for (var w in warehouses) {
      int qty = await service.getWarehouseStock(productId, w.id);
      stockMap[w.id] = qty;
    }
    return stockMap;
  }
}
