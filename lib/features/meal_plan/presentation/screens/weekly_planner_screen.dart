import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../family/data/family_repository.dart';
import '../../../pantry/data/pantry_repository.dart';
import '../../../recipes/data/recipe_repository.dart';
import '../../../recipes/domain/recipe.dart';
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
                    const Text(
                      'Cette semaine',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
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
    if (planned == 0) return null;

    return Text(
      '$planned/${enabledMeals.length} repas planifies',
      style: const TextStyle(fontSize: 12, color: AppColors.secondary),
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
    return ListTile(
      dense: true,
      leading: const SizedBox(width: 40),
      title: Text(label),
      subtitle: Text(
        assignment?.recipeTitle ?? 'Non planifie',
        style: TextStyle(
          color: assignment != null ? AppColors.textPrimary : AppColors.textHint,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (assignment != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => _removeMeal(ref, day, mealType),
            ),
          IconButton(
            icon: Icon(
              assignment != null ? Icons.swap_horiz : Icons.add_circle_outline,
              color: AppColors.primary,
            ),
            onPressed: () => _showRecipeSelector(context, ref, day, mealType),
          ),
        ],
      ),
      onTap: assignment != null
          ? () => context.push('/recipes/${assignment.recipeId}')
          : null,
    );
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
            onSelect: (recipe) {
              Navigator.pop(context);
              _setMeal(ref, day, mealType, recipe);
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
            recipeId: recipe.id,
            recipeTitle: recipe.title,
          ),
        );
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

/// Bottom sheet for selecting a recipe
class _RecipeSelectorSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final Function(Recipe) onSelect;

  const _RecipeSelectorSheet({
    required this.scrollController,
    required this.onSelect,
  });

  @override
  ConsumerState<_RecipeSelectorSheet> createState() => _RecipeSelectorSheetState();
}

class _RecipeSelectorSheetState extends ConsumerState<_RecipeSelectorSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(familyRecipesProvider);
    final pantryNames = ref.watch(availableIngredientNamesProvider);

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

        // Title
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Choisir une recette',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        const SizedBox(height: 8),

        // Recipe list
        Expanded(
          child: recipesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (recipes) {
              var filtered = _searchQuery.isEmpty
                  ? recipes
                  : recipes.where((r) {
                      return r.title.toLowerCase().contains(_searchQuery.toLowerCase());
                    }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text('Aucune recette trouvee'),
                );
              }

              // Calculate match score and sort by it
              final scored = filtered.map((recipe) {
                final score = _calculateMatchScore(recipe, pantryNames);
                return _ScoredRecipe(recipe: recipe, matchPercent: score);
              }).toList();

              // Sort: best matches first
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
                    onTap: () => widget.onSelect(recipe),
                  );
                },
              );
            },
          ),
        ),
      ],
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
