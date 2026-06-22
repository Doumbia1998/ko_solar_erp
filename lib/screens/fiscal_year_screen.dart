import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/fiscal_year.dart';

class FiscalYearScreen extends StatefulWidget {
  const FiscalYearScreen({super.key});

  @override
  State<FiscalYearScreen> createState() => _FiscalYearScreenState();
}

class _FiscalYearScreenState extends State<FiscalYearScreen> {
  final _labelController = TextEditingController();
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime(DateTime.now().year, 12, 31);

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EXERCICES COMPTABLES'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildOpeningForm(service),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('LISTE DES EXERCICES', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          Expanded(child: _buildExerciseList(service)),
        ],
      ),
    );
  }

  Widget _buildOpeningForm(FirestoreService service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OUVRIR UN NOUVEL EXERCICE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
          const SizedBox(height: 15),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(labelText: 'Libellé de l\'exercice (ex: EXERCICE 2027)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: const Text('Date début', style: TextStyle(fontSize: 12)),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                  onTap: () => _pickDate(true),
                  trailing: const Icon(Icons.calendar_today),
                ),
              ),
              Expanded(
                child: ListTile(
                  title: const Text('Date fin', style: TextStyle(fontSize: 12)),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                  onTap: () => _pickDate(false),
                  trailing: const Icon(Icons.calendar_today),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openExercise,
              icon: const Icon(Icons.add_business),
              label: const Text('CRÉER LE NOUVEL EXERCICE'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList(FirestoreService service) {
    return StreamBuilder<List<FiscalYear>>(
      stream: service.getFiscalYears(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final exercises = snapshot.data!;

        return ListView.builder(
          itemCount: exercises.length,
          itemBuilder: (context, index) {
            final ex = exercises[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: ex.isClosed ? Colors.grey.shade100 : Colors.blue.shade50,
              child: ListTile(
                leading: Icon(ex.isClosed ? Icons.lock : Icons.lock_open, color: ex.isClosed ? Colors.red : Colors.green),
                title: Text(ex.label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Période : ${DateFormat('dd/MM/yy').format(ex.startDate)} au ${DateFormat('dd/MM/yy').format(ex.endDate)}'),
                trailing: ex.isClosed
                  ? const Chip(label: Text('CLÔTURÉ', style: TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: Colors.red)
                  : ElevatedButton(
                      onPressed: () => _confirmClose(ex),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      child: const Text('CLÔTURER'),
                    ),
              ),
            );
          },
        );
      },
    );
  }

  void _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040)
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked;
        else _endDate = picked;
      });
    }
  }

  void _openExercise() async {
    if (_labelController.text.isEmpty) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final service = Provider.of<FirestoreService>(context, listen: false);
    final user = await auth.getAppUser((await auth.user.first)!.uid);

    final fy = FiscalYear(
      id: '',
      label: _labelController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      createdBy: user?.displayName ?? 'Admin',
    );

    await service.addFiscalYear(fy);
    _labelController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nouvel exercice ouvert !'), backgroundColor: Colors.green));
  }

  void _confirmClose(FiscalYear fy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clôturer l\'exercice ?'),
        content: const Text('Cette action est irréversible. Toutes les écritures de cet exercice seront verrouillées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          TextButton(
            onPressed: () async {
              final auth = Provider.of<AuthService>(context, listen: false);
              final user = await auth.getAppUser((await auth.user.first)!.uid);
              await Provider.of<FirestoreService>(context, listen: false).closeFiscalYear(fy.id, user?.displayName ?? 'Admin');
              Navigator.pop(context);
            },
            child: const Text('CONFIRMER LA CLÔTURE', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}
