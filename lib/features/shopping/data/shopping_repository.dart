import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../family/data/family_repository.dart';
import '../domain/shopping_item.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepository(FirebaseFirestore.instance);
});

/// Stream of current shopping list items
final shoppingItemsProvider = StreamProvider<List<ShoppingItem>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value([]);
  return ref.watch(shoppingRepositoryProvider).watchShoppingItems(familyId);
});

/// Stream of item history for suggestions (unique item names)
final shoppingHistoryProvider = StreamProvider<List<String>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value([]);
  return ref.watch(shoppingRepositoryProvider).watchItemHistory(familyId);
});

class ShoppingRepository {
  final FirebaseFirestore _firestore;

  ShoppingRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _shoppingCollection(String familyId) {
    return _firestore.collection('families').doc(familyId).collection('shopping');
  }

  CollectionReference<Map<String, dynamic>> _historyCollection(String familyId) {
    return _firestore.collection('families').doc(familyId).collection('shopping_history');
  }

  /// Watch current shopping list
  Stream<List<ShoppingItem>> watchShoppingItems(String familyId) {
    return _shoppingCollection(familyId)
        .orderBy('isChecked')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ShoppingItem.fromFirestore(doc)).toList());
  }

  /// Watch item history for autocomplete suggestions
  Stream<List<String>> watchItemHistory(String familyId) {
    return _historyCollection(familyId)
        .orderBy('useCount', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc['name'] as String).toList());
  }

  /// Add item to shopping list
  Future<void> addItem({
    required String familyId,
    required String name,
    ShoppingCategory? category,
    double? quantity,
    String? unit,
    String? addedBy,
  }) async {
    final detectedCategory = category ?? ShoppingItem.detectCategory(name);

    await _shoppingCollection(familyId).add({
      'name': name,
      'category': detectedCategory.name,
      'quantity': quantity,
      'unit': unit,
      'isChecked': false,
      'addedAt': FieldValue.serverTimestamp(),
      'addedBy': addedBy,
    });

    // Update history for suggestions
    await _updateHistory(familyId, name, detectedCategory);
  }

  /// Add multiple items at once (batch add)
  Future<void> addItems({
    required String familyId,
    required List<String> names,
    String? addedBy,
  }) async {
    final batch = _firestore.batch();

    for (final name in names) {
      if (name.trim().isEmpty) continue;

      final category = ShoppingItem.detectCategory(name);
      final docRef = _shoppingCollection(familyId).doc();

      batch.set(docRef, {
        'name': name.trim(),
        'category': category.name,
        'quantity': null,
        'unit': null,
        'isChecked': false,
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': addedBy,
      });
    }

    await batch.commit();

    // Update history for all items
    for (final name in names) {
      if (name.trim().isEmpty) continue;
      await _updateHistory(familyId, name.trim(), ShoppingItem.detectCategory(name));
    }
  }

  /// Update item history for suggestions
  Future<void> _updateHistory(String familyId, String name, ShoppingCategory category) async {
    final normalizedName = name.toLowerCase().trim();
    final historyRef = _historyCollection(familyId).doc(normalizedName);

    await historyRef.set({
      'name': name.trim(),
      'category': category.name,
      'useCount': FieldValue.increment(1),
      'lastUsed': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Toggle item checked status
  Future<void> toggleChecked(String familyId, String itemId, bool isChecked) async {
    await _shoppingCollection(familyId).doc(itemId).update({
      'isChecked': isChecked,
    });
  }

  /// Update item quantity
  Future<void> updateQuantity(String familyId, String itemId, double? quantity, String? unit) async {
    await _shoppingCollection(familyId).doc(itemId).update({
      'quantity': quantity,
      'unit': unit,
    });
  }

  /// Delete item
  Future<void> deleteItem(String familyId, String itemId) async {
    await _shoppingCollection(familyId).doc(itemId).delete();
  }

  /// Clear checked items
  Future<void> clearChecked(String familyId) async {
    final snapshot = await _shoppingCollection(familyId)
        .where('isChecked', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Clear all items
  Future<void> clearAll(String familyId) async {
    final snapshot = await _shoppingCollection(familyId).get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Get suggestions based on query and history
  Future<List<String>> getSuggestions(String familyId, String query) async {
    if (query.isEmpty) {
      // Return top used items
      final snapshot = await _historyCollection(familyId)
          .orderBy('useCount', descending: true)
          .limit(10)
          .get();
      return snapshot.docs.map((doc) => doc['name'] as String).toList();
    }

    // Search in history
    final normalizedQuery = query.toLowerCase();
    final snapshot = await _historyCollection(familyId)
        .orderBy('useCount', descending: true)
        .limit(50)
        .get();

    return snapshot.docs
        .where((doc) => (doc['name'] as String).toLowerCase().contains(normalizedQuery))
        .take(10)
        .map((doc) => doc['name'] as String)
        .toList();
  }
}
