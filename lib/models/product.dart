class Product {
  final String id;
  final String name;
  final String description;
  final double purchasePrice;
  final double sellingPrice;
  final int totalQuantity;
  final String category;
  final String compteAchat; // Compte 601...
  final String compteVente; // Compte 701...

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.totalQuantity,
    required this.category,
    this.compteAchat = '601100',
    this.compteVente = '701100',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'totalQuantity': totalQuantity,
      'category': category,
      'compteAchat': compteAchat,
      'compteVente': compteVente,
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
      compteAchat: map['compteAchat'] ?? map['compteComptable'] ?? '601100',
      compteVente: map['compteVente'] ?? '701100',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
