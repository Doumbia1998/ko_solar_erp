import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/transaction.dart';
import '../models/app_user.dart';
import '../models/task.dart';

class TaskAssignmentScreen extends StatelessWidget {
  const TaskAssignmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);
    final currentUser = Provider.of<AppUser?>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignation des Chantiers'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<AppTransaction>>(
        stream: service.getTransactions(type: TransactionType.sale),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // On ne prend que les ventes livrées (BL validé par magasinier) ou toutes les ventes selon le flux
          final transactions = snapshot.data!.where((t) => t.deliveryStatus == 'delivered').toList();

          return StreamBuilder<List<Task>>(
            stream: service.getTasks(),
            builder: (context, taskSnapshot) {
              final tasks = taskSnapshot.data ?? [];
              final assignedInvoiceNumbers = tasks.map((e) => e.invoiceNumber).toList();

              // On filtre pour ne proposer que les factures non encore assignées
              final unassignedTransactions = transactions.where((t) => !assignedInvoiceNumbers.contains(t.invoiceNumber)).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: unassignedTransactions.length,
                itemBuilder: (context, index) {
                  final t = unassignedTransactions[index];
                  return Card(
                    child: ListTile(
                      title: Text('Facture : ${t.invoiceNumber}'),
                      subtitle: Text('Client : ${t.tierName}\nDestination : ${t.destination}'),
                      trailing: ElevatedButton(
                        onPressed: () => _showAssignDialog(context, service, t, currentUser?.displayName ?? 'Responsable'),
                        child: const Text('ASSIGNER'),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showAssignDialog(BuildContext context, FirestoreService service, AppTransaction tx, String managerName) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<List<AppUser>>(
        stream: service.getTechnicians(),
        builder: (context, snapshot) {
          final techs = snapshot.data ?? [];
          return AlertDialog(
            title: Text('Assigner ${tx.invoiceNumber}'),
            content: techs.isEmpty
              ? const Text('Aucun technicien trouvé. Veuillez en créer un avec le rôle TECHNICIEN.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: techs.length,
                    itemBuilder: (context, index) {
                      final tech = techs[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(tech.displayName),
                        onTap: () async {
                          final newTask = Task(
                            id: '',
                            transactionId: tx.id,
                            invoiceNumber: tx.invoiceNumber,
                            clientName: tx.tierName,
                            technicianId: tech.uid,
                            technicianName: tech.displayName,
                            assignedBy: managerName,
                            assignedAt: DateTime.now(),
                          );
                          await service.addTask(newTask);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assigné à ${tech.displayName}')));
                        },
                      );
                    },
                  ),
                ),
          );
        },
      ),
    );
  }
}
