import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../family/data/family_repository.dart';
import '../../data/recipe_repository.dart';
import '../../data/recipe_scraper.dart';
import '../../data/recipe_search_service.dart';
import '../../domain/recipe.dart';

class AddRecipeScreen extends ConsumerStatefulWidget {
  final String? initialUrl;

  const AddRecipeScreen({super.key, this.initialUrl});

  @override
  ConsumerState<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends ConsumerState<AddRecipeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController(text: '4');
  final _instructionsController = TextEditingController();

  int _difficulty = 2;
  List<Ingredient> _ingredients = [];
  List<String> _selectedAllergens = [];
  List<int> _kidCanHelpSteps = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _sourceUrl;
  String? _imageUrl;

  // Search
  RecipeProvider _selectedProvider = RecipeProvider.marmiton;
  List<RecipeSearchResult> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Si une URL initiale est fournie, lancer l'import automatiquement
    if (widget.initialUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _urlController.text = widget.initialUrl!;
        _importFromUrl();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _searchController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un ingredient')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      final familyId = ref.read(currentFamilyIdProvider);

      if (user == null || familyId == null) {
        throw Exception('Non connecte ou pas de famille');
      }

      // Parse instructions into steps
      final instructions = _instructionsController.text
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      await ref.read(recipeRepositoryProvider).createRecipe(
            familyId: familyId,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            createdBy: user.uid,
            prepTime: int.tryParse(_prepTimeController.text) ?? 0,
            cookTime: int.tryParse(_cookTimeController.text) ?? 0,
            servings: int.tryParse(_servingsController.text) ?? 4,
            difficulty: _difficulty,
            ingredients: _ingredients,
            instructions: instructions,
            allergens: _selectedAllergens,
            kidCanHelpSteps: _kidCanHelpSteps,
            sourceUrl: _sourceUrl,
            imageUrl: _imageUrl,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recette enregistree!')),
        );
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addIngredient() {
    showDialog(
      context: context,
      builder: (context) => _IngredientDialog(
        onSave: (ingredient) {
          setState(() => _ingredients.add(ingredient));
        },
      ),
    );
  }

  void _removeIngredient(int index) {
    setState(() => _ingredients.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter une recette'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Recherche'),
            Tab(icon: Icon(Icons.link), text: 'URL'),
            Tab(icon: Icon(Icons.edit), text: 'Manuelle'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Search recipes online
          _buildSearchTab(),
          // Import from URL
          _buildUrlImportTab(),
          // Manual entry
          _buildManualEntryTab(),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Provider selector
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Source',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.colorTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<RecipeProvider>(
                segments: RecipeProvider.values.map((p) {
                  return ButtonSegment(
                    value: p,
                    label: Text(p.label),
                    icon: Text(p.icon),
                  );
                }).toList(),
                selected: {_selectedProvider},
                onSelectionChanged: (selected) {
                  setState(() {
                    _selectedProvider = selected.first;
                    _searchResults = [];
                  });
                },
              ),
              const SizedBox(height: 16),
              // Search field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Rechercher une recette',
                  hintText: 'Ex: poulet curry, tarte pommes...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _performSearch,
                        ),
                ),
                onSubmitted: (_) => _performSearch(),
              ),
            ],
          ),
        ),
        // Results
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
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
                        'Recherchez des recettes sur ${_selectedProvider.label}',
                        style: TextStyle(color: context.colorTextSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return _buildSearchResultCard(result);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchResultCard(RecipeSearchResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: result.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  result.imageUrl!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.restaurant),
                  ),
                ),
              )
            : Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant),
              ),
        title: Text(
          result.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            Text(result.provider.icon),
            const SizedBox(width: 4),
            Text(
              result.provider.label,
              style: TextStyle(
                fontSize: 12,
                color: context.colorTextHint,
              ),
            ),
            if (result.prepTime != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.timer, size: 14, color: context.colorTextHint),
              const SizedBox(width: 2),
              Text(
                '${result.prepTime} min',
                style: TextStyle(fontSize: 12, color: context.colorTextHint),
              ),
            ],
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _importFromSearchResult(result),
          child: const Text('Importer'),
        ),
      ),
    );
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final results = await RecipeSearchService.search(query, _selectedProvider);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune recette trouvee')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _importFromSearchResult(RecipeSearchResult result) async {
    // Use the URL importer
    _urlController.text = result.url;
    await _importFromUrl();
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez une URL')),
      );
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL invalide')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final scraped = await RecipeScraper.scrapeFromUrl(url);

      if (scraped == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de lire cette recette')),
          );
        }
        return;
      }

      // Remplir le formulaire avec les donnees importees
      setState(() {
        _titleController.text = scraped.title;
        _descriptionController.text = scraped.description ?? '';
        _prepTimeController.text = scraped.prepTime > 0 ? scraped.prepTime.toString() : '';
        _cookTimeController.text = scraped.cookTime > 0 ? scraped.cookTime.toString() : '';
        _servingsController.text = scraped.servings.toString();
        _ingredients = scraped.ingredients;
        _instructionsController.text = scraped.instructions.join('\n');
        _sourceUrl = scraped.sourceUrl;
        _imageUrl = scraped.imageUrl;
      });

      // Cacher le clavier
      FocusScope.of(context).unfocus();

      // Basculer vers l'onglet manuel pour voir/editer
      _tabController.animateTo(2);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${scraped.ingredients.length} ingredients importes!'),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildUrlImportTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Collez l\'URL d\'une recette',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sites supportes : Marmiton, Betty Bossi, 750g, CuisineAZ, etc.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL de la recette',
              hintText: 'https://www.marmiton.org/recettes/...',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _importFromUrl,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download),
            label: Text(_isLoading ? 'Import en cours...' : 'Importer'),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.secondaryDark),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'La recette sera importee puis vous pourrez la modifier '
                    'avant de l\'enregistrer.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntryTab() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nom de la recette *',
                prefixIcon: Icon(Icons.restaurant),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Entrez un nom';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Time and servings
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Prep (min)',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cookTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cuisson (min)',
                      prefixIcon: Icon(Icons.whatshot_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _servingsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Portions',
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Difficulty
            const Text(
              'Difficulte',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: AppConstants.difficultyLabels.entries.map((e) {
                return ButtonSegment(value: e.key, label: Text(e.value));
              }).toList(),
              selected: {_difficulty},
              onSelectionChanged: (selected) {
                setState(() => _difficulty = selected.first);
              },
            ),
            const SizedBox(height: 24),

            // Ingredients
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ingredients',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_ingredients.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.textHint),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Aucun ingredient',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: _ingredients.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ingredient = entry.value;
                    return ListTile(
                      dense: true,
                      title: Text(ingredient.displayText),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _removeIngredient(index),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 24),

            // Allergens
            const Text(
              'Allergenes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.commonAllergies.map((allergen) {
                final isSelected = _selectedAllergens.contains(allergen);
                return FilterChip(
                  label: Text(allergen.replaceAll('_', ' ')),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedAllergens.add(allergen);
                      } else {
                        _selectedAllergens.remove(allergen);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Instructions
            const Text(
              'Instructions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _instructionsController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Decrivez les etapes (une par ligne)...',
              ),
              onChanged: (value) {
                // Reset kid can help when instructions change
                setState(() => _kidCanHelpSteps = []);
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ajoutez les instructions';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Kid can help steps
            _buildKidCanHelpSection(),
            const SizedBox(height: 24),

            // Save button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveRecipe,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Enregistrer'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildKidCanHelpSection() {
    final steps = _instructionsController.text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.child_care, size: 18, color: AppColors.fruits),
            const SizedBox(width: 8),
            const Text(
              'L\'enfant peut aider',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Cochez les etapes ou l\'enfant peut participer',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isChecked = _kidCanHelpSteps.contains(index);

          return CheckboxListTile(
            value: isChecked,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _kidCanHelpSteps.add(index);
                } else {
                  _kidCanHelpSteps.remove(index);
                }
              });
            },
            title: Text(
              '${index + 1}. ${step.trim()}',
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            activeColor: AppColors.fruits,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          );
        }),
      ],
    );
  }
}

/// Dialog to add an ingredient
class _IngredientDialog extends StatefulWidget {
  final Function(Ingredient) onSave;

  const _IngredientDialog({required this.onSave});

  @override
  State<_IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<_IngredientDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _unitController = TextEditingController();
  bool _isPantryStaple = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un ingredient'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Ingredient *',
                hintText: 'Ex: Tomates',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantite',
                      hintText: '500',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unite',
                      hintText: 'g, ml, pcs',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _isPantryStaple,
              onChanged: (v) => setState(() => _isPantryStaple = v ?? false),
              title: const Text('Ingredient de base'),
              subtitle: const Text('Sel, huile, etc.'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;

            final ingredient = Ingredient(
              name: _nameController.text.trim(),
              amount: double.tryParse(_amountController.text),
              unit: _unitController.text.trim().isEmpty
                  ? null
                  : _unitController.text.trim(),
              isPantryStaple: _isPantryStaple,
            );

            widget.onSave(ingredient);
            Navigator.pop(context);
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
