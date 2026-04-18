class Product {
  final String id;
  final String name;
  final String description;
  final double purchasePrice;
  final double sellingPrice;
  final int totalQuantity;
  final String category;
  final String compteComptable;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.totalQuantity,
    required this.category,
    required this.compteComptable,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'totalQuantity': totalQuantity,
      'category': category,
      'compteComptable': compteComptable,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      purchasePrice: (map['purchasePrice'] ?? 0).toDouble(),
      sellingPrice: (map['sellingPrice'] ?? 0).toDouble(),
      totalQuantity: map['totalQuantity'] ?? 0,
      category: map['category'] ?? '',
      compteComptable: map['compteComptable'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
