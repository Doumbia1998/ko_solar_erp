class Account {
  final String id;
  final String code;
  final String label;
  final String nature;
  final bool isActive;

  Account({
    required this.id,
    required this.code,
    required this.label,
    required this.nature,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'code': code,
    'label': label,
    'nature': nature,
    'isActive': isActive,
  };

  factory Account.fromMap(Map<String, dynamic> map, String id) => Account(
    id: id,
    code: map['code'] ?? '',
    label: map['label'] ?? '',
    nature: map['nature'] ?? 'Charge',
    isActive: map['isActive'] ?? true,
  );
}
