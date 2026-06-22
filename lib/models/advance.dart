import 'package:cloud_firestore/cloud_firestore.dart';

class Advance {
  final String id;
  final String tierId;
  final String tierName;
  final double amount;
  final DateTime date;
  final String method;
  final String reference;
  final String createdBy;
  final bool isUsed;
  final String? usedInInvoice;

  Advance({
    required this.id,
    required this.tierId,
    required this.tierName,
    required this.amount,
    required this.date,
    required this.method,
    required this.reference,
    required this.createdBy,
    this.isUsed = false,
    this.usedInInvoice,
  });

  Map<String, dynamic> toMap() {
    return {
      'tierId': tierId,
      'tierName': tierName,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'method': method,
      'reference': reference,
      'createdBy': createdBy,
      'isUsed': isUsed,
      'usedInInvoice': usedInInvoice,
    };
  }

  factory Advance.fromMap(Map<String, dynamic> map, String id) {
    return Advance(
      id: id,
      tierId: map['tierId'] ?? '',
      tierName: map['tierName'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      method: map['method'] ?? '',
      reference: map['reference'] ?? '',
      createdBy: map['createdBy'] ?? '',
      isUsed: map['isUsed'] ?? false,
      usedInInvoice: map['usedInInvoice'],
    );
  }
}
