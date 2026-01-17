import 'package:cloud_firestore/cloud_firestore.dart';

enum WineType { red, white, rose }

class WineBottle {
  final String id;
  final String name;
  final WineType type;
  final String? grape;
  final int? year;
  final int quantity;
  final DateTime addedAt;

  WineBottle({
    required this.id,
    required this.name,
    required this.type,
    this.grape,
    this.year,
    this.quantity = 1,
    required this.addedAt,
  });

  String get typeLabel {
    switch (type) {
      case WineType.red:
        return 'Rouge';
      case WineType.white:
        return 'Blanc';
      case WineType.rose:
        return 'Rosé';
    }
  }

  factory WineBottle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WineBottle(
      id: doc.id,
      name: data['name'] ?? '',
      type: WineType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => WineType.red,
      ),
      grape: data['grape'],
      year: data['year'],
      quantity: data['quantity'] ?? 1,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.name,
      'grape': grape,
      'year': year,
      'quantity': quantity,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  WineBottle copyWith({
    String? id,
    String? name,
    WineType? type,
    String? grape,
    int? year,
    int? quantity,
    DateTime? addedAt,
  }) {
    return WineBottle(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      grape: grape ?? this.grape,
      year: year ?? this.year,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
