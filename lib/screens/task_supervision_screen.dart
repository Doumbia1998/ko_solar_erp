import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/task.dart';
import '../services/pdf_service.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskSupervisionScreen extends StatefulWidget {
  const TaskSupervisionScreen({super.key});

  @override
  State<TaskSupervisionScreen> createState() => _TaskSupervisionScreenState();
}

class _TaskSupervisionScreenState extends State<TaskSupervisionScreen> {
  String _searchQuery = '';
  DateTime? _filterDate;
  final TextEditingController _searchController = TextEditingController();

  Future<void> _openMap(String location) async {
    final String url = 'https://www.google.com/maps/search/?api=1&query=$location';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {
        _filterDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervision des Chantiers'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barre de Recherche et Filtre Date
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher client ou technicien...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _filterDate != null ? Colors.orange : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300)
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: _filterDate != null ? Colors.white : Colors.grey),
                        if (_filterDate != null) ...[
                          const SizedBox(width: 8),
                          Text(DateFormat('dd/MM/yy').format(_filterDate!), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => _filterDate = null),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          )
                        ]
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: service.getTasks(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var tasks = snapshot.data!.toList();

                // Filtrage
                if (_searchQuery.isNotEmpty) {
                  tasks = tasks.where((t) =>
                    t.clientName.toLowerCase().contains(_searchQuery) ||
                    t.technicianName.toLowerCase().contains(_searchQuery) ||
                    t.invoiceNumber.toLowerCase().contains(_searchQuery)
                  ).toList();
                }

                if (_filterDate != null) {
                  tasks = tasks.where((t) =>
                    t.assignedAt.year == _filterDate!.year &&
                    t.assignedAt.month == _filterDate!.month &&
                    t.assignedAt.day == _filterDate!.day
                  ).toList();
                }

                tasks.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));

                if (tasks.isEmpty) return const Center(child: Text('Aucun chantier trouvé.'));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final statusColor = _getStatusColor(task.status);

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(Icons.location_on, color: statusColor),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(task.clientName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(DateFormat('dd/MM/yyyy').format(task.assignedAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        subtitle: Text('Tech: ${task.technicianName} | Réf: ${task.invoiceNumber}', style: const TextStyle(fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                          onPressed: () => PdfService.generateTechnicianReport(task),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: Column(
                                    children: [
                                      _infoRow('DÉBUT (Assignation)', DateFormat('dd/MM/yyyy HH:mm').format(task.assignedAt), isHighlight: true),
                                      if (task.completedAt != null)
                                        _infoRow('FIN (Intervention)', DateFormat('dd/MM/yyyy HH:mm').format(task.completedAt!), isHighlight: true, color: Colors.green.shade700),
                                      _infoRow('Lieu Site', task.siteLocation ?? 'Non précisé'),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 15),
                                const Text('LOCALISATION GPS & ITINÉRAIRE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A237E))),
                                const SizedBox(height: 8),
                                if (task.signatureGps != null) ...[
                                  Text('Position captée lors de la signature client :', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () => _openMap(task.signatureGps!),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.blue.shade200)),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.map, size: 16, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(task.signatureGps!, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12))),
                                          const Icon(Icons.open_in_new, size: 14, color: Colors.blue),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else
                                  const Text('Aucune donnée GPS captée.', style: TextStyle(color: Colors.red, fontSize: 10, fontStyle: FontStyle.italic)),

                                const SizedBox(height: 15),
                                const Text('RAPPORT D\'INSTALLATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A237E))),
                                const SizedBox(height: 5),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(5)),
                                  child: Text(task.reportDescription ?? 'Aucun rapport rédigé pour le moment.', style: const TextStyle(fontSize: 12, height: 1.4)),
                                ),

                                if (task.managerComment != null) ...[
                                  const SizedBox(height: 15),
                                  const Text('DÉCISION / OBSERVATION RESPONSABLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                                  Text(task.managerComment!, style: const TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic)),
                                ]
                              ],
                            ),
                          )
                        ],
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

  Widget _infoRow(String label, String val, {bool isHighlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label :', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
        ],
      ),
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
}
