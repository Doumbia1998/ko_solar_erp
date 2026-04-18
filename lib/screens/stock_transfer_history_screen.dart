import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../models/stock_transfer.dart';

class StockTransferHistoryScreen extends StatelessWidget {
  const StockTransferHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Transferts'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<List<StockTransfer>>(
            stream: firestoreService.getStockTransfers(),
            builder: (context, snapshot) {
              return IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    PdfService.generateTransferReport(snapshot.data!);
                  }
                },
              );
            }
          )
        ],
      ),
      body: StreamBuilder<List<StockTransfer>>(
        stream: firestoreService.getStockTransfers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final transfers = snapshot.data ?? [];
          
          if (transfers.isEmpty) return const Center(child: Text('Aucun transfert enregistré'));

          return ListView.builder(
            itemCount: transfers.length,
            itemBuilder: (context, index) {
              final t = transfers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.swap_horiz, color: Colors.orange),
                  title: Text(t.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('De: ${t.fromWarehouseName} ➔ Vers: ${t.toWarehouseName}\nDate: ${DateFormat('dd/MM/yyyy HH:mm').format(t.date)}'),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(5)),
                    child: Text('${t.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
