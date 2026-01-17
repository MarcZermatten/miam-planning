import 'package:cloud_firestore/cloud_firestore.dart';
import '../../dishes/domain/dish.dart';

/// Ingredient model
class Ingredient {
  final String name;
  final double? amount;
  final String? unit;
  final bool isPantryStaple;

  Ingredient({
    required this.name,
    this.amount,
    this.unit,
    this.isPantryStaple = false,
  });

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      name: map['name'] ?? '',
      amount: (map['amount'] as num?)?.toDouble(),
      unit: map['unit'],
      isPantryStaple: map['isPantryStaple'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
      'isPantryStaple': isPantryStaple,
    };
  }

  String get displayText {
    final buffer = StringBuffer();
    if (amount != null) {
      buffer.write(amount! % 1 == 0 ? amount!.toInt() : amount);
      buffer.write(' ');
    }
    if (unit != null && unit!.isNotEmpty) {
      buffer.write(unit);
      buffer.write(' ');
    }
    buffer.write(name);
    return buffer.toString();
  }
}

/// Recipe rating by a family member
class RecipeRating {
  final String odauyX6H2Z;
  final String memberName;
  final int score; // 1-5
  final bool isKid;
  final DateTime ratedAt;

  RecipeRating({
    required this.odauyX6H2Z,
    required this.memberName,
    required this.score,
    required this.isKid,
    required this.ratedAt,
  });

