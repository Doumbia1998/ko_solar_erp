import 'package:cloud_firestore/cloud_firestore.dart';

class StockTransfer {
  final String id;
  final String productId;
  final String productName;
  final String fromWarehouseId;
  final String fromWarehouseName;
  final String toWarehouseId;
  final String toWarehouseName;
  final int quantity;
  final DateTime date;

  StockTransfer({
    required this.id,
    required this.productId,
    required this.productName,
    required this.fromWarehouseId,
    required this.fromWarehouseName,
    required this.toWarehouseId,
    required this.toWarehouseName,
    required this.quantity,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'fromWarehouseId': fromWarehouseId,
      'fromWarehouseName': fromWarehouseName,
      'toWarehouseId': toWarehouseId,
      'toWarehouseName': toWarehouseName,
      'quantity': quantity,
      'date': Timestamp.fromDate(date),
    };
  }

  factory StockTransfer.fromMap(Map<String, dynamic> map, String id) {
    return StockTransfer(
      id: id,
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      fromWarehouseId: map['fromWarehouseId'] ?? '',
      fromWarehouseName: map['fromWarehouseName'] ?? '',
      toWarehouseId: map['toWarehouseId'] ?? '',
      toWarehouseName: map['toWarehouseName'] ?? '',
      quantity: map['quantity'] ?? 0,
      date: (map['date'] as Timestamp).toDate(),
    );
  }
}
