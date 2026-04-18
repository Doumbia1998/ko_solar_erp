import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/product.dart';
import '../models/stock_transfer.dart';
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
      body: StreamBuilder<List<Product>>(
        stream: firestoreService.getProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          var products = snapshot.data ?? [];
          if (_searchQuery.isNotEmpty) {
            products = products.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
          }

          return StreamBuilder<List<StockTransfer>>(
            stream: firestoreService.getStockTransfers(),
            builder: (context, transferSnapshot) {
              final allTransfers = transferSnapshot.data ?? [];

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un article...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        
                        // Filtrer les transferts pour ce produit spécifique en mémoire (très rapide)
                        final productTransfers = allTransfers.where((t) => t.productId == product.id).toList();
                        Set<String> depots = {"Dépôt Central"};
                        for (var t in productTransfers) {
                          depots.add(t.toWarehouseName);
                        }

                        return ListTile(
                          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PU: ${product.sellingPrice} FCFA | Caté: ${product.category}'),
                              Text('Lieux: ${depots.join(', ')}', 
                                style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${product.totalQuantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                                  const Text('en stock', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                              if (!widget.isSelectionMode)
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductFormScreen(product: product))),
                                ),
                            ],
                          ),
                          onTap: () {
                            if (widget.isSelectionMode) {
                              Navigator.pop(context, product);
                            } else {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)));
                            }
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
      floatingActionButton: widget.isSelectionMode ? null : Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "transfer",
            onPressed: () => _showTransferDialog(context, firestoreService),
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

  void _showTransferDialog(BuildContext context, FirestoreService service) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const StockTransferScreen()));
  }
}
