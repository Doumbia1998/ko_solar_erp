import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../models/transaction.dart';
import '../models/tier.dart';

class UnpaidReportScreen extends StatefulWidget {
  const UnpaidReportScreen({super.key});

  @override
  State<UnpaidReportScreen> createState() => _UnpaidReportScreenState();
}

class _UnpaidReportScreenState extends State<UnpaidReportScreen> {
  String _reportType = 'client';
  Tier? _selectedTier;
  DateTime _startDate = DateTime(2022, 1, 1); // Commencer très tôt pour inclure tout l'historique par défaut
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _generatePdf() async {
    setState(() => _isLoading = true);
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      
      final details = await firestoreService.getUnpaidReport(
        tierType: _reportType == 'client' ? TierType.client : TierType.supplier,
        start: _startDate,
        end: _endDate,
      );

      // Si un tiers spécifique est sélectionné, on filtre la liste
      List<Map<String, dynamic>> finalDetails = details;
      if (_selectedTier != null) {
        finalDetails = details.where((d) => (d['transaction'] as AppTransaction).tierId == _selectedTier!.id).toList();
      }

      if (finalDetails.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun impayé trouvé pour ces critères.')),
          );
        }
      } else {
        await PdfService.generateUnpaidReport(
          type: _reportType,
          start: _startDate,
          end: _endDate,
          unpaidDetails: details,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport des Impayés'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sélectionnez les paramètres du rapport',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Type d'impayés
            Card(
              elevation: 2,
              child: ListTile(
                title: const Text('Type d\'impayés', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_reportType == 'client' ? 'Clients (Ventes)' : 'Fournisseurs (Achats)'),
                trailing: DropdownButton<String>(
                  underline: const SizedBox(),
                  value: _reportType,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _reportType = newValue;
                        _selectedTier = null; // Reset le tiers si on change de type
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'client', child: Text('Clients')),
                    DropdownMenuItem(value: 'fournisseur', child: Text('Fournisseurs')),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Sélection du Tiers Spécifique
            StreamBuilder<List<Tier>>(
              stream: firestoreService.getTiers(_reportType == 'client' ? TierType.client : TierType.supplier),
              builder: (context, snapshot) {
                final tiers = snapshot.data ?? [];
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Tiers Spécifique', style: TextStyle(fontWeight: FontWeight.w500))),
                        DropdownButton<String?>( // Utilisation de String? (ID) pour éviter les crashs d'objets
                          underline: const SizedBox(),
                          value: _selectedTier?.id,
                          hint: const Text('TOUS'),
                          onChanged: (String? newId) {
                            setState(() {
                              if (newId == null) {
                                _selectedTier = null;
                              } else {
                                _selectedTier = tiers.firstWhere((t) => t.id == newId);
                              }
                            });
                          },
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('TOUS')),
                            ...tiers.map((t) => DropdownMenuItem<String?>(
                              value: t.id, 
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 150),
                                child: Text(t.name, overflow: TextOverflow.ellipsis),
                              ),
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
            ),
            
            const SizedBox(height: 10),

            // Date de début
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.date_range, color: Colors.red),
                title: const Text('Date de début'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                onTap: () => _selectDate(context, true),
              ),
            ),

            // Date de fin
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.date_range, color: Colors.red),
                title: const Text('Date de fin'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                onTap: () => _selectDate(context, false),
              ),
            ),

            const SizedBox(height: 40),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generatePdf,
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Icon(Icons.picture_as_pdf),
              label: const Text('GÉNÉRER LE PDF DES IMPAYÉS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
