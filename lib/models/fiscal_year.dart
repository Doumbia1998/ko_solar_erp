import 'package:cloud_firestore/cloud_firestore.dart';

class FiscalYear {
  final String id;
  final String label; // ex: "EXERCICE 2026"
  final DateTime startDate;
  final DateTime endDate;
  final bool isClosed;
  final String createdBy;

  FiscalYear({
    required this.id,
    required this.label,
    required this.startDate,
    required this.endDate,
    this.isClosed = false,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isClosed': isClosed,
      'createdBy': createdBy,
    };
  }

  factory FiscalYear.fromMap(Map<String, dynamic> map, String id) {
    return FiscalYear(
      id: id,
      label: map['label'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      isClosed: map['isClosed'] ?? false,
      createdBy: map['createdBy'] ?? '',
    );
  }
}
