import 'package:cloud_firestore/cloud_firestore.dart';

/// Category of a dish (nutritional categories)
enum DishCategory {
  protein,     // Proteines (viande, poisson, oeufs, legumineuses)
  starch,      // Feculents (pates, riz, pommes de terre, pain)
  vegetable,   // Legumes
  dairy,       // Produits laitiers
  fruit,       // Fruits
  dessert,     // Desserts
  sauce,       // Sauces et accompagnements liquides
  complete,    // Plat complet (ex: lasagnes, risotto)
  other,       // Autre
}

/// Extension for DishCategory labels
extension DishCategoryExtension on DishCategory {
  String get label {
    switch (this) {
      case DishCategory.protein:
        return 'Proteine';
      case DishCategory.starch:
        return 'Feculent';
      case DishCategory.vegetable:
        return 'Legume';
      case DishCategory.dairy:
        return 'Produit laitier';
      case DishCategory.fruit:
        return 'Fruit';
      case DishCategory.dessert:
        return 'Dessert';
      case DishCategory.sauce:
        return 'Sauce';
      case DishCategory.complete:
        return 'Plat complet';
      case DishCategory.other:
        return 'Autre';
    }
  }

  String get icon {
    switch (this) {
      case DishCategory.protein:
        return '🥩';
      case DishCategory.starch:
        return '🍝';
      case DishCategory.vegetable:
        return '🥦';
      case DishCategory.dairy:
        return '🧀';
      case DishCategory.fruit:
        return '🍎';
      case DishCategory.dessert:
        return '🍰';
      case DishCategory.sauce:
        return '🫕';
      case DishCategory.complete:
        return '🍲';
      case DishCategory.other:
        return '🍴';
    }
  }

  /// Color for this category (for UI)
  String get colorHex {
    switch (this) {
      case DishCategory.protein:
        return '#EF9A9A'; // Rouge pastel
      case DishCategory.starch:
        return '#BCAAA4'; // Brun pastel
      case DishCategory.vegetable:
        return '#A5D6A7'; // Vert pastel
      case DishCategory.dairy:
        return '#90CAF9'; // Bleu pastel
      case DishCategory.fruit:
        return '#FFE082'; // Jaune pastel
      case DishCategory.dessert:
        return '#F8BBD9'; // Rose pastel
      case DishCategory.sauce:
        return '#FFCC80'; // Orange pastel
      case DishCategory.complete:
        return '#B39DDB'; // Violet pastel
      case DishCategory.other:
        return '#CFD8DC'; // Gris pastel
    }
  }
}

/// Type of meal (when in the day this dish is typically served)
enum MealType {
  entree,         // Entree
  plat,           // Plat principal
  dessert,        // Dessert
  gouter,         // Gouter
  petitDejeuner,  // Petit-dejeuner
  apero,          // Aperitif
}

/// Extension for MealType labels
extension MealTypeExtension on MealType {
  String get label {
    switch (this) {
      case MealType.entree:
        return 'Entree';
      case MealType.plat:
        return 'Plat';
      case MealType.dessert:
        return 'Dessert';
      case MealType.gouter:
        return 'Gouter';
      case MealType.petitDejeuner:
        return 'Petit-dej';
      case MealType.apero:
        return 'Apero';
    }
  }

  String get icon {
    switch (this) {
      case MealType.entree:
        return '🥗';
      case MealType.plat:
        return '🍽️';
      case MealType.dessert:
        return '🍰';
      case MealType.gouter:
        return '🍪';
      case MealType.petitDejeuner:
        return '🥐';
      case MealType.apero:
        return '🥂';
    }
  }
}

/// A dish represents a meal item (e.g., "Puree de pommes de terre")
/// Each dish can have multiple recipe variants and multiple nutritional categories
class Dish {
  final String id;
  final String name;
  final String? imageUrl;
  final List<DishCategory> categories; // Multiple categories allowed
  final MealType? mealType; // Type of meal (entree, plat, dessert, etc.)
  final List<String> recipeIds;
  final List<String> tags;
  final DateTime createdAt;
  final String createdBy;

  // Freezer properties
  final bool isFrozen;
  final int frozenPortions;
  final DateTime? frozenAt;