  factory RecipeRating.fromMap(Map<String, dynamic> map) {
    return RecipeRating(
      odauyX6H2Z: map['odauyX6H2Z'] ?? '',
      memberName: map['memberName'] ?? '',
      score: map['score'] ?? 3,
      isKid: map['isKid'] ?? false,
      ratedAt: (map['ratedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'odauyX6H2Z': odauyX6H2Z,
      'memberName': memberName,
      'score': score,
      'isKid': isKid,
      'ratedAt': Timestamp.fromDate(ratedAt),
    };
  }
}

/// Recipe model
class Recipe {
  final String id;
  final String? dishId; // Link to parent dish (null for legacy recipes)
  final String title;
  final String? variantName; // e.g., "Recette de maman", "Version rapide"
  final String? description;
  final String? imageUrl;
  final String? sourceUrl;
  final String? sourceName;
  final int prepTime; // minutes
  final int cookTime; // minutes
  final int servings;
  final int difficulty; // 1-5
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final List<String> tags;
  final List<String> allergens;
  final List<int> kidCanHelpSteps;
  final List<RecipeRating> ratings;
  final MealType? mealType;
  final DateTime createdAt;
  final String createdBy;
  final int timesCooked;
  final DateTime? lastCookedAt;

  Recipe({
    required this.id,
    this.dishId,
    required this.title,
    this.variantName,
    this.description,
    this.imageUrl,
    this.sourceUrl,
    this.sourceName,
    this.prepTime = 0,
    this.cookTime = 0,
    this.servings = 4,
    this.difficulty = 2,
    this.ingredients = const [],
    this.instructions = const [],
    this.tags = const [],
    this.allergens = const [],
    this.kidCanHelpSteps = const [],
    this.ratings = const [],
    this.mealType,
    required this.createdAt,
    required this.createdBy,
    this.timesCooked = 0,
    this.lastCookedAt,
  });

  /// Display name: variant name if set, otherwise title
  String get displayName => variantName ?? title;

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse mealType
    MealType? mealType;
    if (data['mealType'] != null) {
      mealType = MealType.values.firstWhere(
        (e) => e.name == data['mealType'],
        orElse: () => MealType.plat,
      );
    }

    return Recipe(
      id: doc.id,
      dishId: data['dishId'],
      title: data['title'] ?? '',
      variantName: data['variantName'],
      description: data['description'],
      imageUrl: data['imageUrl'],
      sourceUrl: data['sourceUrl'],
      sourceName: data['sourceName'],
      prepTime: data['prepTime'] ?? 0,
      cookTime: data['cookTime'] ?? 0,
      servings: data['servings'] ?? 4,
      difficulty: data['difficulty'] ?? 2,
      ingredients: (data['ingredients'] as List<dynamic>?)
              ?.map((e) => Ingredient.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      instructions: List<String>.from(data['instructions'] ?? []),
      tags: List<String>.from(data['tags'] ?? []),
      allergens: List<String>.from(data['allergens'] ?? []),
      kidCanHelpSteps: List<int>.from(data['kidCanHelpSteps'] ?? []),
      ratings: (data['ratings'] as List<dynamic>?)
              ?.map((e) => RecipeRating.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      mealType: mealType,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      timesCooked: data['timesCooked'] ?? 0,
      lastCookedAt: (data['lastCookedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'dishId': dishId,
      'title': title,
      'variantName': variantName,
      'description': description,
      'imageUrl': imageUrl,
      'sourceUrl': sourceUrl,
      'sourceName': sourceName,
      'prepTime': prepTime,
      'cookTime': cookTime,
      'servings': servings,
      'difficulty': difficulty,
      'ingredients': ingredients.map((e) => e.toMap()).toList(),
      'instructions': instructions,
      'tags': tags,
      'allergens': allergens,
      'kidCanHelpSteps': kidCanHelpSteps,
      'ratings': ratings.map((e) => e.toMap()).toList(),
      'mealType': mealType?.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'timesCooked': timesCooked,
      'lastCookedAt': lastCookedAt != null ? Timestamp.fromDate(lastCookedAt!) : null,
    };
  }

  /// Total time in minutes
  int get totalTime => prepTime + cookTime;

  /// Is this a quick recipe (< 20 min)?
  bool get isQuick => totalTime <= 20;

  /// Average rating from adults
  double? get adultRating {
    final adultRatings = ratings.where((r) => !r.isKid).toList();
    if (adultRatings.isEmpty) return null;
    return adultRatings.map((r) => r.score).reduce((a, b) => a + b) / adultRatings.length;
  }

  /// Average rating from kids
  double? get kidRating {
    final kidRatings = ratings.where((r) => r.isKid).toList();
    if (kidRatings.isEmpty) return null;
    return kidRatings.map((r) => r.score).reduce((a, b) => a + b) / kidRatings.length;
  }

  /// Is this recipe kid-approved (avg kid rating >= 4)?
  bool get isKidApproved => (kidRating ?? 0) >= 4;

  /// Overall average rating (adults + kids combined)
  double? get averageRating {
    if (ratings.isEmpty) return null;
    return ratings.map((r) => r.score).reduce((a, b) => a + b) / ratings.length;
  }

  Recipe copyWith({
    String? dishId,
    String? title,
    String? variantName,
    String? description,
    String? imageUrl,
    String? sourceUrl,
    String? sourceName,
    int? prepTime,
    int? cookTime,
    int? servings,
    int? difficulty,
    List<Ingredient>? ingredients,
    List<String>? instructions,
    List<String>? tags,
    List<String>? allergens,
    List<int>? kidCanHelpSteps,
    List<RecipeRating>? ratings,
    MealType? mealType,
    int? timesCooked,
    DateTime? lastCookedAt,
  }) {
    return Recipe(
      id: id,
      dishId: dishId ?? this.dishId,
      title: title ?? this.title,
      variantName: variantName ?? this.variantName,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceName: sourceName ?? this.sourceName,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      servings: servings ?? this.servings,
      difficulty: difficulty ?? this.difficulty,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      tags: tags ?? this.tags,
      allergens: allergens ?? this.allergens,
      kidCanHelpSteps: kidCanHelpSteps ?? this.kidCanHelpSteps,
      ratings: ratings ?? this.ratings,
      mealType: mealType ?? this.mealType,
      createdAt: createdAt,
      createdBy: createdBy,
      timesCooked: timesCooked ?? this.timesCooked,
      lastCookedAt: lastCookedAt ?? this.lastCookedAt,
    );
  }
}
