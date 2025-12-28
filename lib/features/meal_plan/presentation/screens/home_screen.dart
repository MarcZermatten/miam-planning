import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../routing/app_router.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../family/data/family_repository.dart';
import '../../../pantry/data/pantry_repository.dart';
import '../../../recipes/data/recipe_repository.dart';
import '../../data/meal_plan_repository.dart';
import '../widgets/meal_stats_card.dart';

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
    final suggestions = ref.watch(suggestedRecipesProvider);
    final recipesAsync = ref.watch(familyRecipesProvider);

    // Get user's first name
    String greeting = 'Bonjour';
    if (currentUser != null && currentUser.displayName != null) {
      final firstName = currentUser.displayName!.split(' ').first;
      greeting = 'Bonjour $firstName';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Popote'),
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

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildMealCard(
                        context,
                        label,
                        assignment?.recipeTitle ?? 'Non planifie',
                        icon,
                        color,
                        hasRecipe: assignment != null,
                        onTap: assignment != null
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
            Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    context,
                    'Ajouter recette',
                    Icons.add_circle_outline,
                    AppColors.primaryMedium,
                    () => context.push(AppRoutes.addRecipe),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    context,
                    'Liste courses',
                    Icons.shopping_cart_outlined,
                    AppColors.secondaryMedium,
                    () => context.go(AppRoutes.shopping),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Suggestions based on pantry
            if (suggestions.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Suggestions du frigo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.pantry),
                    child: const Text('Voir tout'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestions.take(5).length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return _buildSuggestionCard(
                      context,
                      suggestion.recipe.title,
                      '${(suggestion.matchPercent * 100).round()}% ingredients',
                      suggestion.recipe.imageUrl,
                      () => context.push('/recipes/${suggestion.recipe.id}'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Meal statistics
            const MealStatsCard(),
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

  Widget _buildSuggestionCard(
    BuildContext context,
    String title,
    String subtitle,
    String? imageUrl,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: imageUrl == null
                  ? const Center(child: Icon(Icons.restaurant, size: 32, color: AppColors.textHint))
                  : null,
            ),
            // Text
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.success),
                  ),
                ],
              ),
            ),
          ],
        ),
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
