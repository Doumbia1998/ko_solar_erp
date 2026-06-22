class Product {
  final String id;
  final String reference;
  final String name;
  final String description;
  final double purchasePrice; // Dernier prix d'achat
  final double sellingPrice;
  final int totalQuantity;
  final String category;
  final String compteAchat;
  final String compteVente;
  final double weightedAverageCost; // CMUP

  Product({
    required this.id,
    this.reference = '',
    required this.name,
    required this.description,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.totalQuantity,
    required this.category,
    this.compteAchat = '60110000',
    this.compteVente = '70110000',
    this.weightedAverageCost = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'reference': reference,
      'name': name,
      'description': description,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'totalQuantity': totalQuantity,
      'category': category,
      'compteAchat': compteAchat,
      'compteVente': compteVente,
      'weightedAverageCost': weightedAverageCost,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      reference: map['reference'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      purchasePrice: (map['purchasePrice'] ?? 0).toDouble(),
      sellingPrice: (map['sellingPrice'] ?? 0).toDouble(),
      totalQuantity: map['totalQuantity'] ?? 0,
      category: map['category'] ?? '',
      compteAchat: map['compteAchat'] ?? '60110000',
      compteVente: map['compteVente'] ?? '70110000',
      weightedAverageCost: (map['weightedAverageCost'] ?? (map['purchasePrice'] ?? 0)).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