  Dish({
    required this.id,
    required this.name,
    this.imageUrl,
    this.categories = const [DishCategory.complete],
    this.mealType,
    this.recipeIds = const [],
    this.tags = const [],
    required this.createdAt,
    required this.createdBy,
    this.isFrozen = false,
    this.frozenPortions = 0,
    this.frozenAt,
  });

  factory Dish.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle both old format (single category) and new format (list)
    List<DishCategory> categories;
    if (data['categories'] != null) {
      categories = (data['categories'] as List<dynamic>)
          .map((c) => DishCategory.values.firstWhere(
                (e) => e.name == c,
                orElse: () => DishCategory.complete,
              ))
          .toList();
    } else if (data['category'] != null) {
      // Legacy: single category
      categories = [
        DishCategory.values.firstWhere(
          (e) => e.name == data['category'],
          orElse: () => DishCategory.complete,
        )
      ];
    } else {
      categories = [DishCategory.complete];
    }

    // Parse mealType
    MealType? mealType;
    if (data['mealType'] != null) {
      mealType = MealType.values.firstWhere(
        (e) => e.name == data['mealType'],
        orElse: () => MealType.plat,
      );
    }

    return Dish(
      id: doc.id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'],
      categories: categories,
      mealType: mealType,
      recipeIds: List<String>.from(data['recipeIds'] ?? []),
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      isFrozen: data['isFrozen'] ?? false,
      frozenPortions: data['frozenPortions'] ?? 0,
      frozenAt: (data['frozenAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'categories': categories.map((c) => c.name).toList(),
      'mealType': mealType?.name,
      'recipeIds': recipeIds,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'isFrozen': isFrozen,
      'frozenPortions': frozenPortions,
      'frozenAt': frozenAt != null ? Timestamp.fromDate(frozenAt!) : null,
    };
  }

  Dish copyWith({
    String? name,
    String? imageUrl,
    List<DishCategory>? categories,
    MealType? mealType,
    List<String>? recipeIds,
    List<String>? tags,
    bool? isFrozen,
    int? frozenPortions,
    DateTime? frozenAt,
  }) {
    return Dish(
      id: id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      categories: categories ?? this.categories,
      mealType: mealType ?? this.mealType,
      recipeIds: recipeIds ?? this.recipeIds,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      createdBy: createdBy,
      isFrozen: isFrozen ?? this.isFrozen,
      frozenPortions: frozenPortions ?? this.frozenPortions,
      frozenAt: frozenAt ?? this.frozenAt,
    );
  }

  /// Get display string for categories (e.g., "Proteine + Feculent")
  String get categoriesDisplay {
    if (categories.isEmpty) return 'Non classe';
    return categories.map((c) => c.label).join(' + ');
  }

  /// Get icons for all categories
  String get categoriesIcons {
    return categories.map((c) => c.icon).join(' ');
  }

  /// Check if dish contains a specific category
  bool hasCategory(DishCategory category) => categories.contains(category);

  /// Add a category
  Dish addCategory(DishCategory category) {
    if (categories.contains(category)) return this;
    return copyWith(categories: [...categories, category]);
  }

  /// Remove a category
  Dish removeCategory(DishCategory category) {
    return copyWith(categories: categories.where((c) => c != category).toList());
  }

  /// Toggle a category
  Dish toggleCategory(DishCategory category) {
    if (categories.contains(category)) {
      return removeCategory(category);
    } else {
      return addCategory(category);
    }
  }

  /// Add a recipe to this dish
  Dish addRecipe(String recipeId) {
    if (recipeIds.contains(recipeId)) return this;
    return copyWith(recipeIds: [...recipeIds, recipeId]);
  }

  /// Remove a recipe from this dish
  Dish removeRecipe(String recipeId) {
    return copyWith(recipeIds: recipeIds.where((id) => id != recipeId).toList());
  }

  /// Add portions to freezer
  Dish addFrozenPortions(int portions) {
    return copyWith(
      isFrozen: true,
      frozenPortions: frozenPortions + portions,
      frozenAt: frozenAt ?? DateTime.now(),
    );
  }

  /// Use portions from freezer
  Dish useFrozenPortions(int portions) {
    final remaining = frozenPortions - portions;
    if (remaining <= 0) {
      return copyWith(
        isFrozen: false,
        frozenPortions: 0,
        frozenAt: null,
      );
    }
    return copyWith(frozenPortions: remaining);
  }

  /// Check if dish has available frozen portions
  bool get hasFrozenPortions => isFrozen && frozenPortions > 0;
}
