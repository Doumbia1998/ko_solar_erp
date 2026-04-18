import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
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
  late TextEditingController _compteComptableController;
  String _category = 'Divers';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name);
    _descriptionController = TextEditingController(text: widget.product?.description);
    _purchasePriceController = TextEditingController(text: widget.product?.purchasePrice.toString());
    _sellingPriceController = TextEditingController(text: widget.product?.sellingPrice.toString());
    _quantityController = TextEditingController(text: widget.product?.totalQuantity.toString());
    _compteComptableController = TextEditingController(text: widget.product?.compteComptable);
    if (widget.product != null) _category = widget.product!.category;
  }

  @override
  Widget build(BuildContext context) {
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
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.inventory, color: Color(0xFF1A237E)),
                      SizedBox(width: 8),
                      Text('INFORMATIONS PRODUIT', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), letterSpacing: 1.2)),
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
                          Row(
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
                          ),
                          const SizedBox(height: 20),
                          Row(
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
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _compteComptableController,
                            decoration: const InputDecoration(
                              labelText: 'Compte Comptable (ex: 601, 701)',
                              prefixIcon: Icon(Icons.account_balance),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => value!.isEmpty ? 'Champ requis' : null,
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
                            compteComptable: _compteComptableController.text,
                          );
                          
                          if (widget.product == null) {
                            await context.read<FirestoreService>().addProduct(product);
                          } else {
                            await context.read<FirestoreService>().updateProduct(product);
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
            ),
          ),
        ),
      ),
    );
  }
}
