import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../models/transaction.dart';
import '../models/product.dart';
import '../models/stock_transfer.dart';
import '../models/warehouse.dart';

class StockMovementScreen extends StatefulWidget {
  const StockMovementScreen({super.key});

  @override
  State<StockMovementScreen> createState() => _StockMovementScreenState();
}

class _StockMovementScreenState extends State<StockMovementScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  Product? _selectedProduct;
  Warehouse? _selectedWarehouse;

  void _printDetailedReport(FirestoreService service) async {
    final products = await service.getProducts().first;
    final transactions = await service.getTransactions().first;
    final transfers = await service.getStockTransfers().first;

    List<Product> targetProducts = products;
    if (_selectedProduct != null) {
      targetProducts = [products.firstWhere((p) => p.id == _selectedProduct!.id)];
    }

    await PdfService.generateDetailedStockMovementReport(
      products: targetProducts,
      transactions: transactions,
      transfers: transfers,
      start: _startDate,
      end: _endDate,
      warehouseName: _selectedWarehouse?.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mouvements de Stock'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Section Filtres
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  StreamBuilder<List<Product>>(
                    stream: firestoreService.getProducts(),
                    builder: (context, snapshot) {
                      final products = snapshot.data ?? [];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2, color: Colors.orange),
                            const SizedBox(width: 15),
                            const Text('Produit :', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _selectedProduct?.id,
                                  isExpanded: true,
                                  hint: const Text('TOUS LES PRODUITS'),
                                  onChanged: (id) => setState(() => _selectedProduct = id == null ? null : products.firstWhere((p) => p.id == id)),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('TOUS')),
                                    ...products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name.toUpperCase()))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  StreamBuilder<List<Warehouse>>(
                    stream: firestoreService.getWarehouses(),
                    builder: (context, snapshot) {
                      final warehouses = snapshot.data ?? [];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.warehouse, color: Colors.brown),
                            const SizedBox(width: 15),
                            const Text('Dépôt :', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _selectedWarehouse?.id,
                                  isExpanded: true,
                                  hint: const Text('TOUS LES DÉPÔTS (GLOBAL)'),
                                  onChanged: (id) => setState(() => _selectedWarehouse = id == null ? null : warehouses.firstWhere((w) => w.id == id)),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('TOUS LES DÉPÔTS')),
                                    ...warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name.toUpperCase()))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Début', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          subtitle: Text(DateFormat('dd/MM/yyyy').format(_startDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () async {
                            final d = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                            if (d != null) setState(() => _startDate = d);
                          },
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: ListTile(
                          title: const Text('Fin', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          subtitle: Text(DateFormat('dd/MM/yyyy').format(_endDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () async {
                            final d = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                            if (d != null) setState(() => _endDate = d);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<AppTransaction>>(
              stream: firestoreService.getTransactions(),
              builder: (context, transSnap) {
                return StreamBuilder<List<StockTransfer>>(
                  stream: firestoreService.getStockTransfers(),
                  builder: (context, transferSnap) {
                    if (!transSnap.hasData || !transferSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final transactions = transSnap.data!;
                    final transfers = transferSnap.data!;

                    List<Map<String, dynamic>> movements = [];

                    // Filtrer et collecter les transactions
                    for (var t in transactions) {
                      if (t.date.isAfter(_startDate.subtract(const Duration(seconds: 1))) && 
                          t.date.isBefore(_endDate.add(const Duration(days: 1)))) {

                        // Si un dépôt est sélectionné, on ne garde que les transactions de ce dépôt
                        if (_selectedWarehouse != null && t.warehouseId != _selectedWarehouse!.id) continue;

                        for (var item in t.items) {
                          if (_selectedProduct == null || item.productId == _selectedProduct!.id) {
                            movements.add({
                              'date': t.date,
                              'type': t.type == TransactionType.sale ? 'SORTIE' : 'ENTRÉE',
                              'ref': t.invoiceNumber,
                              'tier': t.tierName,
                              'qty': item.quantity,
                              'product': item.productName,
                              'color': t.type == TransactionType.sale ? Colors.red : Colors.green,
                            });
                          }
                        }
                      }
                    }

                    // Filtrer et collecter les transferts
                    for (var tr in transfers) {
                      if (tr.date.isAfter(_startDate.subtract(const Duration(seconds: 1))) && 
                          tr.date.isBefore(_endDate.add(const Duration(days: 1)))) {

                        for (var item in tr.items) {
                          if (_selectedProduct == null || item.productId == _selectedProduct!.id) {

                            double displayQty = item.quantity.toDouble();
                            String typeLabel = 'TRANSFERT';
                            Color displayColor = Colors.blue;

                            if (_selectedWarehouse != null) {
                              if (tr.toWarehouseId == _selectedWarehouse!.id) {
                                typeLabel = 'TRF ENTRÉE';
                                displayColor = Colors.green;
                              } else if (tr.fromWarehouseId == _selectedWarehouse!.id) {
                                typeLabel = 'TRF SORTIE';
                                displayColor = Colors.red;
                                displayQty = -displayQty;
                              } else {
                                // Le transfert ne concerne pas le dépôt sélectionné
                                continue;
                              }
                            } else {
                              // Mode global : le transfert ne change pas le stock total
                              displayQty = 0;
                            }

                            movements.add({
                              'date': tr.date,
                              'type': typeLabel,
                              'ref': tr.reference,
                              'tier': '${tr.fromWarehouseName} -> ${tr.toWarehouseName}',
                              'qty': displayQty,
                              'product': item.productName,
                              'color': displayColor,
                            });
                          }
                        }
                      }
                    }

                    movements.sort((a, b) => b['date'].compareTo(a['date']));

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${movements.length} mouvements trouvés', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('MOUVEMENTS (MLD ERP)'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                                onPressed: () => _printDetailedReport(firestoreService),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: movements.length,
                            itemBuilder: (context, index) {
                              final m = movements[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: m['color'].withOpacity(0.1), shape: BoxShape.circle),
                                    child: Icon(
                                      m['type'] == 'ENTRÉE' ? Icons.add_circle_outline : 
                                      m['type'] == 'SORTIE' ? Icons.remove_circle_outline : Icons.swap_horiz,
                                      color: m['color'],
                                    ),
                                  ),
                                  title: Text(m['product'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${m['type']} - ${m['tier']}'),
                                      Text(DateFormat('dd MMM yyyy HH:mm').format(m['date']), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                  trailing: Text(
                                    '${m['qty'] > 0 ? '+' : (m['qty'] < 0 ? '' : '')}${m['qty'] == 0 ? '0' : m['qty'].toInt()}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: m['color']),
                                  ),
                                ),
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
        ],
      ),
    );
  }
}
