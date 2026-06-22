import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tier.dart';
import '../services/firestore_service.dart';

class TierFormScreen extends StatefulWidget {
  final TierType type;
  final Tier? tier; 
  const TierFormScreen({super.key, required this.type, this.tier});

  @override
  State<TierFormScreen> createState() => _TierFormScreenState();
}

class _TierFormScreenState extends State<TierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _compteTiersController;
  late String _compteGeneral;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tier?.name ?? '');
    _phoneController = TextEditingController(text: widget.tier?.phone ?? '');
    _addressController = TextEditingController(text: widget.tier?.address ?? '');
    _compteTiersController = TextEditingController(text: widget.tier?.compteTiers ?? '');
    _compteGeneral = widget.tier?.compteGeneral ?? (widget.type == TierType.client ? '41100000' : '40100000');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _compteTiersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tier == null ? 'Nouveau Tiers' : 'Modifier Tiers'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
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
                      Icon(Icons.person, color: Color(0xFF1A237E)),
                      SizedBox(width: 8),
                      Text('IDENTITÉ DU TIERS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), letterSpacing: 1.2)),
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
                              labelText: 'Nom / Raison Sociale',
                              prefixIcon: Icon(Icons.business),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => value!.isEmpty ? 'Champ requis' : null,
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            value: ['41100000', '40100000'].contains(_compteGeneral) ? _compteGeneral : null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Catégorie Générale',
                              hintText: _compteGeneral,
                              prefixIcon: const Icon(Icons.category),
                              border: const OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: '41100000', 
                                child: Text('41100000 - Clients', overflow: TextOverflow.ellipsis)
                              ),
                              DropdownMenuItem(
                                value: '40100000', 
                                child: Text('40100000 - Fournisseurs', overflow: TextOverflow.ellipsis)
                              ),
                            ],
                            onChanged: (val) => setState(() => _compteGeneral = val!),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _compteTiersController,
                            decoration: const InputDecoration(
                              labelText: 'Compte Tiers (ex: 411AZIZ)',
                              prefixIcon: Icon(Icons.account_tree),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Téléphone',
                              prefixIcon: Icon(Icons.phone),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
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
                          final firestoreService = context.read<FirestoreService>();
                          final newName = _nameController.text.trim().toUpperCase();

                          // Vérification des doublons (Nom et Compte Tiers)
                          if (widget.tier == null) {
                            final allTiers = await firestoreService.getTiers(null).first;
                            bool nameExists = allTiers.any((t) => t.name.trim().toUpperCase() == newName);
                            bool codeExists = allTiers.any((t) => t.compteTiers.trim().toUpperCase() == _compteTiersController.text.trim().toUpperCase());

                            if (nameExists || codeExists) {
                              if (mounted) {
                                String errorMsg = nameExists ? "Le nom '$newName' existe déjà." : "Le compte tiers '${_compteTiersController.text.toUpperCase()}' existe déjà.";
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Doublon détecté", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                    content: Text("$errorMsg\n\nVeuillez utiliser des identifiants uniques."),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
                                    ],
                                  ),
                                );
                              }
                              return;
                            }
                          }

                          final tier = Tier(
                            id: widget.tier?.id ?? '',
                            name: newName,
                            phone: _phoneController.text.trim(),
                            address: _addressController.text.trim(),
                            type: _compteGeneral == '41100000' ? TierType.client : TierType.supplier,
                            compteGeneral: _compteGeneral,
                            compteTiers: _compteTiersController.text.trim().toUpperCase(),
                          );
                          
                          if (widget.tier == null) {
                            await firestoreService.addTier(tier);
                          } else {
                            await firestoreService.updateTier(tier);
                          }
                          if (mounted) Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: Text(
                        widget.tier == null ? 'ENREGISTRER LE TIERS' : 'METTRE À JOUR',
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
