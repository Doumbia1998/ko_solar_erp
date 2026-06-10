import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { pending, in_progress, completed, archived }

class Task {
  final String id;
  final String transactionId; // BL ID
  final String invoiceNumber;
  final String clientName;
  final String technicianId;
  final String technicianName;
  final String assignedBy;
  final DateTime assignedAt;
  final TaskStatus status;

  // Rapport de chantier
  final String? reportDescription;
  final List<Map<String, dynamic>>? usedProducts; // {productId, name, qty}
  final DateTime? completedAt;
  final String? siteLocation;
  final String? gpsLocation; // Coordonnées format "lat,lng"
  final String? sitePhotoUrl;

  Task({
    required this.id,
    required this.transactionId,
    required this.invoiceNumber,
    required this.clientName,
    required this.technicianId,
    required this.technicianName,
    required this.assignedBy,
    required this.assignedAt,
    this.status = TaskStatus.pending,
    this.reportDescription,
    this.usedProducts,
    this.completedAt,
    this.siteLocation,
    this.gpsLocation,
    this.sitePhotoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'invoiceNumber': invoiceNumber,
      'clientName': clientName,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'assignedBy': assignedBy,
      'assignedAt': Timestamp.fromDate(assignedAt),
      'status': status.toString().split('.').last,
      'reportDescription': reportDescription,
      'usedProducts': usedProducts,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'siteLocation': siteLocation,
      'gpsLocation': gpsLocation,
      'sitePhotoUrl': sitePhotoUrl,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map, String id) {
    return Task(
      id: id,
      transactionId: map['transactionId'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      clientName: map['clientName'] ?? '',
      technicianId: map['technicianId'] ?? '',
      technicianName: map['technicianName'] ?? '',
      assignedBy: map['assignedBy'] ?? '',
      assignedAt: (map['assignedAt'] as Timestamp).toDate(),
      status: TaskStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => TaskStatus.pending,
      ),
      reportDescription: map['reportDescription'],
      usedProducts: (map['usedProducts'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList(),
      completedAt: map['completedAt'] != null ? (map['completedAt'] as Timestamp).toDate() : null,
      siteLocation: map['siteLocation'],
      gpsLocation: map['gpsLocation'],
      sitePhotoUrl: map['sitePhotoUrl'],
    );
  }
}
