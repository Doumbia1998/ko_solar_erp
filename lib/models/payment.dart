import 'package:cloud_firestore/cloud_firestore.dart';
import 'tier.dart';

class Payment {
  final String id;
  final String tierId;
  final String tierName;
  final TierType tierType;
  final double amount;
  final DateTime date;
  final String method;
  final String reference;
  final String? invoiceNumber; // Lien avec une facture spécifique
  final String? journalCode; // Code journal (ex: CA, BQ)
  final bool isPosted;
  final String createdBy; // Nom de l'utilisateur

  Payment({
    required this.id,
    required this.tierId,
    required this.tierName,
    required this.tierType,
    required this.amount,
    required this.date,
    required this.method,
    required this.reference,
    this.invoiceNumber,
    this.journalCode,
    this.isPosted = false,
    this.createdBy = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tierId': tierId,
      'tierName': tierName,
      'tierType': tierType.toString().split('.').last,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'method': method,
      'reference': reference,
      'invoiceNumber': invoiceNumber,
      'journalCode': journalCode,
      'isPosted': isPosted,
      'createdBy': createdBy,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map, String id) {
    return Payment(
      id: id,
      tierId: map['tierId'] ?? '',
      tierName: map['tierName'] ?? '',
      tierType: map['tierType'] == 'supplier' ? TierType.supplier : TierType.client,
      amount: (map['amount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      method: map['method'] ?? '',
      reference: map['reference'] ?? '',
      invoiceNumber: map['invoiceNumber'],
      journalCode: map['journalCode'],
      isPosted: map['isPosted'] ?? false,
      createdBy: map['createdBy'] ?? '',
    );
  }
}
