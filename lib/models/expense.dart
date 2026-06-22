import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final DateTime date;
  final String label;
  final double amount;
  final String category;
  final String accountCode; // Compte comptable (Charge)
  final String journalCode; // CA, BQ, PAIE
  final String paymentMethod;
  final String createdBy;

  Expense({
    required this.id,
    required this.date,
    required this.label,
    required this.amount,
    required this.category,
    required this.accountCode,
    required this.journalCode,
    required this.paymentMethod,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'label': label,
      'amount': amount,
      'category': category,
      'accountCode': accountCode,
      'journalCode': journalCode,
      'paymentMethod': paymentMethod,
      'createdBy': createdBy,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map, String id) {
    return Expense(
      id: id,
      date: (map['date'] as Timestamp).toDate(),
      label: map['label'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] ?? '',
      accountCode: map['accountCode'] ?? '',
      journalCode: map['journalCode'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      createdBy: map['createdBy'] ?? '',
    );
  }
}
