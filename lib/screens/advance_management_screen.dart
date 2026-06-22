import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/advance.dart';
import '../models/tier.dart';
import 'tier_list_screen.dart';

class AdvanceManagementScreen extends StatefulWidget {
  const AdvanceManagementScreen({super.key});

  @override
  State<AdvanceManagementScreen> createState() => _AdvanceManagementScreenState();
}

class _AdvanceManagementScreenState extends State<AdvanceManagementScreen> {
  final _format = NumberFormat('#,###', 'fr_FR');
  Tier? _selectedTier;
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  String _selectedMethod = 'Espèces';

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTION DES AVANCES CLIENTS'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildAddForm(service),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('HISTORIQUE DES AVANCES', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          Expanded(child: _buildAdvanceList(service)),
        ],
      ),
    );
  }

  Widget _buildAddForm(FirestoreService service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ENREGISTRER UNE AVANCE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ListTile(
                  tileColor: Colors.grey.shade50,
                  leading: const Icon(Icons.person),
                  title: Text(_selectedTier?.name ?? 'Sélectionner un Client'),
                  onTap: () async {
                    final t = await Navigator.push<Tier>(context, MaterialPageRoute(builder: (context) => const TierListScreen(type: TierType.client, isSelectionMode: true)));
                    if (t != null) setState(() => _selectedTier = t);
                  },
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant de l\'avance', border: OutlineInputBorder(), prefixIcon: Icon(Icons.money)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _refController,
                  decoration: const InputDecoration(labelText: 'Référence / Libellé', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMethod,
                  decoration: const InputDecoration(labelText: 'Mode de règlement', border: OutlineInputBorder()),
                  items: ['Espèces', 'Chèque', 'Virement', 'Mobile Money'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _selectedMethod = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveAdvance,
              icon: const Icon(Icons.save),
              label: const Text('VALIDER L\'AVANCE ET CRÉDITER LE COMPTE'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvanceList(FirestoreService service) {
    return StreamBuilder<List<Advance>>(
      stream: service.getAdvances(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final advances = snapshot.data!;
        if (advances.isEmpty) return const Center(child: Text('Aucune avance enregistrée.'));

        return ListView.builder(
          itemCount: advances.length,
          itemBuilder: (context, index) {
            final a = advances[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: a.isUsed ? Colors.grey.shade100 : Colors.blue.shade50,
              child: ListTile(
                leading: Icon(a.isUsed ? Icons.check_circle : Icons.pending, color: a.isUsed ? Colors.grey : Colors.blue),
                title: Text('${a.tierName.toUpperCase()} - ${_format.format(a.amount)} F'),
                subtitle: Text('Réf: ${a.reference} | Date: ${DateFormat('dd/MM/yy').format(a.date)}\nFait par: ${a.createdBy}'),
                trailing: a.isUsed
                  ? Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                      child: Text('UTILISÉ : ${a.usedInInvoice}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                    )
                  : IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(a)),
              ),
            );
          },
        );
      },
    );
  }

  void _saveAdvance() async {
    if (_selectedTier == null || _amountController.text.isEmpty) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final service = Provider.of<FirestoreService>(context, listen: false);
    final user = await auth.getAppUser((await auth.user.first)!.uid);

    final adv = Advance(
      id: '',
      tierId: _selectedTier!.id,
      tierName: _selectedTier!.name,
      amount: double.tryParse(_amountController.text) ?? 0,
      date: DateTime.now(),
      method: _selectedMethod,
      reference: _refController.text.isEmpty ? 'AVANCE' : _refController.text,
      createdBy: user?.displayName ?? 'Admin',
    );

    await service.addAdvance(adv);
    _amountController.clear();
    _refController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avance enregistrée !'), backgroundColor: Colors.green));
  }

  void _confirmDelete(Advance a) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette avance ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          TextButton(
            onPressed: () async {
              final auth = Provider.of<AuthService>(context, listen: false);
              final user = await auth.getAppUser((await auth.user.first)!.uid);
              await Provider.of<FirestoreService>(context, listen: false).deleteAdvance(a.id, user?.displayName ?? 'Admin');
              Navigator.pop(context);
            },
            child: const Text('SUPPRIMER', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}
