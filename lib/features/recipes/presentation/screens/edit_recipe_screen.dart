import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../family/data/family_repository.dart';
import '../../data/recipe_repository.dart';
import '../../domain/recipe.dart';

class EditRecipeScreen extends ConsumerStatefulWidget {
  final String recipeId;

  const EditRecipeScreen({super.key, required this.recipeId});

  @override
  ConsumerState<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends ConsumerState<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _prepTimeController;
  late TextEditingController _cookTimeController;
  late TextEditingController _servingsController;
  late TextEditingController _imageUrlController;

  List<Ingredient> _ingredients = [];
  List<String> _instructions = [];

  bool _isLoading = true;
  bool _isSaving = false;
  Recipe? _recipe;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _prepTimeController = TextEditingController();
    _cookTimeController = TextEditingController();
    _servingsController = TextEditingController();
    _imageUrlController = TextEditingController();
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    final recipe = await ref.read(recipeRepositoryProvider).getRecipe(familyId, widget.recipeId);
    if (recipe != null && mounted) {
      setState(() {
        _recipe = recipe;
        _titleController.text = recipe.title;
        _descriptionController.text = recipe.description ?? '';
        _prepTimeController.text = recipe.prepTime.toString();
        _cookTimeController.text = recipe.cookTime.toString();
        _servingsController.text = recipe.servings.toString();
        _imageUrlController.text = recipe.imageUrl ?? '';
        _ingredients = List.from(recipe.ingredients);
        _instructions = List.from(recipe.instructions);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_recipe == null) return;

    setState(() => _isSaving = true);

    try {
      final familyId = ref.read(currentFamilyIdProvider);
      if (familyId == null) throw Exception('Non connecte');

      final updatedRecipe = _recipe!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        prepTime: int.tryParse(_prepTimeController.text) ?? 0,
        cookTime: int.tryParse(_cookTimeController.text) ?? 0,
        servings: int.tryParse(_servingsController.text) ?? 4,
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        ingredients: _ingredients,
        instructions: _instructions,
      );

      await ref.read(recipeRepositoryProvider).updateRecipe(familyId, updatedRecipe);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recette mise a jour'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addIngredient() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final amountController = TextEditingController();
        final unitController = TextEditingController();

        return AlertDialog(
          title: const Text('Ajouter un ingredient'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom *'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Quantite'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      decoration: const InputDecoration(labelText: 'Unite'),
                    ),
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
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                setState(() {
                  _ingredients.add(Ingredient(
                    name: nameController.text.trim(),
                    amount: double.tryParse(amountController.text),
                    unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
                  ));
                });
                Navigator.pop(context);
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }

  void _editIngredient(int index) {
    final ingredient = _ingredients[index];
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController(text: ingredient.name);
        final amountController = TextEditingController(
            text: ingredient.amount?.toString() ?? '');
        final unitController = TextEditingController(text: ingredient.unit ?? '');

        return AlertDialog(
          title: const Text('Modifier l\'ingredient'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom *'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Quantite'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      decoration: const InputDecoration(labelText: 'Unite'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _ingredients.removeAt(index));
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Supprimer'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                setState(() {
                  _ingredients[index] = Ingredient(
                    name: nameController.text.trim(),
                    amount: double.tryParse(amountController.text),
                    unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Modifier'),
            ),
          ],
        );
      },
    );
  }

  void _addInstruction() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();

        return AlertDialog(
          title: const Text('Ajouter une etape'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Instruction',
              hintText: 'Decrire l\'etape...',
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                setState(() => _instructions.add(controller.text.trim()));
                Navigator.pop(context);
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }

  void _editInstruction(int index) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _instructions[index]);

        return AlertDialog(
          title: Text('Etape ${index + 1}'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Instruction'),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _instructions.removeAt(index));
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Supprimer'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                setState(() => _instructions[index] = controller.text.trim());
                Navigator.pop(context);
              },
              child: const Text('Modifier'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modifier la recette')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier la recette'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Titre
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Image URL
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'URL de l\'image',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image),
              ),
            ),
            const SizedBox(height: 16),

            // Temps et portions
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Prep (min)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cookTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Cuisson (min)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _servingsController,
                    decoration: const InputDecoration(
                      labelText: 'Portions',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ingredients
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.shopping_basket, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Ingredients',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                  onPressed: _addIngredient,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_ingredients.isEmpty)
              const Text(
                'Aucun ingredient',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ingredients.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _ingredients.removeAt(oldIndex);
                    _ingredients.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final ing = _ingredients[index];
                  return Card(
                    key: ValueKey('ing_$index'),
                    child: ListTile(
                      leading: const Icon(Icons.drag_handle),
                      title: Text(ing.displayText),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editIngredient(index),
                      ),
                      onTap: () => _editIngredient(index),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Instructions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_list_numbered, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Instructions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                  onPressed: _addInstruction,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_instructions.isEmpty)
              const Text(
                'Aucune instruction',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _instructions.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _instructions.removeAt(oldIndex);
                    _instructions.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  return Card(
                    key: ValueKey('inst_$index'),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 14,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      title: Text(
                        _instructions[index],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editInstruction(index),
                      ),
                      onTap: () => _editInstruction(index),
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),

            // Save button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Enregistrer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
