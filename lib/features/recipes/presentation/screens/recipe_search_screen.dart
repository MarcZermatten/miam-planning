import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/recipe_search_service.dart';
import '../../data/recipe_scraper.dart';
import '../../data/recipe_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../family/data/family_repository.dart';

class RecipeSearchScreen extends ConsumerStatefulWidget {
  const RecipeSearchScreen({super.key});

  @override
  ConsumerState<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends ConsumerState<RecipeSearchScreen> {
  final _searchController = TextEditingController();
  List<RecipeSearchResult> _results = [];
  RecipeProvider _selectedProvider = RecipeProvider.spoonacular;
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _importingUrl;

  // Filters
  int? _maxPrepTime; // null = no filter, otherwise max minutes
  int? _minRating;   // null = no filter, otherwise min rating (e.g., 3 or 4)

  List<RecipeSearchResult> get _filteredResults {
    return _results.where((recipe) {
      // Filter by prep time
      if (_maxPrepTime != null && recipe.prepTime != null) {
        if (recipe.prepTime! > _maxPrepTime!) return false;
      }
      // Filter by rating
      if (_minRating != null && recipe.rating != null) {
        if (recipe.rating! < _minRating!) return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await RecipeSearchService.search(query, _selectedProvider);
      setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de recherche: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importRecipe(RecipeSearchResult recipe) async {
    setState(() => _importingUrl = recipe.url);

    try {
      // Scraper la recette complete
      final scraped = await RecipeScraper.scrapeFromUrl(recipe.url);

      if (scraped == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'importer cette recette')),
          );
        }
        return;
      }

      // Sauvegarder directement
      final user = ref.read(currentUserProvider);
      final familyId = ref.read(currentFamilyIdProvider);

      if (user == null || familyId == null) {
        throw Exception('Non connecte');
      }

      await ref.read(recipeRepositoryProvider).createRecipe(
        familyId: familyId,
        title: scraped.title,
        description: scraped.description,
        createdBy: user.uid,
        prepTime: scraped.prepTime,
        cookTime: scraped.cookTime,
        servings: scraped.servings,
        ingredients: scraped.ingredients,
        instructions: scraped.instructions,
        sourceUrl: scraped.sourceUrl,
        imageUrl: scraped.imageUrl,
        sourceName: recipe.provider.label,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${scraped.title} importee!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importingUrl = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher une recette'),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Ex: poulet curry, tarte aux pommes...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Chercher'),
                ),
              ],
            ),
          ),

          // Provider selector tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<RecipeProvider>(
              segments: RecipeProvider.values.map((provider) {
                final isAvailable = provider.isAvailable;
                return ButtonSegment<RecipeProvider>(
                  value: provider,
                  label: Text(
                    isAvailable ? provider.label : '${provider.label} (bientôt)',
                    style: TextStyle(
                      color: isAvailable ? null : AppColors.textHint,
                      fontSize: isAvailable ? null : 12,
                    ),
                  ),
                  icon: Text(provider.icon),
                  enabled: isAvailable,
                );
              }).toList(),
              selected: {_selectedProvider},
              onSelectionChanged: (Set<RecipeProvider> selected) {
                final provider = selected.first;
                if (!provider.isAvailable) return;
                setState(() {
                  _selectedProvider = provider;
                });
                // Re-search if we have a query
                if (_searchController.text.trim().isNotEmpty && _hasSearched) {
                  _search();
                }
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),

          // Filter chips
          if (_hasSearched && _results.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  // Time filter
                  _buildFilterChip(
                    label: _maxPrepTime == null ? 'Temps' : '<${_maxPrepTime!}min',
                    icon: Icons.timer_outlined,
                    isActive: _maxPrepTime != null,
                    onTap: () => _showTimeFilterDialog(),
                  ),
                  const SizedBox(width: 8),
                  // Rating filter
                  _buildFilterChip(
                    label: _minRating == null ? 'Note' : '>${_minRating}★',
                    icon: Icons.star_outline,
                    isActive: _minRating != null,
                    onTap: () => _showRatingFilterDialog(),
                  ),
                  const SizedBox(width: 8),
                  // Clear all filters
                  if (_maxPrepTime != null || _minRating != null)
                    ActionChip(
                      label: const Text('Effacer'),
                      avatar: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _maxPrepTime = null;
                          _minRating = null;
                        });
                      },
                    ),
                  // Show count
                  if (_filteredResults.length != _results.length)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        '${_filteredResults.length}/${_results.length}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Resultats
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 18),
      selected: isActive,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
    );
  }

  void _showTimeFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Tous les temps'),
              leading: const Icon(Icons.all_inclusive),
              selected: _maxPrepTime == null,
              onTap: () {
                setState(() => _maxPrepTime = null);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Moins de 15 minutes'),
              leading: const Icon(Icons.bolt),
              selected: _maxPrepTime == 15,
              onTap: () {
                setState(() => _maxPrepTime = 15);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Moins de 30 minutes'),
              leading: const Icon(Icons.timer),
              selected: _maxPrepTime == 30,
              onTap: () {
                setState(() => _maxPrepTime = 30);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Moins de 45 minutes'),
              leading: const Icon(Icons.schedule),
              selected: _maxPrepTime == 45,
              onTap: () {
                setState(() => _maxPrepTime = 45);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Moins de 60 minutes'),
              leading: const Icon(Icons.hourglass_bottom),
              selected: _maxPrepTime == 60,
              onTap: () {
                setState(() => _maxPrepTime = 60);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Toutes les notes'),
              leading: const Icon(Icons.star_border),
              selected: _minRating == null,
              onTap: () {
                setState(() => _minRating = null);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('3 etoiles ou plus'),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (_) => const Icon(Icons.star, color: Colors.amber, size: 18)),
              ),
              selected: _minRating == 3,
              onTap: () {
                setState(() => _minRating = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('4 etoiles ou plus'),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(4, (_) => const Icon(Icons.star, color: Colors.amber, size: 18)),
              ),
              selected: _minRating == 4,
              onTap: () {
                setState(() => _minRating = 4);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Recherche en cours...'),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'Recherchez une recette',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Tapez un ingredient ou un plat',
              style: TextStyle(color: AppColors.textHint, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'Aucun resultat',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez avec d\'autres mots-cles',
              style: TextStyle(color: AppColors.textHint, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Check if filters excluded all results
    final filtered = _filteredResults;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'Aucun resultat avec ces filtres',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _maxPrepTime = null;
                  _minRating = null;
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Effacer les filtres'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final recipe = filtered[index];
        final isImporting = _importingUrl == recipe.url;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: isImporting ? null : () => _importRecipe(recipe),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: Container(
                    width: 100,
                    height: 100,
                    color: AppColors.surfaceVariant,
                    child: recipe.imageUrl != null
                        ? Image.network(
                            recipe.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.restaurant,
                              size: 40,
                              color: AppColors.textHint,
                            ),
                          )
                        : const Icon(
                            Icons.restaurant,
                            size: 40,
                            color: AppColors.textHint,
                          ),
                  ),
                ),

                // Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getSourceColor(recipe.provider).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                recipe.provider.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _getSourceColor(recipe.provider),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (recipe.rating != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.star, size: 14, color: AppColors.warning),
                              const SizedBox(width: 2),
                              Text(
                                recipe.rating!.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                            if (recipe.prepTime != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 2),
                              Text(
                                '${recipe.prepTime} min',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Action
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: isImporting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline, color: AppColors.primary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getSourceColor(RecipeProvider provider) {
    switch (provider) {
      case RecipeProvider.spoonacular:
        return Colors.green;
      case RecipeProvider.marmiton:
        return Colors.orange;
      case RecipeProvider.bettyBossi:
        return Colors.red;
      case RecipeProvider.cuisineAz:
        return Colors.blue;
    }
  }
}
