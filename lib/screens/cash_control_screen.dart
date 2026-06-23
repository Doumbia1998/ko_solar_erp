import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/journal_entry.dart';
import '../services/pdf_service.dart';

class CashControlScreen extends StatefulWidget {
  const CashControlScreen({super.key});

  @override
  State<CashControlScreen> createState() => _CashControlScreenState();
}

class _CashControlScreenState extends State<CashControlScreen> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contrôle de Caisse'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              const Text('Rapport de Contrôle de Caisse', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Recapitulatif des encaissements et dépenses avec solde progressif.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Date début', style: TextStyle(fontSize: 12)),
                      subtitle: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                      onTap: () => _selectDate(true),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Date fin', style: TextStyle(fontSize: 12)),
                      subtitle: Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                      onTap: () => _selectDate(false),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 50),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _generateReport(service),
                  icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.picture_as_pdf),
                  label: const Text('GÉNÉRER LE CONTRÔLE DE CAISSE'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, foregroundColor: Colors.white),
                ),
              )
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

  void _generateReport(FirestoreService service) async {
    setState(() => _isLoading = true);
    try {
      final allEntries = await service.getJournalEntries(limit: 5000).first;

      // 1. Calcul du solde initial (tout ce qui est avant la date de debut)
      double initialBalance = allEntries.where((e) =>
        e.date.isBefore(_startDate) &&
        (e.accountCode.startsWith('571') || e.accountCode.startsWith('521'))
      ).fold(0.0, (sum, e) => sum + (e.debit - e.credit));

      // 2. Filtrage des ecritures de la periode pour les comptes de tresorerie
      final filtered = allEntries.where((e) =>
        e.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
        e.date.isBefore(_endDate.add(const Duration(days: 1))) &&
        (e.accountCode.startsWith('571') || e.accountCode.startsWith('521'))
      ).toList();

      filtered.sort((a, b) => a.date.compareTo(b.date));

      if (filtered.isEmpty && initialBalance == 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun mouvement trouvé.')));
      } else {
        await PdfService.generateCashControlReport(
          start: _startDate,
          end: _endDate,
          initialBalance: initialBalance,
          entries: filtered
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
