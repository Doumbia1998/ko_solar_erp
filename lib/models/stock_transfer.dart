import 'package:cloud_firestore/cloud_firestore.dart';

class StockTransferItem {
  final String productId;
  final String productName;
  final int quantity;

  StockTransferItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
    };
  }

  factory StockTransferItem.fromMap(Map<String, dynamic> map) {
    return StockTransferItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
    );
  }
}

class StockTransfer {
  final String id;
  final String reference;
  final String fromWarehouseId;
  final String fromWarehouseName;
  final String toWarehouseId;
  final String toWarehouseName;
  final List<StockTransferItem> items;
  final DateTime date;
  final String createdBy;

  StockTransfer({
    required this.id,
    required this.reference,
    required this.fromWarehouseId,
    required this.fromWarehouseName,
    required this.toWarehouseId,
    required this.toWarehouseName,
    required this.items,
    required this.date,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'reference': reference,
      'fromWarehouseId': fromWarehouseId,
      'fromWarehouseName': fromWarehouseName,
      'toWarehouseId': toWarehouseId,
      'toWarehouseName': toWarehouseName,
      'items': items.map((i) => i.toMap()).toList(),
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
    };
  }

  factory StockTransfer.fromMap(Map<String, dynamic> map, String id) {
    // Gestion de la rétrocompatibilité (ancien format mono-produit)
    List<StockTransferItem> itemsList = [];
    if (map['items'] != null) {
      itemsList = (map['items'] as List).map((i) => StockTransferItem.fromMap(i)).toList();
    } else if (map['productId'] != null) {
      itemsList = [
        StockTransferItem(
          productId: map['productId'],
          productName: map['productName'] ?? 'Inconnu',
          quantity: map['quantity'] ?? 0,
        )
      ];
    }

    return StockTransfer(
      id: id,
      reference: map['reference'] ?? id,
      fromWarehouseId: map['fromWarehouseId'] ?? '',
      fromWarehouseName: map['fromWarehouseName'] ?? '',
      toWarehouseId: map['toWarehouseId'] ?? '',
      toWarehouseName: map['toWarehouseName'] ?? '',
      items: itemsList,
      date: (map['date'] as Timestamp).toDate(),
      createdBy: map['createdBy'] ?? '',
    );
  }
}
