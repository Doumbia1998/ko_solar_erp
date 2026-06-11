class JournalConfig {
  final String id;
  final String code;
  final String name;

  JournalConfig({required this.id, required this.code, required this.name});

  Map<String, dynamic> toMap() {
    return {'code': code, 'name': name};
  }

  factory JournalConfig.fromMap(Map<String, dynamic> map, String id) {
    return JournalConfig(
      id: id,
      code: map['code'] ?? '',
      name: map['name'] ?? '',
    );
  }
}
