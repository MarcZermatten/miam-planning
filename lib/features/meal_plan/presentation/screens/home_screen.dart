import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../routing/app_router.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../family/data/family_repository.dart';
import '../../../recipes/data/recipe_repository.dart';
import '../../data/meal_plan_repository.dart';
import '../widgets/freezer_card.dart';
import '../widgets/meal_stats_card.dart';
import '../widgets/wines_alert_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final dayName = AppConstants.weekDays[today.weekday - 1];
    final currentUser = ref.watch(currentUserProvider);
    final mealPlanAsync = ref.watch(currentMealPlanProvider);
    final family = ref.watch(currentFamilyProvider).value;
    final enabledMeals = family?.settings.enabledMeals ?? ['lunch', 'dinner'];
    final recipesAsync = ref.watch(familyRecipesProvider);

    // Get user's first name
    String greeting = 'Bonjour';
    if (currentUser != null && currentUser.displayName != null) {
      final firstName = currentUser.displayName!.split(' ').first;
      greeting = 'Bonjour $firstName';
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/popote_logo.png',
                height: 32,
                width: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Popote'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.family_restroom),
            onPressed: () => context.push(AppRoutes.familySettings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text(
              '$greeting !',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '$dayName ${today.day}/${today.month}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),

            // Today's meals (from actual meal plan)
            const Text(
              'Repas du jour',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            mealPlanAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erreur: $e'),
              data: (mealPlan) {
                final dayMeals = mealPlan?.getMealsForDate(today);
                return Column(
                  children: enabledMeals.map((mealType) {
                    final assignment = dayMeals?.getMeal(mealType);
                    final label = AppConstants.mealLabels[mealType] ?? mealType;
                    final icon = _getMealIcon(mealType);
                    final color = _getMealColor(mealType);

                    // Format meal display with accompaniment
                    String mealDisplay = 'Non planifie';
                    if (assignment != null && assignment.isNotEmpty) {
                      mealDisplay = assignment.recipeTitle;
                      if (assignment.accompaniment != null &&
                          assignment.accompaniment!.isNotEmpty) {
                        mealDisplay += ' + ${assignment.accompaniment}';
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildMealCard(
                        context,
                        label,
                        mealDisplay,
                        icon,
                        color,
                        hasRecipe: assignment != null && assignment.isNotEmpty,
                        onTap: assignment != null && assignment.isNotEmpty
                            ? () => context.push('/recipes/${assignment.recipeId}')
                            : () => context.go(AppRoutes.weeklyPlanner),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),

            // Quick actions
            const Text(
              'Actions rapides',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildQuickAction(
              context,
              'Ajouter recette',
              Icons.add_circle_outline,
              AppColors.primaryMedium,
              () => context.push(AppRoutes.addRecipe),
            ),
            const SizedBox(height: 24),

            // Meal statistics
            const MealStatsCard(),
            const SizedBox(height: 24),

            // Freezer summary
            const FreezerCard(),
            const SizedBox(height: 24),

            // Wines to consume soon
            const WinesAlertCard(),
            const SizedBox(height: 24),

            // Popular recipes
            recipesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (recipes) {
                final popular = recipes.where((r) => r.ratings.isNotEmpty).toList()
                  ..sort((a, b) => (b.averageRating ?? 0).compareTo(a.averageRating ?? 0));

                if (popular.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recettes populaires',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.recipes),
                          child: const Text('Voir tout'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...popular.take(3).map((recipe) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceVariant,
                          backgroundImage: recipe.imageUrl != null
                              ? NetworkImage(recipe.imageUrl!)
                              : null,
                          child: recipe.imageUrl == null
                              ? const Icon(Icons.restaurant)
                              : null,
                        ),
                        title: Text(recipe.title),
                        subtitle: Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: AppColors.warning),
                            const SizedBox(width: 4),
                            Text('${recipe.averageRating?.toStringAsFixed(1) ?? "-"}'),
                            if (recipe.isKidApproved) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.child_care, size: 16, color: AppColors.fruits),
                            ],
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/recipes/${recipe.id}'),
                      ),
                    )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMealIcon(String mealType) {
    return switch (mealType) {
      'breakfast' => Icons.free_breakfast_outlined,
      'lunch' => Icons.wb_sunny_outlined,
      'snack' => Icons.cookie_outlined,
      'dinner' => Icons.nightlight_outlined,
      _ => Icons.restaurant,
    };
  }

  Color _getMealColor(String mealType) {
    return switch (mealType) {
      'breakfast' => Colors.orange,
      'lunch' => Colors.amber,
      'snack' => AppColors.fruits,
      'dinner' => Colors.indigo,
      _ => AppColors.primary,
    };
  }

  Widget _buildMealCard(
    BuildContext context,
    String mealType,
    String recipeName,
    IconData icon,
    Color color, {
    bool hasRecipe = false,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(mealType),
        subtitle: Text(
          recipeName,
          style: TextStyle(
            color: hasRecipe ? AppColors.textPrimary : AppColors.textHint,
            fontWeight: hasRecipe ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        trailing: Icon(
          hasRecipe ? Icons.chevron_right : Icons.add_circle_outline,
          color: hasRecipe ? null : AppColors.textHint,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
