import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../family/data/family_repository.dart';
import '../domain/meal_plan.dart';
import '../domain/meal_statistics.dart';

/// Provider for meal statistics
final mealStatisticsProvider = FutureProvider<MealStatistics>((ref) async {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return MealStatistics();

  final family = ref.watch(currentFamilyProvider).value;
  final enabledMeals = family?.settings.enabledMeals ?? ['lunch', 'dinner'];

  final firestore = FirebaseFirestore.instance;

  // Get the last 8 weeks of meal plans for good statistics
  final now = DateTime.now();
  final eightWeeksAgo = now.subtract(const Duration(days: 56));
  final currentWeekStart = MealPlan.getWeekStart(now);

  try {
    final snapshot = await firestore
        .collection('families')
        .doc(familyId)
        .collection('mealPlans')
        .where('weekStart', isGreaterThanOrEqualTo: Timestamp.fromDate(eightWeeksAgo))
        .get();

    final mealPlans = snapshot.docs
        .map((doc) => MealPlan.fromFirestore(doc))
        .toList();

    return MealStatisticsCalculator.calculate(
      mealPlans: mealPlans,
      currentWeekStart: currentWeekStart,
      enabledMealsCount: enabledMeals.length,
    );
  } catch (e) {
    return MealStatistics();
  }
});

/// Stream provider for real-time statistics updates
final mealStatisticsStreamProvider = StreamProvider<MealStatistics>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value(MealStatistics());

  final family = ref.watch(currentFamilyProvider).value;
  final enabledMeals = family?.settings.enabledMeals ?? ['lunch', 'dinner'];

  final firestore = FirebaseFirestore.instance;
  final now = DateTime.now();
  final eightWeeksAgo = now.subtract(const Duration(days: 56));
  final currentWeekStart = MealPlan.getWeekStart(now);

  return firestore
      .collection('families')
      .doc(familyId)
      .collection('mealPlans')
      .where('weekStart', isGreaterThanOrEqualTo: Timestamp.fromDate(eightWeeksAgo))
      .snapshots()
      .map((snapshot) {
    final mealPlans = snapshot.docs
        .map((doc) => MealPlan.fromFirestore(doc))
        .toList();

    return MealStatisticsCalculator.calculate(
      mealPlans: mealPlans,
      currentWeekStart: currentWeekStart,
      enabledMealsCount: enabledMeals.length,
    );
  });
});
