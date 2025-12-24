import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../family/data/family_repository.dart';
import '../../meal_plan/data/meal_plan_repository.dart';
import '../../meal_plan/domain/meal_plan.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../recipes/data/recipe_repository.dart';
import '../domain/shopping_list.dart';

/// Shopping list repository provider
final shoppingListRepositoryProvider = Provider<ShoppingListRepository>((ref) {
  return ShoppingListRepository(
    ref.watch(firestoreProvider),
    ref.watch(recipeRepositoryProvider),
    ref.watch(mealPlanRepositoryProvider),
    ref.watch(pantryRepositoryProvider),
  );
});

/// Current week's shopping list
final currentShoppingListProvider = StreamProvider<ShoppingList?>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  final weekStart = ref.watch(selectedWeekStartProvider);

  if (familyId == null) return Stream.value(null);

  final weekId = MealPlan.getWeekId(weekStart);
  return ref.watch(shoppingListRepositoryProvider).watchShoppingList(familyId, weekId);
});

/// Shopping list repository for Firestore operations
class ShoppingListRepository {
  final FirebaseFirestore _firestore;
  final RecipeRepository _recipeRepo;
  final MealPlanRepository _mealPlanRepo;
  final PantryRepository _pantryRepo;

  ShoppingListRepository(this._firestore, this._recipeRepo, this._mealPlanRepo, this._pantryRepo);

  CollectionReference<Map<String, dynamic>> _listsRef(String familyId) =>
      _firestore.collection('families').doc(familyId).collection('shoppingLists');

