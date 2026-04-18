class Warehouse {
  final String id;
  final String name;
  final String location;

  Warehouse({
    required this.id,
    required this.name,
    required this.location,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
    };
  }

  factory Warehouse.fromMap(Map<String, dynamic> map, String id) {
    return Warehouse(
      id: id,
      name: map['name'] ?? '',
      location: map['location'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Warehouse && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
