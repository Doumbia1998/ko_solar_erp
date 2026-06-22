class PaymentMethodConfig {
  final String id;
  final String name;

  PaymentMethodConfig({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'name': name};

  factory PaymentMethodConfig.fromMap(Map<String, dynamic> map, String id) {
    return PaymentMethodConfig(id: id, name: map['name'] ?? '');
  }
}
