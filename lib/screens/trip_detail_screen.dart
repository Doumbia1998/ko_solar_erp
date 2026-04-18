import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transport.dart';
import '../models/account.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import 'package:provider/provider.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;
  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return StreamBuilder<List<Trip>>(
      stream: service.getTrips(),
      builder: (context, snapshot) {
        Trip currentTrip = widget.trip;
        if (snapshot.hasData) {
          try {
            currentTrip = snapshot.data!.firstWhere((t) => t.id == widget.trip.id);
          } catch (e) {}
        }

        return Scaffold(
          appBar: AppBar(
            title: Text("Suivi : ${currentTrip.truck.plateNumber}"),
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => PdfService.generateTruckReport(currentTrip.truck, [currentTrip]),
              ),
              // Option pour ré-ouvrir le voyage
              if (currentTrip.isFinished)
                IconButton(
                  tooltip: "Ré-ouvrir le voyage",
                  icon: const Icon(Icons.settings_backup_restore),
                  onPressed: () async {
                    currentTrip.isFinished = false;
                    await service.updateTrip(currentTrip);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Voyage ré-ouvert pour modification")));
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                color: const Color(0xFFF5F6FA),
                child: Column(
                  children: [
                    _buildSummaryRow('Revenus', '${_currencyFormat.format(currentTrip.totalRevenue)} FCFA', Colors.black),
                    _buildSummaryRow('Encaissé', '${_currencyFormat.format(currentTrip.totalPaid)} FCFA', Colors.blue),
                    _buildSummaryRow('Impayés', '${_currencyFormat.format(currentTrip.totalUnpaid)} FCFA', Colors.orange, isBold: currentTrip.totalUnpaid > 0),
                    _buildSummaryRow('Dépenses', '- ${_currencyFormat.format(currentTrip.totalExpenses)} FCFA', Colors.red),
                    const Divider(),
                    _buildSummaryRow('BÉNÉFICE NET', '${_currencyFormat.format(currentTrip.netProfit)} FCFA', Colors.green, isBold: true),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    const Padding(padding: EdgeInsets.all(16), child: Text("PRESTATIONS ET RÈGLEMENTS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                    ...currentTrip.prestations.asMap().entries.map((entry) {
                      int idx = entry.key;
                      Prestation p = entry.value;
                      return ListTile(
                        leading: const Icon(Icons.local_shipping, color: Colors.blue),
                        title: Text(p.axis),
                        subtitle: Text("${p.clientName} - ${_currencyFormat.format(p.amountPaid)} payés"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("${_currencyFormat.format(p.price)} F", style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (p.balance > 0)
                                  Text("Reste: ${_currencyFormat.format(p.balance)}", style: const TextStyle(color: Colors.orange, fontSize: 10)),
                              ],
                            ),
                            const Icon(Icons.edit, size: 16, color: Colors.grey),
                          ],
                        ),
                        onLongPress: () => _confirmDelete(context, () {
                          currentTrip.prestations.removeAt(idx);
                          service.updateTrip(currentTrip);
                        }, "cette prestation"),
                        onTap: () => _editPrestation(context, currentTrip, idx, service),
                      );
                    }),
                    const Divider(),
                    const Padding(padding: EdgeInsets.all(16), child: Text("DÉPENSES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                    ...currentTrip.expenses.asMap().entries.map((entry) {
                      int idx = entry.key;
                      TripExpense e = entry.value;
                      return ListTile(
                        leading: const Icon(Icons.money_off, color: Colors.red),
                        title: Text(e.label),
                        subtitle: Text(DateFormat('dd/MM/yyyy').format(e.date)),
                        trailing: Text("- ${_currencyFormat.format(e.amount)} F", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        onLongPress: () => _confirmDelete(context, () {
                          currentTrip.expenses.removeAt(idx);
                          service.updateTrip(currentTrip);
                        }, "cette dépense"),
                        onTap: () => _editExpense(context, currentTrip, idx, service),
                      );
                    }),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: ElevatedButton.icon(
                          onPressed: () => _addPrestation(context, currentTrip, service),
                          icon: const Icon(Icons.add),
                          label: const Text("Prestation"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton.icon(
                          onPressed: () => _addExpense(context, currentTrip, service),
                          icon: const Icon(Icons.add),
                          label: const Text("Dépense"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!currentTrip.isFinished)
                      ElevatedButton(
                        onPressed: () async {
                          currentTrip.isFinished = true;
                          currentTrip.returnDate = DateTime.now();
                          await service.updateTrip(currentTrip);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                        child: const Text("CLÔTURER LE VOYAGE (RETOUR)"),
                      ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, VoidCallback onDelete, String label) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Suppression"),
        content: Text("Voulez-vous vraiment supprimer $label ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          TextButton(onPressed: () { onDelete(); Navigator.pop(context); }, child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _editPrestation(BuildContext context, Trip trip, int index, FirestoreService service) {
    final p = trip.prestations[index];
    final axisController = TextEditingController(text: p.axis);
    final clientController = TextEditingController(text: p.clientName);
    final priceController = TextEditingController(text: p.price.toString());
    final paidController = TextEditingController(text: p.amountPaid.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Modifier Prestation / Paiement"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: axisController, decoration: const InputDecoration(labelText: "Axe")),
              TextField(controller: clientController, decoration: const InputDecoration(labelText: "Client")),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: "Prix Total", suffixText: "F"), keyboardType: TextInputType.number),
              const Divider(),
              TextField(controller: paidController, decoration: const InputDecoration(labelText: "Total Encaissé", suffixText: "F"), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              trip.prestations[index] = Prestation(
                axis: axisController.text,
                clientId: p.clientId,
                clientName: clientController.text,
                price: double.tryParse(priceController.text) ?? 0,
                amountPaid: double.tryParse(paidController.text) ?? 0,
                date: p.date,
              );
              await service.updateTrip(trip);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  void _editExpense(BuildContext context, Trip trip, int index, FirestoreService service) {
    final e = trip.expenses[index];
    final labelController = TextEditingController(text: e.label);
    final amountController = TextEditingController(text: e.amount.toString());
    String? selectedAccount = e.compteComptable;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Modifier Dépense"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: labelController, decoration: const InputDecoration(labelText: "Libellé")),
                TextField(controller: amountController, decoration: const InputDecoration(labelText: "Montant", suffixText: "F"), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                StreamBuilder<List<Account>>(
                  stream: service.getAccounts(),
                  builder: (context, snapshot) {
                    final accounts = snapshot.data ?? [];
                    
                    // Sécurité : Vérifier si le compte sélectionné existe dans la liste chargée
                    String? effectiveValue = selectedAccount;
                    if (effectiveValue != null && !accounts.any((a) => a.code == effectiveValue)) {
                      effectiveValue = null; 
                    }

                    return DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: effectiveValue,
                      decoration: const InputDecoration(labelText: "Compte Comptable"),
                      items: accounts.map((a) => DropdownMenuItem(
                        value: a.code, 
                        child: Text("${a.code} - ${a.label}", overflow: TextOverflow.ellipsis)
                      )).toList(),
                      onChanged: (val) => setState(() => selectedAccount = val),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () async {
                trip.expenses[index] = TripExpense(
                  label: labelController.text,
                  amount: double.tryParse(amountController.text) ?? 0,
                  compteComptable: selectedAccount ?? '600000',
                  date: e.date,
                );
                await service.updateTrip(trip);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Enregistrer"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: isBold ? 18 : 14)),
        ],
      ),
    );
  }

  void _addPrestation(BuildContext context, Trip trip, FirestoreService service) {
    final axisController = TextEditingController();
    final clientController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nouvelle Prestation"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: axisController, decoration: const InputDecoration(labelText: "Axe (Ex: BKO-DKR)")),
            TextField(controller: clientController, decoration: const InputDecoration(labelText: "Client")),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: "Prix", suffixText: "F"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              final p = Prestation(
                axis: axisController.text,
                clientId: '',
                clientName: clientController.text,
                price: double.tryParse(priceController.text) ?? 0,
                amountPaid: 0,
                date: DateTime.now(),
              );
              trip.prestations.add(p);
              await service.updateTrip(trip);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  void _addExpense(BuildContext context, Trip trip, FirestoreService service) {
    final labelController = TextEditingController();
    final amountController = TextEditingController();
    String? selectedAccount;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Nouvelle Dépense"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: labelController, decoration: const InputDecoration(labelText: "Libellé")),
                TextField(controller: amountController, decoration: const InputDecoration(labelText: "Montant", suffixText: "F"), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                StreamBuilder<List<Account>>(
                  stream: service.getAccounts(),
                  builder: (context, snapshot) {
                    final accounts = snapshot.data ?? [];
                    
                    String? effectiveValue = selectedAccount;
                    if (effectiveValue != null && !accounts.any((a) => a.code == effectiveValue)) {
                      effectiveValue = null;
                    }

                    return DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: effectiveValue,
                      decoration: const InputDecoration(labelText: "Compte Comptable"),
                      items: accounts.map((a) => DropdownMenuItem(
                        value: a.code, 
                        child: Text("${a.code} - ${a.label}", overflow: TextOverflow.ellipsis)
                      )).toList(),
                      onChanged: (val) => setState(() => selectedAccount = val),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () async {
                final e = TripExpense(
                  label: labelController.text,
                  amount: double.tryParse(amountController.text) ?? 0,
                  compteComptable: selectedAccount ?? '600000',
                  date: DateTime.now(),
                );
                trip.expenses.add(e);
                await service.updateTrip(trip);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Ajouter"),
            ),
          ],
        ),
      ),
    );
  }
}
