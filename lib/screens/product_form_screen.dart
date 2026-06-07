import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/warehouse.dart';
import '../models/account.dart';
import '../services/firestore_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _quantityController;
  
  Account? _selectedAccountAchat;
  Account? _selectedAccountVente;
  
  String _category = 'Divers';
  Warehouse? _selectedWarehouse;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descriptionController = TextEditingController(text: widget.product?.description ?? '');
    _purchasePriceController = TextEditingController(text: widget.product?.purchasePrice.toString() ?? '0');
    _sellingPriceController = TextEditingController(text: widget.product?.sellingPrice.toString() ?? '0');
    _quantityController = TextEditingController(text: widget.product?.totalQuantity.toString() ?? '0');
    
    if (widget.product != null) _category = widget.product!.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Nouvel Article' : 'Modifier Article'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: StreamBuilder<List<Account>>(
              stream: service.getAccounts(),
              builder: (context, snapshotAcc) {
                final accounts = snapshotAcc.data ?? [];
                
                // Initialisation des comptes au chargement
                if (accounts.isNotEmpty && _selectedAccountAchat == null) {
                  String codeAchat = widget.product?.compteAchat ?? '601100';
                  String codeVente = widget.product?.compteVente ?? '701100';
                  
                  try {
                    _selectedAccountAchat = accounts.firstWhere((a) => a.code == codeAchat);
                  } catch(_) {
                    _selectedAccountAchat = accounts.where((a) => a.nature == 'Charge').firstOrNull;
                  }
                  
                  try {
                    _selectedAccountVente = accounts.firstWhere((a) => a.code == codeVente);
                  } catch(_) {
                    _selectedAccountVente = accounts.where((a) => a.nature == 'Produit').firstOrNull;
                  }
                }

                return Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory, color: Color(0xFF1A237E)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'INFORMATIONS PRODUIT', 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), letterSpacing: 1.2),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Désignation / Nom',
                                  prefixIcon: Icon(Icons.label),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value!.isEmpty ? 'Champ requis' : null,
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(
                                  labelText: 'Description détaillée',
                                  prefixIcon: Icon(Icons.description),
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 20),
                              
                              // --- COMPTES COMPTABLES ---
                              const Text('PARAMÉTRAGE COMPTABLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<Account>(
                                value: _selectedAccountAchat,
                                decoration: const InputDecoration(
                                  labelText: 'Compte Achat de Marchandises',
                                  prefixIcon: Icon(Icons.shopping_basket),
                                  border: OutlineInputBorder(),
                                ),
                                isExpanded: true,
                                items: accounts.where((a) => a.nature == 'Charge').map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text('${a.code} - ${a.label}', style: const TextStyle(fontSize: 13)),
                                )).toList(),
                                onChanged: (val) => setState(() => _selectedAccountAchat = val),
                                validator: (val) => val == null ? 'Requis' : null,
                              ),
                              const SizedBox(height: 15),
                              DropdownButtonFormField<Account>(
                                value: _selectedAccountVente,
                                decoration: const InputDecoration(
                                  labelText: 'Compte Vente de Marchandises',
                                  prefixIcon: Icon(Icons.sell),
                                  border: OutlineInputBorder(),
                                ),
                                isExpanded: true,
                                items: accounts.where((a) => a.nature == 'Produit').map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text('${a.code} - ${a.label}', style: const TextStyle(fontSize: 13)),
                                )).toList(),
                                onChanged: (val) => setState(() => _selectedAccountVente = val),
                                validator: (val) => val == null ? 'Requis' : null,
                              ),
                              const SizedBox(height: 20),

                              LayoutBuilder(
                                builder: (context, constraints) {
                                  bool isMobile = constraints.maxWidth < 500;
                                  return isMobile 
                                    ? Column(
                                        children: [
                                          TextFormField(
                                            controller: _purchasePriceController,
                                            decoration: const InputDecoration(
                                              labelText: 'Prix d\'achat',
                                              prefixIcon: Icon(Icons.download),
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType: TextInputType.number,
                                          ),
                                          const SizedBox(height: 20),
                                          TextFormField(
                                            controller: _sellingPriceController,
                                            decoration: const InputDecoration(
                                              labelText: 'Prix de vente',
                                              prefixIcon: Icon(Icons.upload),
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType: TextInputType.number,
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _purchasePriceController,
                                              decoration: const InputDecoration(
                                                labelText: 'Prix d\'achat',
                                                prefixIcon: Icon(Icons.download),
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType: TextInputType.number,
                                            ),
                                          ),
                                          const SizedBox(width: 15),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _sellingPriceController,
                                              decoration: const InputDecoration(
                                                labelText: 'Prix de vente',
                                                prefixIcon: Icon(Icons.upload),
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType: TextInputType.number,
                                            ),
                                          ),
                                        ],
                                      );
                                }
                              ),
                              const SizedBox(height: 20),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  bool isMobile = constraints.maxWidth < 500;
                                  return isMobile
                                    ? Column(
                                        children: [
                                          TextFormField(
                                            controller: _quantityController,
                                            decoration: const InputDecoration(
                                              labelText: 'Stock Initial',
                                              prefixIcon: Icon(Icons.storage),
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType: TextInputType.number,
                                          ),
                                          const SizedBox(height: 20),
                                          DropdownButtonFormField<String>(
                                            value: _category,
                                            decoration: const InputDecoration(
                                              labelText: 'Catégorie',
                                              prefixIcon: Icon(Icons.category),
                                              border: OutlineInputBorder(),
                                            ),
                                            items: ['Divers', 'Pièces', 'Huiles'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                            onChanged: (val) => setState(() => _category = val!),
                                          ),
                                          if (widget.product == null) ...[
                                            const SizedBox(height: 20),
                                            StreamBuilder<List<Warehouse>>(
                                              stream: service.getWarehouses(),
                                              builder: (context, snapshot) {
                                                final warehouses = snapshot.data ?? [];
                                                return DropdownButtonFormField<Warehouse>(
                                                  value: _selectedWarehouse,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Dépôt de stockage initial',
                                                    prefixIcon: Icon(Icons.warehouse),
                                                    border: OutlineInputBorder(),
                                                  ),
                                                  items: warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
                                                  onChanged: (val) => setState(() => _selectedWarehouse = val),
                                                  validator: (val) => (int.tryParse(_quantityController.text) ?? 0) > 0 && val == null ? 'Dépôt requis pour le stock initial' : null,
                                                );
                                              },
                                            ),
                                          ],
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _quantityController,
                                              decoration: const InputDecoration(
                                                labelText: 'Stock Initial',
                                                prefixIcon: Icon(Icons.storage),
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType: TextInputType.number,
                                            ),
                                          ),
                                          const SizedBox(width: 15),
                                          Expanded(
                                            child: DropdownButtonFormField<String>(
                                              value: _category,
                                              decoration: const InputDecoration(
                                                labelText: 'Catégorie',
                                                prefixIcon: Icon(Icons.category),
                                                border: OutlineInputBorder(),
                                              ),
                                              items: ['Divers', 'Pièces', 'Huiles'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                              onChanged: (val) => setState(() => _category = val!),
                                            ),
                                          ),
                                        ],
                                      );
                                }
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final product = Product(
                                id: widget.product?.id ?? '',
                                name: _nameController.text.toUpperCase(),
                                description: _descriptionController.text,
                                purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0,
                                sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0,
                                totalQuantity: int.tryParse(_quantityController.text) ?? 0,
                                category: _category,
                                compteAchat: _selectedAccountAchat?.code ?? '601100',
                                compteVente: _selectedAccountVente?.code ?? '701100',
                              );
                              
                              if (widget.product == null) {
                                await service.addProduct(product, warehouseId: _selectedWarehouse?.id);
                              } else {
                                await service.updateProduct(product);
                              }

                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          child: Text(
                            widget.product == null ? 'ENREGISTRER L\'ARTICLE' : 'METTRE À JOUR',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
