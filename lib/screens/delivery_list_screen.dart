import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/transaction.dart';
import '../models/app_user.dart';
import '../services/pdf_service.dart';

class DeliveryListScreen extends StatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> {
  String _searchQuery = "";
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);
    final currentUser = Provider.of<AppUser?>(context);

    if (currentUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isAdmin = currentUser.role == UserRole.admin;
    final warehouseId = currentUser.warehouseId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bons de Livraison (BL)'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _selectedDate = null),
            ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher par N° Facture ou Client...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Chip(
                label: Text('Date : ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}'),
                onDeleted: () => setState(() => _selectedDate = null),
                backgroundColor: Colors.orange.shade100,
              ),
            ),
          Expanded(
            child: StreamBuilder<List<AppTransaction>>(
              stream: service.getTransactions(type: TransactionType.sale),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                var transactions = snapshot.data ?? [];

                // 1. Filtrer par dépôt si c'est un magasinier
                if (!isAdmin && warehouseId != null) {
                  transactions = transactions.where((t) => t.warehouseId == warehouseId).toList();
                } else if (!isAdmin && warehouseId == null && currentUser.role == UserRole.storekeeper) {
                  return const Center(child: Text('Erreur : Aucun dépôt assigné à votre compte.'));
                }

                // 2. Filtrer par recherche (N° Facture ou Nom Client)
                if (_searchQuery.isNotEmpty) {
                  transactions = transactions.where((t) => 
                    t.invoiceNumber.toLowerCase().contains(_searchQuery) || 
                    t.tierName.toLowerCase().contains(_searchQuery)
                  ).toList();
                }

                // 3. Filtrer par date
                if (_selectedDate != null) {
                  transactions = transactions.where((t) => 
                    t.date.year == _selectedDate!.year &&
                    t.date.month == _selectedDate!.month &&
                    t.date.day == _selectedDate!.day
                  ).toList();
                }

                if (transactions.isEmpty) return const Center(child: Text('Aucun bon de livraison trouvé.'));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    final isDelivered = t.deliveryStatus == 'delivered';

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: isDelivered ? Colors.green.shade50 : Colors.orange.shade50,
                          child: Icon(
                            isDelivered ? Icons.check_circle : Icons.local_shipping, 
                            color: isDelivered ? Colors.green : Colors.orange
                          ),
                        ),
                        title: Text('BL-${t.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Client : ${t.tierName.toUpperCase()}'),
                            Text('Date : ${DateFormat('dd/MM/yyyy HH:mm').format(t.date)}'),
                            if (t.destination.isNotEmpty)
                              Text('Destination : ${t.destination}', style: const TextStyle(fontStyle: FontStyle.italic)),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isDelivered)
                              ElevatedButton(
                                onPressed: () => _markAsDelivered(context, service, t.id),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                child: const Text('LIVRER', style: TextStyle(color: Colors.white, fontSize: 12)),
                              )
                            else
                              const Icon(Icons.verified, color: Colors.green, size: 30),
                          ],
                        ),
                        onTap: () => PdfService.generateDeliveryNote(t),
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

  void _markAsDelivered(BuildContext context, FirestoreService service, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la livraison'),
        content: const Text('Voulez-vous marquer ce bon de livraison comme "LIVRÉ" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer', style: TextStyle(color: Colors.green))),
        ],
      ),
    );

    if (confirm == true) {
      await service.updateDeliveryStatus(id, 'delivered');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Livraison confirmée !'),
            backgroundColor: Colors.green,
          )
        );
      }
    }
  }
}
