class PointPackage {
  const PointPackage({
    required this.id,
    required this.name,
    required this.currency,
    required this.priceAmount,
    required this.pointsAmount,
    required this.bonusPoints,
    required this.enabled,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String currency;
  final double priceAmount;
  final int pointsAmount;
  final int bonusPoints;
  final bool enabled;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get totalPoints => pointsAmount + bonusPoints;

  factory PointPackage.fromJson(Map<String, dynamic> json) {
    int integer(String key) => _integer(json[key]);
    final createdAt = integer('created_at');
    final updatedAt = integer('updated_at');

    return PointPackage(
      id: integer('id'),
      name: json['name']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      priceAmount: _decimal(json['price_amount']),
      pointsAmount: integer('points_amount'),
      bonusPoints: integer('bonus_points'),
      enabled: _boolean(json['enabled']),
      sortOrder: integer('sort_order'),
      createdAt: createdAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(createdAt * 1000, isUtc: true)
          : null,
      updatedAt: updatedAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(updatedAt * 1000, isUtc: true)
          : null,
    );
  }
}

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _decimal(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _boolean(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().toLowerCase() == 'true';
}
