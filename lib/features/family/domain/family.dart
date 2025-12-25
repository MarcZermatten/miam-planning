import 'package:cloud_firestore/cloud_firestore.dart';

/// Family model
class Family {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final FamilySettings settings;
  final String? inviteCode;

  Family({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.settings,
    this.inviteCode,
  });

  factory Family.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Family(
      id: doc.id,
      name: data['name'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      settings: FamilySettings.fromMap(data['settings'] ?? {}),
      inviteCode: data['inviteCode'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'settings': settings.toMap(),
      'inviteCode': inviteCode,
    };
  }

  Family copyWith({
    String? name,
    FamilySettings? settings,
    String? inviteCode,
  }) {
    return Family(
      id: id,
      name: name ?? this.name,
      createdBy: createdBy,
      createdAt: createdAt,
      settings: settings ?? this.settings,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }
}

/// Family settings
class FamilySettings {
  final List<String> enabledMeals;
  final int weekStartDay; // 1 = Monday, 7 = Sunday
  final bool notificationsEnabled;
  final int reminderMinutesBefore; // Minutes before meal to send reminder
  /// Meal slots to skip by day. Format: "dayOfWeek-mealType" e.g., "1-lunch" for Monday lunch
  /// dayOfWeek: 1=Monday, 7=Sunday
  final Set<String> disabledMealSlots;

  FamilySettings({
    List<String>? enabledMeals,
    this.weekStartDay = 1,
    this.notificationsEnabled = false,
    this.reminderMinutesBefore = 60, // Default: 1 hour before
    Set<String>? disabledMealSlots,
  }) : enabledMeals = enabledMeals ?? ['lunch', 'dinner'],
       disabledMealSlots = disabledMealSlots ?? {};

  factory FamilySettings.fromMap(Map<String, dynamic> map) {
    return FamilySettings(
      enabledMeals: List<String>.from(map['enabledMeals'] ?? ['lunch', 'dinner']),
      weekStartDay: map['weekStartDay'] ?? 1,
      notificationsEnabled: map['notificationsEnabled'] ?? false,
      reminderMinutesBefore: map['reminderMinutesBefore'] ?? 60,
      disabledMealSlots: Set<String>.from(map['disabledMealSlots'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabledMeals': enabledMeals,
      'weekStartDay': weekStartDay,
      'notificationsEnabled': notificationsEnabled,
      'reminderMinutesBefore': reminderMinutesBefore,
      'disabledMealSlots': disabledMealSlots.toList(),
    };
  }

  FamilySettings copyWith({
    List<String>? enabledMeals,
    int? weekStartDay,
    bool? notificationsEnabled,
    int? reminderMinutesBefore,
    Set<String>? disabledMealSlots,
  }) {
    return FamilySettings(
      enabledMeals: enabledMeals ?? this.enabledMeals,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      disabledMealSlots: disabledMealSlots ?? this.disabledMealSlots,
    );
  }

  /// Check if a meal slot is enabled for a given day
  /// dayOfWeek: 1=Monday, 7=Sunday
  bool isMealEnabled(int dayOfWeek, String mealType) {
    if (!enabledMeals.contains(mealType)) return false;
    return !disabledMealSlots.contains('$dayOfWeek-$mealType');
  }

  /// Toggle a meal slot for a specific day
  FamilySettings toggleMealSlot(int dayOfWeek, String mealType) {
    final slot = '$dayOfWeek-$mealType';
    final newDisabled = Set<String>.from(disabledMealSlots);
    if (newDisabled.contains(slot)) {
      newDisabled.remove(slot);
    } else {
      newDisabled.add(slot);
    }
    return copyWith(disabledMealSlots: newDisabled);
  }
}
