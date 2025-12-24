import 'package:cloud_firestore/cloud_firestore.dart';

/// A single meal assignment
class MealAssignment {
  final String recipeId;
  final String recipeTitle;
  final String? note;

  MealAssignment({
    required this.recipeId,
    required this.recipeTitle,
    this.note,
  });

  factory MealAssignment.fromMap(Map<String, dynamic> map) {
    return MealAssignment(
      recipeId: map['recipeId'] ?? '',
      recipeTitle: map['recipeTitle'] ?? '',
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipeId': recipeId,
      'recipeTitle': recipeTitle,
      'note': note,
    };
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
