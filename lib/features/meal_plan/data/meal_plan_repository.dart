import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../family/data/family_repository.dart';
import '../domain/meal_plan.dart';

/// Meal plan repository provider
final mealPlanRepositoryProvider = Provider<MealPlanRepository>((ref) {
  return MealPlanRepository(ref.watch(firestoreProvider));
});

/// Currently selected week offset (0 = current week, 1 = next week, -1 = last week)
final selectedWeekOffsetProvider = StateProvider<int>((ref) => 0);

/// Currently selected week's start date
final selectedWeekStartProvider = Provider<DateTime>((ref) {
  final offset = ref.watch(selectedWeekOffsetProvider);
  final now = DateTime.now();
  final currentWeekStart = MealPlan.getWeekStart(now);
  return currentWeekStart.add(Duration(days: offset * 7));
});

/// Current week's meal plan
final currentMealPlanProvider = StreamProvider<MealPlan?>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  final weekStart = ref.watch(selectedWeekStartProvider);

  if (familyId == null) return Stream.value(null);

  final weekId = MealPlan.getWeekId(weekStart);
  return ref.watch(mealPlanRepositoryProvider).watchMealPlan(familyId, weekId);
});

/// Meal plan repository for Firestore operations
class MealPlanRepository {
  final FirebaseFirestore _firestore;

  MealPlanRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _mealPlansRef(String familyId) =>
      _firestore.collection('families').doc(familyId).collection('mealPlans');

  /// Get or create a meal plan for a week
  Future<MealPlan> getOrCreateMealPlan(String familyId, DateTime weekStart) async {
    final weekId = MealPlan.getWeekId(weekStart);
    final normalizedStart = MealPlan.getWeekStart(weekStart);

    // Try to find existing plan
    final query = await _mealPlansRef(familyId)
        .where('weekId', isEqualTo: weekId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return MealPlan.fromFirestore(query.docs.first);
    }

    // Create new plan
    final docRef = _mealPlansRef(familyId).doc();
    final plan = MealPlan(
      id: docRef.id,
      weekId: weekId,
      weekStart: normalizedStart,
      createdAt: DateTime.now(),
    );

    await docRef.set(plan.toFirestore());
    return plan;
  }

  /// Watch a meal plan for a specific week
  Stream<MealPlan?> watchMealPlan(String familyId, String weekId) {
    return _mealPlansRef(familyId)
        .where('weekId', isEqualTo: weekId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return MealPlan.fromFirestore(snapshot.docs.first);
    });
  }

  /// Set a meal in the plan
  Future<void> setMeal({
    required String familyId,
    required DateTime date,
    required String mealType,
    required MealAssignment assignment,
  }) async {
    final weekStart = MealPlan.getWeekStart(date);
    final plan = await getOrCreateMealPlan(familyId, weekStart);
    final updatedPlan = plan.setMeal(date, mealType, assignment);

    await _mealPlansRef(familyId).doc(plan.id).update(updatedPlan.toFirestore());
  }

  /// Remove a meal from the plan
  Future<void> removeMeal({
    required String familyId,
    required DateTime date,
    required String mealType,
  }) async {
    final weekStart = MealPlan.getWeekStart(date);
    final weekId = MealPlan.getWeekId(weekStart);

    final query = await _mealPlansRef(familyId)
        .where('weekId', isEqualTo: weekId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return;

    final plan = MealPlan.fromFirestore(query.docs.first);
    final updatedPlan = plan.removeMeal(date, mealType);

    await _mealPlansRef(familyId).doc(plan.id).update(updatedPlan.toFirestore());
  }

  /// Copy a meal plan from one week to another
  Future<void> copyWeek({
    required String familyId,
    required DateTime sourceWeekStart,
    required DateTime targetWeekStart,
  }) async {
    final sourceWeekId = MealPlan.getWeekId(sourceWeekStart);
    final query = await _mealPlansRef(familyId)
        .where('weekId', isEqualTo: sourceWeekId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return;

    final sourcePlan = MealPlan.fromFirestore(query.docs.first);
    final targetPlan = await getOrCreateMealPlan(familyId, targetWeekStart);

    // Copy meals with adjusted dates
    final daysDiff = targetWeekStart.difference(sourceWeekStart).inDays;
    final newDays = <String, DayMeals>{};

    sourcePlan.days.forEach((dateKey, dayMeals) {
      final parts = dateKey.split('-');
      final sourceDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final targetDate = sourceDate.add(Duration(days: daysDiff));
      final newKey =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      newDays[newKey] = dayMeals;
    });

    await _mealPlansRef(familyId).doc(targetPlan.id).update({
      'days': newDays.map((k, v) => MapEntry(k, v.toMap())),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Clear all meals for a week
  Future<void> clearWeek(String familyId, DateTime weekStart) async {
    final weekId = MealPlan.getWeekId(weekStart);
    final query = await _mealPlansRef(familyId)
        .where('weekId', isEqualTo: weekId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return;

    await _mealPlansRef(familyId).doc(query.docs.first.id).update({
      'days': {},
      'updatedAt': Timestamp.now(),
    });
  }

  /// Get recipes used in a date range (for shopping list generation)
  Future<List<String>> getRecipeIdsForDateRange({
    required String familyId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final recipeIds = <String>{};

    // Get all weeks that overlap with the date range
    var currentWeekStart = MealPlan.getWeekStart(startDate);
    final lastWeekStart = MealPlan.getWeekStart(endDate);

    while (!currentWeekStart.isAfter(lastWeekStart)) {
      final weekId = MealPlan.getWeekId(currentWeekStart);
      final query = await _mealPlansRef(familyId)
          .where('weekId', isEqualTo: weekId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final plan = MealPlan.fromFirestore(query.docs.first);

        plan.days.forEach((dateKey, dayMeals) {
          final parts = dateKey.split('-');
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );

          if (!date.isBefore(startDate) && !date.isAfter(endDate)) {
            dayMeals.meals.forEach((_, assignment) {
              if (assignment != null) {
                recipeIds.add(assignment.recipeId);
              }
            });
          }
        });
      }

      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    }

    return recipeIds.toList();
  }
}
