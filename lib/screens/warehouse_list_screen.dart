import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/warehouse.dart';
import '../models/stock_transfer.dart';
import '../services/firestore_service.dart';

class WarehouseListScreen extends StatelessWidget {
  const WarehouseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTION DES DÉPÔTS'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Warehouse>>(
        stream: firestoreService.getWarehouses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final warehouses = snapshot.data ?? [];

          return ListView.builder(
            itemCount: warehouses.length,
            itemBuilder: (context, index) {
              final w = warehouses[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ExpansionTile(
                  leading: const Icon(Icons.warehouse, color: Color(0xFF1A237E)),
                  title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(w.location),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => firestoreService.deleteWarehouse(w.id),
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("Mouvements récents", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    StreamBuilder<List<StockTransfer>>(
                      stream: firestoreService.getStockTransfers(),
                      builder: (context, snapshotTrans) {
                        final transfers = (snapshotTrans.data ?? []).where((t) => t.toWarehouseId == w.id || t.fromWarehouseId == w.id).toList();
                        if (transfers.isEmpty) return const Padding(padding: EdgeInsets.all(8.0), child: Text("Aucun transfert"));
                        return Column(
                          children: transfers.map((t) => ListTile(
                            dense: true,
                            leading: Icon(t.toWarehouseId == w.id ? Icons.download : Icons.upload, color: t.toWarehouseId == w.id ? Colors.green : Colors.orange),
                            title: Text("${t.items.length} article(s) - Réf: ${t.reference}"),
                            subtitle: Text(DateFormat('dd/MM/yyyy').format(t.date)),
                            trailing: Text(t.toWarehouseId == w.id ? "ENTRÉE" : "SORTIE", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          )).toList(),
                        );
                      },
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWarehouseDialog(context, firestoreService),
        backgroundColor: const Color(0xFF1A237E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddWarehouseDialog(BuildContext context, FirestoreService service) {
    final nameController = TextEditingController();
    final locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau Dépôt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom du dépôt')),
            TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Emplacement')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                service.addWarehouse(Warehouse(id: '', name: nameController.text, location: locationController.text));
                Navigator.pop(context);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}
