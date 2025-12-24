import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../family/data/family_repository.dart';
import '../../meal_plan/data/meal_plan_repository.dart';
import '../../meal_plan/domain/meal_plan.dart';
import '../data/shopping_list_repository.dart';
import '../domain/shopping_list.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final shoppingListAsync = ref.watch(currentShoppingListProvider);
    final weekStart = ref.watch(selectedWeekStartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste de courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Regenerer depuis planning',
            onPressed: _isGenerating ? null : () => _generateFromPlan(weekStart),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value, shoppingListAsync.value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy',
                child: ListTile(
                  leading: Icon(Icons.copy),
                  title: Text('Copier'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Partager'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_checked',
                child: ListTile(
                  leading: Icon(Icons.remove_done),
                  title: Text('Supprimer coches'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep, color: AppColors.error),
                  title: Text('Vider la liste', style: TextStyle(color: AppColors.error)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: shoppingListAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (shoppingList) {
          if (shoppingList == null || shoppingList.items.isEmpty) {
            return _buildEmptyState(weekStart);
          }
          return _buildListView(shoppingList);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(DateTime weekStart) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          const Text(
            'Liste de courses vide',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Planifiez des repas pour generer la liste',
            style: TextStyle(color: AppColors.textHint),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isGenerating ? null : () => _generateFromPlan(weekStart),
            icon: _isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: const Text('Generer depuis planning'),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(ShoppingList shoppingList) {
    final groupedItems = shoppingList.groupedItems;

    return Column(
      children: [
        // Progress bar
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surfaceVariant,
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: shoppingList.items.isEmpty
                      ? 0
                      : shoppingList.checkedCount / shoppingList.items.length,
                  backgroundColor: AppColors.textHint.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${shoppingList.checkedCount}/${shoppingList.items.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: groupedItems.length,
            itemBuilder: (context, index) {
              final entry = groupedItems.entries.elementAt(index);
              return _buildCategorySection(entry.key, entry.value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(IngredientCategory category, List<ShoppingItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            category.label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...items.map((item) => _buildItemTile(item)),
      ],
    );
  }

  Widget _buildItemTile(ShoppingItem item) {
    final shoppingList = ref.read(currentShoppingListProvider).value;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeItem(shoppingList, item),
      child: ListTile(
        leading: Checkbox(
          value: item.isChecked,
          onChanged: (_) => _toggleItem(shoppingList, item),
          activeColor: AppColors.secondary,
        ),
        title: Text(
          item.displayText,
          style: TextStyle(
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
            color: item.isChecked ? AppColors.textHint : null,
          ),
        ),
        subtitle: item.recipeIds.isNotEmpty
            ? Text(
                '${item.recipeIds.length} recette(s)',
                style: const TextStyle(fontSize: 12),
              )
            : item.isManual
                ? const Text('Ajoute manuellement', style: TextStyle(fontSize: 12))
                : null,
        trailing: IconButton(
          icon: Image.asset(
            'assets/images/migros_logo.png',
            width: 24,
            height: 24,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.primary,
            ),
          ),
          tooltip: 'Chercher sur Migros',
          onPressed: () => _openMigrosSearch(item),
        ),
        onTap: () => _toggleItem(shoppingList, item),
      ),
    );
  }

  Future<void> _generateFromPlan(DateTime weekStart) async {
    setState(() => _isGenerating = true);

    try {
      final familyId = ref.read(currentFamilyIdProvider);
      if (familyId == null) return;

      await ref.read(shoppingListRepositoryProvider).generateFromMealPlan(
            familyId: familyId,
            weekStart: weekStart,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liste generee!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _toggleItem(ShoppingList? list, ShoppingItem item) async {
    if (list == null) return;
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    await ref.read(shoppingListRepositoryProvider).toggleItem(
          familyId,
          list.id,
          item.id,
        );
  }

  Future<void> _removeItem(ShoppingList? list, ShoppingItem item) async {
    if (list == null) return;
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    await ref.read(shoppingListRepositoryProvider).removeItem(
          familyId,
          list.id,
          item.id,
        );
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final unitController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un article'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Article *',
                hintText: 'Ex: Lait',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantite',
                      hintText: '2',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unite',
                      hintText: 'L',
                    ),
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
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              Navigator.pop(context);

              final familyId = ref.read(currentFamilyIdProvider);
              final weekStart = ref.read(selectedWeekStartProvider);
              if (familyId == null) return;

              await ref.read(shoppingListRepositoryProvider).addManualItem(
                    familyId: familyId,
                    weekId: MealPlan.getWeekId(weekStart),
                    name: nameController.text.trim(),
                    amount: double.tryParse(amountController.text),
                    unit: unitController.text.trim().isEmpty
                        ? null
                        : unitController.text.trim(),
                  );
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, ShoppingList? list) async {
    if (list == null) return;
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: list.toPlainText()));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Liste copiee!')),
          );
        }
        break;

      case 'share':
        // For now, just copy - share requires share_plus package
        await Clipboard.setData(ClipboardData(text: list.toPlainText()));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Liste copiee dans le presse-papier!')),
          );
        }
        break;

      case 'clear_checked':
        await ref.read(shoppingListRepositoryProvider).clearCheckedItems(
              familyId,
              list.id,
            );
        break;

      case 'clear_all':
        _confirmClearAll(list);
        break;
    }
  }

  void _confirmClearAll(ShoppingList list) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider la liste?'),
        content: const Text('Tous les articles seront supprimes.'),
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

              await ref.read(shoppingListRepositoryProvider).clearList(
                    familyId,
                    list.id,
                  );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }

  Future<void> _openMigrosSearch(ShoppingItem item) async {
    final uri = Uri.parse(item.migrosSearchUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le navigateur')),
        );
      }
    }
  }
}
