import 'package:cloud_firestore/cloud_firestore.dart';
import '../../dishes/domain/dish.dart';

/// A single dish assignment within a meal
class DishAssignment {
  final String dishId;
  final String dishName;
  final String? recipeId;
  final String? recipeName;
  final bool fromFreezer;
  final int portionsUsed;
  final String? note;
  /// Nutritional categories of the dish (vegetable, protein, starch, etc.)
  final List<String> categories;

  DishAssignment({
    required this.dishId,
    required this.dishName,
    this.recipeId,
    this.recipeName,
    this.fromFreezer = false,
    this.portionsUsed = 1,
    this.note,
    this.categories = const [],
  });

  factory DishAssignment.fromMap(Map<String, dynamic> map) {
    return DishAssignment(
      dishId: map['dishId'] ?? '',
      dishName: map['dishName'] ?? '',
      recipeId: map['recipeId'],
      recipeName: map['recipeName'],
      fromFreezer: map['fromFreezer'] ?? false,
      portionsUsed: map['portionsUsed'] ?? 1,
      note: map['note'],
      categories: List<String>.from(map['categories'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dishId': dishId,
      'dishName': dishName,
      'recipeId': recipeId,
      'recipeName': recipeName,
      'fromFreezer': fromFreezer,
      'portionsUsed': portionsUsed,
      'note': note,
      'categories': categories,
    };
  }

  DishAssignment copyWith({
    String? dishId,
    String? dishName,
    String? recipeId,
    String? recipeName,
    bool? fromFreezer,
    int? portionsUsed,
    String? note,
    List<String>? categories,
  }) {
    return DishAssignment(
      dishId: dishId ?? this.dishId,
      dishName: dishName ?? this.dishName,
      recipeId: recipeId ?? this.recipeId,
      recipeName: recipeName ?? this.recipeName,
      fromFreezer: fromFreezer ?? this.fromFreezer,
      portionsUsed: portionsUsed ?? this.portionsUsed,
      note: note ?? this.note,
      categories: categories ?? this.categories,
    );
  }

  /// Check if dish has a specific category
  bool hasCategory(DishCategory category) => categories.contains(category.name);

  /// Check if dish has vegetable
  bool get hasVegetable => hasCategory(DishCategory.vegetable);

  /// Check if dish has starch/carbs
  bool get hasStarch => hasCategory(DishCategory.starch);

  /// Check if dish has protein
  bool get hasProtein => hasCategory(DishCategory.protein);

  /// Check if this is a complete meal (has vegetable + starch)
  bool get isComplete => hasCategory(DishCategory.complete);
}

/// Default accompaniment options
const List<String> defaultAccompaniments = [
  'Pâtes',
  'Riz',
  'Ébly',
  'Couscous',
  'Boulgour',
  'Pommes de terre',
  'Purée',
  'Pain',
  'Quinoa',
  'Polenta',
  'Semoule',
];

/// A meal assignment containing one or more dishes
class MealAssignment {
  final List<DishAssignment> dishes;
  final String? accompaniment; // Optional side dish: "Pâtes", "Riz", etc.
  final String? note;

  MealAssignment({
    this.dishes = const [],
    this.accompaniment,
    this.note,
  });

  /// Check if meal has vegetable (from any dish or complete dish)
  bool get hasVegetable => dishes.any((d) => d.hasVegetable || d.isComplete);

  /// Check if meal has starch (from any dish or complete dish)
  bool get hasStarch => dishes.any((d) => d.hasStarch || d.isComplete);

  /// Check if meal has protein (from any dish)
  bool get hasProtein => dishes.any((d) => d.hasProtein || d.isComplete);

  /// Check if meal is considered "complete" (has vegetable + starch at minimum)
  bool get isNutritionallyComplete => hasVegetable && hasStarch;

  /// Get nutritional status message
  String get nutritionalStatus {
    if (isEmpty) return 'Non planifie';
    if (isNutritionallyComplete) return 'Repas complet';
    final missing = <String>[];
    if (!hasVegetable) missing.add('legume');
    if (!hasStarch) missing.add('feculent');
    return 'Manque: ${missing.join(', ')}';
  }

  /// Legacy constructor for backward compatibility
  factory MealAssignment.legacy({
    required String recipeId,
    required String recipeTitle,
    String? note,
  }) {
    return MealAssignment(
      dishes: [
        DishAssignment(
          dishId: recipeId, // Use recipeId as dishId for legacy data
          dishName: recipeTitle,
          recipeId: recipeId,
          recipeName: recipeTitle,
        ),
      ],
      note: note,
    );
  }

  factory MealAssignment.fromMap(Map<String, dynamic> map) {
    // Handle legacy format (single recipe)
    if (map.containsKey('recipeId') && !map.containsKey('dishes')) {
      return MealAssignment.legacy(
        recipeId: map['recipeId'] ?? '',
        recipeTitle: map['recipeTitle'] ?? '',
        note: map['note'],
      );
    }

    // New format with dishes array
    return MealAssignment(
      dishes: (map['dishes'] as List<dynamic>?)
              ?.map((e) => DishAssignment.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      accompaniment: map['accompaniment'],
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dishes': dishes.map((d) => d.toMap()).toList(),
      if (accompaniment != null) 'accompaniment': accompaniment,
      'note': note,
    };
  }

  MealAssignment copyWith({
    List<DishAssignment>? dishes,
    String? accompaniment,
    String? note,
  }) {
    return MealAssignment(
      dishes: dishes ?? this.dishes,
      accompaniment: accompaniment ?? this.accompaniment,
      note: note ?? this.note,
    );
  }

  /// Check if this meal has any dishes assigned
  bool get isEmpty => dishes.isEmpty;
  bool get isNotEmpty => dishes.isNotEmpty;

  /// Get the first dish (for simple display)
  DishAssignment? get firstDish => dishes.isNotEmpty ? dishes.first : null;

  /// Legacy getters for backward compatibility
  String get recipeId => dishes.isNotEmpty ? (dishes.first.recipeId ?? dishes.first.dishId) : '';
  String get recipeTitle => dishes.isNotEmpty ? dishes.first.dishName : '';

  /// Add a dish to this meal
  MealAssignment addDish(DishAssignment dish) {
    return MealAssignment(
      dishes: [...dishes, dish],
      accompaniment: accompaniment,
      note: note,
    );
  }

  /// Remove a dish from this meal
  MealAssignment removeDish(String dishId) {
    return MealAssignment(
      dishes: dishes.where((d) => d.dishId != dishId).toList(),
      accompaniment: accompaniment,
      note: note,
    );
  }

  /// Update a dish in this meal
  MealAssignment updateDish(String dishId, DishAssignment updated) {
    return MealAssignment(
      dishes: dishes.map((d) => d.dishId == dishId ? updated : d).toList(),
      accompaniment: accompaniment,
      note: note,
    );
  }
}

/// Meals for a single day
class DayMeals {
  final Map<String, MealAssignment?> meals; // mealType -> assignment

  DayMeals({Map<String, MealAssignment?>? meals}) : meals = meals ?? {};

  factory DayMeals.fromMap(Map<String, dynamic> map) {
    final meals = <String, MealAssignment?>{};
    map.forEach((key, value) {
      if (value != null && value is Map<String, dynamic>) {
        meals[key] = MealAssignment.fromMap(value);
      }
    });
    return DayMeals(meals: meals);
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    meals.forEach((key, value) {
      map[key] = value?.toMap();
    });
    return map;
  }

  MealAssignment? getMeal(String mealType) => meals[mealType];

  DayMeals copyWith({Map<String, MealAssignment?>? meals}) {
    return DayMeals(meals: meals ?? Map.from(this.meals));
  }

  DayMeals setMeal(String mealType, MealAssignment? assignment) {
    final newMeals = Map<String, MealAssignment?>.from(meals);
    newMeals[mealType] = assignment;
    return DayMeals(meals: newMeals);
  }

  DayMeals removeMeal(String mealType) {
    final newMeals = Map<String, MealAssignment?>.from(meals);
    newMeals.remove(mealType);
    return DayMeals(meals: newMeals);
  }
}

/// Weekly meal plan
class MealPlan {
  final String id;
  final String weekId; // Format: "2024-W52"
  final DateTime weekStart;
  final Map<String, DayMeals> days; // date string (yyyy-MM-dd) -> DayMeals
  final DateTime createdAt;
  final DateTime updatedAt;

  MealPlan({
    required this.id,
    required this.weekId,
    required this.weekStart,
    Map<String, DayMeals>? days,
    required this.createdAt,
    DateTime? updatedAt,
  })  : days = days ?? {},
        updatedAt = updatedAt ?? createdAt;

  factory MealPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final daysMap = <String, DayMeals>{};
    final daysData = data['days'] as Map<String, dynamic>? ?? {};
    daysData.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        daysMap[key] = DayMeals.fromMap(value);
      }
    });

