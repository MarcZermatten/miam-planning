import 'package:cloud_firestore/cloud_firestore.dart';

/// Ingredient category for grouping
enum IngredientCategory {
  produce,      // Fruits & legumes
  meat,         // Viandes & poissons
  dairy,        // Produits laitiers
  bakery,       // Boulangerie
  frozen,       // Surgeles
  pantry,       // Epicerie
  beverages,    // Boissons
  other,        // Autres
}

extension IngredientCategoryExt on IngredientCategory {
  String get label {
    switch (this) {
      case IngredientCategory.produce:
        return 'Fruits & Legumes';
      case IngredientCategory.meat:
        return 'Viandes & Poissons';
      case IngredientCategory.dairy:
        return 'Produits laitiers';
      case IngredientCategory.bakery:
        return 'Boulangerie';
      case IngredientCategory.frozen:
        return 'Surgeles';
      case IngredientCategory.pantry:
        return 'Epicerie';
      case IngredientCategory.beverages:
        return 'Boissons';
      case IngredientCategory.other:
        return 'Autres';
    }
  }

  int get sortOrder {
    switch (this) {
      case IngredientCategory.produce:
        return 0;
      case IngredientCategory.bakery:
        return 1;
      case IngredientCategory.meat:
        return 2;
      case IngredientCategory.dairy:
        return 3;
      case IngredientCategory.frozen:
        return 4;
      case IngredientCategory.pantry:
        return 5;
      case IngredientCategory.beverages:
        return 6;
      case IngredientCategory.other:
        return 7;
    }
  }
}

/// A single shopping list item
class ShoppingItem {
  final String id;
  final String name;
  final double? amount;
  final String? unit;
  final IngredientCategory category;
  final bool isChecked;
  final List<String> recipeIds;
  final bool isManual; // Added manually, not from recipes

  ShoppingItem({
    required this.id,
    required this.name,
    this.amount,
    this.unit,
    this.category = IngredientCategory.other,
    this.isChecked = false,
    this.recipeIds = const [],
    this.isManual = false,
  });

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    return ShoppingItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      amount: (map['amount'] as num?)?.toDouble(),
      unit: map['unit'],
      category: IngredientCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => IngredientCategory.other,
      ),
      isChecked: map['isChecked'] ?? false,
      recipeIds: List<String>.from(map['recipeIds'] ?? []),
      isManual: map['isManual'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'unit': unit,
      'category': category.name,
      'isChecked': isChecked,
      'recipeIds': recipeIds,
      'isManual': isManual,
    };
  }

  ShoppingItem copyWith({
    String? name,
    double? amount,
    String? unit,
    IngredientCategory? category,
    bool? isChecked,
    List<String>? recipeIds,
    bool? isManual,
  }) {
    return ShoppingItem(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      isChecked: isChecked ?? this.isChecked,
      recipeIds: recipeIds ?? this.recipeIds,
      isManual: isManual ?? this.isManual,
    );
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

  /// URL to search this item on Migros
  String get migrosSearchUrl {
    final query = Uri.encodeComponent(name);
    return 'https://www.migros.ch/fr/search?query=$query';
  }
}

/// Shopping list for a week
class ShoppingList {
  final String id;
  final String weekId;
  final List<ShoppingItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShoppingList({
    required this.id,
    required this.weekId,
    List<ShoppingItem>? items,
    required this.createdAt,
    DateTime? updatedAt,
  })  : items = items ?? [],
        updatedAt = updatedAt ?? createdAt;

  factory ShoppingList.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShoppingList(
      id: doc.id,
      weekId: data['weekId'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((e) => ShoppingItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'weekId': weekId,
      'items': items.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Group items by category
  Map<IngredientCategory, List<ShoppingItem>> get groupedItems {
    final grouped = <IngredientCategory, List<ShoppingItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.sortOrder.compareTo(b.key.sortOrder)),
    );
  }

  /// Count of unchecked items
  int get remainingCount => items.where((i) => !i.isChecked).length;

  /// Count of checked items
  int get checkedCount => items.where((i) => i.isChecked).length;

  /// Export as plain text
  String toPlainText() {
    final buffer = StringBuffer();
    buffer.writeln('Liste de courses - MiamPlanning');
    buffer.writeln('');

    for (final entry in groupedItems.entries) {
      buffer.writeln('--- ${entry.key.label} ---');
      for (final item in entry.value) {
        final checkbox = item.isChecked ? '[x]' : '[ ]';
        buffer.writeln('$checkbox ${item.displayText}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  ShoppingList copyWith({
    List<ShoppingItem>? items,
  }) {
    return ShoppingList(
      id: id,
      weekId: weekId,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Category detection keywords
class CategoryDetector {
  static final Map<IngredientCategory, List<String>> _keywords = {
    IngredientCategory.produce: [
      'tomate', 'carotte', 'oignon', 'ail', 'pomme', 'banane', 'orange',
      'citron', 'salade', 'laitue', 'courgette', 'aubergine', 'poivron',
      'champignon', 'pomme de terre', 'patate', 'haricot', 'petit pois',
      'brocoli', 'chou', 'epinard', 'persil', 'basilic', 'ciboulette',
      'concombre', 'avocat', 'fraise', 'framboise', 'myrtille', 'raisin',
      'poire', 'peche', 'abricot', 'cerise', 'melon', 'pasteque', 'ananas',
      'mangue', 'kiwi', 'legume', 'fruit', 'herbe', 'celeri', 'poireau',
    ],
    IngredientCategory.meat: [
      'poulet', 'boeuf', 'porc', 'veau', 'agneau', 'dinde', 'canard',
      'saucisse', 'jambon', 'bacon', 'lard', 'viande', 'steak', 'escalope',
      'filet', 'cuisse', 'aile', 'saumon', 'thon', 'cabillaud', 'crevette',
      'moule', 'poisson', 'truite', 'sardine', 'anchois', 'fruits de mer',
    ],
    IngredientCategory.dairy: [
      'lait', 'fromage', 'beurre', 'creme', 'yaourt', 'yogourt', 'oeuf',
      'mozzarella', 'parmesan', 'gruyere', 'emmental', 'raclette', 'feta',
      'mascarpone', 'ricotta', 'creme fraiche', 'lait de coco',
    ],
    IngredientCategory.bakery: [
      'pain', 'baguette', 'croissant', 'brioche', 'pain de mie', 'toast',
      'farine', 'levure', 'pate', 'pizza', 'tarte', 'gateau',
    ],
    IngredientCategory.frozen: [
      'glace', 'surgele', 'congele', 'frozen',
    ],
    IngredientCategory.pantry: [
      'riz', 'pate', 'spaghetti', 'penne', 'macaroni', 'nouille',
      'huile', 'vinaigre', 'sauce', 'ketchup', 'mayonnaise', 'moutarde',
      'sel', 'poivre', 'epice', 'sucre', 'miel', 'confiture',
      'conserve', 'boite', 'tomate pelees', 'concentre', 'bouillon',
      'chocolat', 'cacao', 'cafe', 'the', 'cereale', 'muesli',
      'noix', 'amande', 'noisette', 'olive', 'cornichon',
    ],
    IngredientCategory.beverages: [
      'eau', 'jus', 'soda', 'coca', 'limonade', 'sirop', 'vin', 'biere',
    ],
  };

  static IngredientCategory detect(String ingredientName) {
    final name = ingredientName.toLowerCase();

    for (final entry in _keywords.entries) {
      for (final keyword in entry.value) {
        if (name.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return IngredientCategory.other;
  }
}
