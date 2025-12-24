import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../family/data/family_repository.dart';
import '../../../family/domain/family_member.dart';
import '../../data/recipe_repository.dart';
import '../../domain/recipe.dart';

class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(recipeProvider(recipeId));

    return recipeAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erreur: $e')),
      ),
      data: (recipe) {
        if (recipe == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Recette introuvable')),
          );
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // App bar with image
              SliverAppBar(
                expandedHeight: recipe.imageUrl != null ? 200 : 0,
                pinned: true,
                flexibleSpace: recipe.imageUrl != null
                    ? FlexibleSpaceBar(
                        background: Image.network(
                          recipe.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.surfaceVariant,
                          ),
                        ),
                      )
                    : null,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, recipe),
                  ),
                ],
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        recipe.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (recipe.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          recipe.description!,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Quick info row
                      _buildInfoRow(recipe),
                      const SizedBox(height: 16),

                      // Ratings
                      if (recipe.ratings.isNotEmpty) ...[
                        _buildRatingsSection(recipe),
                        const SizedBox(height: 16),
                      ],

                      // Rate button
                      _buildRateButton(context, ref, recipe),
                      const SizedBox(height: 24),

                      // Ingredients
                      _buildSection(
                        'Ingredients',
                        Icons.shopping_basket_outlined,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: recipe.ingredients.map((ing) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(ing.displayText)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Instructions
                      _buildSection(
                        'Instructions',
                        Icons.format_list_numbered,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: recipe.instructions.asMap().entries.map((entry) {
                            final index = entry.key;
                            final step = entry.value;
                            final canHelp = recipe.kidCanHelpSteps.contains(index);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: canHelp
                                          ? AppColors.fruits
                                          : AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: canHelp
                                          ? const Icon(
                                              Icons.child_care,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : Text(
                                              '${index + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(step)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Allergens
                      if (recipe.allergens.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSection(
                          'Allergenes',
                          Icons.warning_amber,
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: recipe.allergens.map((a) {
                              return Chip(
                                label: Text(a.replaceAll('_', ' ')),
                                backgroundColor: AppColors.error.withValues(alpha: 0.1),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => _markAsCooked(ref, recipe),
                icon: const Icon(Icons.restaurant),
                label: Text(
                  recipe.timesCooked > 0
                      ? 'Cuisine (${recipe.timesCooked}x)'
                      : 'Marquer comme cuisine',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(Recipe recipe) {
    return Row(
      children: [
        _buildInfoChip(Icons.timer_outlined, '${recipe.totalTime} min'),
        const SizedBox(width: 12),
        _buildInfoChip(Icons.people_outline, '${recipe.servings} pers.'),
        const SizedBox(width: 12),
        _buildInfoChip(
          Icons.signal_cellular_alt,
          AppConstants.difficultyLabels[recipe.difficulty] ?? '',
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRatingsSection(Recipe recipe) {
    return Row(
      children: [
        if (recipe.adultRating != null)
          _buildRatingDisplay('Adultes', recipe.adultRating!, false),
        if (recipe.adultRating != null && recipe.kidRating != null)
          const SizedBox(width: 24),
        if (recipe.kidRating != null)
          _buildRatingDisplay('Enfants', recipe.kidRating!, true),
      ],
    );
  }

  Widget _buildRatingDisplay(String label, double rating, bool isKid) {
    // Emojis pour les enfants (1-5)
    const kidEmojis = ['😫', '😕', '😐', '🙂', '😋'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Row(
          children: [
            Icon(
              isKid ? Icons.child_care : Icons.person,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            if (isKid) ...[
              Text(
                kidEmojis[(rating.round() - 1).clamp(0, 4)],
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ] else ...[
              ...List.generate(5, (i) {
                return Icon(
                  i < rating.round() ? Icons.star : Icons.star_border,
                  size: 18,
                  color: AppColors.warning,
                );
              }),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(1)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildRateButton(BuildContext context, WidgetRef ref, Recipe recipe) {
    return OutlinedButton.icon(
      onPressed: () => _showRatingDialog(context, ref, recipe),
      icon: const Icon(Icons.star_outline),
      label: const Text('Noter cette recette'),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  void _showRatingDialog(BuildContext context, WidgetRef ref, Recipe recipe) {
    final members = ref.read(familyMembersProvider).value ?? [];
    if (members.isEmpty) return;

    String? selectedMemberId = members.first.id;
    int selectedRating = 3;

    // Emojis pour les enfants (1-5)
    const kidEmojis = ['😫', '😕', '😐', '🙂', '😋'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final selectedMember = members.firstWhere(
            (m) => m.id == selectedMemberId,
            orElse: () => members.first,
          );
          final isKid = selectedMember.isKid;

          return AlertDialog(
            title: const Text('Noter la recette'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Member selector
                const Text(
                  'Qui note ?',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: members.map((member) {
                    final isSelected = member.id == selectedMemberId;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            member.isKid ? Icons.child_care : Icons.person,
                            size: 16,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(member.name),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => selectedMemberId = member.id);
                        }
                      },
                      selectedColor: member.isKid ? AppColors.fruits : AppColors.primaryMedium,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Rating selector
                if (isKid) ...[
                  const Text(
                    'Comment c\'etait ?',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final isSelected = i + 1 == selectedRating;
                      return GestureDetector(
                        onTap: () => setState(() => selectedRating = i + 1),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.fruits.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: AppColors.fruits, width: 2)
                                : null,
                          ),
                          child: Text(
                            kidEmojis[i],
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      );
                    }),
                  ),
                ] else ...[
                  const Text(
                    'Votre note',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return IconButton(
                        icon: Icon(
                          i < selectedRating ? Icons.star : Icons.star_border,
                          color: AppColors.warning,
                          size: 36,
                        ),
                        onPressed: () => setState(() => selectedRating = i + 1),
                      );
                    }),
                  ),
                ],
              ],
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

                  await ref.read(recipeRepositoryProvider).addRating(
                        familyId: familyId,
                        recipeId: recipe.id,
                        rating: RecipeRating(
                          odauyX6H2Z: selectedMember.odauyX6H2Z,
                          memberName: selectedMember.name,
                          score: selectedRating,
                          isKid: selectedMember.isKid,
                          ratedAt: DateTime.now(),
                        ),
                      );
                },
                child: const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _markAsCooked(WidgetRef ref, Recipe recipe) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    await ref.read(recipeRepositoryProvider).markAsCooked(familyId, recipe.id);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Recipe recipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la recette?'),
        content: Text('Voulez-vous vraiment supprimer "${recipe.title}"?'),
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

              await ref.read(recipeRepositoryProvider).deleteRecipe(
                    familyId,
                    recipe.id,
                  );
              if (context.mounted) context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
