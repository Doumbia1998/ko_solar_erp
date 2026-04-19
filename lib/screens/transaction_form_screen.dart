import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/tier.dart';
import '../models/product.dart';
import '../models/warehouse.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'tier_list_screen.dart';
import 'stock_screen.dart';

class TransactionFormScreen extends StatefulWidget {
  final TransactionType type;
  final AppTransaction? transaction;
  const TransactionFormScreen({super.key, required this.type, this.transaction});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
   Tier? _selectedTier;
  Warehouse? _selectedWarehouse;
  final List<TransactionItem> _items = [];
  // Stocker les produits pour le calcul des marges et vérification stock
  final Map<String, Product> _cachedProducts = {}; 
  
  String _paymentMethod = 'Espèces';
  String _destination = ''; 
  bool _addTransport = true; 
  late TextEditingController _amountPaidController;
  late TextEditingController _transportFeesController;
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _amountPaidController = TextEditingController(text: _formatInitialValue(widget.transaction?.amountPaid));
    _transportFeesController = TextEditingController(text: _formatInitialValue(widget.transaction?.transportFees));
    
    if (widget.transaction != null) {
      _paymentMethod = widget.transaction!.paymentMethod;
      _addTransport = widget.transaction!.addTransport;
      _destination = widget.transaction!.destination;
      _items.addAll(widget.transaction!.items);
      
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final service = Provider.of<FirestoreService>(context, listen: false);
        final tiers = await service.getTiers(widget.type == TransactionType.sale ? TierType.client : TierType.supplier).first;
        final t = tiers.firstWhere((t) => t.id == widget.transaction!.tierId, orElse: () => _selectedTier!);
        
        final warehouses = await service.getWarehouses().first;
        final w = warehouses.firstWhere((w) => w.id == widget.transaction!.warehouseId, orElse: () => _selectedWarehouse!);

        // Charger les produits en cache pour les marges
        final allProducts = await service.getProducts().first;
        for (var p in allProducts) {
          _cachedProducts[p.id] = p;
        }
        
        if (mounted) {
          setState(() {
            _selectedTier = t;
            _selectedWarehouse = w;
          });
        }
      });
    }
  }

  String _formatInitialValue(double? value) {
    if (value == null) return '0';
    return _currencyFormat.format(value);
  }

  double get _totalHT => _items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice) - item.discount);

  double get _totalMarge {
    double marge = 0;
    for (var item in _items) {
      final prod = _cachedProducts[item.productId];
      if (prod != null) {
        marge += ((item.unitPrice - prod.purchasePrice) * item.quantity);
      }
    }
    return marge;
  }
  
  double get _netToPay {
    double fees = double.tryParse(_transportFeesController.text.replaceAll(' ', '')) ?? 0;
    return _addTransport ? (_totalHT + fees) : (_totalHT - fees);
  }

  void _checkStock(Product product, int requestedQty, int indexIfUpdate) {
    if (widget.type == TransactionType.sale) {
      if (requestedQty > product.totalQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('STOCK INSUFFISANT pour ${product.name} !\nDisponible: ${product.totalQuantity} | Demandé: $requestedQty'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final isSale = widget.type == TransactionType.sale;
    final color = isSale ? const Color(0xFF1A237E) : const Color(0xFF00796B);

    return Scaffold(
      appBar: AppBar(
        title: Text('${isSale ? "Vente" : "Achat"} FA${DateFormat('ddMMyy').format(DateTime.now())}'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Tiers et Dépôt
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(_selectedTier?.name ?? 'Choisir un ${isSale ? "Client" : "Fournisseur"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(isSale ? 'Client' : 'Fournisseur'),
                          trailing: const Icon(Icons.search),
                          onTap: () async {
                            final tier = await Navigator.push<Tier>(
                              context,
                              MaterialPageRoute(builder: (context) => TierListScreen(type: isSale ? TierType.client : TierType.supplier, isSelectionMode: true)),
                            );
                            if (tier != null) setState(() => _selectedTier = tier);
                          },
                        ),
                        const Divider(),
                        StreamBuilder<List<Warehouse>>(
                          stream: firestoreService.getWarehouses(),
                          builder: (context, snapshot) {
                            final warehouses = snapshot.data ?? [];
                            return DropdownButtonFormField<Warehouse>(
                              value: _selectedWarehouse,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.warehouse), 
                                labelText: 'Sélectionner le Dépôt de stockage',
                                border: InputBorder.none
                              ),
                              items: warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
                              onChanged: (val) => setState(() => _selectedWarehouse = val),
                            );
                          },
                        ),
                        const Divider(),
                        TextFormField(
                          initialValue: _destination,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.location_on_outlined), 
                            labelText: 'Destination / Origine des produits',
                            hintText: 'Ex: Port d\'Abidjan, Entrepôt Nord...',
                            border: InputBorder.none
                          ),
                          onChanged: (val) => _destination = val,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ARTICLES / PRODUITS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final product = await Navigator.push<Product>(
                          context,
                          MaterialPageRoute(builder: (context) => const StockScreen(isSelectionMode: true)),
                        );
                        if (product != null) {
                          _cachedProducts[product.id] = product;
                          _checkStock(product, 1, -1);
                          setState(() => _items.add(TransactionItem(
                            productId: product.id,
                            productName: product.name,
                            quantity: 1,
                            unitPrice: isSale ? product.sellingPrice : product.purchasePrice,
                          )));
                        }
                      },
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('AJOUTER'),
                      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                
                // Items List
                ..._items.asMap().entries.map((entry) {
                  int idx = entry.key;
                  TransactionItem item = entry.value;
                  final prod = _cachedProducts[item.productId];
                  double margeUnitaire = (isSale && prod != null) ? item.unitPrice - prod.purchasePrice : 0;

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(item.productName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                              ),
                              if (isSale && prod != null)
                                Expanded(
                                  flex: 2,
                                  child: Text('Marge: ${_currencyFormat.format(margeUnitaire * item.quantity)} F', 
                                         style: TextStyle(color: margeUnitaire >= 0 ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _items.removeAt(idx))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: item.quantity.toString(),
                                  decoration: InputDecoration(
                                    labelText: 'Qté',
                                    border: const OutlineInputBorder(),
                                    suffixText: prod != null ? '/ ${prod.totalQuantity}' : null,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    int q = int.tryParse(val) ?? 0;
                                    if (prod != null) _checkStock(prod, q, idx);
                                    setState(() => _items[idx] = TransactionItem(
                                      productId: item.productId,
                                      productName: item.productName,
                                      quantity: q,
                                      unitPrice: item.unitPrice,
                                      discount: item.discount,
                                    ));
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  initialValue: _currencyFormat.format(item.unitPrice),
                                  decoration: const InputDecoration(labelText: 'Prix Unitaire', border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    String plain = val.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '');
                                    setState(() => _items[idx] = TransactionItem(
                                      productId: item.productId,
                                      productName: item.productName,
                                      quantity: item.quantity,
                                      unitPrice: double.tryParse(plain) ?? 0,
                                      discount: item.discount,
                                    ));
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  initialValue: _currencyFormat.format(item.discount),
                                  decoration: const InputDecoration(labelText: 'Remise', border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    String plain = val.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '');
                                    setState(() => _items[idx] = TransactionItem(
                                      productId: item.productId,
                                      productName: item.productName,
                                      quantity: item.quantity,
                                      unitPrice: item.unitPrice,
                                      discount: double.tryParse(plain) ?? 0,
                                    ));
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                
                const SizedBox(height: 20),
                const Divider(),
                
                // Section Totaux et Transport
                Card(
                  color: color.withOpacity(0.02),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        if (isSale)
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _transportFeesController,
                                  decoration: const InputDecoration(icon: Icon(Icons.local_shipping), labelText: 'Frais de Transport', border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    String plainValue = val.replaceAll(' ', '');
                                    if (plainValue.isNotEmpty) {
                                      double? amount = double.tryParse(plainValue);
                                      if (amount != null) {
                                        String formatted = _currencyFormat.format(amount);
                                        _transportFeesController.value = TextEditingValue(
                                          text: formatted,
                                          selection: TextSelection.collapsed(offset: formatted.length),
                                        );
                                      }
                                    }
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 15),
                              DropdownButton<bool>(
                                value: _addTransport,
                                items: const [
                                  DropdownMenuItem(value: true, child: Text('Ajouter (+)')),
                                  DropdownMenuItem(value: false, child: Text('Soustraire (-)')),
                                ],
                                onChanged: (val) => setState(() => _addTransport = val!),
                              ),
                            ],
                          ),
                        const SizedBox(height: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (isSale) 
                              Text(
                                'MARGE ESTIMÉE : ${_currencyFormat.format(_totalMarge)} FCFA', 
                                style: TextStyle(color: _totalMarge >= 0 ? Colors.green : Colors.red, fontSize: 13, fontWeight: FontWeight.bold)
                              ),
                            const SizedBox(height: 5),
                            Text('Total Articles (HT) : ${_currencyFormat.format(_totalHT)} FCFA', style: const TextStyle(fontSize: 15)),
                            const Divider(),
                            Text(
                              'NET À PAYER : ${_currencyFormat.format(_netToPay)} FCFA',
                              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: (_selectedTier == null || _items.isEmpty || _selectedWarehouse == null) ? null : () async {
                      final transaction = AppTransaction(
                        id: widget.transaction?.id ?? '',
                        invoiceNumber: widget.transaction?.invoiceNumber ?? 'FA${DateFormat('ddMMyyHHmm').format(DateTime.now())}',
                        date: widget.transaction?.date ?? DateTime.now(),
                        tierId: _selectedTier!.id,
                        tierName: _selectedTier!.name,
                        type: widget.type,
                        items: List.from(_items),
                        totalHT: _totalHT,
                        amountPaid: double.tryParse(_amountPaidController.text.replaceAll(' ', '')) ?? 0,
                        paymentMethod: _paymentMethod,
                        warehouseId: _selectedWarehouse!.id,
                        destination: _destination,
                        transportFees: double.tryParse(_transportFeesController.text.replaceAll(' ', '')) ?? 0,
                        addTransport: _addTransport,
                      );
                      
                      if (widget.transaction == null) {
                        final authService = Provider.of<AuthService>(context, listen: false);
                        final user = await authService.getAppUser((await authService.user.first)!.uid);
                        await firestoreService.addTransaction(transaction, user?.displayName ?? 'Inconnu');
                      } else {
                        await firestoreService.updateTransaction(transaction, widget.transaction!);
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 5
                    ),
                    child: Text(
                      widget.transaction == null ? 'VALIDER LA TRANSACTION' : 'MODIFIER LA TRANSACTION',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
