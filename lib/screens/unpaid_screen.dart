import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../models/transaction.dart';
import '../models/payment.dart';
import '../models/tier.dart';

class UnpaidScreen extends StatefulWidget {
  const UnpaidScreen({super.key});

  @override
  State<UnpaidScreen> createState() => _UnpaidScreenState();
}

class _UnpaidScreenState extends State<UnpaidScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();
  final currencyFormat = NumberFormat('#,###', 'fr_FR');
  TierType _selectedType = TierType.client;

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      backgroundColor: Colors.grey[200], // Fond gris pour faire ressortir le cadre
      appBar: AppBar(
        title: const Text('GESTION DES IMPAYÉS'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000), // Largeur max pour le Web
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
              ],
            ),
            child: Column(
              children: [
                _buildFilterHeader(),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: firestoreService.getUnpaidReport(
                      tierType: _selectedType,
                      start: _startDate,
                      end: _endDate,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
                              SizedBox(height: 10),
                              Text('Aucun impayé trouvé pour cette période', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      final unpaidResults = snapshot.data!;

                      return Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: unpaidResults.length,
                              itemBuilder: (context, index) {
                                final item = unpaidResults[index];
                                final AppTransaction t = item['transaction'];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  elevation: 1,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.red[50],
                                      child: const Icon(Icons.money_off, color: Colors.red),
                                    ),
                                    title: Text(t.tierName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Facture ${t.invoiceNumber} du ${DateFormat('dd/MM/yy').format(t.date)}'),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('${currencyFormat.format(item['remaining'])} F', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text('Sur ${currencyFormat.format(t.netToPay)} F', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          _buildSummary(unpaidResults),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<TierType>(
                  segments: const [
                    ButtonSegment(value: TierType.client, label: Text('Clients')),
                    ButtonSegment(value: TierType.supplier, label: Text('Fournisseurs')),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (val) => setState(() => _selectedType = val.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (date != null) setState(() => _startDate = date);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(DateFormat('dd/MM/yy').format(_startDate)),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('au')),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (date != null) setState(() => _endDate = date);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(DateFormat('dd/MM/yy').format(_endDate)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<Map<String, dynamic>> results) {
    double total = results.fold(0, (sum, item) => sum + (item['remaining'] as double));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL DES IMPAYÉS', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${currencyFormat.format(total)} FCFA', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => PdfService.generateUnpaidReport(
                    type: _selectedType == TierType.client ? 'Client' : 'Fournisseur',
                    start: _startDate,
                    end: _endDate,
                    unpaidDetails: results,
                  ),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('EXPORTER PDF'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
