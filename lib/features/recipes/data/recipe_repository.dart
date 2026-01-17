import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dishes/domain/dish.dart';
import '../../family/data/family_repository.dart';
import '../domain/recipe.dart';

/// Auto-filter allergies setting
final autoFilterAllergiesProvider = StateProvider<bool>((ref) => true);

/// Recipe repository provider
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(firestoreProvider));
});

/// Stream of recipes for current family
final familyRecipesProvider = StreamProvider<List<Recipe>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value([]);
  return ref.watch(recipeRepositoryProvider).watchRecipes(familyId);
});

/// Single recipe provider
final recipeProvider = StreamProvider.family<Recipe?, String>((ref, recipeId) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value(null);
  return ref.watch(recipeRepositoryProvider).watchRecipe(familyId, recipeId);
});

/// Search/filter state
class RecipeFilter {
  final String? searchQuery;
  final List<String> tags;
  final bool? isQuick;
  final bool? isKidApproved;
  final List<String> excludeAllergens;
  final MealType? mealType;

  const RecipeFilter({
    this.searchQuery,
    this.tags = const [],
    this.isQuick,
    this.isKidApproved,
    this.excludeAllergens = const [],
    this.mealType,
  });

  RecipeFilter copyWith({
    String? searchQuery,
    List<String>? tags,
    bool? isQuick,
    bool? isKidApproved,
    List<String>? excludeAllergens,
    MealType? mealType,
    bool clearMealType = false,
  }) {
    return RecipeFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      tags: tags ?? this.tags,
      isQuick: isQuick ?? this.isQuick,
      isKidApproved: isKidApproved ?? this.isKidApproved,
      excludeAllergens: excludeAllergens ?? this.excludeAllergens,
      mealType: clearMealType ? null : (mealType ?? this.mealType),
    );
  }
}

final recipeFilterProvider = StateProvider<RecipeFilter>((ref) => const RecipeFilter());

/// Filtered recipes
final filteredRecipesProvider = Provider<List<Recipe>>((ref) {
  final recipesAsync = ref.watch(familyRecipesProvider);
  final filter = ref.watch(recipeFilterProvider);
  final autoFilter = ref.watch(autoFilterAllergiesProvider);
  final familyAllergies = ref.watch(familyAllergiesProvider);
  final filterPicky = ref.watch(filterPickyEaterProvider);
  final pickyAvoid = ref.watch(pickyEaterAvoidProvider);

  return recipesAsync.when(
    data: (recipes) {
      var filtered = recipes;

      // Search query
      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        final query = filter.searchQuery!.toLowerCase();
        filtered = filtered.where((r) {
          return r.title.toLowerCase().contains(query) ||
              r.ingredients.any((i) => i.name.toLowerCase().contains(query));
        }).toList();
      }

      // Tags
      if (filter.tags.isNotEmpty) {
        filtered = filtered.where((r) {
          return filter.tags.every((tag) => r.tags.contains(tag));
        }).toList();
      }

      // Quick filter
      if (filter.isQuick == true) {
        filtered = filtered.where((r) => r.isQuick).toList();
      }

      // Kid approved filter
      if (filter.isKidApproved == true) {
        filtered = filtered.where((r) => r.isKidApproved).toList();
      }

      // MealType filter
      if (filter.mealType != null) {
        filtered = filtered.where((r) => r.mealType == filter.mealType).toList();
      }

      // Exclude allergens (manual filter)
      if (filter.excludeAllergens.isNotEmpty) {
        filtered = filtered.where((r) {
          return !r.allergens.any((a) => filter.excludeAllergens.contains(a));
        }).toList();
      }

      // Auto-filter family allergies
      if (autoFilter && familyAllergies.isNotEmpty) {
        filtered = filtered.where((r) {
          return !r.allergens.any((a) => familyAllergies.contains(a));
        }).toList();
      }

      // Filter picky eater avoided ingredients
      if (filterPicky && pickyAvoid.isNotEmpty) {
        filtered = filtered.where((r) {
          return !r.ingredients.any((i) =>
              pickyAvoid.any((avoid) => i.name.toLowerCase().contains(avoid.toLowerCase())));
        }).toList();
      }

      return filtered;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Recipe repository for Firestore operations
class RecipeRepository {
  final FirebaseFirestore _firestore;

  RecipeRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _recipesRef(String familyId) =>
      _firestore.collection('families').doc(familyId).collection('recipes');

  /// Create a new recipe
  Future<Recipe> createRecipe({
    required String familyId,
    required String title,
    required String createdBy,
    String? description,
    String? imageUrl,
    String? sourceUrl,
    String? sourceName,
    int prepTime = 0,
    int cookTime = 0,
    int servings = 4,
    int difficulty = 2,
    List<Ingredient> ingredients = const [],
    List<String> instructions = const [],
    List<String> tags = const [],
    List<String> allergens = const [],
    List<int> kidCanHelpSteps = const [],
    MealType? mealType,
  }) async {
    final docRef = _recipesRef(familyId).doc();
    final recipe = Recipe(
      id: docRef.id,
      title: title,
      description: description,
      imageUrl: imageUrl,
      sourceUrl: sourceUrl,
      sourceName: sourceName,
      prepTime: prepTime,
      cookTime: cookTime,
      servings: servings,
      difficulty: difficulty,
      ingredients: ingredients,
      instructions: instructions,
      tags: tags,
      allergens: allergens,
      kidCanHelpSteps: kidCanHelpSteps,
      mealType: mealType,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    await docRef.set(recipe.toFirestore());
    return recipe;
  }

  /// Update a recipe
  Future<void> updateRecipe(String familyId, Recipe recipe) async {
    await _recipesRef(familyId).doc(recipe.id).update(recipe.toFirestore());
  }

  /// Delete a recipe
  Future<void> deleteRecipe(String familyId, String recipeId) async {
    await _recipesRef(familyId).doc(recipeId).delete();
  }

  /// Get a single recipe
  Future<Recipe?> getRecipe(String familyId, String recipeId) async {
    final doc = await _recipesRef(familyId).doc(recipeId).get();
    if (!doc.exists) return null;
    return Recipe.fromFirestore(doc);
  }

  /// Watch a single recipe
  Stream<Recipe?> watchRecipe(String familyId, String recipeId) {
    return _recipesRef(familyId).doc(recipeId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Recipe.fromFirestore(doc);
    });
  }

  /// Watch all recipes for a family
  Stream<List<Recipe>> watchRecipes(String familyId) {
    return _recipesRef(familyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();
    });
  }

  /// Add a rating to a recipe
  Future<void> addRating({
    required String familyId,
    required String recipeId,
    required RecipeRating rating,
  }) async {
    final doc = await _recipesRef(familyId).doc(recipeId).get();
    if (!doc.exists) return;

    final recipe = Recipe.fromFirestore(doc);
    final ratings = List<RecipeRating>.from(recipe.ratings);

    // Remove existing rating from same user
    ratings.removeWhere((r) => r.odauyX6H2Z == rating.odauyX6H2Z);
    ratings.add(rating);

    await _recipesRef(familyId).doc(recipeId).update({
      'ratings': ratings.map((r) => r.toMap()).toList(),
    });
  }

  /// Mark recipe as cooked
  Future<void> markAsCooked(String familyId, String recipeId) async {
    await _recipesRef(familyId).doc(recipeId).update({
      'timesCooked': FieldValue.increment(1),
      'lastCookedAt': Timestamp.now(),
    });
  }
}
