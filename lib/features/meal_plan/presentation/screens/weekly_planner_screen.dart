import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../family/data/family_repository.dart';
import '../../../pantry/data/pantry_repository.dart';
import '../../../recipes/data/recipe_repository.dart';
import '../../../recipes/domain/recipe.dart';
import '../../../dishes/data/dish_repository.dart';
import '../../../dishes/data/quick_dish_repository.dart';
import '../../../dishes/domain/dish.dart';
import '../../../dishes/domain/quick_dish.dart';
import '../../data/meal_plan_repository.dart';
import '../../domain/meal_plan.dart';

class WeeklyPlannerScreen extends ConsumerWidget {
  const WeeklyPlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(selectedWeekStartProvider);
    final mealPlanAsync = ref.watch(currentMealPlanProvider);
    final family = ref.watch(currentFamilyProvider).value;
    final enabledMeals = family?.settings.enabledMeals ?? ['lunch', 'dinner'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy),
            tooltip: 'Copier la semaine',
            onPressed: () => _showCopyDialog(context, ref, weekStart),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Vider la semaine',
            onPressed: () => _confirmClearWeek(context, ref, weekStart),
          ),
        ],
      ),
      body: Column(
        children: [
          // Week selector
          _buildWeekSelector(context, ref, weekStart),

          // Days list
          Expanded(
            child: mealPlanAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (mealPlan) => ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final day = weekStart.add(Duration(days: index));
                  return _buildDayCard(
                    context,
                    ref,
                    day,
                    index,
                    mealPlan,
                    enabledMeals,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekSelector(BuildContext context, WidgetRef ref, DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final isCurrentWeek = _isSameWeek(weekStart, DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: AppColors.surfaceVariant,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              ref.read(selectedWeekOffsetProvider.notifier).state--;
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: isCurrentWeek
                  ? null
                  : () {
                      ref.read(selectedWeekOffsetProvider.notifier).state = 0;
                    },
              child: Column(
                children: [
                  Text(
                    '${weekStart.day}/${weekStart.month} - ${weekEnd.day}/${weekEnd.month}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isCurrentWeek)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMedium.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Cette semaine',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              ref.read(selectedWeekOffsetProvider.notifier).state++;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    int dayIndex,
    MealPlan? mealPlan,
    List<String> enabledMeals,
  ) {
    final isToday = _isSameDay(day, DateTime.now());
    final dayMeals = mealPlan?.getMealsForDate(day) ?? DayMeals();
    final family = ref.watch(currentFamilyProvider).value;
    final dayOfWeek = day.weekday; // 1=Monday, 7=Sunday

    // Filter meals based on weekly schedule config
    final mealsForThisDay = enabledMeals.where((mealType) {
      return family?.settings.isMealEnabled(dayOfWeek, mealType) ?? true;
    }).toList();

    // Don't show days with no meals to plan
    if (mealsForThisDay.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isToday ? (isDark ? AppColors.darkPrimary.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1)) : null,
      child: ExpansionTile(
        initiallyExpanded: isToday,
        leading: CircleAvatar(
          backgroundColor: isToday
              ? (isDark ? AppColors.darkPrimary : AppColors.primary)
              : (isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant),
          foregroundColor: isToday
              ? Colors.white
              : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          child: Text('${day.day}'),
        ),
        title: Text(
          AppConstants.weekDays[dayIndex],
          style: TextStyle(
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: _buildDaySummary(dayMeals, mealsForThisDay),
        children: mealsForThisDay.map((mealType) {
          final assignment = dayMeals.getMeal(mealType);
          final label = AppConstants.mealLabels[mealType] ?? mealType;

          return _buildMealSlot(
            context,
            ref,
            day,
            mealType,
            label,
            assignment,
          );
        }).toList(),
      ),
    );
  }

  Widget? _buildDaySummary(DayMeals dayMeals, List<String> enabledMeals) {
    final planned = enabledMeals.where((m) => dayMeals.getMeal(m) != null).length;
    if (planned == 0) {
      return const Text(
        'Aucun repas planifie',
        style: TextStyle(fontSize: 12, color: AppColors.textHint),
      );
    }

    final isComplete = planned == enabledMeals.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isComplete ? Icons.check_circle : Icons.schedule,
          size: 14,
          color: isComplete ? AppColors.success : AppColors.warning,
        ),
        const SizedBox(width: 4),
        Text(
          '$planned/${enabledMeals.length} repas',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isComplete ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMealSlot(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    String mealType,
    String label,
    MealAssignment? assignment,
  ) {
    final hasAssignment = assignment != null && assignment.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: hasAssignment
            ? (isDark ? AppColors.darkPrimary.withValues(alpha: 0.15) : AppColors.primaryMedium.withValues(alpha: 0.08))
            : (isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5) : AppColors.surfaceVariant.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAssignment
              ? (isDark ? AppColors.darkPrimary.withValues(alpha: 0.4) : AppColors.primaryMedium.withValues(alpha: 0.3))
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: hasAssignment
                ? (isDark ? AppColors.darkPrimaryDark : AppColors.primaryMedium)
                : (isDark ? AppColors.darkTextHint.withValues(alpha: 0.3) : AppColors.textHint.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getMealIcon(mealType),
            size: 18,
            color: Colors.white,
          ),
        ),
        title: Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            if (hasAssignment) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                size: 16,
                color: AppColors.success,
              ),
            ],
          ],
        ),
        subtitle: Text(
          hasAssignment
              ? _formatMealDisplay(assignment)
              : 'Tap pour ajouter',
          style: TextStyle(
            fontSize: 14,
            fontWeight: hasAssignment ? FontWeight.w600 : FontWeight.normal,
            color: hasAssignment
                ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                : (isDark ? AppColors.darkTextHint : AppColors.textHint),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasAssignment)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.error,
                onPressed: () => _removeMeal(context, ref, day, mealType),
                tooltip: 'Supprimer tout',
              ),
            if (hasAssignment)
              IconButton(
                icon: Icon(
                  assignment.accompaniment != null ? Icons.rice_bowl : Icons.rice_bowl_outlined,
                  size: 20,
                ),
                color: assignment.accompaniment != null ? AppColors.primary : AppColors.textHint,
                onPressed: () => _showAccompanimentSelector(context, ref, day, mealType, assignment),
                tooltip: assignment.accompaniment ?? 'Ajouter accompagnement',
              ),
            IconButton(
              icon: Icon(
                hasAssignment ? Icons.add : Icons.add_circle,
                size: 22,
              ),
              color: AppColors.primaryDark,
              onPressed: () => _showRecipeSelector(context, ref, day, mealType, assignment),
              tooltip: hasAssignment ? 'Ajouter un plat' : 'Ajouter',
            ),
          ],
        ),
        onTap: () {
          if (hasAssignment && assignment.dishes.length == 1) {
            // Single dish - show details
            final dish = assignment.dishes.first;
            if (dish.recipeId != null) {
              context.push('/recipes/${dish.recipeId}');
            }
          } else if (hasAssignment) {
            // Multiple dishes - show selector to add more
            _showRecipeSelector(context, ref, day, mealType, assignment);
          } else {
            _showRecipeSelector(context, ref, day, mealType, null);
          }
        },
      ),
    );
  }

  IconData _getMealIcon(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      case 'snack':
        return Icons.cookie;
      default:
        return Icons.restaurant;
    }
  }

  /// Format meal display with dishes and optional accompaniment
  String _formatMealDisplay(MealAssignment assignment) {
    final dishNames = assignment.dishes.map((d) => d.dishName).join(' + ');
    if (assignment.accompaniment != null && assignment.accompaniment!.isNotEmpty) {
      return '$dishNames + ${assignment.accompaniment}';
    }
    return dishNames;
  }

  /// Show accompaniment selector bottom sheet
  void _showAccompanimentSelector(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    String mealType,
    MealAssignment assignment,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.rice_bowl, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Accompagnement',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (assignment.accompaniment != null)
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _setAccompaniment(ref, day, mealType, assignment, null);
                      },
                      child: const Text('Retirer'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: defaultAccompaniments.map((acc) {
                      final isSelected = assignment.accompaniment == acc;
                      return ChoiceChip(
                        label: Text(acc),
                        selected: isSelected,
                        onSelected: (_) async {
                          Navigator.pop(context);
                          await _setAccompaniment(ref, day, mealType, assignment, acc);
                        },
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Set accompaniment for a meal
  Future<void> _setAccompaniment(
    WidgetRef ref,
    DateTime day,
    String mealType,
    MealAssignment assignment,
    String? accompaniment,
  ) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    final updatedAssignment = MealAssignment(
      dishes: assignment.dishes,
      accompaniment: accompaniment,
      note: assignment.note,
    );

    await ref.read(mealPlanRepositoryProvider).setMeal(
          familyId: familyId,
          date: day,
          mealType: mealType,
          assignment: updatedAssignment,
        );
  }

  void _showRecipeSelector(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    String mealType,
    MealAssignment? currentAssignment,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _RecipeSelectorSheet(
            scrollController: scrollController,
            onSelectRecipe: (recipe) {
              Navigator.pop(context);
              _addMeal(ref, day, mealType, recipe, currentAssignment);
            },
            onSelectFrozen: (dish) {
              Navigator.pop(context);
              _addMealFromFreezer(context, ref, day, mealType, dish, currentAssignment);
            },
            onSelectQuickDish: (quickDish) {
              Navigator.pop(context);
              _addMealFromQuickDish(ref, day, mealType, quickDish, currentAssignment);
            },
            onCreateQuickDish: (name, categories) async {
              Navigator.pop(context);
              await _createAndAddQuickDish(ref, day, mealType, name, categories, currentAssignment);
            },
          );
        },
      ),
    );
  }

  Future<void> _addMeal(
    WidgetRef ref,
    DateTime day,
    String mealType,
    Recipe recipe,
    MealAssignment? currentAssignment,
  ) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    // Create new dish assignment
    final newDish = DishAssignment(
      dishId: recipe.dishId ?? recipe.id,
      dishName: recipe.title,
      recipeId: recipe.id,
      recipeName: recipe.displayName,
      categories: ['complete'], // Default: assume complete meal
    );

    // Add to existing dishes or create new assignment
    final dishes = currentAssignment != null
        ? [...currentAssignment.dishes, newDish]
        : [newDish];

    await ref.read(mealPlanRepositoryProvider).setMeal(
          familyId: familyId,
          date: day,
          mealType: mealType,
          assignment: MealAssignment(dishes: dishes),
        );
  }

  Future<void> _addMealFromFreezer(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    String mealType,
    Dish dish,
    MealAssignment? currentAssignment,
  ) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    // Show dialog to select number of portions
    final portions = await _showPortionsDialog(context, dish);
    if (portions == null || portions <= 0) return;

    // Create new dish assignment
    final newDish = DishAssignment(
      dishId: dish.id,
      dishName: dish.name,
      fromFreezer: true,
      portionsUsed: portions,
      categories: dish.categories.map((c) => c.name).toList(),
    );

    // Add to existing dishes or create new assignment
    final dishes = currentAssignment != null
        ? [...currentAssignment.dishes, newDish]
        : [newDish];

    // Set the meal
    await ref.read(mealPlanRepositoryProvider).setMeal(
          familyId: familyId,
          date: day,
          mealType: mealType,
          assignment: MealAssignment(dishes: dishes),
        );

    // Decrement frozen portions
    await ref.read(dishRepositoryProvider).useFromFreezer(
          familyId: familyId,
          dishId: dish.id,
          portions: portions,
        );

    // Show confirmation
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${dish.name} ($portions portion${portions > 1 ? 's' : ''}) ajoute'),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  /// Add meal from a quick dish
  Future<void> _addMealFromQuickDish(
    WidgetRef ref,
    DateTime day,
    String mealType,
    QuickDish quickDish,
    MealAssignment? currentAssignment,
  ) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    // Create new dish assignment
    final newDish = DishAssignment(
      dishId: 'quick_${quickDish.id}',
      dishName: quickDish.name,
      categories: quickDish.categories.map((c) => c.name).toList(),
    );

    // Add to existing dishes or create new assignment
    final dishes = currentAssignment != null
        ? [...currentAssignment.dishes, newDish]
        : [newDish];

    await ref.read(mealPlanRepositoryProvider).setMeal(
          familyId: familyId,
          date: day,
          mealType: mealType,
          assignment: MealAssignment(
            dishes: dishes,
            accompaniment: currentAssignment?.accompaniment,
          ),
        );

    // Increment usage count
    await ref.read(quickDishRepositoryProvider).incrementUsage(familyId, quickDish.id);
  }

  /// Create a new quick dish and add it to the meal
  Future<void> _createAndAddQuickDish(
    WidgetRef ref,
    DateTime day,
    String mealType,
    String name,
    List<DishCategory> categories,
    MealAssignment? currentAssignment,
  ) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    // Create the quick dish
    final quickDish = await ref.read(quickDishRepositoryProvider).createQuickDish(
          familyId: familyId,
          name: name,
          categories: categories,
        );

    // Create new dish assignment
    final newDish = DishAssignment(
      dishId: 'quick_${quickDish.id}',
      dishName: quickDish.name,
      categories: quickDish.categories.map((c) => c.name).toList(),
    );

    // Add to existing dishes or create new assignment
    final dishes = currentAssignment != null
        ? [...currentAssignment.dishes, newDish]
        : [newDish];

    await ref.read(mealPlanRepositoryProvider).setMeal(
          familyId: familyId,
          date: day,
          mealType: mealType,
          assignment: MealAssignment(
            dishes: dishes,
            accompaniment: currentAssignment?.accompaniment,
          ),
        );
  }

  /// Show dialog to select number of portions
  Future<int?> _showPortionsDialog(BuildContext context, Dish dish) async {
    int selectedPortions = 1;
    final maxPortions = dish.frozenPortions;

    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Portions de ${dish.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$maxPortions portion${maxPortions > 1 ? 's' : ''} disponible${maxPortions > 1 ? 's' : ''}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: selectedPortions > 1
                        ? () => setDialogState(() => selectedPortions--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 32,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$selectedPortions',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: selectedPortions < maxPortions
                        ? () => setDialogState(() => selectedPortions++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 32,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedPortions),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeMeal(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    String mealType,
  ) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    // Get current meal assignment to check for frozen dishes
    final mealPlan = ref.read(currentMealPlanProvider).value;
    final dayMeals = mealPlan?.getMealsForDate(day);
    final assignment = dayMeals?.getMeal(mealType);

    // Find dishes from freezer
    final frozenDishes = assignment?.dishes
            .where((d) => d.fromFreezer && d.portionsUsed > 0)
            .toList() ??
        [];

    // If there are frozen dishes, ask for confirmation to restore portions
    if (frozenDishes.isNotEmpty) {
      final totalPortions =
          frozenDishes.fold<int>(0, (sum, d) => sum + d.portionsUsed);
      final dishNames = frozenDishes.map((d) => d.dishName).join(', ');

      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Supprimer le repas?'),
          content: Text(
            'Ce repas contient $totalPortions portion(s) du congelateur ($dishNames).\n\n'
            'Voulez-vous remettre ces portions au congelateur?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null), // Cancel
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false), // Delete without restore
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Supprimer sans restaurer'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true), // Restore
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Restaurer au congelo'),
            ),
          ],
        ),
      );

      // User cancelled
      if (shouldRestore == null) return;

      // Remove the meal
      await ref.read(mealPlanRepositoryProvider).removeMeal(
            familyId: familyId,
            date: day,
            mealType: mealType,
          );

      // Restore portions if requested
      if (shouldRestore) {
        for (final dish in frozenDishes) {
          await ref.read(dishRepositoryProvider).addToFreezer(
                familyId: familyId,
                dishId: dish.dishId,
                portions: dish.portionsUsed,
              );
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$totalPortions portion(s) remise(s) au congelateur'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } else {
      // No frozen dishes, just remove the meal
      await ref.read(mealPlanRepositoryProvider).removeMeal(
            familyId: familyId,
            date: day,
            mealType: mealType,
          );
    }
  }

  void _showCopyDialog(BuildContext context, WidgetRef ref, DateTime weekStart) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copier la semaine'),
        content: const Text(
          'Copier tous les repas de cette semaine vers la semaine suivante?',
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

              await ref.read(mealPlanRepositoryProvider).copyWeek(
                    familyId: familyId,
                    sourceWeekStart: weekStart,
                    targetWeekStart: weekStart.add(const Duration(days: 7)),
                  );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Semaine copiee!')),
                );
              }
            },
            child: const Text('Copier'),
          ),
        ],
      ),
    );
  }

  void _confirmClearWeek(BuildContext context, WidgetRef ref, DateTime weekStart) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider la semaine?'),
        content: const Text('Supprimer tous les repas planifies pour cette semaine?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final familyId = ref.read(currentFamilyIdProvider);
              if (familyId == null) return;

              await ref.read(mealPlanRepositoryProvider).clearWeek(
                    familyId,
                    weekStart,
                  );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameWeek(DateTime a, DateTime b) {
    final aStart = MealPlan.getWeekStart(a);
    final bStart = MealPlan.getWeekStart(b);
    return _isSameDay(aStart, bStart);
  }
}

