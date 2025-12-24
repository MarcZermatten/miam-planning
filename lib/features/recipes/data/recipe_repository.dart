import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  const RecipeFilter({
    this.searchQuery,
    this.tags = const [],
    this.isQuick,
    this.isKidApproved,
    this.excludeAllergens = const [],
  });

  RecipeFilter copyWith({
    String? searchQuery,
    List<String>? tags,
    bool? isQuick,
    bool? isKidApproved,
    List<String>? excludeAllergens,
  }) {
    return RecipeFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      tags: tags ?? this.tags,
      isQuick: isQuick ?? this.isQuick,
      isKidApproved: isKidApproved ?? this.isKidApproved,
      excludeAllergens: excludeAllergens ?? this.excludeAllergens,
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

/// Leftover suggestions - recipes using ingredients from recently cooked meals
final leftoverSuggestionsProvider = Provider<List<Recipe>>((ref) {
  final recipesAsync = ref.watch(familyRecipesProvider);

  return recipesAsync.when(
    data: (recipes) {
      // Find recently cooked recipes (last 3 days)
      final now = DateTime.now();
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      final recentlyCooked = recipes
          .where((r) => r.lastCookedAt != null && r.lastCookedAt!.isAfter(threeDaysAgo))
          .toList();

      if (recentlyCooked.isEmpty) return [];

      // Extract main ingredients from recently cooked recipes
      final recentIngredients = <String>{};
      for (final recipe in recentlyCooked) {
        for (final ing in recipe.ingredients) {
          if (!ing.isPantryStaple) {
            recentIngredients.add(ing.name.toLowerCase());
          }
        }
      }

      if (recentIngredients.isEmpty) return [];

      // Find recipes that use some of these ingredients (but weren't just cooked)
      final recentIds = recentlyCooked.map((r) => r.id).toSet();
      final suggestions = recipes
          .where((r) => !recentIds.contains(r.id))
          .where((r) {
            final recipeIngredients = r.ingredients
                .where((i) => !i.isPantryStaple)
                .map((i) => i.name.toLowerCase())
                .toSet();
            // At least 1 ingredient in common
            return recipeIngredients.any((i) =>
                recentIngredients.any((recent) => i.contains(recent) || recent.contains(i)));
          })
          .toList();

      // Sort by match count
      suggestions.sort((a, b) {
        int matchA = a.ingredients
            .where((i) => recentIngredients.any((r) =>
                i.name.toLowerCase().contains(r) || r.contains(i.name.toLowerCase())))
            .length;
        int matchB = b.ingredients
            .where((i) => recentIngredients.any((r) =>
                i.name.toLowerCase().contains(r) || r.contains(i.name.toLowerCase())))
            .length;
        return matchB.compareTo(matchA);
      });

      return suggestions.take(5).toList();
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

  /// Search recipes by ingredients
  Future<List<Recipe>> searchByIngredients({
    required String familyId,
    required List<String> availableIngredients,
    bool ignorePantryStaples = true,
  }) async {
    final snapshot = await _recipesRef(familyId).get();
    final recipes = snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();

    final available = availableIngredients.map((i) => i.toLowerCase()).toSet();

    return recipes.where((recipe) {
      final needed = recipe.ingredients
          .where((i) => !ignorePantryStaples || !i.isPantryStaple)
          .map((i) => i.name.toLowerCase())
          .toSet();

      // Check if we have at least 70% of ingredients
      final matched = needed.where((i) => available.contains(i)).length;
      return matched >= needed.length * 0.7;
    }).toList();
  }
}
