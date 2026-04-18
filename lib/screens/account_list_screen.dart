import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../services/firestore_service.dart';

class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  String _searchQuery = "";
  String _selectedNature = "Toutes";
  final List<String> _natures = ['Toutes', 'Charge', 'Produit', 'Immobilisation', 'Client', 'Fournisseur', 'Banque', 'Caisse'];

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Comptable SYSCOHADA'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountDialog(context, service),
        backgroundColor: const Color(0xFF1A237E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un compte...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2, // Augmenté pour éviter l'overflow
                  child: DropdownButtonFormField<String>(
                    value: _selectedNature,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 5),
                    ),
                    items: _natures.map((n) => DropdownMenuItem(
                      value: n, 
                      child: Text(n, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedNature = val!),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Account>>(
              stream: service.getAccounts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                var accounts = snapshot.data ?? [];
                
                if (_searchQuery.isNotEmpty) {
                  accounts = accounts.where((a) => a.label.toLowerCase().contains(_searchQuery) || a.code.contains(_searchQuery)).toList();
                }
                if (_selectedNature != "Toutes") {
                  accounts = accounts.where((a) => a.nature == _selectedNature).toList();
                }

                if (accounts.isEmpty) return const Center(child: Text('Aucun compte trouvé'));

                return ListView.builder(
                  itemCount: accounts.length,
                  itemBuilder: (context, index) {
                    final acc = accounts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      color: acc.isActive ? Colors.white : Colors.grey.shade100,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: acc.isActive ? _getNatureColor(acc.nature) : Colors.grey,
                          child: Text(acc.code.substring(0, 1), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(acc.label, style: TextStyle(fontWeight: FontWeight.bold, decoration: acc.isActive ? null : TextDecoration.lineThrough)),
                        subtitle: Text("Code: ${acc.code} | Nature: ${acc.nature}", style: TextStyle(color: acc.isActive ? null : Colors.red)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(acc.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, color: acc.isActive ? Colors.orange : Colors.green),
                              tooltip: 'Mettre en sommeil',
                              onPressed: () => _toggleAccountStatus(service, acc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showAccountDialog(context, service, account: acc),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleAccountStatus(FirestoreService service, Account acc) {
    final updated = Account(id: acc.id, code: acc.code, label: acc.label, nature: acc.nature, isActive: !acc.isActive);
    service.updateAccount(updated);
  }

  Color _getNatureColor(String nature) {
    switch (nature) {
      case 'Charge': return Colors.orange;
      case 'Produit': return Colors.green;
      case 'Immobilisation': return Colors.blue;
      case 'Banque': return Colors.teal;
      case 'Caisse': return Colors.amber;
      case 'Client': return Colors.indigo;
      case 'Fournisseur': return Colors.deepPurple;
      default: return Colors.grey;
    }
  }

  void _showAccountDialog(BuildContext context, FirestoreService service, {Account? account}) {
    final codeController = TextEditingController(text: account?.code);
    final labelController = TextEditingController(text: account?.label);
    String selectedNature = account?.nature ?? 'Charge';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(account == null ? "Nouveau Compte" : "Modifier Compte"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codeController, decoration: const InputDecoration(labelText: "Code")),
                TextField(controller: labelController, decoration: const InputDecoration(labelText: "Libellé")),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedNature,
                  decoration: const InputDecoration(labelText: "Nature"),
                  items: _natures.where((n) => n != 'Toutes')
                      .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedNature = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () async {
                final newAcc = Account(
                  id: account?.id ?? '',
                  code: codeController.text,
                  label: labelController.text,
                  nature: selectedNature,
                  isActive: account?.isActive ?? true,
                );
                if (account == null) {
                  await service.addAccount(newAcc);
                } else {
                  await service.updateAccount(newAcc);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Enregistrer"),
            ),
          ],
        ),
      ),
    );
  }
}
