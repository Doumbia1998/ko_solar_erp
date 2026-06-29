import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/transaction.dart';
import '../services/pdf_service.dart';
import '../services/report_service.dart';

class DeliveryListScreen extends StatefulWidget {
  final int initialTab;
  const DeliveryListScreen({super.key, this.initialTab = 0});

  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = "";
  DateTime? _filterDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void didUpdateWidget(DeliveryListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _tabController.animateTo(widget.initialTab);
    }
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
            icon: Icon(Icons.event, color: _filterDate != null ? Colors.yellow : Colors.white),
            tooltip: 'Filtrer par date de livraison',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _filterDate ?? DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
                locale: const Locale('fr', 'FR'),
              );
              if (picked != null) setState(() => _filterDate = picked);
            },
          ),
          if (_filterDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.redAccent),
              onPressed: () => setState(() => _filterDate = null),
            ),
          TextButton.icon(
            icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
            label: const Text('RAPP. LIVRÉS', style: TextStyle(color: Colors.white, fontSize: 10)),
            onPressed: () => _generateDailyDeliveryReport(service),
          ),
          TextButton.icon(
            icon: const Icon(Icons.pending_outlined, color: Colors.orangeAccent),
            label: const Text('RAPP. ATTENTES', style: TextStyle(color: Colors.white, fontSize: 10)),
            onPressed: () => _generatePendingDeliveryReport(service),
          ),
          const SizedBox(width: 10),
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

        // Filtrage par date pour l'onglet "Déjà Livré"
        if (status == 'delivered' && _filterDate != null) {
          list = list.where((t) =>
            t.deliveredAt != null &&
            t.deliveredAt!.year == _filterDate!.year &&
            t.deliveredAt!.month == _filterDate!.month &&
            t.deliveredAt!.day == _filterDate!.day
          ).toList();
        }

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
                    Text('Facturé le: ${DateFormat('dd/MM/yyyy').format(t.date)}\nArticles: ${t.items.length}'),
                    if (status == 'delivered' && t.deliveredAt != null)
                      Text('Livré le: ${DateFormat('dd/MM/yyyy HH:mm').format(t.deliveredAt!)}',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
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
    DateTime? reportDate = _filterDate;

    if (reportDate == null) {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2023),
        lastDate: DateTime.now(),
      );
      if (picked == null) return;
      reportDate = picked;
    }

    final txs = await service.getTransactions(type: TransactionType.sale).first;
    final targetTxs = txs.where((t) {
      if (t.deliveryStatus != 'delivered' || t.deliveredAt == null) return false;
      final dDate = t.deliveredAt!.toLocal();
      return dDate.year == reportDate!.year &&
             dDate.month == reportDate.month &&
             dDate.day == reportDate.day;
    }).toList();

    if (targetTxs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Aucune livraison validée le ${DateFormat('dd/MM/yyyy').format(reportDate)}.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    ReportService.generateDailyDeliveryReport(targetTxs,
      title: "LIVRAISONS EFFECTUÉES LE ${DateFormat('dd/MM/yyyy').format(reportDate)}");
  }

  void _generatePendingDeliveryReport(FirestoreService service) async {
    final txs = await service.getTransactions(type: TransactionType.sale).first;
    final pendingTxs = txs.where((t) => t.deliveryStatus == 'pending').toList();

    if (pendingTxs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune livraison en attente.')));
      return;
    }

    ReportService.generateDailyDeliveryReport(pendingTxs, title: "LIVRAISONS EN ATTENTE (NON LIVRÉES)");
  }
}
