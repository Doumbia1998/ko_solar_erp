import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/product.dart';
import '../models/warehouse.dart';
import 'product_form_screen.dart';
import 'product_detail_screen.dart';
import 'stock_transfer_screen.dart';
import '../models/app_user.dart';
import '../services/report_service.dart';

class StockScreen extends StatefulWidget {
  final bool isSelectionMode;
  const StockScreen({super.key, this.isSelectionMode = false});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _searchQuery = "";
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');
  String _alertFilter = "Tous"; // "Tous", "Rouge", "Orange", "Vert"

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final currentUser = Provider.of<AppUser?>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTION DES STOCKS'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrer par alerte',
            onSelected: (val) => setState(() => _alertFilter = val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: "Tous", child: Text("Tous les articles")),
              PopupMenuItem(value: "Rouge", child: Row(children: [const Icon(Icons.circle, color: Colors.red, size: 12), const SizedBox(width: 10), const Text("Alerte Rouge (<= 2)")])),
              PopupMenuItem(value: "Orange", child: Row(children: [const Icon(Icons.circle, color: Colors.orange, size: 12), const SizedBox(width: 10), const Text("Alerte Orange (<= 5)")])),
              PopupMenuItem(value: "Vert", child: Row(children: [const Icon(Icons.circle, color: Colors.green, size: 12), const SizedBox(width: 10), const Text("Stock OK (> 10)")])),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Synchroniser les stocks totaux',
            onPressed: () async {
              showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
              await firestoreService.syncAllProductsTotalStock();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stocks totaux synchronisés sur la base des dépôts !'), backgroundColor: Colors.green));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Inventaire',
            onPressed: () => _showInventoryMenu(context, firestoreService),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: StreamBuilder<List<Product>>(
            stream: firestoreService.getProducts(),
            builder: (context, productSnapshot) {
              if (productSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              
              var products = productSnapshot.data ?? [];
              if (_searchQuery.isNotEmpty) {
                products = products.where((p) =>
                  p.name.toLowerCase().contains(_searchQuery) ||
                  p.reference.toLowerCase().contains(_searchQuery)
                ).toList();
              }

              return StreamBuilder<List<Warehouse>>(
                stream: firestoreService.getWarehouses(),
                builder: (context, warehouseSnapshot) {
                  final warehouses = warehouseSnapshot.data ?? [];

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: firestoreService.getAllStocks(),
                    builder: (context, stockSnapshot) {
                      final allStocks = stockSnapshot.data ?? [];

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
                                
                                Map<String, int> stockMap = {};
                                int calculatedTotal = 0;
                                for (var s in allStocks) {
                                  if (s['productId'] == product.id) {
                                    int qty = (s['quantity'] as num?)?.toInt() ?? 0;
                                    stockMap[s['warehouseId']] = qty;
                                    calculatedTotal += qty;
                                  }
                                }

                                // Calcul des alertes en vérifiant tous les dépôts existants
                                bool hasRedAlert = false;
                                bool hasOrangeAlert = false;

                                for (var w in warehouses) {
                                  int qty = stockMap[w.id] ?? 0;
                                  if (qty <= 1) {
                                    hasRedAlert = true;
                                  } else if (qty <= 5) {
                                    hasOrangeAlert = true;
                                  }
                                }

                                // Application du filtre d'alerte (par dépôt désormais)
                                if (_alertFilter == "Rouge" && !hasRedAlert) return const SizedBox.shrink();
                                if (_alertFilter == "Orange" && !hasOrangeAlert) return const SizedBox.shrink();
                                if (_alertFilter == "Vert" && (hasRedAlert || hasOrangeAlert)) return const SizedBox.shrink();

                                Color badgeColor = Colors.green;
                                if (hasRedAlert) {
                                  badgeColor = Colors.red;
                                } else if (hasOrangeAlert) {
                                  badgeColor = Colors.orange;
                                }

                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      backgroundColor: badgeColor.withOpacity(0.1),
                                      child: Text('$calculatedTotal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeColor)),
                                    ),
                                    title: Text(product.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: Text('Réf: ${product.reference} | PU Vente: ${_currencyFormat.format(product.sellingPrice)} F', style: const TextStyle(fontSize: 12)),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          children: [
                                            const Divider(),
                                            ...warehouses.map((w) {
                                              int qty = stockMap[w.id] ?? 0;
                                              Color qtyColor = Colors.blue;
                                              if (qty <= 2) {
                                                qtyColor = Colors.red;
                                              } else if (qty <= 5) {
                                                qtyColor = Colors.orange;
                                              }

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
                                                    Text('$qty', style: TextStyle(fontWeight: FontWeight.bold, color: qtyColor)),
                                                  ],
                                                ),
                                              );
                                            }),
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                if (currentUser?.canEditProducts == true || currentUser?.role == UserRole.admin)
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
                                                if (currentUser?.canDeleteProducts == true || currentUser?.role == UserRole.admin)
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                                    onPressed: () => _confirmDelete(context, firestoreService, product),
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
                            ),
                          ),
                        ],
                      );
                    },
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

  void _showInventoryMenu(BuildContext context, FirestoreService service) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('TIRER L\'INVENTAIRE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A237E))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit_note, color: Colors.blue),
              title: const Text('État Préparatoire'),
              subtitle: const Text('Pour le comptage physique en magasin'),
              onTap: () async {
                Navigator.pop(context);
                final products = await service.getProducts().first;
                final warehouses = await service.getWarehouses().first;
                final allStocks = await service.getAllStocks().first;
                ReportService.generatePreparatoryInventory(products, warehouses, allStocks);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
              title: const Text('Livre d\'Inventaire'),
              subtitle: const Text('Inventaire valorisé (CMUP)'),
              onTap: () async {
                Navigator.pop(context);
                final products = await service.getProducts().first;
                final warehouses = await service.getWarehouses().first;
                final allStocks = await service.getAllStocks().first;
                ReportService.generateInventoryBook(products, warehouses, allStocks);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, FirestoreService service, Product p) {
    final currentUser = Provider.of<AppUser?>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le produit ?'),
        content: Text('Voulez-vous vraiment supprimer ${p.name} ?\nCette action est irréversible et échouera si le produit est lié à des factures.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () async {
              try {
                await service.deleteProduct(p.id, currentUser?.displayName ?? 'Inconnu');
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produit supprimé'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SUPPRIMER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