  /// Watch shopping list for a week
  Stream<ShoppingList?> watchShoppingList(String familyId, String weekId) {
    return _listsRef(familyId)
        .where('weekId', isEqualTo: weekId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return ShoppingList.fromFirestore(snapshot.docs.first);
    });
  }

  /// Get or create shopping list for a week
  Future<ShoppingList> getOrCreateShoppingList(String familyId, String weekId) async {
    final query = await _listsRef(familyId)
        .where('weekId', isEqualTo: weekId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return ShoppingList.fromFirestore(query.docs.first);
    }

    final docRef = _listsRef(familyId).doc();
    final list = ShoppingList(
      id: docRef.id,
      weekId: weekId,
      createdAt: DateTime.now(),
    );

    await docRef.set(list.toFirestore());
    return list;
  }

  /// Generate shopping list from meal plan
  Future<ShoppingList> generateFromMealPlan({
    required String familyId,
    required DateTime weekStart,
    bool includePantryStaples = false,
  }) async {
    final weekId = MealPlan.getWeekId(weekStart);
    final weekEnd = weekStart.add(const Duration(days: 6));

    // Get recipe IDs from meal plan
    final recipeIds = await _mealPlanRepo.getRecipeIdsForDateRange(
      familyId: familyId,
      startDate: weekStart,
      endDate: weekEnd,
    );

    // Get available ingredients from pantry
    final pantryIngredients = await _pantryRepo.getAvailableIngredientNames(familyId);

    // Aggregate ingredients from all recipes
    final ingredientMap = <String, _AggregatedIngredient>{};

    for (final recipeId in recipeIds) {
      final recipe = await _recipeRepo.getRecipe(familyId, recipeId);
      if (recipe == null) continue;

      for (final ingredient in recipe.ingredients) {
        // Skip pantry staples if not included
        if (!includePantryStaples && ingredient.isPantryStaple) continue;

        final key = _normalizeIngredientName(ingredient.name);

        // Skip if ingredient is available in pantry
        if (_isInPantry(key, pantryIngredients)) continue;

        if (ingredientMap.containsKey(key)) {
          final existing = ingredientMap[key]!;
          // Try to aggregate amounts if units match
          if (existing.unit == ingredient.unit && existing.amount != null && ingredient.amount != null) {
            existing.amount = existing.amount! + ingredient.amount!;
          }
          existing.recipeIds.add(recipeId);
        } else {
          ingredientMap[key] = _AggregatedIngredient(
            name: ingredient.name,
            amount: ingredient.amount,
            unit: ingredient.unit,
            recipeIds: [recipeId],
          );
        }
      }
    }

    // Get existing list to preserve manual items and checked status
    final existingList = await getOrCreateShoppingList(familyId, weekId);
    final existingItems = {for (final item in existingList.items) item.name.toLowerCase(): item};

    // Create shopping items
    final items = <ShoppingItem>[];
    var itemIndex = 0;

    for (final agg in ingredientMap.values) {
      final existingItem = existingItems[agg.name.toLowerCase()];

      items.add(ShoppingItem(
        id: existingItem?.id ?? 'item_$itemIndex',
        name: agg.name,
        amount: agg.amount,
        unit: agg.unit,
        category: CategoryDetector.detect(agg.name),
        isChecked: existingItem?.isChecked ?? false,
        recipeIds: agg.recipeIds.toSet().toList(),
        isManual: false,
      ));
      itemIndex++;
    }

    // Preserve manual items
    for (final item in existingList.items) {
      if (item.isManual) {
        items.add(item);
      }
    }

    // Sort by category
    items.sort((a, b) => a.category.sortOrder.compareTo(b.category.sortOrder));

    // Update in Firestore
    final updatedList = existingList.copyWith(items: items);
    await _listsRef(familyId).doc(existingList.id).update(updatedList.toFirestore());

    return updatedList;
  }

  /// Check if ingredient name matches something in pantry
  bool _isInPantry(String ingredientName, Set<String> pantryIngredients) {
    final normalized = ingredientName.toLowerCase().trim();
    return pantryIngredients.any((pantryItem) =>
        pantryItem.contains(normalized) || normalized.contains(pantryItem));
  }

  /// Add a manual item
  Future<void> addManualItem({
    required String familyId,
    required String weekId,
    required String name,
    double? amount,
    String? unit,
  }) async {
    final list = await getOrCreateShoppingList(familyId, weekId);
    final newItem = ShoppingItem(
      id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      amount: amount,
      unit: unit,
      category: CategoryDetector.detect(name),
      isManual: true,
    );

    final items = [...list.items, newItem];
    await _listsRef(familyId).doc(list.id).update({
      'items': items.map((e) => e.toMap()).toList(),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Toggle item checked status
  Future<void> toggleItem(String familyId, String listId, String itemId) async {
    final doc = await _listsRef(familyId).doc(listId).get();
    if (!doc.exists) return;

    final list = ShoppingList.fromFirestore(doc);
    final items = list.items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(isChecked: !item.isChecked);
      }
      return item;
    }).toList();

    await _listsRef(familyId).doc(listId).update({
      'items': items.map((e) => e.toMap()).toList(),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Remove an item
  Future<void> removeItem(String familyId, String listId, String itemId) async {
    final doc = await _listsRef(familyId).doc(listId).get();
    if (!doc.exists) return;

    final list = ShoppingList.fromFirestore(doc);
    final items = list.items.where((item) => item.id != itemId).toList();

    await _listsRef(familyId).doc(listId).update({
      'items': items.map((e) => e.toMap()).toList(),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Clear all checked items
  Future<void> clearCheckedItems(String familyId, String listId) async {
    final doc = await _listsRef(familyId).doc(listId).get();
    if (!doc.exists) return;

    final list = ShoppingList.fromFirestore(doc);
    final items = list.items.where((item) => !item.isChecked).toList();

    await _listsRef(familyId).doc(listId).update({
      'items': items.map((e) => e.toMap()).toList(),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Clear entire list
  Future<void> clearList(String familyId, String listId) async {
    await _listsRef(familyId).doc(listId).update({
      'items': [],
      'updatedAt': Timestamp.now(),
    });
  }

  String _normalizeIngredientName(String name) {
    return name.toLowerCase().trim();
  }
}

class _AggregatedIngredient {
  String name;
  double? amount;
  String? unit;
  List<String> recipeIds;

  _AggregatedIngredient({
    required this.name,
    this.amount,
    this.unit,
    required this.recipeIds,
  });
}
