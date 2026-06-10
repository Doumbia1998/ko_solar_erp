import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/task.dart';
import '../models/app_user.dart';

class TechnicianTaskScreen extends StatelessWidget {
  const TechnicianTaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);
    final currentUser = Provider.of<AppUser?>(context);

    if (currentUser == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Chantiers'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Task>>(
        stream: service.getTasks(technicianId: currentUser.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final tasks = snapshot.data!.where((t) => t.status != TaskStatus.archived).toList();

          if (tasks.isEmpty) return const Center(child: Text('Aucun chantier assigné.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isCompleted = task.status == TaskStatus.completed;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text('Client : ${task.clientName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Facture : ${task.invoiceNumber}\nStatut : ${task.status.toString().split('.').last.toUpperCase()}'),
                  trailing: Icon(
                    isCompleted ? Icons.verified : Icons.pending_actions,
                    color: isCompleted ? Colors.green : Colors.orange,
                  ),
                  onTap: () => _showReportDialog(context, service, task),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showReportDialog(BuildContext context, FirestoreService service, Task task) {
    final descriptionController = TextEditingController(text: task.reportDescription);
    final locationController = TextEditingController(text: task.siteLocation);
    final gpsController = TextEditingController(text: task.gpsLocation);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rapport : ${task.clientName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Lieu du chantier')),
              const SizedBox(height: 10),
              TextField(controller: gpsController, decoration: const InputDecoration(labelText: 'Coordonnées GPS (Optionnel)', hintText: 'Lat, Lng')),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Travaux effectués / Notes', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          if (task.status != TaskStatus.completed)
            ElevatedButton(
              onPressed: () async {
                await service.updateTaskStatus(task.id, TaskStatus.completed, reportData: {
                  'reportDescription': descriptionController.text,
                  'siteLocation': locationController.text,
                  'gpsLocation': gpsController.text,
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapport enregistré et Chantier clôturé !')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('CLÔTURER LE CHANTIER'),
            ),
        ],
      ),
    );
  }
}
