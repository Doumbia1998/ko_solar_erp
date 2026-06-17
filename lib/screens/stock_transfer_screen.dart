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
  Product? _selectedProduct;
  final _qtyController = TextEditingController();
  final _refController = TextEditingController(text: 'MT${DateFormat('ddMMyyHHmm').format(DateTime.now())}');
  bool _isProcessing = false;

  // Filtres pour l'historique
  String _historySearch = "";
  DateTime? _historyDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transferts de Stock', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E), // Bleu KO SOLAR plus vif
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
          onTap: (index) => setState(() {}), // Pour rafraîchir les actions de l'appbar
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline, color: Colors.white), text: 'NOUVEAU TRANSFERT'),
            Tab(icon: Icon(Icons.history, color: Colors.white), text: 'HISTORIQUE DES DOCUMENTS'),
          ],
          indicatorColor: Colors.yellow, // Indicateur jaune pour bien voir l'onglet actif
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
    final user = Provider.of<AppUser?>(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête (Similaire à l'image)
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
          const Text('SÉLECTION DE L\'ARTICLE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2, color: Colors.orange),
              title: Text(_selectedProduct?.name ?? 'Cliquer pour choisir un article...'),
              subtitle: _selectedProduct != null ? Text('Quantité totale disponible : ${_selectedProduct!.totalQuantity}') : null,
              trailing: const Icon(Icons.search),
              onTap: () async {
                final p = await Navigator.push<Product>(context, MaterialPageRoute(builder: (context) => const StockScreen(isSelectionMode: true)));
                if (p != null) setState(() => _selectedProduct = p);
              },
            ),
          ),

          if (_selectedProduct != null) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantité à transférer', border: OutlineInputBorder(), prefixIcon: Icon(Icons.add_shopping_cart)),
            ),
          ],

          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: (_fromWarehouse == null || _toWarehouse == null || _selectedProduct == null || _qtyController.text.isEmpty || _isProcessing)
                ? null
                : _performTransfer,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('VALIDER LE TRANSFERT ET ÉMETTRE BORDEREAU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(FirestoreService service) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (val) => setState(() => _historySearch = val.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Rechercher un produit ou un dépôt...',
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

              // Filtrage par recherche
              if (_historySearch.isNotEmpty) {
                transfers = transfers.where((t) =>
                  t.productName.toLowerCase().contains(_historySearch) ||
                  t.fromWarehouseName.toLowerCase().contains(_historySearch) ||
                  t.toWarehouseName.toLowerCase().contains(_historySearch)
                ).toList();
              }

              // Filtrage par date
              if (_historyDate != null) {
                transfers = transfers.where((t) =>
                  t.date.year == _historyDate!.year &&
                  t.date.month == _historyDate!.month &&
                  t.date.day == _historyDate!.day
                ).toList();
              }

              if (transfers.isEmpty) return const Center(child: Text('Aucun historique trouvé pour ces critères.'));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: transfers.length,
                itemBuilder: (context, index) {
                  final t = transfers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.swap_horiz, color: Colors.white)),
                      title: Text('${t.productName.toUpperCase()} - Qté : ${t.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('De : ${t.fromWarehouseName} ➔ Vers : ${t.toWarehouseName}\nDate : ${DateFormat('dd/MM/yyyy HH:mm').format(t.date)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        onPressed: () => PdfService.generateTransferBordereau(t),
                      ),
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

  void _performTransfer() async {
    final service = Provider.of<FirestoreService>(context, listen: false);
    final user = Provider.of<AppUser?>(context, listen: false);
    int qty = int.tryParse(_qtyController.text) ?? 0;

    if (_fromWarehouse!.id == _toWarehouse!.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le dépôt source et destination doivent être différents.')));
      return;
    }

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez saisir une quantité valide.')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final transfer = StockTransfer(
        id: '',
        date: DateTime.now(),
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        fromWarehouseId: _fromWarehouse!.id,
        fromWarehouseName: _fromWarehouse!.name,
        toWarehouseId: _toWarehouse!.id,
        toWarehouseName: _toWarehouse!.name,
        quantity: qty,
        createdBy: user?.displayName ?? 'Inconnu',
      );

      await service.addStockTransfer(transfer);

      // Émettre le bordereau PDF automatiquement
      await PdfService.generateTransferBordereau(transfer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfert réussi et Bordereau généré !'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isProcessing = false);
    }
  }
}
