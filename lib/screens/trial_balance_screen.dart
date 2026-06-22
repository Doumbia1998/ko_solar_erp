import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/journal_entry.dart';
import '../services/pdf_service.dart';

class TrialBalanceScreen extends StatefulWidget {
  const TrialBalanceScreen({super.key});

  @override
  State<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends State<TrialBalanceScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BALANCE DES COMPTES'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance, size: 80, color: Color(0xFF1A237E)),
              const SizedBox(height: 20),
              const Text(
                'Génération de la Balance Générale',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Sélectionnez la période pour calculer les mouvements et soldes de tous les comptes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Date début', style: TextStyle(fontSize: 12)),
                      subtitle: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                      onTap: () => _selectDate(true),
                      trailing: const Icon(Icons.calendar_today),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Date fin', style: TextStyle(fontSize: 12)),
                      subtitle: Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                      onTap: () => _selectDate(false),
                      trailing: const Icon(Icons.calendar_today),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _generateBalance(service),
                  icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf),
                  label: const Text('TIRER LA BALANCE (PDF)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365))
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked;
        else _endDate = picked;
      });
    }
  }

  void _generateBalance(FirestoreService service) async {
    setState(() => _isLoading = true);
    try {
      final entries = await service.getJournalEntries().first;
      final filtered = entries.where((e) =>
        e.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
        e.date.isBefore(_endDate.add(const Duration(days: 1)))
      ).toList();

      if (filtered.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune écriture trouvée sur cette période.')));
      } else {
        await PdfService.generateTrialBalance(filtered);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
