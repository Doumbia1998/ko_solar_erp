import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/transaction.dart';
import '../services/pdf_service.dart';
import '../services/report_service.dart';

class DeliveryListScreen extends StatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTION DES LIVRAISONS (BL)'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Rapport Journalier des Livraisons',
            onPressed: () => _generateDailyDeliveryReport(service),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'À LIVRER (EN ATTENTE)'),
            Tab(text: 'DÉJÀ LIVRÉ (ARCHIVES)'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orangeAccent,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un client ou N° BL...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => setState(() => _search = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(service, 'pending'),
                _buildList(service, 'delivered'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(FirestoreService service, String status) {
    return StreamBuilder<List<AppTransaction>>(
      stream: service.getTransactions(type: TransactionType.sale),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var list = snapshot.data!.where((t) => t.deliveryStatus == status).toList();

        if (_search.isNotEmpty) {
          list = list.where((t) =>
            t.tierName.toLowerCase().contains(_search) ||
            t.invoiceNumber.toLowerCase().contains(_search)
          ).toList();
        }

        if (list.isEmpty) return Center(child: Text(status == 'pending' ? 'Aucune livraison en attente.' : 'Aucune archive de livraison.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final t = list[index];
            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: status == 'pending' ? Colors.orange.shade50 : Colors.green.shade50,
                  child: Icon(status == 'pending' ? Icons.local_shipping : Icons.check_circle, color: status == 'pending' ? Colors.orange : Colors.green),
                ),
                title: Text('BL-${t.invoiceNumber} | ${t.tierName.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date: ${DateFormat('dd/MM/yyyy').format(t.date)}\nArticles: ${t.items.length}'),
                    if (t.createdBy.isNotEmpty)
                      Text('Fait par: ${t.createdBy}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.blueGrey),
                      onPressed: () => PdfService.generateDeliveryNote(t),
                    ),
                    if (status == 'pending')
                      ElevatedButton(
                        onPressed: () => _confirmDelivery(context, service, t),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('MARQUER LIVRÉ'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelivery(BuildContext context, FirestoreService service, AppTransaction t) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la livraison'),
        content: Text('Voulez-vous marquer le BL-${t.invoiceNumber} comme livré ? Il sera archivé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('NON')),
          ElevatedButton(
            onPressed: () async {
              await service.updateDeliveryStatus(t.id, 'delivered');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Livraison confirmée et archivée !'), backgroundColor: Colors.green));
            },
            child: const Text('OUI, LIVRÉ'),
          ),
        ],
      ),
    );
  }

  void _generateDailyDeliveryReport(FirestoreService service) async {
    final txs = await service.getTransactions(type: TransactionType.sale).first;
    final now = DateTime.now();
    final todayTxs = txs.where((t) =>
      t.date.year == now.year && t.date.month == now.month && t.date.day == now.day
    ).toList();

    if (todayTxs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune livraison enregistrée aujourd\'hui.')));
      return;
    }

    ReportService.generateDailyDeliveryReport(todayTxs);
  }
}
