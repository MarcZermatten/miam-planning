import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/family/data/family_repository.dart';
import '../../features/meal_plan/data/meal_plan_repository.dart';
import 'notification_service.dart';

/// Provider for meal reminder service
final mealReminderServiceProvider = Provider<MealReminderService>((ref) {
  return MealReminderService(ref);
});

/// Service for scheduling meal planning reminders
class MealReminderService {
  final Ref _ref;

  MealReminderService(this._ref);

  /// Check and schedule reminders based on current settings
  Future<void> scheduleReminders() async {
    final notificationService = _ref.read(notificationServiceProvider);
    final family = _ref.read(currentFamilyProvider).value;

    if (family == null) {
      debugPrint('MealReminderService: No family found');
      return;
    }

    final settings = family.settings;

    // Cancel existing reminders first
    await notificationService.cancelNotification(NotificationIds.breakfastReminder);
    await notificationService.cancelNotification(NotificationIds.lunchReminder);
    await notificationService.cancelNotification(NotificationIds.dinnerReminder);

    if (!settings.notificationsEnabled) {
      debugPrint('MealReminderService: Notifications disabled');
      return;
    }

    final enabledMeals = settings.enabledMeals;
    final reminderMinutes = settings.reminderMinutesBefore;

    // Schedule reminders for each enabled meal
    if (enabledMeals.contains('breakfast')) {
      // Breakfast reminder (default 7:00, remind at 7:00 - reminderMinutes the day before)
      final reminderHour = 7 - (reminderMinutes ~/ 60);
      final reminderMinute = 60 - (reminderMinutes % 60);
      await notificationService.scheduleDailyNotification(
        id: NotificationIds.breakfastReminder,
        title: 'Petit-dejeuner non planifie',
        body: 'N\'oubliez pas de planifier le petit-dejeuner de demain !',
        hour: reminderHour < 0 ? 20 : reminderHour, // Previous day evening if needed
        minute: reminderMinute >= 60 ? 0 : reminderMinute,
        payload: 'breakfast',
      );
    }

    if (enabledMeals.contains('lunch')) {
      // Lunch reminder (default 12:00, remind at configured time before)
      final lunchHour = 12;
      final reminderTime = _calculateReminderTime(lunchHour, 0, reminderMinutes);
      await notificationService.scheduleDailyNotification(
        id: NotificationIds.lunchReminder,
        title: 'Dejeuner non planifie',
        body: 'Pensez a planifier le dejeuner !',
        hour: reminderTime.hour,
        minute: reminderTime.minute,
        payload: 'lunch',
      );
    }

    if (enabledMeals.contains('dinner')) {
      // Dinner reminder (default 19:00, remind at configured time before)
      final dinnerHour = 19;
      final reminderTime = _calculateReminderTime(dinnerHour, 0, reminderMinutes);
      await notificationService.scheduleDailyNotification(
        id: NotificationIds.dinnerReminder,
        title: 'Diner non planifie',
        body: 'N\'oubliez pas de planifier le diner !',
        hour: reminderTime.hour,
        minute: reminderTime.minute,
        payload: 'dinner',
      );
    }

    debugPrint('MealReminderService: Reminders scheduled');
  }

  /// Calculate reminder time based on meal time and minutes before
  ({int hour, int minute}) _calculateReminderTime(int mealHour, int mealMinute, int minutesBefore) {
    var totalMinutes = mealHour * 60 + mealMinute - minutesBefore;
    if (totalMinutes < 0) {
      totalMinutes += 24 * 60; // Previous day
    }
    return (hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }

  /// Check if a specific meal is planned for today
  Future<bool> isMealPlannedForToday(String mealType) async {
    final mealPlan = _ref.read(currentMealPlanProvider).value;
    if (mealPlan == null) return false;

    final today = DateTime.now();
    final dayMeals = mealPlan.getMealsForDate(today);
    if (dayMeals == null) return false;

    return dayMeals.getMeal(mealType) != null;
  }

  /// Check unplanned meals and show immediate notification if needed
  Future<void> checkAndNotifyUnplannedMeals() async {
    final notificationService = _ref.read(notificationServiceProvider);
    final family = _ref.read(currentFamilyProvider).value;

    if (family == null || !family.settings.notificationsEnabled) return;

    final enabledMeals = family.settings.enabledMeals;
    final unplannedMeals = <String>[];

    for (final mealType in enabledMeals) {
      if (!await isMealPlannedForToday(mealType)) {
        unplannedMeals.add(_getMealLabel(mealType));
      }
    }

    if (unplannedMeals.isNotEmpty) {
      await notificationService.showNotification(
        id: 100,
        title: 'Repas non planifies',
        body: 'Aujourd\'hui: ${unplannedMeals.join(", ")}',
        payload: 'unplanned',
      );
    }
  }

  String _getMealLabel(String mealType) {
    return switch (mealType) {
      'breakfast' => 'Petit-dej',
      'lunch' => 'Dejeuner',
      'snack' => 'Gouter',
      'dinner' => 'Diner',
      _ => mealType,
    };
  }
}
