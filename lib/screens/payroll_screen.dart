import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/salary_payment.dart';
import '../models/app_user.dart';
import '../services/pdf_service.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final _format = NumberFormat('#,###', 'fr_FR');
  AppUser? _selectedEmployee;
  final _amountController = TextEditingController();
  String _selectedMonth = DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now());
  String _selectedMethod = 'Espèces';

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTION DE LA PAIE'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildAddForm(service),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('HISTORIQUE DES SALAIRES PAYÉS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          Expanded(child: _buildSalaryList(service)),
        ],
      ),
    );
  }

  Widget _buildAddForm(FirestoreService service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ENREGISTRER UN PAIEMENT DE SALAIRE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: StreamBuilder<List<AppUser>>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots().map((snap) =>
                      snap.docs.map((doc) => AppUser.fromMap(doc.data())).toList()),
                  builder: (context, snapshot) {
                    final users = snapshot.data ?? [];
                    return DropdownButtonFormField<AppUser>(
                      value: _selectedEmployee,
                      decoration: const InputDecoration(labelText: 'Employé', border: OutlineInputBorder()),
                      items: users.map((u) => DropdownMenuItem(value: u, child: Text(u.displayName.toUpperCase()))).toList(),
                      onChanged: (val) => setState(() => _selectedEmployee = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Net à Payer (FCFA)', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMonth,
                  decoration: const InputDecoration(labelText: 'Mois de Paie', border: OutlineInputBorder()),
                  items: _getRecentMonths().map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _selectedMonth = val!),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMethod,
                  decoration: const InputDecoration(labelText: 'Mode de paiement', border: OutlineInputBorder()),
                  items: ['Espèces', 'Virement BIM SA', 'Chèque'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _selectedMethod = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveSalary,
              icon: const Icon(Icons.check_circle),
              label: const Text('VALIDER LE PAIEMENT ET GÉNÉRER ÉCRITURE'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getRecentMonths() {
    List<String> months = [];
    for (int i = 0; i < 6; i++) {
      months.add(DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now().subtract(Duration(days: i * 30))));
    }
    return months;
  }

  Widget _buildSalaryList(FirestoreService service) {
    return StreamBuilder<List<SalaryPayment>>(
      stream: service.getSalaryPayments(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final salaries = snapshot.data!;
        if (salaries.isEmpty) return const Center(child: Text('Aucun salaire enregistré.'));

        return ListView.builder(
          itemCount: salaries.length,
          itemBuilder: (context, index) {
            final s = salaries[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.person, color: Colors.white)),
                title: Text('${s.employeeName.toUpperCase()} - ${_format.format(s.amount)} F'),
                subtitle: Text('Période: ${s.month} | Journal: ${s.journalCode}\nFait par: ${s.createdBy} le ${DateFormat('dd/MM/yy').format(s.date)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.indigo),
                      onPressed: () => PdfService.generatePayslip(s),
                    ),
                    const Icon(Icons.verified, color: Colors.green),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _saveSalary() async {
    if (_selectedEmployee == null || _amountController.text.isEmpty) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final service = Provider.of<FirestoreService>(context, listen: false);
    final user = await auth.getAppUser((await auth.user.first)!.uid);

    final salary = SalaryPayment(
      id: '',
      employeeId: _selectedEmployee!.uid,
      employeeName: _selectedEmployee!.displayName,
      amount: double.tryParse(_amountController.text) ?? 0,
      date: DateTime.now(),
      month: _selectedMonth,
      method: _selectedMethod,
      journalCode: 'PAIE',
      createdBy: user?.displayName ?? 'Admin',
    );

    await service.addSalaryPayment(salary);
    _amountController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salaire enregistré en comptabilité !'), backgroundColor: Colors.green));
  }
}
