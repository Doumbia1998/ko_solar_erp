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
  late TextEditingController _compteComptableController;
  late String _accountNumber;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tier?.name ?? '');
    _phoneController = TextEditingController(text: widget.tier?.phone ?? '');
    _addressController = TextEditingController(text: widget.tier?.address ?? '');
    _compteComptableController = TextEditingController(text: widget.tier?.compteComptable ?? '');
    _accountNumber = widget.tier?.accountNumber ?? (widget.type == TierType.client ? '41100000' : '40100000');
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Row(
                children: [
                  Icon(Icons.person, color: Color(0xFF1A237E)),
                  SizedBox(width: 8),
                  Text('Identité', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom / Compte Tiers', border: UnderlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _accountNumber,
                decoration: const InputDecoration(border: UnderlineInputBorder(), labelText: 'Compte Général'),
                items: const [
                  DropdownMenuItem(value: '41100000', child: Text('41100000 - Clients Divers')),
                  DropdownMenuItem(value: '40100000', child: Text('40100000 - Fournisseurs')),
                ],
                onChanged: (val) => setState(() => _accountNumber = val!),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _compteComptableController,
                decoration: const InputDecoration(labelText: 'Compte Comptable Spécifique', border: UnderlineInputBorder(), hintText: 'ex: 41110001'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Téléphone', border: UnderlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final tier = Tier(
                        id: widget.tier?.id ?? '',
                        name: _nameController.text,
                        phone: _phoneController.text,
                        address: _addressController.text,
                        type: _accountNumber == '41100000' ? TierType.client : TierType.supplier,
                        accountNumber: _accountNumber,
                        compteComptable: _compteComptableController.text,
                      );
                      
                      if (widget.tier == null) {
                        await context.read<FirestoreService>().addTier(tier);
                      } else {
                        await context.read<FirestoreService>().updateTier(tier);
                      }
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(widget.tier == null ? 'VALIDER' : 'MODIFIER', style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
