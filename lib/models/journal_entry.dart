import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntry {
  final String id;
  final DateTime date;
  final String label;
  final String accountCode;
  final String accountLabel;
  final double debit;
  final double credit;
  final String reference;
  final String journalCode; // ACH, VEN, BQ, CAI

  JournalEntry({
    required this.id,
    required this.date,
    required this.label,
    required this.accountCode,
    required this.accountLabel,
    required this.debit,
    required this.credit,
    required this.reference,
    required this.journalCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'label': label,
      'accountCode': accountCode,
      'accountLabel': accountLabel,
      'debit': debit,
      'credit': credit,
      'reference': reference,
      'journalCode': journalCode,
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map, String id) {
    return JournalEntry(
      id: id,
      date: (map['date'] as Timestamp).toDate(),
      label: map['label'] ?? '',
      accountCode: map['accountCode'] ?? '',
      accountLabel: map['accountLabel'] ?? '',
      debit: (map['debit'] as num).toDouble(),
      credit: (map['credit'] as num).toDouble(),
      reference: map['reference'] ?? '',
      journalCode: map['journalCode'] ?? '',
    );
  }
}