/// Bottom sheet for selecting a recipe, frozen dish, or quick dish
class _RecipeSelectorSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final Function(Recipe) onSelectRecipe;
  final Function(Dish) onSelectFrozen;
  final Function(QuickDish) onSelectQuickDish;
  final Function(String name, List<DishCategory> categories) onCreateQuickDish;

  const _RecipeSelectorSheet({
    required this.scrollController,
    required this.onSelectRecipe,
    required this.onSelectFrozen,
    required this.onSelectQuickDish,
    required this.onCreateQuickDish,
  });

  @override
  ConsumerState<_RecipeSelectorSheet> createState() => _RecipeSelectorSheetState();
}

class _RecipeSelectorSheetState extends ConsumerState<_RecipeSelectorSheet>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  late TabController _tabController;

  // Quick dish creation state
  final _quickDishNameController = TextEditingController();
  final Set<DishCategory> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _quickDishNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(familyRecipesProvider);
    final pantryNames = ref.watch(availableIngredientNamesProvider);
    final frozenDishes = ref.watch(frozenDishesProvider);
    final quickDishes = ref.watch(familyQuickDishesProvider);

    return Column(
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textHint,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Title with tabs
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryDark,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            const Tab(
              icon: Icon(Icons.restaurant_menu, size: 18),
              text: 'Recettes',
            ),
            Tab(
              icon: const Icon(Icons.ac_unit, size: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Congelo'),
                  frozenDishes.when(
                    data: (dishes) => dishes.isNotEmpty
                        ? Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.info,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${dishes.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const Tab(
              icon: Icon(Icons.flash_on, size: 18),
              text: 'Rapide',
            ),
          ],
        ),

        // Search (only for recipes tab)
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            if (_tabController.index == 0) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Rechercher une recette...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              );
            }
            return const SizedBox(height: 8);
          },
        ),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Recipes
              _buildRecipesList(recipesAsync, pantryNames),
              // Tab 2: Frozen dishes
              _buildFrozenList(frozenDishes),
              // Tab 3: Quick dishes
              _buildQuickDishList(quickDishes),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecipesList(AsyncValue<List<Recipe>> recipesAsync, Set<String> pantryNames) {
    return recipesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (recipes) {
        var filtered = _searchQuery.isEmpty
            ? recipes
            : recipes.where((r) {
                return r.title.toLowerCase().contains(_searchQuery.toLowerCase());
              }).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text('Aucune recette trouvee'));
        }

        final scored = filtered.map((recipe) {
          final score = _calculateMatchScore(recipe, pantryNames);
          return _ScoredRecipe(recipe: recipe, matchPercent: score);
        }).toList();

        scored.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));

        return ListView.builder(
          controller: widget.scrollController,
          itemCount: scored.length,
          itemBuilder: (context, index) {
            final item = scored[index];
            final recipe = item.recipe;
            final matchPercent = item.matchPercent;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.surfaceVariant,
                child: recipe.imageUrl != null
                    ? ClipOval(
                        child: Image.network(
                          recipe.imageUrl!,
                          fit: BoxFit.cover,
                          width: 40,
                          height: 40,
                          errorBuilder: (_, __, ___) => const Icon(Icons.restaurant),
                        ),
                      )
                    : const Icon(Icons.restaurant),
              ),
              title: Text(recipe.title),
              subtitle: Row(
                children: [
                  Text('${recipe.totalTime} min'),
                  if (matchPercent > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getMatchColor(matchPercent).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(matchPercent * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getMatchColor(matchPercent),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (matchPercent >= 1.0)
                    const Tooltip(
                      message: 'Tous les ingredients disponibles!',
                      child: Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    ),
                  if (recipe.isKidApproved)
                    const Icon(Icons.child_care, color: AppColors.fruits, size: 20),
                ],
              ),
              onTap: () => widget.onSelectRecipe(recipe),
            );
          },
        );
      },
    );
  }

  Widget _buildFrozenList(AsyncValue<List<Dish>> frozenDishes) {
    return frozenDishes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (dishes) {
        if (dishes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.ac_unit, size: 48, color: AppColors.textHint),
                const SizedBox(height: 16),
                const Text(
                  'Aucun plat congele',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ajoutez des plats dans Frigo > Congelo',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: dishes.length,
          itemBuilder: (context, index) {
            final dish = dishes[index];
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.ac_unit, color: AppColors.info),
              ),
              title: Text(dish.name),
              subtitle: Text(
                '${dish.categoriesDisplay} - ${dish.frozenPortions} portion(s)',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${dish.frozenPortions}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onTap: () => widget.onSelectFrozen(dish),
            );
          },
        );
      },
    );
  }

  double _calculateMatchScore(Recipe recipe, Set<String> pantryNames) {
    if (pantryNames.isEmpty) return 0;

    final needed = recipe.ingredients
        .where((i) => !i.isPantryStaple)
        .map((i) => i.name.toLowerCase().trim())
        .toList();

    if (needed.isEmpty) return 1.0;

    final matched = needed.where((name) {
      return pantryNames.any((pantry) =>
          pantry.contains(name) || name.contains(pantry));
    }).length;

    return matched / needed.length;
  }

  Color _getMatchColor(double percent) {
    if (percent >= 0.8) return AppColors.success;
    if (percent >= 0.5) return AppColors.warning;
    return AppColors.info;
  }

  Widget _buildQuickDishList(AsyncValue<List<QuickDish>> quickDishesAsync) {
    return quickDishesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (quickDishes) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick creation form
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ajouter un plat rapide',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _quickDishNameController,
                            decoration: const InputDecoration(
                              hintText: 'Nom du plat...',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _submitQuickDish(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _submitQuickDish,
                          icon: const Icon(Icons.add_circle),
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Category chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        DishCategory.vegetable,
                        DishCategory.starch,
                        DishCategory.protein,
                        DishCategory.complete,
                      ].map((category) {
                        final isSelected = _selectedCategories.contains(category);
                        return FilterChip(
                          label: Text(
                            '${category.icon} ${category.label}',
                            style: TextStyle(fontSize: 11),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCategories.add(category);
                              } else {
                                _selectedCategories.remove(category);
                              }
                            });
                          },
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Existing quick dishes
              if (quickDishes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.flash_on, size: 48, color: AppColors.textHint),
                        SizedBox(height: 16),
                        Text(
                          'Aucun plat rapide',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Creez des plats simples pour les reutiliser',
                          style: TextStyle(fontSize: 12, color: AppColors.textHint),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Plats recents (${quickDishes.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ...quickDishes.map((quickDish) => ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            quickDish.categoriesDisplay.isNotEmpty
                                ? quickDish.categoriesDisplay
                                : '🍽️',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      title: Text(quickDish.name),
                      subtitle: Text(
                        'Utilise ${quickDish.usageCount}x',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${quickDish.usageCount}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      onTap: () => widget.onSelectQuickDish(quickDish),
                    )),
              ],
            ],
          ),
        );
      },
    );
  }

  void _submitQuickDish() {
    final name = _quickDishNameController.text.trim();
    if (name.isEmpty) return;

    widget.onCreateQuickDish(name, _selectedCategories.toList());
    _quickDishNameController.clear();
    setState(() {
      _selectedCategories.clear();
    });
  }
}

class _ScoredRecipe {
  final Recipe recipe;
  final double matchPercent;

  _ScoredRecipe({required this.recipe, required this.matchPercent});
}