    return MealPlan(
      id: doc.id,
      weekId: data['weekId'] ?? '',
      weekStart: (data['weekStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      days: daysMap,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final daysMap = <String, dynamic>{};
    days.forEach((key, value) {
      daysMap[key] = value.toMap();
    });

    return {
      'weekId': weekId,
      'weekStart': Timestamp.fromDate(weekStart),
      'days': daysMap,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Get meals for a specific date
  DayMeals getMealsForDate(DateTime date) {
    final key = _dateToKey(date);
    return days[key] ?? DayMeals();
  }

  /// Set a meal for a specific date
  MealPlan setMeal(DateTime date, String mealType, MealAssignment? assignment) {
    final key = _dateToKey(date);
    final dayMeals = days[key] ?? DayMeals();
    final newDayMeals = dayMeals.setMeal(mealType, assignment);

    final newDays = Map<String, DayMeals>.from(days);
    newDays[key] = newDayMeals;

    return MealPlan(
      id: id,
      weekId: weekId,
      weekStart: weekStart,
      days: newDays,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove a meal from a specific date
  MealPlan removeMeal(DateTime date, String mealType) {
    return setMeal(date, mealType, null);
  }

  /// Get all dates in this week
  List<DateTime> get weekDates {
    return List.generate(7, (i) => weekStart.add(Duration(days: i)));
  }

  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Generate weekId from date
  static String getWeekId(DateTime date) {
    // ISO week number calculation
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final weekOfYear = ((dayOfYear - date.weekday + 10) / 7).floor();
    return '${date.year}-W${weekOfYear.toString().padLeft(2, '0')}';
  }

  /// Get Monday of the week containing the given date
  static DateTime getWeekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }
}
