import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/task.dart';
import '../models/app_user.dart';
import '../models/transaction.dart';
import '../services/pdf_service.dart';

class TechnicianTaskScreen extends StatelessWidget {
  const TechnicianTaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);
    final currentUser = Provider.of<AppUser?>(context);

    if (currentUser == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Chantiers Assignés'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Task>>(
        stream: service.getTasks(technicianId: currentUser.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final tasks = snapshot.data!.toList();

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_late, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('Aucun chantier ne vous a été assigné pour le moment.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isApproved = task.status == TaskStatus.approved;
              final isRejected = task.status == TaskStatus.rejected;
              final isCompleted = task.status == TaskStatus.completed;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isApproved ? Colors.green.shade100 : (isRejected ? Colors.red.shade100 : (isCompleted ? Colors.blue.shade100 : Colors.orange.shade50)),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.engineering, color: isApproved ? Colors.green : (isRejected ? Colors.red : (isCompleted ? Colors.blue : Colors.orange))),
                          const SizedBox(width: 10),
                          Text('CHANTIER N° ${task.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isApproved ? Colors.green : (isRejected ? Colors.red : (isCompleted ? Colors.blue : Colors.orange)),
                              borderRadius: BorderRadius.circular(4)
                            ),
                            child: Text(task.status.toString().split('.').last.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      title: Text(task.clientName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Assigné le : ${DateFormat('dd/MM/yyyy').format(task.assignedAt)}'),
                          if (task.siteLocation != null) Text('Lieu : ${task.siteLocation}'),
                          if (isApproved) Text('Approuvé le : ${task.updatedAt != null ? DateFormat('dd/MM/yyyy').format(task.updatedAt!) : "-"} par ${task.approvedBy ?? "Admin"}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                          if (isRejected && task.managerComment != null) ...[
                            const SizedBox(height: 8),
                            Text('MOTIF DU REJET : ${task.managerComment}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isApproved)
                            IconButton(
                              icon: const Icon(Icons.print, color: Colors.blueGrey),
                              tooltip: 'Imprimer Rapport Clôturé',
                              onPressed: () => PdfService.generateTechnicianReport(task),
                            ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                            tooltip: 'Voir BL',
                            onPressed: () async {
                              final txs = await service.getTransactions(type: TransactionType.sale).first;
                              try {
                                final tx = txs.firstWhere((t) => t.invoiceNumber == task.invoiceNumber);
                                PdfService.generateDeliveryNote(tx);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de charger le BL')));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showReportDialog(context, service, task, currentUser.displayName),
                          icon: Icon(isApproved ? Icons.visibility : Icons.edit_note),
                          label: Text(isApproved ? 'VOIR LE RAPPORT' : (isRejected ? 'CORRIGER LE RAPPORT' : (isCompleted ? 'MODIFIER LE RAPPORT' : 'REMPLIR LE RAPPORT'))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isApproved ? Colors.grey : (isRejected ? Colors.red : (isCompleted ? Colors.blue : Colors.orange.shade800)),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showReportDialog(BuildContext context, FirestoreService service, Task task, String userName) {
    final descriptionController = TextEditingController(text: task.reportDescription);
    final locationController = TextEditingController(text: task.siteLocation);
    final gpsController = TextEditingController(text: task.gpsLocation);
    final bool canEdit = task.status != TaskStatus.approved;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rapport de Chantier : ${task.invoiceNumber}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: locationController,
                enabled: canEdit,
                decoration: const InputDecoration(labelText: 'Lieu précis de l\'installation', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: gpsController,
                enabled: canEdit,
                decoration: const InputDecoration(labelText: 'Coordonnées GPS (Lat, Lng)', hintText: 'Ex: 12.63, -8.00', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                enabled: canEdit,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Détail des travaux effectués',
                  hintText: 'Notez ici l\'avancement quotidien du chantier...',
                  border: OutlineInputBorder()
                ),
              ),
              if (task.managerComment != null) ...[
                const SizedBox(height: 10),
                const Divider(),
                Text('Commentaire du Responsable : ${task.managerComment}', style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
              ]
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('FERMER')),
          if (canEdit)
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await service.updateTaskStatus(task.id, TaskStatus.in_progress, userName, reportData: {
                      'reportDescription': descriptionController.text,
                      'siteLocation': locationController.text,
                      'gpsLocation': gpsController.text,
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapport sauvegardé !')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('SAUVEGARDER'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    await service.updateTaskStatus(task.id, TaskStatus.completed, userName, reportData: {
                      'reportDescription': descriptionController.text,
                      'siteLocation': locationController.text,
                      'gpsLocation': gpsController.text,
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chantier finalisé ! En attente d\'approbation.'), backgroundColor: Colors.orange));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('FINALISER'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
