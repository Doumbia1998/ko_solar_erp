import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/warehouse.dart';
import '../models/stock_transfer.dart';
import '../services/firestore_service.dart';
import 'stock_transfer_history_screen.dart';

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  Product? selectedProduct;
  Warehouse? sourceWarehouse;
  Warehouse? targetWarehouse;
  final TextEditingController quantityController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau Transfert'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StockTransferHistoryScreen())),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Sélection Produit
            StreamBuilder<List<Product>>(
              stream: firestoreService.getProducts(),
              builder: (context, snapshot) {
                final products = snapshot.data ?? [];
                return DropdownButtonFormField<Product>(
                  value: selectedProduct,
                  hint: const Text("Sélectionner l'article"),
                  decoration: const InputDecoration(labelText: 'Article'),
                  items: products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                  onChanged: (val) => setState(() => selectedProduct = val),
                );
              },
            ),
            const SizedBox(height: 16),
            // Source
            StreamBuilder<List<Warehouse>>(
              stream: firestoreService.getWarehouses(),
              builder: (context, snapshot) {
                final warehouses = snapshot.data ?? [];
                return DropdownButtonFormField<Warehouse>(
                  value: sourceWarehouse,
                  hint: const Text("Sélectionner le dépôt source"),
                  decoration: const InputDecoration(labelText: 'Dépôt Source'),
                  items: warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
                  onChanged: (val) => setState(() => sourceWarehouse = val),
                );
              },
            ),
            const SizedBox(height: 16),
            // Destination
            StreamBuilder<List<Warehouse>>(
              stream: firestoreService.getWarehouses(),
              builder: (context, snapshot) {
                final warehouses = snapshot.data ?? [];
                return DropdownButtonFormField<Warehouse>(
                  value: targetWarehouse,
                  hint: const Text("Sélectionner le dépôt destination"),
                  decoration: const InputDecoration(labelText: 'Dépôt Destination'),
                  items: warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
                  onChanged: (val) => setState(() => targetWarehouse = val),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: 'Quantité à transférer'),
              keyboardType: TextInputType.number,
            ),
            if (selectedProduct != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Stock actuel : ${selectedProduct!.totalQuantity}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                if (selectedProduct == null || sourceWarehouse == null || targetWarehouse == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir tous les champs')));
                  return;
                }
                
                int qty = int.tryParse(quantityController.text) ?? 0;
                
                // Vérification de la quantité disponible
                if (qty > selectedProduct!.totalQuantity) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Stock Insuffisant"),
                      content: Text("Le stock de la quantité demandée est insuffisante. Stock disponible : ${selectedProduct!.totalQuantity}"),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
                    ),
                  );
                  return;
                }

                if (qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantité invalide')));
                  return;
                }

                final transfer = StockTransfer(
                  id: '',
                  productId: selectedProduct!.id,
                  productName: selectedProduct!.name,
                  fromWarehouseId: sourceWarehouse!.id,
                  fromWarehouseName: sourceWarehouse!.name,
                  toWarehouseId: targetWarehouse!.id,
                  toWarehouseName: targetWarehouse!.name,
                  quantity: qty,
                  date: DateTime.now(),
                );

                await firestoreService.addStockTransfer(transfer);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfert enregistré avec succès')));
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              child: const Text('VALIDER LE TRANSFERT'),
            ),
          ],
        ),
      ),
    );
  }
}
