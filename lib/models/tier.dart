enum TierType { client, supplier }

class Tier {
  final String id;
  final String name;
  final String phone;
  final String address;
  final TierType type;
  final String compteGeneral; // ex: 41100000 (Général)
  final String compteTiers; // ex: 411ABAZIZ (Spécifique Sage)

  Tier({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.type,
    required this.compteGeneral,
    required this.compteTiers,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'type': type.toString().split('.').last,
      'compteGeneral': compteGeneral,
      'compteTiers': compteTiers,
    };
  }

  factory Tier.fromMap(Map<String, dynamic> map, String id) {
    return Tier(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      type: map['type'] == 'supplier' ? TierType.supplier : TierType.client,
      compteGeneral: map['compteGeneral'] ?? map['accountNumber'] ?? '',
      compteTiers: map['compteTiers'] ?? map['compteComptable'] ?? '',
    );
  }
}
