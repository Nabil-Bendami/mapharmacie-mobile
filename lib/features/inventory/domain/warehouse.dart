class Warehouse {
  const Warehouse({
    required this.id,
    required this.name,
    required this.isDefault,
    this.locationKind = 'pharmacy_stock',
  });

  final String id;
  final String name;
  final bool isDefault;
  final String locationKind;
  String get displayName =>
      '$name · ${locationKind == "depot" ? "Dépôt" : "Réserve d’officine"}';

  factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
    id: json['id'] as String,
    locationKind: json['location_kind'] as String? ?? 'pharmacy_stock',
    name: json['name'] as String,
    isDefault: (json['is_default'] as bool?) ?? false,
  );
}
