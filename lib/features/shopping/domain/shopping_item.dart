import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories for shopping items - auto-detected based on item name
enum ShoppingCategory {
  fruitsLegumes,
  viandes,
  poissons,
  produitsFrais,
  epicerie,
  boissons,
  surgeles,
  boulangerie,
  hygiene,
  autre,
}

extension ShoppingCategoryExtension on ShoppingCategory {
  String get label {
    switch (this) {
      case ShoppingCategory.fruitsLegumes:
        return 'Fruits & Legumes';
      case ShoppingCategory.viandes:
        return 'Viandes';
      case ShoppingCategory.poissons:
        return 'Poissons';
      case ShoppingCategory.produitsFrais:
        return 'Produits frais';
      case ShoppingCategory.epicerie:
        return 'Epicerie';
      case ShoppingCategory.boissons:
        return 'Boissons';
      case ShoppingCategory.surgeles:
        return 'Surgeles';
      case ShoppingCategory.boulangerie:
        return 'Boulangerie';
      case ShoppingCategory.hygiene:
        return 'Hygiene';
      case ShoppingCategory.autre:
        return 'Autre';
    }
  }

  String get icon {
    switch (this) {
      case ShoppingCategory.fruitsLegumes:
        return '🥬';
      case ShoppingCategory.viandes:
        return '🥩';
      case ShoppingCategory.poissons:
        return '🐟';
      case ShoppingCategory.produitsFrais:
        return '🧀';
      case ShoppingCategory.epicerie:
        return '🛒';
      case ShoppingCategory.boissons:
        return '🍷';
      case ShoppingCategory.surgeles:
        return '❄️';
      case ShoppingCategory.boulangerie:
        return '🥖';
      case ShoppingCategory.hygiene:
        return '🧴';
      case ShoppingCategory.autre:
        return '📦';
    }
  }

  int get sortOrder {
    switch (this) {
      case ShoppingCategory.fruitsLegumes:
        return 0;
      case ShoppingCategory.boulangerie:
        return 1;
      case ShoppingCategory.viandes:
        return 2;
      case ShoppingCategory.poissons:
        return 3;
      case ShoppingCategory.produitsFrais:
        return 4;
      case ShoppingCategory.surgeles:
        return 5;
      case ShoppingCategory.epicerie:
        return 6;
      case ShoppingCategory.boissons:
        return 7;
      case ShoppingCategory.hygiene:
        return 8;
      case ShoppingCategory.autre:
        return 9;
    }
  }
}

class ShoppingItem {
  final String id;
  final String name;
  final ShoppingCategory category;
  final double? quantity;
  final String? unit;
  final bool isChecked;
  final DateTime addedAt;
  final String? addedBy;

  ShoppingItem({
    required this.id,
    required this.name,
    required this.category,
    this.quantity,
    this.unit,
    this.isChecked = false,
    required this.addedAt,
    this.addedBy,
  });

  factory ShoppingItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShoppingItem(
      id: doc.id,
      name: data['name'] ?? '',
      category: ShoppingCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => ShoppingCategory.autre,
      ),
      quantity: (data['quantity'] as num?)?.toDouble(),
      unit: data['unit'],
      isChecked: data['isChecked'] ?? false,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      addedBy: data['addedBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category.name,
      'quantity': quantity,
      'unit': unit,
      'isChecked': isChecked,
      'addedAt': Timestamp.fromDate(addedAt),
      'addedBy': addedBy,
    };
  }

  ShoppingItem copyWith({
    String? id,
    String? name,
    ShoppingCategory? category,
    double? quantity,
    String? unit,
    bool? isChecked,
    DateTime? addedAt,
    String? addedBy,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isChecked: isChecked ?? this.isChecked,
      addedAt: addedAt ?? this.addedAt,
      addedBy: addedBy ?? this.addedBy,
    );
  }

  /// Auto-detect category based on item name
  static ShoppingCategory detectCategory(String itemName) {
    final name = itemName.toLowerCase();

    // Fruits & Legumes
    if (_matchesAny(name, [
      'pomme', 'poire', 'banane', 'orange', 'citron', 'fraise', 'framboise',
      'tomate', 'salade', 'laitue', 'carotte', 'oignon', 'ail', 'poireau',
      'courgette', 'aubergine', 'poivron', 'concombre', 'celeri', 'brocoli',
      'chou', 'epinard', 'haricot vert', 'petits pois', 'pomme de terre',
      'patate', 'avocat', 'melon', 'pasteque', 'raisin', 'peche', 'abricot',
      'mangue', 'ananas', 'kiwi', 'fruit', 'legume', 'champignon', 'radis',
    ])) return ShoppingCategory.fruitsLegumes;

    // Viandes
    if (_matchesAny(name, [
      'poulet', 'boeuf', 'porc', 'veau', 'agneau', 'canard', 'dinde',
      'jambon', 'lard', 'bacon', 'saucisse', 'viande', 'steak', 'escalope',
      'filet', 'cote', 'roti', 'hache', 'merguez', 'chipolata',
    ])) return ShoppingCategory.viandes;

    // Poissons
    if (_matchesAny(name, [
      'saumon', 'thon', 'cabillaud', 'crevette', 'moule', 'huitre',
      'poisson', 'truite', 'sardine', 'maquereau', 'sole', 'bar', 'dorade',
      'crabe', 'homard', 'langoustine', 'fruit de mer',
    ])) return ShoppingCategory.poissons;

    // Produits frais
    if (_matchesAny(name, [
      'lait', 'fromage', 'yaourt', 'yogourt', 'beurre', 'creme', 'oeuf',
      'mozzarella', 'gruyere', 'emmental', 'parmesan', 'camembert', 'brie',
      'ricotta', 'mascarpone', 'cottage', 'feta', 'chevre',
    ])) return ShoppingCategory.produitsFrais;

    // Boulangerie
    if (_matchesAny(name, [
      'pain', 'baguette', 'croissant', 'brioche', 'gateau', 'tarte',
      'patisserie', 'cookie', 'biscuit', 'muffin', 'cake',
    ])) return ShoppingCategory.boulangerie;

    // Surgeles
    if (_matchesAny(name, [
      'surgele', 'glace', 'congele', 'pizza surgelee', 'frites surgelees',
    ])) return ShoppingCategory.surgeles;

    // Boissons
    if (_matchesAny(name, [
      'eau', 'jus', 'soda', 'coca', 'biere', 'vin', 'cafe', 'the',
      'sirop', 'limonade', 'sprite', 'fanta', 'orangina', 'boisson',
    ])) return ShoppingCategory.boissons;

    // Hygiene
    if (_matchesAny(name, [
      'savon', 'shampoing', 'dentifrice', 'brosse', 'papier toilette',
      'mouchoir', 'deodorant', 'rasoir', 'coton', 'serviette', 'lessive',
      'nettoyant', 'eponge', 'liquide vaisselle',
    ])) return ShoppingCategory.hygiene;

    // Epicerie (default alimentaire)
    if (_matchesAny(name, [
      'pate', 'riz', 'farine', 'sucre', 'sel', 'poivre', 'huile', 'vinaigre',
      'conserve', 'sauce', 'moutarde', 'ketchup', 'mayonnaise', 'epice',
      'cereale', 'muesli', 'confiture', 'miel', 'nutella', 'chocolat',
      'biscuit', 'chips', 'olive', 'cornichon', 'bouillon', 'soupe',
    ])) return ShoppingCategory.epicerie;

    return ShoppingCategory.autre;
  }

  static bool _matchesAny(String text, List<String> patterns) {
    return patterns.any((p) => text.contains(p));
  }
}
