import '../domain/meal_plan.dart';

/// Statistics about meal planning
class MealStatistics {
  /// Top dishes by usage count
  final List<DishUsage> topDishes;

  /// Days since each dish was last cooked
  final Map<String, int> daysSinceLastCooked;

  /// Accompaniment frequency this week
  final Map<String, int> accompanimentFrequency;

  /// Number of meals planned this week
  final int mealsPlannedThisWeek;

  /// Total meals possible this week
  final int totalMealsThisWeek;

  MealStatistics({
    this.topDishes = const [],
    this.daysSinceLastCooked = const {},
    this.accompanimentFrequency = const {},
    this.mealsPlannedThisWeek = 0,
    this.totalMealsThisWeek = 14,
  });

  /// Completion rate as percentage
  double get completionRate =>
      totalMealsThisWeek > 0 ? mealsPlannedThisWeek / totalMealsThisWeek : 0;

  /// Get top accompaniment if overused (>3 times this week)
  String? get overusedAccompaniment {
    for (final entry in accompanimentFrequency.entries) {
      if (entry.value > 3) return entry.key;
    }
    return null;
  }

  /// Get a dish that hasn't been cooked in a while
  MapEntry<String, int>? get neglectedDish {
    if (daysSinceLastCooked.isEmpty) return null;
    final sorted = daysSinceLastCooked.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    // Only return if more than 14 days
    return top.value > 14 ? top : null;
  }
}

/// A dish with its usage count
class DishUsage {
  final String dishId;
  final String dishName;
  final int usageCount;

  DishUsage({
    required this.dishId,
    required this.dishName,
    required this.usageCount,
  });
}

/// Helper class to compute statistics from meal plans
class MealStatisticsCalculator {
  /// Calculate statistics from a list of meal plans
  static MealStatistics calculate({
    required List<MealPlan> mealPlans,
    required DateTime currentWeekStart,
    required int enabledMealsCount,
  }) {
    final dishUsageMap = <String, DishUsage>{};
    final lastCookedMap = <String, DateTime>{};
    final accompanimentMap = <String, int>{};
    int mealsThisWeek = 0;

    final now = DateTime.now();
    final weekEnd = currentWeekStart.add(const Duration(days: 7));

    for (final plan in mealPlans) {
      for (final dayEntry in plan.days.entries) {
        final dateStr = dayEntry.key;
        final dateParts = dateStr.split('-');
        if (dateParts.length != 3) continue;

        final date = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );

        final dayMeals = dayEntry.value;

        for (final mealEntry in dayMeals.meals.entries) {
          final assignment = mealEntry.value;
          if (assignment == null || assignment.isEmpty) continue;

          // Count meals for current week
          if (date.isAfter(currentWeekStart.subtract(const Duration(days: 1))) &&
              date.isBefore(weekEnd)) {
            mealsThisWeek++;

            // Track accompaniments for current week
            if (assignment.accompaniment != null &&
                assignment.accompaniment!.isNotEmpty) {
              accompanimentMap.update(
                assignment.accompaniment!,
                (v) => v + 1,
                ifAbsent: () => 1,
              );
            }
          }

          // Track dish usage and last cooked date
          for (final dish in assignment.dishes) {
            final key = dish.dishId;
            final name = dish.dishName;

            // Update usage count
            if (dishUsageMap.containsKey(key)) {
              dishUsageMap[key] = DishUsage(
                dishId: key,
                dishName: name,
                usageCount: dishUsageMap[key]!.usageCount + 1,
              );
            } else {
              dishUsageMap[key] = DishUsage(
                dishId: key,
                dishName: name,
                usageCount: 1,
              );
            }

            // Update last cooked date
            if (!lastCookedMap.containsKey(key) ||
                date.isAfter(lastCookedMap[key]!)) {
              lastCookedMap[key] = date;
            }
          }
        }
      }
    }

    // Sort by usage and take top 5
    final topDishes = dishUsageMap.values.toList()
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));

    // Calculate days since last cooked
    final daysSince = <String, int>{};
    for (final entry in lastCookedMap.entries) {
      daysSince[entry.key] = now.difference(entry.value).inDays;
    }

    return MealStatistics(
      topDishes: topDishes.take(5).toList(),
      daysSinceLastCooked: daysSince,
      accompanimentFrequency: accompanimentMap,
      mealsPlannedThisWeek: mealsThisWeek,
      totalMealsThisWeek: enabledMealsCount * 7,
    );
  }
}
