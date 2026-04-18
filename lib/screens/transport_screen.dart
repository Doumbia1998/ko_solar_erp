import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/transport.dart';
import '../models/tier.dart';
import 'tier_list_screen.dart';
import 'trip_detail_screen.dart';
import '../services/pdf_service.dart';

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TRANSPORT'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.route), text: 'Voyages'),
            Tab(icon: Icon(Icons.local_shipping), text: 'Nos Camions'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTripsList(firestoreService),
          _buildTrucksList(firestoreService),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(firestoreService),
        backgroundColor: const Color(0xFF1A237E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(_tabController.index == 0 ? 'DÉMARRER VOYAGE' : 'AJOUTER CAMION', style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildTripsList(FirestoreService service) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A237E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              const Text('BÉNÉFICE TOTAL TRANSPORT', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 5),
              StreamBuilder<List<Trip>>(
                stream: service.getTrips(),
                builder: (context, snapshot) {
                  double totalBenefice = snapshot.data?.fold(0.0, (sum, trip) => sum! + trip.netProfit) ?? 0.0;
                  return Text(
                    '${_currencyFormat.format(totalBenefice)} FCFA',
                    style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 24),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Trip>>(
            stream: service.getTrips(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final trips = snapshot.data ?? [];
              if (trips.isEmpty) return const Center(child: Text('Aucun voyage enregistré'));

              return ListView.builder(
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: trip.isFinished ? Colors.green : Colors.orange,
                      child: Icon(trip.isFinished ? Icons.check : Icons.local_shipping, color: Colors.white),
                    ),
                    title: Text(trip.truck.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${trip.clientName} - ${trip.mainAxis}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_currencyFormat.format(trip.netProfit)} F', 
                          style: TextStyle(color: trip.isFinished ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                        if (!trip.isFinished)
                          IconButton(
                            icon: const Icon(Icons.done_all, color: Colors.green),
                            tooltip: 'Clôturer le voyage',
                            onPressed: () => _finishTrip(service, trip),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TripDetailScreen(trip: trip)),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrucksList(FirestoreService service) {
    return StreamBuilder<List<Truck>>(
      stream: service.getTrucks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final trucks = snapshot.data ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Chercher n° camion...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            Expanded(
              child: trucks.isEmpty 
                ? const Center(child: Text('Aucun camion enregistré'))
                : ListView.builder(
                    itemCount: trucks.length,
                    itemBuilder: (context, index) {
                      final truck = trucks[index];
                      return ListTile(
                        leading: const Icon(Icons.local_shipping, color: Color(0xFF1A237E)),
                        title: Text(truck.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Chauffeur: ${truck.driverName}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditTruckDialog(truck, service),
                        ),
                        onTap: () => _showTruckReport(truck, service),
                      );
                    },
                  ),
            ),
          ],
        );
      }
    );
  }

  void _showTruckReport(Truck truck, FirestoreService service) {
    DateTimeRange? selectedRange;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setReportState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Scaffold(
            appBar: AppBar(
              title: Text(truck.plateNumber),
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              actions: [
                IconButton(icon: const Icon(Icons.calendar_month), onPressed: () async {
                  final range = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (range != null) setReportState(() => selectedRange = range);
                }),
                IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () async {
                  final tripsSnapshot = await service.getTrips(truckId: truck.id).first;
                  await PdfService.generateTruckReport(truck, tripsSnapshot);
                }),
              ],
            ),
            body: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Column(
                    children: [
                      const Text('BÉNÉFICE TOTAL (TOUTE PÉRIODE)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      StreamBuilder<List<Trip>>(
                        stream: service.getTrips(truckId: truck.id),
                        builder: (context, snapshot) {
                          double total = snapshot.data?.fold(0.0, (sum, trip) => sum! + trip.netProfit) ?? 0.0;
                          return Text('${_currencyFormat.format(total)} FCFA', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 20));
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Trip>>(
                    stream: service.getTrips(truckId: truck.id),
                    builder: (context, snapshot) {
                      var trips = snapshot.data ?? [];
                      if (selectedRange != null) {
                        trips = trips.where((t) => t.departureDate.isAfter(selectedRange!.start.subtract(const Duration(days: 1))) && t.departureDate.isBefore(selectedRange!.end.add(const Duration(days: 1)))).toList();
                      }
                      if (trips.isEmpty) return const Center(child: Text('Aucun voyage trouvé'));
                      return ListView.builder(
                        itemCount: trips.length,
                        itemBuilder: (context, index) => ListTile(
                          title: Text(trips[index].mainAxis),
                          subtitle: Text(DateFormat('dd/MM/yyyy').format(trips[index].departureDate)),
                          trailing: Text('${_currencyFormat.format(trips[index].netProfit)} F', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
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

  void _finishTrip(FirestoreService service, Trip trip) {
    final updated = Trip(
      id: trip.id,
      truck: trip.truck,
      prestations: trip.prestations,
      expenses: trip.expenses,
      departureDate: trip.departureDate,
      returnDate: DateTime.now(),
      isFinished: true,
    );
    service.updateTrip(updated);
  }

  void _showAddDialog(FirestoreService service) {
    if (_tabController.index == 1) {
      _showAddTruckDialog(service);
    } else {
      _showAddTripDialog(service);
    }
  }

  void _showAddTripDialog(FirestoreService service) {
    final axeController = TextEditingController();
    final priceController = TextEditingController();
    final expensesController = TextEditingController();
    Truck? selectedTruck;
    Tier? selectedClient;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => StreamBuilder<List<Truck>>(
          stream: service.getTrucks(),
          builder: (context, snapshot) {
            final trucks = snapshot.data ?? [];
            return AlertDialog(
              title: const Text('Démarrer un Voyage'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Truck>(
                      decoration: const InputDecoration(labelText: 'Sélectionner le Camion'),
                      items: trucks.map((t) => DropdownMenuItem(value: t, child: Text(t.plateNumber))).toList(),
                      onChanged: (val) => setDialogState(() => selectedTruck = val),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(selectedClient?.name ?? 'Cliquer pour choisir un Client'),
                      trailing: const Icon(Icons.search),
                      onTap: () async {
                        final tier = await Navigator.push<Tier>(
                          context,
                          MaterialPageRoute(builder: (context) => const TierListScreen(type: TierType.client, isSelectionMode: true)),
                        );
                        if (tier != null) setDialogState(() => selectedClient = tier);
                      },
                    ),
                    TextField(controller: axeController, decoration: const InputDecoration(labelText: 'Axe (ex: BKO - DKR)')),
                    TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Prix Prestation initial'), keyboardType: TextInputType.number),
                    TextField(controller: expensesController, decoration: const InputDecoration(labelText: 'Dépenses initiales'), keyboardType: TextInputType.number),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: (selectedTruck == null || selectedClient == null) ? null : () async {
                    final initialPrestation = Prestation(
                      axis: axeController.text,
                      clientId: selectedClient!.id,
                      clientName: selectedClient!.name,
                      price: double.tryParse(priceController.text) ?? 0,
                      date: DateTime.now(),
                    );
                    final initialExpense = TripExpense(
                      label: 'Dépenses départ',
                      amount: double.tryParse(expensesController.text) ?? 0,
                      compteComptable: '60000000',
                      date: DateTime.now(),
                    );

                    final authService = Provider.of<AuthService>(context, listen: false);
                    final user = await authService.getAppUser((await authService.user.first)!.uid);

                    await service.addTrip(Trip(
                      id: '',
                      truck: selectedTruck!,
                      departureDate: DateTime.now(),
                      prestations: [initialPrestation],
                      expenses: [initialExpense],
                      isFinished: false,
                    ), user?.displayName ?? 'Inconnu');
                    Navigator.pop(context);
                  },
                  child: const Text('Valider'),
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  void _showAddTruckDialog(FirestoreService service, {Truck? truckToEdit}) {
    final plate = TextEditingController(text: truckToEdit?.plateNumber ?? "");
    final name = TextEditingController(text: truckToEdit?.driverName ?? "");
    final tel = TextEditingController(text: truckToEdit?.driverPhone ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(truckToEdit == null ? 'Nouveau Camion' : 'Modifier Camion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: plate, decoration: const InputDecoration(labelText: 'N° Matricule')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom Chauffeur')),
            TextField(controller: tel, decoration: const InputDecoration(labelText: 'Tél')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (truckToEdit != null) {
                final updatedTruck = Truck(id: truckToEdit.id, plateNumber: plate.text, driverName: name.text, driverPhone: tel.text);
                await service.updateTruck(updatedTruck);
              } else {
                await service.addTruck(Truck(id: '', plateNumber: plate.text, driverName: name.text, driverPhone: tel.text));
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E)),
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditTruckDialog(Truck truck, FirestoreService service) {
    _showAddTruckDialog(service, truckToEdit: truck);
  }
}
