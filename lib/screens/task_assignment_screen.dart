import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/transaction.dart';
import '../models/app_user.dart';
import '../models/task.dart';
import '../services/pdf_service.dart';

class TaskAssignmentScreen extends StatefulWidget {
  const TaskAssignmentScreen({super.key});

  @override
  State<TaskAssignmentScreen> createState() => _TaskAssignmentScreenState();
}

class _TaskAssignmentScreenState extends State<TaskAssignmentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);
    final currentUser = Provider.of<AppUser?>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Chantiers'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'À ASSIGNER'),
            Tab(text: 'SUIVI & APPROBATION'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildToAssignList(service, currentUser),
          _buildFollowUpList(service, currentUser),
        ],
      ),
    );
  }

  Widget _buildToAssignList(FirestoreService service, AppUser? currentUser) {
    return StreamBuilder<List<AppTransaction>>(
      stream: service.getTransactions(type: TransactionType.sale),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final transactions = snapshot.data!.toList();

        return StreamBuilder<List<Task>>(
          stream: service.getTasks(),
          builder: (context, taskSnapshot) {
            final tasks = taskSnapshot.data ?? [];
            final assignedInvoiceNumbers = tasks.map((e) => e.invoiceNumber).toList();
            final unassignedTransactions = transactions.where((t) => !assignedInvoiceNumbers.contains(t.invoiceNumber)).toList();

            if (unassignedTransactions.isEmpty) return const Center(child: Text('Toutes les ventes sont assignées.'));

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: unassignedTransactions.length,
              itemBuilder: (context, index) {
                final t = unassignedTransactions[index];
                return Card(
                  child: ListTile(
                    title: Text('Facture : ${t.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildFollowUpList(FirestoreService service, AppUser? currentUser) {
    return StreamBuilder<List<Task>>(
      stream: service.getTasks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final tasks = snapshot.data!;

        if (tasks.isEmpty) return const Center(child: Text('Aucun chantier en cours.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final statusColor = _getStatusColor(task.status);
            final bool canApprove = task.status == TaskStatus.completed || task.status == TaskStatus.rejected;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: CircleAvatar(backgroundColor: statusColor.withOpacity(0.2), child: Icon(Icons.engineering, color: statusColor, size: 20)),
                title: Text('${task.clientName.toUpperCase()} (${task.invoiceNumber})'),
                subtitle: Text('Technicien : ${task.technicianName} | Statut : ${task.status.toString().split('.').last.toUpperCase()}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Lieu : ${task.siteLocation ?? 'Non renseigné'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('GPS : ${task.gpsLocation ?? 'Non renseigné'}', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text('Assigné par : ${task.assignedBy} le ${DateFormat('dd/MM/yy').format(task.assignedAt)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        const Divider(),
                        const Text('RAPPORT DU TECHNICIEN :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.all(10),
                          width: double.infinity,
                          color: Colors.grey.shade50,
                          child: Text(task.reportDescription ?? 'Aucun rapport rédigé.', style: const TextStyle(fontSize: 13)),
                        ),
                        if (task.managerComment != null) ...[
                          const SizedBox(height: 10),
                          const Text('COMMENTAIRE RESPONSABLE :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                          Text(task.managerComment!, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => PdfService.generateTechnicianReport(task),
                              icon: const Icon(Icons.print),
                              label: const Text('IMPRIMER'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white),
                            ),
                            if (canApprove)
                              ElevatedButton.icon(
                                onPressed: () => _showApproveDialog(context, service, task, currentUser?.displayName ?? 'Responsable'),
                                icon: const Icon(Icons.check_circle),
                                label: const Text('DÉCISION RESPONSABLE'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade900, foregroundColor: Colors.white),
                              ),
                            if (task.status == TaskStatus.approved)
                              const Text('✅ CHANTIER ARCHIVÉ', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.pending: return Colors.grey;
      case TaskStatus.in_progress: return Colors.blue;
      case TaskStatus.completed: return Colors.orange;
      case TaskStatus.approved: return Colors.green;
      case TaskStatus.rejected: return Colors.red;
    }
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
              ? const Text('Aucun technicien trouvé.')
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

  void _showApproveDialog(BuildContext context, FirestoreService service, Task task, String managerName) {
    final commentCtrl = TextEditingController(text: task.managerComment);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Validation du Responsable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Veuillez donner votre avis sur les travaux effectués par le technicien.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(labelText: 'Commentaire / Observation', border: OutlineInputBorder()),
              maxLines: 4
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await service.approveTask(task.id, managerName, commentCtrl.text, false);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapport rejeté pour correction.'), backgroundColor: Colors.red));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DEMANDER CORRECTION'),
          ),
          ElevatedButton(
            onPressed: () async {
              await service.approveTask(task.id, managerName, commentCtrl.text, true);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chantier approuvé et archivé !'), backgroundColor: Colors.green));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('APPROUVER & CLÔTURER'),
          ),
        ],
      ),
    );
  }
}
