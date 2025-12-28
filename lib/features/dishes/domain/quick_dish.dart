import 'package:cloud_firestore/cloud_firestore.dart';
import 'dish.dart';

/// A simple dish that can be quickly added to meals
/// Unlike full recipes, these are just names with categories
class QuickDish {
  final String id;
  final String name;
  final List<DishCategory> categories;
  final DateTime createdAt;
  final int usageCount; // For sorting by frequency

  QuickDish({
    required this.id,
    required this.name,
    this.categories = const [],
    required this.createdAt,
    this.usageCount = 0,
  });

  factory QuickDish.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuickDish(
      id: doc.id,
      name: data['name'] ?? '',
      categories: (data['categories'] as List<dynamic>?)
              ?.map((e) => DishCategory.values.firstWhere(
                    (c) => c.name == e,
                    orElse: () => DishCategory.other,
                  ))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usageCount: data['usageCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'categories': categories.map((c) => c.name).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'usageCount': usageCount,
    };
  }

  QuickDish copyWith({
    String? id,
    String? name,
    List<DishCategory>? categories,
    DateTime? createdAt,
    int? usageCount,
  }) {
    return QuickDish(
      id: id ?? this.id,
      name: name ?? this.name,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      usageCount: usageCount ?? this.usageCount,
    );
  }

  /// Increment usage count
  QuickDish incrementUsage() {
    return copyWith(usageCount: usageCount + 1);
  }

  /// Get display string for categories
  String get categoriesDisplay {
    if (categories.isEmpty) return '';
    return categories.map((c) => c.icon).join(' ');
  }
}
