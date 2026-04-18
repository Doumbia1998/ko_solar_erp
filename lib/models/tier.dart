enum TierType { client, supplier }

class Tier {
  final String id;
  final String name;
  final String phone;
  final String address;
  final TierType type;
  final String accountNumber; // General account number (e.g., 41100000 or 40100000)
  final String compteComptable; // Specific accounting account

  Tier({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.type,
    required this.accountNumber,
    required this.compteComptable,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'type': type.toString().split('.').last,
      'accountNumber': accountNumber,
      'compteComptable': compteComptable,
    };
  }

  factory Tier.fromMap(Map<String, dynamic> map, String id) {
    return Tier(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      type: map['type'] == 'supplier' ? TierType.supplier : TierType.client,
      accountNumber: map['accountNumber'] ?? '',
      compteComptable: map['compteComptable'] ?? '',
    );
  }
}
