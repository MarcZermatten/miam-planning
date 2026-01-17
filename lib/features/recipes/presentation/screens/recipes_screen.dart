import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routing/app_router.dart';
import '../../../dishes/domain/dish.dart';
import '../../../family/data/family_repository.dart';
import '../../data/recipe_repository.dart';
import '../../domain/recipe.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  final _searchController = TextEditingController();
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(filteredRecipesProvider);
    final filter = ref.watch(recipeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recettes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.travel_explore),
            tooltip: 'Chercher sur le web',
            onPressed: () => context.push(AppRoutes.searchRecipes),
          ),
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une recette...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(recipeFilterProvider.notifier).state =
                              filter.copyWith(searchQuery: '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(recipeFilterProvider.notifier).state =
                    filter.copyWith(searchQuery: value);
              },
            ),
          ),

          // Filters
          if (_showFilters) _buildFilters(filter),

          // Recipe list
          Expanded(
            child: recipes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recipes.length,
                    itemBuilder: (context, index) {
                      return _buildRecipeCard(recipes[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addRecipe),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilters(RecipeFilter filter) {
    final filterPicky = ref.watch(filterPickyEaterProvider);
    final pickyAvoid = ref.watch(pickyEaterAvoidProvider);
    final recipes = ref.watch(familyRecipesProvider).value ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // General filters
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Rapide (< 20 min)'),
                selected: filter.isQuick == true,
                onSelected: (selected) {
                  ref.read(recipeFilterProvider.notifier).state =
                      filter.copyWith(isQuick: selected ? true : null);
                },
              ),
              FilterChip(
                label: const Text('Approuve enfants'),
                selected: filter.isKidApproved == true,
                onSelected: (selected) {
                  ref.read(recipeFilterProvider.notifier).state =
                      filter.copyWith(isKidApproved: selected ? true : null);
                },
              ),
              if (pickyAvoid.isNotEmpty)
                FilterChip(
                  avatar: const Icon(Icons.child_care, size: 18),
                  label: const Text('Mangeurs difficiles'),
                  selected: filterPicky,
                  selectedColor: AppColors.warning.withValues(alpha: 0.3),
                  onSelected: (selected) {
                    ref.read(filterPickyEaterProvider.notifier).state = selected;
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          // MealType filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: filter.mealType == null,
                  onSelected: (_) {
                    ref.read(recipeFilterProvider.notifier).state =
                        filter.copyWith(clearMealType: true);
                  },
                ),
                const SizedBox(width: 6),
                ...MealType.values.map((type) {
                  final count = recipes.where((r) => r.mealType == type).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('${type.icon} ${type.label}${count > 0 ? ' ($count)' : ''}'),
                      selected: filter.mealType == type,
                      onSelected: (_) {
                        ref.read(recipeFilterProvider.notifier).state = filter.copyWith(
                          mealType: filter.mealType == type ? null : type,
                          clearMealType: filter.mealType == type,
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 64,
            color: context.colorTextHint,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune recette',
            style: TextStyle(
              fontSize: 18,
              color: context.colorTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre premiere recette !',
            style: TextStyle(color: context.colorTextHint),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.addRecipe),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une recette'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/recipes/${recipe.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image placeholder
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.colorSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: recipe.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          recipe.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.restaurant,
                            color: context.colorTextHint,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.restaurant,
                        color: context.colorTextHint,
                      ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: context.colorTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.totalTime} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colorTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: context.colorTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.servings} pers.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colorTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Tags
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (recipe.mealType != null)
                          _buildTag('${recipe.mealType!.icon} ${recipe.mealType!.label}', AppColors.primary),
                        if (recipe.isQuick)
                          _buildTag('Rapide', AppColors.secondary),
                        if (recipe.isKidApproved)
                          _buildTag('Enfants', AppColors.fruits),
                      ],
                    ),
                  ],
                ),
              ),
              // Rating
              if (recipe.adultRating != null || recipe.kidRating != null)
                Column(
                  children: [
                    if (recipe.adultRating != null)
                      _buildRating(recipe.adultRating!, false),
                    if (recipe.kidRating != null)
                      _buildRating(recipe.kidRating!, true),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }

  Widget _buildRating(double rating, bool isKid) {
    return Builder(
      builder: (context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isKid ? Icons.child_care : Icons.person,
            size: 12,
            color: context.colorTextSecondary,
          ),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 12),
        ),
        const Icon(Icons.star, size: 12, color: AppColors.warning),
        ],
      ),
    );
  }
}
