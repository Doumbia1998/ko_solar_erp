import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { purchase, sale, quote, saleReturn, purchaseReturn }

class TransactionItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double discount;

  TransactionItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'discount': discount,
      'total': (quantity * unitPrice) - discount,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
    );
  }
}

class AppTransaction {
  final String id;
  final String invoiceNumber;
  final DateTime date;
  final DateTime? dueDate; // Date d'échéance pour les relances
  final String tierId; // Client or Supplier ID
  final String tierName;
  final TransactionType type;
  final List<TransactionItem> items;
  final double totalHT;
  final double amountPaid;
  final String paymentMethod;
  final String warehouseId;
  final String destination; // Destination du produit
  final double transportFees;
  final bool addTransport; // true = ajouter, false = soustraire
  final bool isPosted; // statut comptabilisation
  final String deliveryStatus; // 'pending', 'delivered'
  final String createdBy; // Nom de l'utilisateur

  AppTransaction({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    this.dueDate,
    required this.tierId,
    required this.tierName,
    required this.type,
    required this.items,
    required this.totalHT,
    required this.amountPaid,
    required this.paymentMethod,
    required this.warehouseId,
    this.destination = '',
    this.transportFees = 0.0,
    this.addTransport = true,
    this.isPosted = false,
    this.deliveryStatus = 'pending',
    this.createdBy = '',
  });

  double get netToPay {
    double net = addTransport ? (totalHT + transportFees) : (totalHT - transportFees);
    // Pour les retours, le montant net est négatif dans les calculs de solde
    if (type == TransactionType.saleReturn || type == TransactionType.purchaseReturn) {
      return -net;
    }
    return net;
  }

  double get balance => netToPay - amountPaid;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'date': Timestamp.fromDate(date),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'tierId': tierId,
      'tierName': tierName,
      'type': type.toString().split('.').last,
      'items': items.map((i) => i.toMap()).toList(),
      'totalHT': totalHT,
      'amountPaid': amountPaid,
      'paymentMethod': paymentMethod,
      'warehouseId': warehouseId,
      'destination': destination,
      'transportFees': transportFees,
      'addTransport': addTransport,
      'isPosted': isPosted,
      'deliveryStatus': deliveryStatus,
      'createdBy': createdBy,
    };
  }

  factory AppTransaction.fromMap(Map<String, dynamic> map, String id) {
    TransactionType tType;
    String typeStr = map['type'] ?? 'sale';
    if (typeStr == 'sale') {
      tType = TransactionType.sale;
    } else if (typeStr == 'quote') {
      tType = TransactionType.quote;
    } else if (typeStr == 'saleReturn') {
      tType = TransactionType.saleReturn;
    } else if (typeStr == 'purchaseReturn') {
      tType = TransactionType.purchaseReturn;
    } else {
      tType = TransactionType.purchase;
    }

    return AppTransaction(
      id: id,
      invoiceNumber: map['invoiceNumber'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      dueDate: map['dueDate'] != null ? (map['dueDate'] as Timestamp).toDate() : null,
      tierId: map['tierId'] ?? '',
      tierName: map['tierName'] ?? '',
      type: tType,
      items: (map['items'] as List).map((i) => TransactionItem.fromMap(i)).toList(),
      totalHT: (map['totalHT'] ?? 0).toDouble(),
      amountPaid: (map['amountPaid'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? '',
      warehouseId: map['warehouseId'] ?? '',
      destination: map['destination'] ?? map['sourceLocation'] ?? '',
      transportFees: (map['transportFees'] ?? 0).toDouble(),
      addTransport: map['addTransport'] ?? true,
      isPosted: map['isPosted'] ?? false,
      deliveryStatus: map['deliveryStatus'] ?? 'pending',
      createdBy: map['createdBy'] ?? '',
    );
  }
}
