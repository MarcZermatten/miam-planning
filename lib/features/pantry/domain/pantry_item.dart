import 'package:cloud_firestore/cloud_firestore.dart';

/// Un ingredient dans le garde-manger
class PantryItem {
  final String id;
  final String name;
  final String? category;
  final double? quantity;
  final String? unit;
  final bool isStaple; // Ingredient de base (sel, huile, etc.)
  final DateTime? expiresAt;
  final DateTime addedAt;

  const PantryItem({
    required this.id,
    required this.name,
    this.category,
    this.quantity,
    this.unit,
    this.isStaple = false,
    this.expiresAt,
    required this.addedAt,
  });

  /// Nom normalise pour la comparaison
  String get normalizedName => name.toLowerCase().trim();

  /// Affichage avec quantite
  String get displayText {
    if (quantity != null && unit != null) {
      return '$name ($quantity $unit)';
    } else if (quantity != null) {
      return '$name ($quantity)';
    }
    return name;
  }

  /// Verifie si l'ingredient est expire
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Verifie si l'ingredient expire bientot (dans 3 jours)
  bool get expiresSoon {
    if (expiresAt == null) return false;
    final threeDays = DateTime.now().add(const Duration(days: 3));
    return expiresAt!.isBefore(threeDays) && !isExpired;
  }

  PantryItem copyWith({
    String? id,
    String? name,
    String? category,
    double? quantity,
    String? unit,
    bool? isStaple,
    DateTime? expiresAt,
    DateTime? addedAt,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isStaple: isStaple ?? this.isStaple,
      expiresAt: expiresAt ?? this.expiresAt,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'isStaple': isStaple,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  factory PantryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PantryItem(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'],
      quantity: (data['quantity'] as num?)?.toDouble(),
      unit: data['unit'],
      isStaple: data['isStaple'] ?? false,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Categories d'ingredients pour le garde-manger
enum PantryCategory {
  fruits('Fruits', 1),
  vegetables('Legumes', 2),
  dairy('Produits laitiers', 3),
  meat('Viandes', 4),
  fish('Poissons', 5),
  grains('Cereales & Feculents', 6),
  condiments('Condiments & Epices', 7),
  frozen('Surgeles', 8),
  canned('Conserves', 9),
  beverages('Boissons', 10),
  other('Autres', 99);

  final String label;
  final int sortOrder;

  const PantryCategory(this.label, this.sortOrder);

  static PantryCategory? fromString(String? value) {
    if (value == null) return null;
    return PantryCategory.values.cast<PantryCategory?>().firstWhere(
          (c) => c?.name == value,
          orElse: () => null,
        );
  }
}
