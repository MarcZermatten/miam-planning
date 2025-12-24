import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../family/data/family_repository.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/domain/recipe.dart';
import '../domain/pantry_item.dart';

/// Pantry repository provider
final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return PantryRepository(ref.watch(firestoreProvider));
});

/// Stream des ingredients du garde-manger
final pantryItemsProvider = StreamProvider<List<PantryItem>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value([]);
  return ref.watch(pantryRepositoryProvider).watchPantryItems(familyId);
});

/// Ingredients de base (staples) seulement
final pantryStaplesProvider = Provider<List<PantryItem>>((ref) {
  final items = ref.watch(pantryItemsProvider);
  return items.when(
    data: (list) => list.where((i) => i.isStaple).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Noms des ingredients disponibles (pour comparaison)
final availableIngredientNamesProvider = Provider<Set<String>>((ref) {
  final items = ref.watch(pantryItemsProvider);
  return items.when(
    data: (list) => list.map((i) => i.normalizedName).toSet(),
    loading: () => {},
    error: (_, __) => {},
  );
});

/// Recettes realisables avec les ingredients disponibles
final suggestedRecipesProvider = Provider<List<RecipeSuggestion>>((ref) {
  final recipesAsync = ref.watch(familyRecipesProvider);
  final availableNames = ref.watch(availableIngredientNamesProvider);

  if (availableNames.isEmpty) return [];

  return recipesAsync.when(
    data: (recipes) {
      final suggestions = <RecipeSuggestion>[];

      for (final recipe in recipes) {
        final needed = recipe.ingredients
            .where((i) => !i.isPantryStaple)
            .map((i) => i.name.toLowerCase().trim())
            .toList();

        if (needed.isEmpty) continue;

        final matched = needed.where((name) {
          return availableNames.any((available) =>
              available.contains(name) || name.contains(available));
        }).length;

        final matchPercent = matched / needed.length;

        // Au moins 50% des ingredients disponibles
        if (matchPercent >= 0.5) {
          suggestions.add(RecipeSuggestion(
            recipe: recipe,
            matchedIngredients: matched,
            totalIngredients: needed.length,
            matchPercent: matchPercent,
            missingIngredients: needed
                .where((name) => !availableNames.any((available) =>
                    available.contains(name) || name.contains(available)))
                .toList(),
          ));
        }
      }

      // Trier par pourcentage de match decroissant
      suggestions.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));

      return suggestions;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Suggestion de recette avec score de correspondance
class RecipeSuggestion {
  final Recipe recipe;
  final int matchedIngredients;
  final int totalIngredients;
  final double matchPercent;
  final List<String> missingIngredients;

  const RecipeSuggestion({
    required this.recipe,
    required this.matchedIngredients,
    required this.totalIngredients,
    required this.matchPercent,
    required this.missingIngredients,
  });

  String get matchLabel => '${(matchPercent * 100).round()}%';
}

/// Pantry repository for Firestore operations
class PantryRepository {
  final FirebaseFirestore _firestore;

  PantryRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _pantryRef(String familyId) =>
      _firestore.collection('families').doc(familyId).collection('pantry');

  /// Watch all pantry items
  Stream<List<PantryItem>> watchPantryItems(String familyId) {
    return _pantryRef(familyId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PantryItem.fromFirestore(doc)).toList();
    });
  }

  /// Add an item to pantry
  Future<PantryItem> addItem({
    required String familyId,
    required String name,
    String? category,
    double? quantity,
    String? unit,
    bool isStaple = false,
    DateTime? expiresAt,
  }) async {
    final docRef = _pantryRef(familyId).doc();
    final item = PantryItem(
      id: docRef.id,
      name: name,
      category: category,
      quantity: quantity,
      unit: unit,
      isStaple: isStaple,
      expiresAt: expiresAt,
      addedAt: DateTime.now(),
    );

    await docRef.set(item.toFirestore());
    return item;
  }

  /// Add multiple items quickly (from text input)
  Future<List<PantryItem>> addItemsFromText({
    required String familyId,
    required String text,
  }) async {
    final lines = text.split(RegExp(r'[,\n]'));
    final items = <PantryItem>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final item = await addItem(
        familyId: familyId,
        name: trimmed,
      );
      items.add(item);
    }

    return items;
  }

  /// Update an item
  Future<void> updateItem(String familyId, PantryItem item) async {
    await _pantryRef(familyId).doc(item.id).update(item.toFirestore());
  }

  /// Remove an item
  Future<void> removeItem(String familyId, String itemId) async {
    await _pantryRef(familyId).doc(itemId).delete();
  }

  /// Clear all items (except staples optionally)
  Future<void> clearPantry(String familyId, {bool keepStaples = true}) async {
    final snapshot = await _pantryRef(familyId).get();
    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      if (keepStaples) {
        final data = doc.data();
        if (data['isStaple'] == true) continue;
      }
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Check if ingredient is available in pantry
  Future<bool> hasIngredient(String familyId, String ingredientName) async {
    final normalized = ingredientName.toLowerCase().trim();
    final snapshot = await _pantryRef(familyId).get();

    return snapshot.docs.any((doc) {
      final name = (doc.data()['name'] as String?)?.toLowerCase().trim() ?? '';
      return name.contains(normalized) || normalized.contains(name);
    });
  }

  /// Get list of available ingredient names
  Future<Set<String>> getAvailableIngredientNames(String familyId) async {
    final snapshot = await _pantryRef(familyId).get();
    return snapshot.docs
        .map((doc) => (doc.data()['name'] as String?)?.toLowerCase().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
  }
}
