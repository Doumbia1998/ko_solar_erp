import 'package:cloud_firestore/cloud_firestore.dart';

class Truck {
  String id;
  String plateNumber, driverName, driverPhone;
  
  Truck({required this.id, required this.plateNumber, required this.driverName, required this.driverPhone});

  String get registrationNumber => plateNumber;

  Map<String, dynamic> toMap() => {
    'plateNumber': plateNumber,
    'driverName': driverName,
    'driverPhone': driverPhone,
  };

  factory Truck.fromMap(Map<String, dynamic> map, String id) => Truck(
    id: id,
    plateNumber: map['plateNumber'] ?? '',
    driverName: map['driverName'] ?? '',
    driverPhone: map['driverPhone'] ?? '',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Truck && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Prestation {
  String axis;
  String clientId;
  String clientName;
  double price;
  double amountPaid; // Nouveau: pour gérer les impayés par prestation
  DateTime date;

  Prestation({
    required this.axis, 
    required this.clientId, 
    required this.clientName, 
    required this.price, 
    this.amountPaid = 0.0,
    required this.date
  });

  double get balance => price - amountPaid;
  bool get isPaid => balance <= 0;

  Map<String, dynamic> toMap() => {
    'axis': axis,
    'clientId': clientId,
    'clientName': clientName,
    'price': price,
    'amountPaid': amountPaid,
    'date': Timestamp.fromDate(date),
  };

  factory Prestation.fromMap(Map<String, dynamic> map) => Prestation(
    axis: map['axis'] ?? '',
    clientId: map['clientId'] ?? '',
    clientName: map['clientName'] ?? 'Inconnu',
    price: (map['price'] ?? 0).toDouble(),
    amountPaid: (map['amountPaid'] ?? 0).toDouble(),
    date: map['date'] != null ? (map['date'] as Timestamp).toDate() : DateTime.now(),
  );
}

class TripExpense {
  String label;
  double amount;
  String compteComptable;
  DateTime date;

  TripExpense({required this.label, required this.amount, required this.compteComptable, required this.date});

  Map<String, dynamic> toMap() => {
    'label': label,
    'amount': amount,
    'compteComptable': compteComptable,
    'date': Timestamp.fromDate(date),
  };

  factory TripExpense.fromMap(Map<String, dynamic> map) => TripExpense(
    label: map['label'] ?? '',
    amount: (map['amount'] ?? 0).toDouble(),
    compteComptable: map['compteComptable'] ?? '60110000',
    date: map['date'] != null ? (map['date'] as Timestamp).toDate() : DateTime.now(),
  );
}

class Trip {
  String id;
  Truck truck;
  List<Prestation> prestations;
  List<TripExpense> expenses;
  DateTime departureDate;
  DateTime? returnDate;
  bool isFinished;
  String createdBy;

  Trip({
    required this.id,
    required this.truck,
    required this.prestations,
    required this.expenses,
    required this.departureDate,
    this.returnDate,
    this.isFinished = false,
    this.createdBy = '',
  });

  String get truckId => truck.id;
  String get truckRegistration => truck.plateNumber;
  String get clientName => prestations.isNotEmpty ? prestations.first.clientName : "Aucun";
  String get clientNames => prestations.map((p) => p.clientName).join(", ");
  String get mainAxis => prestations.isNotEmpty ? prestations.first.axis : "Axe non défini";
  DateTime get date => departureDate;
  String get destination => mainAxis;
  
  double get totalRevenue => prestations.fold(0.0, (sum, p) => sum + p.price);
  double get totalPaid => prestations.fold(0.0, (sum, p) => sum + p.amountPaid);
  double get totalUnpaid => totalRevenue - totalPaid;
  
  double get totalExpenses => expenses.fold(0.0, (sum, e) => sum + e.amount);
  double get netProfit => totalRevenue - totalExpenses;

  Map<String, dynamic> toMap() => {
    'truck': truck.toMap(),
    'truckId': truck.id,
    'prestations': prestations.map((e) => e.toMap()).toList(),
    'expenses': expenses.map((e) => e.toMap()).toList(),
    'departureDate': Timestamp.fromDate(departureDate),
    'returnDate': returnDate != null ? Timestamp.fromDate(returnDate!) : null,
    'isFinished': isFinished,
  };

  factory Trip.fromMap(Map<String, dynamic> map, String id) {
    try {
      return Trip(
        id: id,
        truck: Truck.fromMap(map['truck'] as Map<String, dynamic>? ?? {}, map['truckId'] ?? ''),
        prestations: (map['prestations'] as List? ?? []).map((e) => Prestation.fromMap(e as Map<String, dynamic>)).toList(),
        expenses: (map['expenses'] as List? ?? []).map((e) => TripExpense.fromMap(e as Map<String, dynamic>)).toList(),
        departureDate: (map['departureDate'] as Timestamp).toDate(),
        returnDate: map['returnDate'] != null ? (map['returnDate'] as Timestamp).toDate() : null,
        isFinished: map['isFinished'] ?? false,
      );
    } catch (e) {
      return Trip(id: id, truck: Truck(id: '', plateNumber: 'ERREUR', driverName: '', driverPhone: ''), prestations: [], expenses: [], departureDate: DateTime.now());
    }
  }
}
