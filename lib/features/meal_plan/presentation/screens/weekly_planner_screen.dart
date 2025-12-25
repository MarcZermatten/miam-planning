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
import '../../../dishes/domain/dish.dart';
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

    return Card(
      color: isToday ? AppColors.primary.withValues(alpha: 0.1) : null,
      child: ExpansionTile(
        initiallyExpanded: isToday,
        leading: CircleAvatar(
          backgroundColor: isToday ? AppColors.primary : AppColors.surfaceVariant,
          foregroundColor: isToday ? Colors.white : AppColors.textPrimary,
          child: Text('${day.day}'),
        ),
        title: Text(
          AppConstants.weekDays[dayIndex],
          style: TextStyle(
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: _buildDaySummary(dayMeals, enabledMeals),
        children: enabledMeals.map((mealType) {
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
    final hasAssignment = assignment != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: hasAssignment
            ? AppColors.primaryMedium.withValues(alpha: 0.08)
            : AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAssignment
              ? AppColors.primaryMedium.withValues(alpha: 0.3)
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
            color: hasAssignment ? AppColors.primaryMedium : AppColors.textHint.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getMealIcon(mealType),
            size: 18,
            color: Colors.white,
          ),
        ),
        title: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          hasAssignment ? assignment.recipeTitle : 'Tap pour ajouter',
          style: TextStyle(
            fontSize: 14,
            fontWeight: hasAssignment ? FontWeight.w600 : FontWeight.normal,
            color: hasAssignment ? AppColors.textPrimary : AppColors.textHint,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasAssignment)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.error,
                onPressed: () => _removeMeal(ref, day, mealType),
                tooltip: 'Supprimer',
              ),
            IconButton(
              icon: Icon(
                hasAssignment ? Icons.swap_horiz : Icons.add_circle,
                size: 22,
              ),
              color: AppColors.primaryDark,
              onPressed: () => _showRecipeSelector(context, ref, day, mealType),
              tooltip: hasAssignment ? 'Changer' : 'Ajouter',
            ),
          ],
        ),
        onTap: () {
          if (hasAssignment) {
            context.push('/recipes/${assignment.recipeId}');
          } else {
            _showRecipeSelector(context, ref, day, mealType);
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

  void _showRecipeSelector(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    String mealType,
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
              _setMeal(ref, day, mealType, recipe);
            },
            onSelectFrozen: (dish) {
              Navigator.pop(context);
              _setMealFromFreezer(context, ref, day, mealType, dish);
            },
          );
        },
      ),
    );
  }

  Future<void> _setMeal(
    WidgetRef ref,
    DateTime day,
    String mealType,
    Recipe recipe,
  ) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    await ref.read(mealPlanRepositoryProvider).setMeal(
          familyId: familyId,
          date: day,
          mealType: mealType,
          assignment: MealAssignment(
            dishes: [
              DishAssignment(
                dishId: recipe.dishId ?? recipe.id,
                dishName: recipe.title,
                recipeId: recipe.id,
                recipeName: recipe.displayName,
              ),
            ],
          ),
        );
  }

  Future<void> _setMealFromFreezer(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    String mealType,
    Dish dish,
  ) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    // Set the meal with fromFreezer flag
    await ref.read(mealPlanRepositoryProvider).setMeal(
          familyId: familyId,
          date: day,
          mealType: mealType,
          assignment: MealAssignment(
            dishes: [
              DishAssignment(
                dishId: dish.id,
                dishName: dish.name,
                fromFreezer: true,
                portionsUsed: 1,
              ),
            ],
          ),
        );

    // Decrement frozen portions
    await ref.read(dishRepositoryProvider).useFromFreezer(
          familyId: familyId,
          dishId: dish.id,
          portions: 1,
        );

    // Show confirmation
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${dish.name} ajoute depuis le congelo'),
          backgroundColor: AppColors.info,
          action: SnackBarAction(
            label: 'Annuler',
            textColor: Colors.white,
            onPressed: () async {
              // Undo: remove meal and restore portion
              await ref.read(mealPlanRepositoryProvider).removeMeal(
                    familyId: familyId,
                    date: day,
                    mealType: mealType,
                  );
              await ref.read(dishRepositoryProvider).addToFreezer(
                    familyId: familyId,
                    dishId: dish.id,
                    portions: 1,
                  );
            },
          ),
        ),
      );
    }
  }

  Future<void> _removeMeal(
    WidgetRef ref,
    DateTime day,
    String mealType,
  ) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    await ref.read(mealPlanRepositoryProvider).removeMeal(
          familyId: familyId,
          date: day,
          mealType: mealType,
        );
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

/// Bottom sheet for selecting a recipe or frozen dish
class _RecipeSelectorSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final Function(Recipe) onSelectRecipe;
  final Function(Dish) onSelectFrozen;

  const _RecipeSelectorSheet({
    required this.scrollController,
    required this.onSelectRecipe,
    required this.onSelectFrozen,
  });

  @override
  ConsumerState<_RecipeSelectorSheet> createState() => _RecipeSelectorSheetState();
}

class _RecipeSelectorSheetState extends ConsumerState<_RecipeSelectorSheet>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(familyRecipesProvider);
    final pantryNames = ref.watch(availableIngredientNamesProvider);
    final frozenDishes = ref.watch(frozenDishesProvider);

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
          tabs: [
            const Tab(
              icon: Icon(Icons.restaurant_menu, size: 20),
              text: 'Recettes',
            ),
            Tab(
              icon: const Icon(Icons.ac_unit, size: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Congelo'),
                  frozenDishes.when(
                    data: (dishes) => dishes.isNotEmpty
                        ? Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.info,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${dishes.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
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
}

class _ScoredRecipe {
  final Recipe recipe;
  final double matchPercent;

  _ScoredRecipe({required this.recipe, required this.matchPercent});
}
