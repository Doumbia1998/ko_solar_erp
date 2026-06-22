import 'package:cloud_firestore/cloud_firestore.dart';

class SalaryPayment {
  final String id;
  final String employeeId;
  final String employeeName;
  final double amount;
  final DateTime date;
  final String month; // ex: "Juin 2026"
  final String method;
  final String journalCode; // PAIE
  final String createdBy;

  SalaryPayment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.amount,
    required this.date,
    required this.month,
    required this.method,
    required this.journalCode,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'month': month,
      'method': method,
      'journalCode': journalCode,
      'createdBy': createdBy,
    };
  }

  factory SalaryPayment.fromMap(Map<String, dynamic> map, String id) {
    return SalaryPayment(
      id: id,
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      month: map['month'] ?? '',
      method: map['method'] ?? '',
      journalCode: map['journalCode'] ?? 'PAIE',
      createdBy: map['createdBy'] ?? '',
    );
  }
}
