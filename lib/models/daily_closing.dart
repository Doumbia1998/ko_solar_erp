import 'package:cloud_firestore/cloud_firestore.dart';

class DailyClosing {
  final String id;
  final DateTime date;
  final double totalSales;
  final double totalPurchases;
  final double totalIncomes; // Encaissements (Acomptes + Règlements)
  final double totalOutcomes; // Décaissements
  final double cashInHand; // Espèces théoriques en caisse
  final String closedBy;

  DailyClosing({
    required this.id,
    required this.date,
    required this.totalSales,
    required this.totalPurchases,
    required this.totalIncomes,
    required this.totalOutcomes,
    required this.cashInHand,
    required this.closedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'totalSales': totalSales,
      'totalPurchases': totalPurchases,
      'totalIncomes': totalIncomes,
      'totalOutcomes': totalOutcomes,
      'cashInHand': cashInHand,
      'closedBy': closedBy,
    };
  }

  factory DailyClosing.fromMap(Map<String, dynamic> map, String id) {
    return DailyClosing(
      id: id,
      date: (map['date'] as Timestamp).toDate(),
      totalSales: (map['totalSales'] ?? 0).toDouble(),
      totalPurchases: (map['totalPurchases'] ?? 0).toDouble(),
      totalIncomes: (map['totalIncomes'] ?? 0).toDouble(),
      totalOutcomes: (map['totalOutcomes'] ?? 0).toDouble(),
      cashInHand: (map['cashInHand'] ?? 0).toDouble(),
      closedBy: map['closedBy'] ?? '',
    );
  }
}
