import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/meal_reminder_service.dart';
import '../../../../routing/app_router.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/family_repository.dart';
import '../../domain/family.dart';
import '../../domain/family_member.dart';

class FamilySettingsScreen extends ConsumerStatefulWidget {
  const FamilySettingsScreen({super.key});

  @override
  ConsumerState<FamilySettingsScreen> createState() => _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends ConsumerState<FamilySettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(currentFamilyProvider);
    final membersAsync = ref.watch(familyMembersProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma famille'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: familyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (family) {
          if (family == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucune famille configuree'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go(AppRoutes.familySetup),
                    child: const Text('Configurer'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Family card with invite code
              _buildFamilyCard(family),
              const SizedBox(height: 24),

              // Members section
              _buildSectionTitle('Membres'),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Erreur: $e'),
                data: (members) => Column(
                  children: [
                    ...members.map((m) => _buildMemberCard(m, currentUser?.uid)),
                    const SizedBox(height: 8),
                    _buildInviteButton(family.inviteCode),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Appearance settings
              _buildSectionTitle('Apparence'),
              const SizedBox(height: 8),
              _buildAppearanceSettings(),
              const SizedBox(height: 24),

              // Meal settings
              _buildSectionTitle('Repas a planifier'),
              const SizedBox(height: 8),
              _buildMealSettings(family),
              const SizedBox(height: 24),

              // Notification settings
              _buildSectionTitle('Notifications'),
              const SizedBox(height: 8),
              _buildNotificationSettings(family),
              const SizedBox(height: 24),

              // Danger zone
              _buildSectionTitle('Zone de danger', isError: true),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _showLeaveDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
                child: const Text('Quitter la famille'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool isError = false}) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isError ? AppColors.error : null,
      ),
    );
  }

  Widget _buildAppearanceSettings() {
    final themeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
              color: themeMode == ThemeMode.dark
                  ? AppColors.darkPrimary
                  : AppColors.primaryMedium,
            ),
            title: const Text('Theme'),
            subtitle: Text(
              themeMode == ThemeMode.dark
                  ? 'Mode sombre'
                  : themeMode == ThemeMode.light
                      ? 'Mode clair'
                      : 'Automatique (systeme)',
            ),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode, size: 18),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (Set<ThemeMode> selection) {
                themeNotifier.setThemeMode(selection.first);
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyCard(Family family) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  radius: 24,
                  child: const Icon(Icons.family_restroom, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Code: ${family.inviteCode ?? "..."}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copier le code',
                  onPressed: () {
                    if (family.inviteCode != null) {
                      Clipboard.setData(ClipboardData(text: family.inviteCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copie!')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(FamilyMember member, String? currentUserId) {
    final isCurrentUser = member.odauyX6H2Z == currentUserId;
    final roleLabel = switch (member.role) {
      FamilyRole.admin => 'Admin',
      FamilyRole.parent => 'Parent',
      FamilyRole.child => 'Enfant',
    };

    return Card(
      child: ListTile(
        onTap: () => _showMemberEditDialog(member),
        leading: CircleAvatar(
          backgroundColor: member.isKid ? AppColors.fruits : AppColors.secondary,
          child: Icon(
            member.isKid ? Icons.child_care : Icons.person,
            color: Colors.white,
          ),
        ),
        title: Row(
          children: [
            Text(member.name),
            if (isCurrentUser)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Vous',
                  style: TextStyle(fontSize: 11, color: AppColors.primary),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(roleLabel),
            if (member.allergies.isNotEmpty)
              Wrap(
                spacing: 4,
                children: member.allergies.map((a) => Chip(
                  label: Text(a, style: const TextStyle(fontSize: 10)),
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        isThreeLine: member.allergies.isNotEmpty,
      ),
    );
  }

  void _showMemberEditDialog(FamilyMember member) {
    final selectedAllergies = List<String>.from(member.allergies);
    final avoidIngredients = List<String>.from(member.avoidIngredients);
    bool isKid = member.isKid;
    bool isPickyEater = member.isPickyEater;
    final avoidController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Modifier ${member.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Is kid toggle
                SwitchListTile(
                  value: isKid,
                  onChanged: (v) => setState(() => isKid = v),
                  title: const Text('Enfant'),
                  subtitle: const Text('Affiche les emojis pour noter'),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Allergies',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppConstants.commonAllergies.map((allergy) {
                    final isSelected = selectedAllergies.contains(allergy);
                    return FilterChip(
                      label: Text(allergy.replaceAll('_', ' ')),
                      selected: isSelected,
                      selectedColor: AppColors.error.withValues(alpha: 0.2),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedAllergies.add(allergy);
                          } else {
                            selectedAllergies.remove(allergy);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const Divider(),
                const SizedBox(height: 8),
                // Picky eater mode
                SwitchListTile(
                  value: isPickyEater,
                  onChanged: (v) => setState(() => isPickyEater = v),
                  title: const Text('Mangeur difficile'),
                  subtitle: const Text('Exclure certains ingredients'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (isPickyEater) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Ingredients a eviter',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: avoidController,
                          decoration: const InputDecoration(
                            hintText: 'Ex: champignons',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              setState(() {
                                avoidIngredients.add(value.trim().toLowerCase());
                                avoidController.clear();
                              });
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (avoidController.text.trim().isNotEmpty) {
                            setState(() {
                              avoidIngredients.add(avoidController.text.trim().toLowerCase());
                              avoidController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: avoidIngredients.map((ingredient) {
                      return Chip(
                        label: Text(ingredient),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() => avoidIngredients.remove(ingredient));
                        },
                        backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final familyId = ref.read(currentFamilyIdProvider);
                if (familyId == null) return;

                final updated = member.copyWith(
                  allergies: selectedAllergies,
                  isKid: isKid,
                  isPickyEater: isPickyEater,
                  avoidIngredients: avoidIngredients,
                );
                await ref.read(familyRepositoryProvider).updateMember(familyId, updated);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteButton(String? inviteCode) {
    return OutlinedButton.icon(
      onPressed: () {
        if (inviteCode != null) {
          _showInviteDialog(inviteCode);
        }
      },
      icon: const Icon(Icons.person_add),
      label: const Text('Inviter un membre'),
    );
  }

  Widget _buildMealSettings(Family family) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Global meal types
        Card(
          child: Column(
            children: AppConstants.defaultMealTypes.map((mealType) {
              final label = AppConstants.mealLabels[mealType] ?? mealType;
              final isEnabled = family.settings.enabledMeals.contains(mealType);
              final isPrimary = AppConstants.primaryMealTypes.contains(mealType);

              return CheckboxListTile(
                value: isEnabled,
                onChanged: (value) => _toggleMeal(family, mealType, value ?? false),
                title: Row(
                  children: [
                    Text(label),
                    if (isPrimary)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Principal',
                          style: TextStyle(fontSize: 11, color: AppColors.secondary),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        // Weekly schedule configuration
        Text(
          'Semaine type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.colorTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Desactivez les repas que vous ne planifiez pas',
          style: TextStyle(
            fontSize: 12,
            color: context.colorTextHint,
          ),
        ),
        const SizedBox(height: 8),
        _buildWeeklyScheduleGrid(family),
      ],
    );
  }

  Widget _buildWeeklyScheduleGrid(Family family) {
    // Show all enabled meals in the grid, ordered by defaultMealTypes
    final enabledMeals = AppConstants.defaultMealTypes
        .where((m) => family.settings.enabledMeals.contains(m))
        .toList();

    if (enabledMeals.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Activez au moins un repas pour configurer la semaine type.',
            style: TextStyle(color: context.colorTextHint),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header row with meal types
            Row(
              children: [
                const SizedBox(width: 60), // Space for day labels
                ...enabledMeals.map((meal) => Expanded(
                  child: Center(
                    child: Text(
                      AppConstants.mealLabels[meal] ?? meal,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 8),
            // Day rows
            ...List.generate(7, (dayIndex) {
              final dayOfWeek = dayIndex + 1; // 1 = Monday
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        AppConstants.weekDays[dayIndex].substring(0, 3),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colorTextSecondary,
                        ),
                      ),
                    ),
                    ...enabledMeals.map((meal) {
                      final isEnabled = family.settings.isMealEnabled(dayOfWeek, meal);
                      return Expanded(
                        child: Center(
                          child: GestureDetector(
                            onTap: () => _toggleMealSlot(family, dayOfWeek, meal),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isEnabled
                                    ? AppColors.primaryMedium
                                    : context.colorSurfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isEnabled
                                      ? AppColors.primaryMedium
                                      : context.colorTextHint.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                isEnabled ? Icons.check : Icons.close,
                                size: 20,
                                color: isEnabled
                                    ? Colors.white
                                    : context.colorTextHint,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleMealSlot(Family family, int dayOfWeek, String mealType) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    final newSettings = family.settings.toggleMealSlot(dayOfWeek, mealType);
    await ref.read(familyRepositoryProvider).updateFamily(
      familyId,
      settings: newSettings,
    );
  }

  Widget _buildNotificationSettings(Family family) {
    final settings = family.settings;
    // Options: 30min, 1h, 2h, 4h, 1 jour, 2 jours, 3 jours, 1 semaine, 2 semaines
    final reminderOptions = [
      30,          // 30 min
      60,          // 1 heure
      120,         // 2 heures
      240,         // 4 heures
      1440,        // 1 jour (24h)
      2880,        // 2 jours
      4320,        // 3 jours
      10080,       // 1 semaine
      20160,       // 2 semaines
    ];

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: settings.notificationsEnabled,
            onChanged: (value) => _toggleNotifications(family, value),
            title: const Text('Activer les rappels'),
            subtitle: const Text('Recevoir une notification si un repas n\'est pas planifie'),
            secondary: const Icon(Icons.notifications_outlined),
          ),
          if (settings.notificationsEnabled) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Rappeler avant le repas'),
              subtitle: Text(_formatMinutes(settings.reminderMinutesBefore)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showReminderTimePicker(family, reminderOptions),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    if (minutes < 1440) {
      // Less than a day, show hours
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) return '$hours h';
      return '$hours h $mins min';
    }
    if (minutes < 10080) {
      // Less than a week, show days
      final days = minutes ~/ 1440;
      return '$days jour${days > 1 ? 's' : ''}';
    }
    // Weeks
    final weeks = minutes ~/ 10080;
    return '$weeks semaine${weeks > 1 ? 's' : ''}';
  }

  Future<void> _toggleNotifications(Family family, bool enabled) async {
    if (enabled) {
      // Request permission first
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.initialize();
      final granted = await notificationService.requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission refusee pour les notifications')),
          );
        }
        return;
      }
    }

    final familyRepo = ref.read(familyRepositoryProvider);
    await familyRepo.updateFamily(
      family.id,
      settings: family.settings.copyWith(notificationsEnabled: enabled),
    );

    // Schedule or cancel reminders
    if (enabled) {
      await ref.read(mealReminderServiceProvider).scheduleReminders();
    } else {
      await ref.read(notificationServiceProvider).cancelAllNotifications();
    }
  }

  void _showReminderTimePicker(Family family, List<int> options) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rappeler combien de temps avant?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((minutes) {
            final isSelected = family.settings.reminderMinutesBefore == minutes;
            return ListTile(
              title: Text(_formatMinutes(minutes)),
              leading: Radio<int>(
                value: minutes,
                groupValue: family.settings.reminderMinutesBefore,
                onChanged: (value) async {
                  Navigator.pop(context);
                  if (value != null) {
                    await _updateReminderTime(family, value);
                  }
                },
              ),
              selected: isSelected,
              onTap: () async {
                Navigator.pop(context);
                await _updateReminderTime(family, minutes);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _updateReminderTime(Family family, int minutes) async {
    final familyRepo = ref.read(familyRepositoryProvider);
    await familyRepo.updateFamily(
      family.id,
      settings: family.settings.copyWith(reminderMinutesBefore: minutes),
    );

    // Reschedule reminders with new time
    if (family.settings.notificationsEnabled) {
      await ref.read(mealReminderServiceProvider).scheduleReminders();
    }
  }

  Future<void> _toggleMeal(Family family, String mealType, bool enabled) async {
    final meals = List<String>.from(family.settings.enabledMeals);
    if (enabled) {
      if (!meals.contains(mealType)) meals.add(mealType);
    } else {
      meals.remove(mealType);
    }

    final familyRepo = ref.read(familyRepositoryProvider);
    await familyRepo.updateFamily(
      family.id,
      settings: family.settings.copyWith(enabledMeals: meals),
    );
  }

  void _showInviteDialog(String code) {
    final familyAsync = ref.read(currentFamilyProvider);
    final familyName = familyAsync.value?.name ?? 'Popote';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person_add, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Inviter un membre'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Partagez ce code avec la personne a inviter:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Copy button
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copie!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copier'),
                ),
                const SizedBox(width: 12),
                // Share button
                ElevatedButton.icon(
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(
                        text: 'Rejoins notre famille "$familyName" sur Popote!\n\n'
                            'Code d\'invitation: $code\n\n'
                            'Telecharge l\'app et entre ce code pour nous rejoindre.',
                      ),
                    );
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Partager'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Regenerate code button
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _regenerateInviteCode();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Nouveau code'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _regenerateInviteCode() async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    try {
      final newCode = await ref.read(familyRepositoryProvider).regenerateInviteCode(familyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nouveau code: $newCode'),
            backgroundColor: AppColors.success,
          ),
        );
        // Show dialog with new code
        _showInviteDialog(newCode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _showLeaveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitter la famille?'),
        content: const Text(
          'Vous ne pourrez plus acceder aux recettes et plannings de cette famille.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _leaveFamily();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveFamily() async {
    final familyId = ref.read(currentFamilyIdProvider);
    final currentUser = ref.read(currentUserProvider);
    final members = ref.read(familyMembersProvider).value ?? [];

    if (familyId == null || currentUser == null) return;

    // Find current user's member record
    final myMember = members.where((m) => m.odauyX6H2Z == currentUser.uid).firstOrNull;
    if (myMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: membre non trouve')),
      );
      return;
    }

    try {
      // Remove member from family
      await ref.read(familyRepositoryProvider).removeMember(
        familyId,
        myMember.id,
        currentUser.uid,
      );

      // Clear current family selection
      ref.read(currentFamilyIdProvider.notifier).clearFamilyId();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous avez quitte la famille')),
        );
        // Go to family setup to join/create another family
        context.go(AppRoutes.familySetup);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se deconnecter?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authRepositoryProvider).signOut();
              if (mounted) context.go(AppRoutes.login);
            },
            child: const Text('Deconnecter'),
          ),
        ],
      ),
    );
  }
}
