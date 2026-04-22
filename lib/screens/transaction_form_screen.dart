import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/tier.dart';
import '../models/product.dart';
import '../models/warehouse.dart';
import '../models/payment.dart';
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
        final t = tiers.firstWhere((t) => t.id == widget.transaction!.tierId, 
            orElse: () => Tier(
              id: '', 
              name: widget.transaction!.tierName, 
              type: widget.type == TransactionType.sale ? TierType.client : TierType.supplier, 
              phone: '', 
              address: '',
              accountNumber: '',
              compteComptable: '',
            ));

        final warehouses = await service.getWarehouses().first;
        final w = warehouses.firstWhere((w) => w.id == widget.transaction!.warehouseId, 
            orElse: () => warehouses.isNotEmpty ? warehouses.first : Warehouse(id: '', name: '', location: ''));

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

  @override
  void dispose() {
    _amountPaidController.dispose();
    _transportFeesController.dispose();
    super.dispose();
  }

  String _formatInitialValue(double? value) {
    if (value == null || value == 0) return '0';
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
    double fees = double.tryParse(_transportFeesController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return _addTransport ? (_totalHT + fees) : (_totalHT - fees);
  }

  // Affiche les informations détaillées de l'article (Oeil)
  void _showProductInfo(BuildContext context, FirestoreService service, String productId) async {
    final product = _cachedProducts[productId];
    if (product == null) return;
    
    int warehouseStock = 0;
    if (_selectedWarehouse != null) {
      warehouseStock = await service.getWarehouseStock(productId, _selectedWarehouse!.id);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Prix d\'achat:', '${_currencyFormat.format(product.purchasePrice)} FCFA'),
            _buildInfoRow('Prix de vente:', '${_currencyFormat.format(product.sellingPrice)} FCFA'),
            const Divider(),
            _buildInfoRow('Stock Global:', '${product.totalQuantity}'),
            _buildInfoRow('Stock Dépôt (${_selectedWarehouse?.name ?? "N/A"}):', '$warehouseStock', color: Colors.blue),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // Dialogue de validation définitive (Check)
  void _confirmPosting(BuildContext context, FirestoreService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider la facture ?'),
        content: const Text('Une fois validée, cette facture sera verrouillée et ne pourra plus être modifiée ni supprimée. Voulez-vous continuer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () async {
              await service.updateTransactionStatus(widget.transaction!.id, true);
              if (mounted) {
                Navigator.pop(context); // Fermer dialogue
                Navigator.pop(context); // Retourner à la liste
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('VALIDER DÉFINITIVEMENT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final isSale = widget.type == TransactionType.sale;
    final color = isSale ? const Color(0xFF1A237E) : const Color(0xFF00796B);

    return StreamBuilder<List<Payment>>(
      stream: firestoreService.getPayments(),
      builder: (context, paymentSnapshot) {
        bool isEditable = true;

        if (widget.transaction != null) {
          isEditable = false; 
          if (paymentSnapshot.hasData) {
            final String invNorm = widget.transaction!.invoiceNumber.trim().toUpperCase().replaceAll(' ', '');
            bool isLocked = (widget.transaction!.amountPaid > 0) || widget.transaction!.isPosted;
            if (!isLocked) {
              isLocked = paymentSnapshot.data!.any((p) {
                if (p.tierId != widget.transaction!.tierId) return false;
                final String pInv = (p.invoiceNumber ?? "").trim().toUpperCase().replaceAll(' ', '');
                final String pRef = p.reference.trim().toUpperCase().replaceAll(' ', '');
                return (pInv == invNorm && pInv.isNotEmpty) || pRef.contains(invNorm);
              });
            }
            if (!isLocked) isEditable = true;
          } else if (paymentSnapshot.connectionState == ConnectionState.waiting) {
            isEditable = false;
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${isSale ? "Vente" : "Achat"} ${widget.transaction?.invoiceNumber ?? "Nouveau"}'),
            backgroundColor: color,
            foregroundColor: Colors.white,
            actions: [
              if (widget.transaction != null && isEditable)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  tooltip: 'Valider et Verrouiller la facture',
                  onPressed: () => _confirmPosting(context, firestoreService),
                ),
            ],
          ),
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isEditable && widget.transaction != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock, color: Colors.orange),
                            const SizedBox(width: 10),
                            Expanded(child: Text("FACTURE VERROUILLÉE : Un règlement a été détecté ou la facture a été validée.",
                              style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                        ),
                      ),
                    
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
                              trailing: isEditable ? const Icon(Icons.search) : null,
                              onTap: isEditable ? () async {
                                final tier = await Navigator.push<Tier>(context, MaterialPageRoute(builder: (context) => TierListScreen(type: isSale ? TierType.client : TierType.supplier, isSelectionMode: true)));
                                if (tier != null) setState(() => _selectedTier = tier);
                              } : null,
                            ),
                            const Divider(),
                            StreamBuilder<List<Warehouse>>(
                              stream: firestoreService.getWarehouses(),
                              builder: (context, snapshot) {
                                final warehouses = snapshot.data ?? [];
                                return DropdownButtonFormField<Warehouse>(
                                  value: _selectedWarehouse,
                                  decoration: const InputDecoration(prefixIcon: Icon(Icons.warehouse), labelText: 'Dépôt de stockage', border: InputBorder.none),
                                  items: warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
                                  onChanged: isEditable ? (val) => setState(() => _selectedWarehouse = val) : null,
                                );
                              },
                            ),
                            const Divider(),
                            TextFormField(
                              initialValue: _destination,
                              enabled: isEditable,
                              decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on), labelText: 'Destination / Origine', border: InputBorder.none),
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
                        const Text('ARTICLES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (isEditable)
                          ElevatedButton.icon(
                            onPressed: () async {
                              final p = await Navigator.push<Product>(context, MaterialPageRoute(builder: (context) => const StockScreen(isSelectionMode: true)));
                              if (p != null) {
                                _cachedProducts[p.id] = p;
                                setState(() {
                                  final index = _items.indexWhere((item) => item.productId == p.id);
                                  if (index != -1) {
                                    // Si l'article existe déjà, on incrémente la quantité
                                    final existingItem = _items[index];
                                    _items[index] = TransactionItem(
                                      productId: existingItem.productId,
                                      productName: existingItem.productName,
                                      quantity: existingItem.quantity + 1,
                                      unitPrice: existingItem.unitPrice,
                                      discount: existingItem.discount,
                                    );
                                  } else {
                                    // Sinon, on ajoute une nouvelle ligne
                                    _items.add(TransactionItem(
                                      productId: p.id, 
                                      productName: p.name, 
                                      quantity: 1, 
                                      unitPrice: isSale ? p.sellingPrice : p.purchasePrice
                                    ));
                                  }
                                });
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('AJOUTER'),
                            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                          ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    ..._items.asMap().entries.map((entry) {
                      int idx = entry.key;
                      TransactionItem item = entry.value;
                      final prod = _cachedProducts[item.productId];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(item.productName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                  if (isSale && prod != null)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Text(
                                        'Marge: ${_currencyFormat.format((item.unitPrice - prod.purchasePrice) * item.quantity)}',
                                        style: TextStyle(fontSize: 11, color: (item.unitPrice - prod.purchasePrice) >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.visibility, size: 20, color: Colors.blue),
                                    onPressed: () => _showProductInfo(context, firestoreService, item.productId),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  Text('Stock: ${prod?.totalQuantity ?? 0}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                  if (isEditable) IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), constraints: const BoxConstraints(), padding: const EdgeInsets.only(left: 8), onPressed: () => setState(() => _items.removeAt(idx))),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: item.quantity.toString(),
                                      enabled: isEditable,
                                      decoration: const InputDecoration(
                                        labelText: 'Qté', 
                                        border: OutlineInputBorder(), 
                                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 13),
                                      onChanged: (v) => setState(() => _items[idx] = TransactionItem(productId: item.productId, productName: item.productName, quantity: int.tryParse(v) ?? 0, unitPrice: item.unitPrice, discount: item.discount)),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      initialValue: _currencyFormat.format(item.unitPrice),
                                      enabled: isEditable,
                                      decoration: const InputDecoration(
                                        labelText: 'P. Unit', 
                                        border: OutlineInputBorder(), 
                                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 13),
                                      onChanged: (v) => setState(() => _items[idx] = TransactionItem(productId: item.productId, productName: item.productName, quantity: item.quantity, unitPrice: double.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0, discount: item.discount)),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: _currencyFormat.format(item.discount),
                                      enabled: isEditable,
                                      decoration: const InputDecoration(
                                        labelText: 'Rem.', 
                                        border: OutlineInputBorder(), 
                                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 13),
                                      onChanged: (v) => setState(() => _items[idx] = TransactionItem(productId: item.productId, productName: item.productName, quantity: item.quantity, unitPrice: item.unitPrice, discount: double.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)),
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
                    Card(
                      color: color.withOpacity(0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _transportFeesController,
                                    enabled: isEditable,
                                    decoration: const InputDecoration(
                                      labelText: 'Transp.', 
                                      border: OutlineInputBorder(), 
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 13),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<bool>(
                                    value: _addTransport,
                                    decoration: const InputDecoration(
                                      labelText: 'Type', 
                                      border: OutlineInputBorder(), 
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                      isDense: true,
                                    ),
                                    style: const TextStyle(fontSize: 12, color: Colors.black),
                                    items: const [
                                      DropdownMenuItem(value: true, child: Text('Ajout (+)', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: false, child: Text('Soust. (-)', style: TextStyle(fontSize: 12))),
                                    ],
                                    onChanged: isEditable ? (val) => setState(() => _addTransport = val!) : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _amountPaidController,
                                    enabled: isEditable,
                                    decoration: const InputDecoration(
                                      labelText: 'Acompte', 
                                      border: OutlineInputBorder(), 
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 13),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    value: _paymentMethod,
                                    decoration: const InputDecoration(
                                      labelText: 'Mode', 
                                      border: OutlineInputBorder(), 
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                      isDense: true,
                                    ),
                                    style: const TextStyle(fontSize: 12, color: Colors.black),
                                    items: ['Espèces', 'Chèque', 'Virement', 'Mobile'].map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
                                    onChanged: isEditable ? (val) => setState(() => _paymentMethod = val!) : null,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 30),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (isSale) FittedBox(fit: BoxFit.scaleDown, child: Text('MARGE ESTIMÉE : ${_currencyFormat.format(_totalMarge)} FCFA', style: TextStyle(color: _totalMarge >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
                                FittedBox(fit: BoxFit.scaleDown, child: Text('TOTAL HT : ${_currencyFormat.format(_totalHT)} FCFA')),
                                FittedBox(fit: BoxFit.scaleDown, child: Text('NET À PAYER : ${_currencyFormat.format(_netToPay)} FCFA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    if (isEditable)
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: (_selectedTier == null || _items.isEmpty || _selectedWarehouse == null) ? null : () async {
                            final auth = Provider.of<AuthService>(context, listen: false);
                            final user = await auth.getAppUser((await auth.user.first)!.uid);
                            
                            final tx = AppTransaction(
                              id: widget.transaction?.id ?? '',
                              invoiceNumber: widget.transaction?.invoiceNumber ?? 'FA${DateFormat('ddMMyyHHmm').format(DateTime.now())}',
                              date: widget.transaction?.date ?? DateTime.now(),
                              tierId: _selectedTier!.id,
                              tierName: _selectedTier!.name,
                              type: widget.type,
                              items: List.from(_items),
                              totalHT: _totalHT,
                              amountPaid: double.tryParse(_amountPaidController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                              paymentMethod: _paymentMethod,
                              warehouseId: _selectedWarehouse!.id,
                              destination: _destination,
                              transportFees: double.tryParse(_transportFeesController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                              addTransport: _addTransport,
                            );

                            if (widget.transaction == null) {
                              await firestoreService.addTransaction(tx, user?.displayName ?? 'Inconnu');
                            } else {
                              await firestoreService.updateTransaction(tx, widget.transaction!);
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text(widget.transaction == null ? 'VALIDER LA TRANSACTION' : 'MODIFIER LA TRANSACTION', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
