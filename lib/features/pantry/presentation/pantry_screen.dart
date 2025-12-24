import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../family/data/family_repository.dart';
import '../data/pantry_repository.dart';
import '../domain/pantry_item.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen>
    with SingleTickerProviderStateMixin {
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
    final pantryItems = ref.watch(pantryItemsProvider);
    final suggestions = ref.watch(suggestedRecipesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Frigo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.kitchen),
              text: 'Ingredients',
            ),
            Tab(
              icon: const Icon(Icons.lightbulb_outline),
              text: 'Suggestions (${suggestions.length})',
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_quick',
                child: ListTile(
                  leading: Icon(Icons.flash_on),
                  title: Text('Ajout rapide'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep, color: AppColors.error),
                  title: Text('Vider', style: TextStyle(color: AppColors.error)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Ingredients list
          pantryItems.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (items) => items.isEmpty
                ? _buildEmptyState()
                : _buildIngredientsList(items),
          ),
          // Tab 2: Recipe suggestions
          suggestions.isEmpty
              ? _buildNoSuggestionsState()
              : _buildSuggestionsList(suggestions),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.kitchen,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          const Text(
            'Frigo vide',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez les ingredients que vous avez',
            style: TextStyle(color: AppColors.textHint),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showQuickAddDialog,
            icon: const Icon(Icons.flash_on),
            label: const Text('Ajout rapide'),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsList(List<PantryItem> items) {
    // Grouper par staples vs non-staples
    final staples = items.where((i) => i.isStaple).toList();
    final regular = items.where((i) => !i.isStaple).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        if (regular.isNotEmpty) ...[
          _buildSectionHeader('Ingredients disponibles', regular.length),
          ...regular.map((item) => _buildItemTile(item)),
        ],
        if (staples.isNotEmpty) ...[
          _buildSectionHeader('Ingredients de base', staples.length),
          ...staples.map((item) => _buildItemTile(item)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(PantryItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeItem(item),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.isStaple ? AppColors.cream : AppColors.secondary,
          child: Icon(
            item.isStaple ? Icons.star : Icons.restaurant,
            color: item.isStaple ? AppColors.warning : AppColors.secondaryDark,
            size: 20,
          ),
        ),
        title: Text(item.name),
        subtitle: item.quantity != null
            ? Text('${item.quantity} ${item.unit ?? ''}')
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.expiresSoon)
              const Tooltip(
                message: 'Expire bientot',
                child: Icon(Icons.schedule, color: AppColors.warning, size: 20),
              ),
            if (item.isExpired)
              const Tooltip(
                message: 'Expire',
                child: Icon(Icons.error_outline, color: AppColors.error, size: 20),
              ),
            IconButton(
              icon: Icon(
                item.isStaple ? Icons.star : Icons.star_border,
                color: item.isStaple ? AppColors.warning : AppColors.textHint,
              ),
              onPressed: () => _toggleStaple(item),
              tooltip: item.isStaple ? 'Retirer des basiques' : 'Marquer comme basique',
            ),
          ],
        ),
        onTap: () => _showEditDialog(item),
      ),
    );
  }

  Widget _buildNoSuggestionsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          const Text(
            'Pas de suggestions',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez des ingredients pour voir les recettes possibles',
            style: TextStyle(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(List<RecipeSuggestion> suggestions) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return _buildSuggestionCard(suggestion);
      },
    );
  }

  Widget _buildSuggestionCard(RecipeSuggestion suggestion) {
    final recipe = suggestion.recipe;
    final matchColor = suggestion.matchPercent >= 0.8
        ? AppColors.success
        : suggestion.matchPercent >= 0.6
            ? AppColors.warning
            : AppColors.info;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/recipes/${recipe.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: matchColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      suggestion.matchLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: matchColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${suggestion.matchedIngredients}/${suggestion.totalIngredients} ingredients disponibles',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (suggestion.missingIngredients.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: suggestion.missingIngredients.take(3).map((name) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '- $name',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'add_quick':
        _showQuickAddDialog();
        break;
      case 'clear':
        _confirmClear();
        break;
    }
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final unitController = TextEditingController();
    bool isStaple = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter un ingredient'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
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
                        controller: quantityController,
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
                        controller: unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unite',
                          hintText: 'g',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: isStaple,
                  onChanged: (v) => setDialogState(() => isStaple = v ?? false),
                  title: const Text('Ingredient de base'),
                  subtitle: const Text('Sel, huile, farine...'),
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
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(context);

                final familyId = ref.read(currentFamilyIdProvider);
                if (familyId == null) return;

                await ref.read(pantryRepositoryProvider).addItem(
                      familyId: familyId,
                      name: nameController.text.trim(),
                      quantity: double.tryParse(quantityController.text),
                      unit: unitController.text.trim().isEmpty
                          ? null
                          : unitController.text.trim(),
                      isStaple: isStaple,
                    );
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAddDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajout rapide'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entrez plusieurs ingredients (un par ligne ou separes par des virgules)',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              autofocus: true,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Tomates\nOignons\nAil\nHuile d\'olive',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (textController.text.trim().isEmpty) return;
              Navigator.pop(context);

              final familyId = ref.read(currentFamilyIdProvider);
              if (familyId == null) return;

              final items = await ref.read(pantryRepositoryProvider).addItemsFromText(
                    familyId: familyId,
                    text: textController.text,
                  );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${items.length} ingredients ajoutes!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(PantryItem item) {
    final nameController = TextEditingController(text: item.name);
    final quantityController = TextEditingController(
      text: item.quantity?.toString() ?? '',
    );
    final unitController = TextEditingController(text: item.unit ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Ingredient'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantite'),
                    ),
                  ),
                  const SizedBox(width: 12),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(context);

              final familyId = ref.read(currentFamilyIdProvider);
              if (familyId == null) return;

              final updated = item.copyWith(
                name: nameController.text.trim(),
                quantity: double.tryParse(quantityController.text),
                unit: unitController.text.trim().isEmpty
                    ? null
                    : unitController.text.trim(),
              );

              await ref.read(pantryRepositoryProvider).updateItem(familyId, updated);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStaple(PantryItem item) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    final updated = item.copyWith(isStaple: !item.isStaple);
    await ref.read(pantryRepositoryProvider).updateItem(familyId, updated);
  }

  Future<void> _removeItem(PantryItem item) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    await ref.read(pantryRepositoryProvider).removeItem(familyId, item.id);
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le frigo?'),
        content: const Text('Les ingredients de base seront conserves.'),
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

              await ref.read(pantryRepositoryProvider).clearPantry(
                    familyId,
                    keepStaples: true,
                  );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }
}
