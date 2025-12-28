import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../family/data/family_repository.dart';
import '../domain/dish.dart';
import '../domain/quick_dish.dart';

final quickDishRepositoryProvider = Provider<QuickDishRepository>((ref) {
  return QuickDishRepository(FirebaseFirestore.instance);
});

/// Provider for family's quick dishes, sorted by usage
final familyQuickDishesProvider = StreamProvider<List<QuickDish>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value([]);

  return ref.watch(quickDishRepositoryProvider).watchQuickDishes(familyId);
});

class QuickDishRepository {
  final FirebaseFirestore _firestore;

  QuickDishRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _quickDishesRef(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('quickDishes');
  }

  /// Watch all quick dishes for a family, sorted by usage count
  Stream<List<QuickDish>> watchQuickDishes(String familyId) {
    return _quickDishesRef(familyId)
        .orderBy('usageCount', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => QuickDish.fromFirestore(doc)).toList());
  }

  /// Create a new quick dish
  Future<QuickDish> createQuickDish({
    required String familyId,
    required String name,
    List<DishCategory> categories = const [],
  }) async {
    final docRef = _quickDishesRef(familyId).doc();
    final quickDish = QuickDish(
      id: docRef.id,
      name: name,
      categories: categories,
      createdAt: DateTime.now(),
      usageCount: 1, // Start with 1 since we're using it
    );

    await docRef.set(quickDish.toFirestore());
    return quickDish;
  }

  /// Increment usage count for a quick dish
  Future<void> incrementUsage(String familyId, String quickDishId) async {
    await _quickDishesRef(familyId).doc(quickDishId).update({
      'usageCount': FieldValue.increment(1),
    });
  }

  /// Delete a quick dish
  Future<void> deleteQuickDish(String familyId, String quickDishId) async {
    await _quickDishesRef(familyId).doc(quickDishId).delete();
  }

  /// Update a quick dish
  Future<void> updateQuickDish(String familyId, QuickDish quickDish) async {
    await _quickDishesRef(familyId)
        .doc(quickDish.id)
        .update(quickDish.toFirestore());
  }
}
