import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../family/data/family_repository.dart';
import '../domain/dish.dart';

/// Repository for dish operations
class DishRepository {
  final FirebaseFirestore _firestore;

  DishRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _dishesCollection(String familyId) {
    return _firestore.collection('families').doc(familyId).collection('dishes');
  }

  /// Watch all dishes for a family
  Stream<List<Dish>> watchDishes(String familyId) {
    return _dishesCollection(familyId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Dish.fromFirestore).toList());
  }

  /// Watch frozen dishes only (for freezer module)
  /// Note: Using single where clause + client-side filter to avoid composite index requirement
  Stream<List<Dish>> watchFrozenDishes(String familyId) {
    return _dishesCollection(familyId)
        .where('isFrozen', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(Dish.fromFirestore)
            .where((dish) => dish.frozenPortions > 0)
            .toList());
  }

  /// Watch dishes by category
  Stream<List<Dish>> watchDishesByCategory(String familyId, DishCategory category) {
    return _dishesCollection(familyId)
        .where('category', isEqualTo: category.name)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Dish.fromFirestore).toList());
  }

  /// Get a single dish
  Future<Dish?> getDish(String familyId, String dishId) async {
    final doc = await _dishesCollection(familyId).doc(dishId).get();
    if (!doc.exists) return null;
    return Dish.fromFirestore(doc);
  }

  /// Create a new dish
  Future<Dish> createDish({
    required String familyId,
    required String name,
    required String createdBy,
    String? imageUrl,
    List<DishCategory> categories = const [DishCategory.complete],
    MealType? mealType,
    List<String> tags = const [],
    bool isFrozen = false,
    int frozenPortions = 0,
  }) async {
    final docRef = _dishesCollection(familyId).doc();
    final dish = Dish(
      id: docRef.id,
      name: name,
      imageUrl: imageUrl,
      categories: categories,
      mealType: mealType,
      tags: tags,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      isFrozen: isFrozen,
      frozenPortions: frozenPortions,
      frozenAt: isFrozen ? DateTime.now() : null,
    );

    await docRef.set(dish.toFirestore());
    return dish;
  }

  /// Watch dishes by meal type
  Stream<List<Dish>> watchDishesByMealType(String familyId, MealType mealType) {
    return _dishesCollection(familyId)
        .where('mealType', isEqualTo: mealType.name)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Dish.fromFirestore).toList());
  }

  /// Update a dish
  Future<void> updateDish(String familyId, Dish dish) async {
    await _dishesCollection(familyId).doc(dish.id).update(dish.toFirestore());
  }

  /// Delete a dish
  Future<void> deleteDish(String familyId, String dishId) async {
    await _dishesCollection(familyId).doc(dishId).delete();
  }

  /// Add portions to freezer
  Future<void> addToFreezer({
    required String familyId,
    required String dishId,
    required int portions,
  }) async {
    final dish = await getDish(familyId, dishId);
    if (dish == null) return;

    final updated = dish.addFrozenPortions(portions);
    await updateDish(familyId, updated);
  }

  /// Use portions from freezer
  Future<void> useFromFreezer({
    required String familyId,
    required String dishId,
    required int portions,
  }) async {
    final dish = await getDish(familyId, dishId);
    if (dish == null) return;

    final updated = dish.useFrozenPortions(portions);
    await updateDish(familyId, updated);
  }

  /// Link a recipe to a dish
  Future<void> linkRecipe({
    required String familyId,
    required String dishId,
    required String recipeId,
  }) async {
    final dish = await getDish(familyId, dishId);
    if (dish == null) return;

    final updated = dish.addRecipe(recipeId);
    await updateDish(familyId, updated);
  }

  /// Unlink a recipe from a dish
  Future<void> unlinkRecipe({
    required String familyId,
    required String dishId,
    required String recipeId,
  }) async {
    final dish = await getDish(familyId, dishId);
    if (dish == null) return;

    final updated = dish.removeRecipe(recipeId);
    await updateDish(familyId, updated);
  }

  /// Update dish image
  Future<void> updateImage({
    required String familyId,
    required String dishId,
    required String? imageUrl,
  }) async {
    await _dishesCollection(familyId).doc(dishId).update({
      'imageUrl': imageUrl,
    });
  }

  /// Search dishes by name
  Future<List<Dish>> searchDishes(String familyId, String query) async {
    final queryLower = query.toLowerCase();
    final snapshot = await _dishesCollection(familyId).get();

    return snapshot.docs
        .map(Dish.fromFirestore)
        .where((dish) => dish.name.toLowerCase().contains(queryLower))
        .toList();
  }
}

/// Provider for DishRepository
final dishRepositoryProvider = Provider<DishRepository>((ref) {
  return DishRepository();
});

/// Provider for all dishes in the current family
final familyDishesProvider = StreamProvider<List<Dish>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value([]);
  return ref.watch(dishRepositoryProvider).watchDishes(familyId);
});

/// Provider for frozen dishes only
final frozenDishesProvider = StreamProvider<List<Dish>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value([]);
  return ref.watch(dishRepositoryProvider).watchFrozenDishes(familyId);
});

/// Provider for dishes by category
final dishesByCategoryProvider = StreamProvider.family<List<Dish>, DishCategory>((ref, category) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value([]);
  return ref.watch(dishRepositoryProvider).watchDishesByCategory(familyId, category);
});

/// Provider for dishes by meal type
final dishesByMealTypeProvider = StreamProvider.family<List<Dish>, MealType>((ref, mealType) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value([]);
  return ref.watch(dishRepositoryProvider).watchDishesByMealType(familyId, mealType);
});
