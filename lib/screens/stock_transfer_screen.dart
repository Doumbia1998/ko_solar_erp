import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../models/warehouse.dart';
import '../models/product.dart';
import '../models/stock_transfer.dart';
import '../models/app_user.dart';
import 'stock_screen.dart';

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Warehouse? _fromWarehouse;
  Warehouse? _toWarehouse;

  final List<StockTransferItem> _items = [];
  final _qtyController = TextEditingController();
  Product? _selectedProduct;

  final _refController = TextEditingController();
  bool _isProcessing = false;

  // Filtres pour l'historique
  String _historySearch = "";
  DateTime? _historyDate;

  final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNextRef();
  }

  void _loadNextRef() async {
    final service = Provider.of<FirestoreService>(context, listen: false);
    String nextRef = await service.getNextStockTransferRef();
    setState(() {
      _refController.text = nextRef;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _qtyController.dispose();
    _refController.dispose();
    super.dispose();
  }

  void _addItem() async {
    if (_fromWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez d\'abord sélectionner le dépôt source.')));
      return;
    }
    if (_selectedProduct == null || _qtyController.text.isEmpty) return;

    int qty = int.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0) return;

    // Vérification du stock réel dans le dépôt source
    final service = Provider.of<FirestoreService>(context, listen: false);
    int available = await service.getWarehouseStock(_selectedProduct!.id, _fromWarehouse!.id);

    if (available < qty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Stock Insuffisant", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: Text("Le dépôt '${_fromWarehouse!.name}' ne contient que $available unité(s) de '${_selectedProduct!.name}'.\n\nVous ne pouvez pas transférer $qty."),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("COMPRIS"))],
          ),
        );
      }
      return;
    }

    setState(() {
      _items.add(StockTransferItem(
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        quantity: qty,
      ));
      _selectedProduct = null;
      _qtyController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transferts de Stock', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          if (_tabController.index == 1) ...[
            IconButton(
              icon: Icon(Icons.calendar_today, color: _historyDate != null ? Colors.yellow : Colors.white),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _historyDate ?? DateTime.now(),
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                );
                setState(() => _historyDate = picked);
              },
            ),
            if (_historyDate != null)
              IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () => setState(() => _historyDate = null)),
            const SizedBox(width: 10),
          ]
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => setState(() {}),
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline, color: Colors.white), text: 'NOUVEAU TRANSFERT'),
            Tab(icon: Icon(Icons.history, color: Colors.white), text: 'HISTORIQUE DES DOCUMENTS'),
          ],
          indicatorColor: Colors.yellow,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildForm(service),
          _buildHistory(service),
        ],
      ),
    );
  }

  Widget _buildForm(FirestoreService service) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('N° Document', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(_refController.text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  StreamBuilder<List<Warehouse>>(
                    stream: service.getWarehouses(),
                    builder: (context, snapshot) {
                      final warehouses = snapshot.data ?? [];
                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Warehouse>(
                              value: _fromWarehouse,
                              decoration: const InputDecoration(labelText: 'Transfert de (Source)', border: OutlineInputBorder()),
                              items: warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
                              onChanged: (val) => setState(() => _fromWarehouse = val),
                            ),
                          ),
                          const SizedBox(width: 20),
                          const Icon(Icons.arrow_forward, color: Colors.blue),
                          const SizedBox(width: 20),
                          Expanded(
                            child: DropdownButtonFormField<Warehouse>(
                              value: _toWarehouse,
                              decoration: const InputDecoration(labelText: 'Vers (Destination)', border: OutlineInputBorder()),
                              items: warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
                              onChanged: (val) => setState(() => _toWarehouse = val),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
          const Text('AJOUTER DES ARTICLES', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  leading: const Icon(Icons.inventory_2, color: Colors.orange),
                  title: Text(_selectedProduct?.name ?? 'Choisir un article...'),
                  subtitle: _selectedProduct != null ? Text('Disponible : ${_selectedProduct!.totalQuantity}') : null,
                  trailing: const Icon(Icons.search),
                  onTap: () async {
                    final p = await Navigator.push<Product>(context, MaterialPageRoute(builder: (context) => const StockScreen(isSelectionMode: true)));
                    if (p != null) setState(() => _selectedProduct = p);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantité', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _addItem,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                        child: const Icon(Icons.add),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('LISTE DES ARTICLES À TRANSFÉRER', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const Divider(),

          if (_items.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Aucun article ajouté', style: TextStyle(fontStyle: FontStyle.italic))))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  child: ListTile(
                    title: Text(item.productName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Quantité : ${item.quantity}'),
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _items.removeAt(index))),
                  ),
                );
              },
            ),

          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: (_fromWarehouse == null || _toWarehouse == null || _items.isEmpty || _isProcessing)
                ? null
                : _performTransfer,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('VALIDER LE TRANSFERT DE MASSE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(FirestoreService service) {
    final currentUser = Provider.of<AppUser?>(context);
    final isAdmin = currentUser?.role == UserRole.admin || currentUser?.role == UserRole.manager;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (val) => setState(() => _historySearch = val.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Rechercher par dépôt ou référence...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<StockTransfer>>(
            stream: service.getStockTransfers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var transfers = snapshot.data!;

              if (_historySearch.isNotEmpty) {
                transfers = transfers.where((t) =>
                  t.reference.toLowerCase().contains(_historySearch) ||
                  t.fromWarehouseName.toLowerCase().contains(_historySearch) ||
                  t.toWarehouseName.toLowerCase().contains(_historySearch)
                ).toList();
              }

              if (_historyDate != null) {
                transfers = transfers.where((t) =>
                  t.date.year == _historyDate!.year &&
                  t.date.month == _historyDate!.month &&
                  t.date.day == _historyDate!.day
                ).toList();
              }

              if (transfers.isEmpty) return const Center(child: Text('Aucun transfert trouvé.'));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: transfers.length,
                itemBuilder: (context, index) {
                  final t = transfers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.swap_horiz, color: Colors.white)),
                      title: Text('Réf: ${t.reference}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('De : ${t.fromWarehouseName} ➔ Vers : ${t.toWarehouseName}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                            onPressed: () => PdfService.generateTransferBordereau(t),
                          ),
                          if (isAdmin)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => _confirmDeleteTransfer(t, service, currentUser?.displayName ?? 'Admin'),
                            ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(t.date)}'),
                              Text('Par: ${t.createdBy}'),
                              const Divider(),
                              ...t.items.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item.productName.toUpperCase(), style: const TextStyle(fontSize: 12)),
                                    Text('Qté: ${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )),
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
  }

  void _confirmDeleteTransfer(StockTransfer t, FirestoreService service, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Annuler le transfert ?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("Cette action va annuler le transfert '${t.reference}' et remettre les stocks à leur état initial (Soustraction du dépôt destination et ré-ajout au dépôt source).\n\nConfirmer ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("NON")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await service.deleteStockTransfer(t, userName);
              if (mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfert annulé et stocks restaurés.')));
            },
            child: const Text("OUI, ANNULER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _performTransfer() async {
    final service = Provider.of<FirestoreService>(context, listen: false);
    final user = Provider.of<AppUser?>(context, listen: false);

    if (_fromWarehouse!.id == _toWarehouse!.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le dépôt source et destination doivent être différents.')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final transfer = StockTransfer(
        id: '',
        reference: _refController.text,
        date: DateTime.now(),
        fromWarehouseId: _fromWarehouse!.id,
        fromWarehouseName: _fromWarehouse!.name,
        toWarehouseId: _toWarehouse!.id,
        toWarehouseName: _toWarehouse!.name,
        items: List.from(_items),
        createdBy: user?.displayName ?? 'Inconnu',
      );

      await service.addStockTransfer(transfer);

      // Émettre le bordereau PDF
      await PdfService.generateTransferBordereau(transfer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfert de masse réussi !'), backgroundColor: Colors.green));
        setState(() {
          _items.clear();
          _fromWarehouse = null;
          _toWarehouse = null;
        });
        _loadNextRef(); // Charger le nouveau numéro séquentiel
        _tabController.animateTo(1); // Aller à l'historique
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isProcessing = false);
    }
  }
}
