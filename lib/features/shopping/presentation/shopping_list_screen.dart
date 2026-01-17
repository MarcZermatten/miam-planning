import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../family/data/family_repository.dart';
import '../data/shopping_repository.dart';
import '../domain/shopping_item.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _addController = TextEditingController();
  final _addFocusNode = FocusNode();
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  bool _groupByCategory = true;

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shoppingItems = ref.watch(shoppingItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste de courses'),
        actions: [
          // Toggle group by category
          IconButton(
            icon: Icon(_groupByCategory ? Icons.category : Icons.list),
            tooltip: _groupByCategory ? 'Vue liste' : 'Vue categories',
            onPressed: () => setState(() => _groupByCategory = !_groupByCategory),
          ),
          // Menu
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_checked',
                child: ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('Effacer les coches'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep, color: AppColors.error),
                  title: Text('Tout effacer', style: TextStyle(color: AppColors.error)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick add bar
          _buildAddBar(),
          // Suggestions
          if (_showSuggestions && _suggestions.isNotEmpty) _buildSuggestions(),
          // List
          Expanded(
            child: shoppingItems.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (items) => items.isEmpty
                  ? _buildEmptyState()
                  : _groupByCategory
                      ? _buildGroupedList(items)
                      : _buildFlatList(items),
            ),
          ),
          // Progress bar
          shoppingItems.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) => items.isEmpty ? const SizedBox.shrink() : _buildProgressBar(items),
          ),
        ],
      ),
    );
  }

  Widget _buildAddBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _addController,
              focusNode: _addFocusNode,
              decoration: InputDecoration(
                hintText: 'Ajouter un article...',
                prefixIcon: const Icon(Icons.add),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _addItem(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _addItem,
            icon: const Icon(Icons.send),
          ),
          IconButton(
            onPressed: _showBatchAddDialog,
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Ajout multiple',
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return ListTile(
            dense: true,
            leading: Text(ShoppingItem.detectCategory(suggestion).icon),
            title: Text(suggestion),
            onTap: () {
              _addController.text = suggestion;
              _addItem();
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: context.colorTextHint,
          ),
          const SizedBox(height: 16),
          Text(
            'Liste vide',
            style: TextStyle(
              fontSize: 18,
              color: context.colorTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des articles ci-dessus',
            style: TextStyle(color: context.colorTextHint),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatList(List<ShoppingItem> items) {
    // Sort: unchecked first, then by addedAt
    final sorted = List<ShoppingItem>.from(items)
      ..sort((a, b) {
        if (a.isChecked != b.isChecked) {
          return a.isChecked ? 1 : -1;
        }
        return b.addedAt.compareTo(a.addedAt);
      });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (context, index) => _buildItemTile(sorted[index]),
    );
  }

  Widget _buildGroupedList(List<ShoppingItem> items) {
    // Group by category
    final grouped = <ShoppingCategory, List<ShoppingItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    // Sort categories by sortOrder
    final sortedCategories = grouped.keys.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final category = sortedCategories[index];
        final categoryItems = grouped[category]!
          ..sort((a, b) {
            if (a.isChecked != b.isChecked) return a.isChecked ? 1 : -1;
            return a.name.compareTo(b.name);
          });

        // Check if all items in category are checked
        final allChecked = categoryItems.every((item) => item.isChecked);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(category.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    category.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: allChecked ? context.colorTextHint : null,
                      decoration: allChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryMedium.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${categoryItems.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            ...categoryItems.map(_buildItemTile),
            const Divider(),
          ],
        );
      },
    );
  }

  Widget _buildItemTile(ShoppingItem item) {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return const SizedBox.shrink();

    return Slidable(
      key: Key(item.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _editItem(item),
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Modifier',
          ),
          SlidableAction(
            onPressed: (_) {
              ref.read(shoppingRepositoryProvider).deleteItem(familyId, item.id);
            },
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Supprimer',
          ),
        ],
      ),
      child: CheckboxListTile(
        value: item.isChecked,
        onChanged: (value) {
          ref.read(shoppingRepositoryProvider).toggleChecked(
            familyId,
            item.id,
            value ?? false,
          );
        },
        title: Text(
          _formatItemName(item),
          style: TextStyle(
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
            color: item.isChecked ? context.colorTextHint : null,
          ),
        ),
        subtitle: !_groupByCategory
            ? Text(
                '${item.category.icon} ${item.category.label}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colorTextHint,
                ),
              )
            : null,
        secondary: item.isChecked
            ? Icon(Icons.check_circle, color: AppColors.success)
            : null,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  String _formatItemName(ShoppingItem item) {
    final buffer = StringBuffer(item.name);
    if (item.quantity != null) {
      buffer.write(' (${_formatQuantity(item.quantity!)}');
      if (item.unit != null && item.unit!.isNotEmpty) {
        buffer.write(' ${item.unit}');
      }
      buffer.write(')');
    }
    return buffer.toString();
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(1);
  }

  Widget _buildProgressBar(List<ShoppingItem> items) {
    final total = items.length;
    final checked = items.where((i) => i.isChecked).length;
    final progress = total > 0 ? checked / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$checked / $total articles',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: progress == 1.0 ? AppColors.success : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.colorTextHint.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(
                progress == 1.0 ? AppColors.success : AppColors.primary,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
      });
      return;
    }

    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    final suggestions = await ref.read(shoppingRepositoryProvider).getSuggestions(familyId, query);
    setState(() {
      _suggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty;
    });
  }

  void _addItem() {
    final text = _addController.text.trim();
    if (text.isEmpty) return;

    final familyId = ref.read(currentFamilyIdProvider);
    final userId = ref.read(currentUserProvider)?.uid;
    if (familyId == null) return;

    ref.read(shoppingRepositoryProvider).addItem(
      familyId: familyId,
      name: text,
      addedBy: userId,
    );

    _addController.clear();
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
    _addFocusNode.requestFocus();
  }

  void _showBatchAddDialog() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ajout multiple',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Un article par ligne',
              style: TextStyle(color: context.colorTextHint),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Tomates\nOignons\nPoulet\n...',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final lines = controller.text
                    .split('\n')
                    .map((l) => l.trim())
                    .where((l) => l.isNotEmpty)
                    .toList();

                if (lines.isEmpty) {
                  Navigator.pop(context);
                  return;
                }

                final familyId = ref.read(currentFamilyIdProvider);
                final userId = ref.read(currentUserProvider)?.uid;
                if (familyId == null) {
                  Navigator.pop(context);
                  return;
                }

                ref.read(shoppingRepositoryProvider).addItems(
                  familyId: familyId,
                  names: lines,
                  addedBy: userId,
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${lines.length} articles ajoutes')),
                );
              },
              child: const Text('Ajouter'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _editItem(ShoppingItem item) {
    final nameController = TextEditingController(text: item.name);
    final quantityController = TextEditingController(
      text: item.quantity?.toString() ?? '',
    );
    final unitController = TextEditingController(text: item.unit ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Quantite'),
                    keyboardType: TextInputType.number,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final familyId = ref.read(currentFamilyIdProvider);
              if (familyId == null) {
                Navigator.pop(context);
                return;
              }

              ref.read(shoppingRepositoryProvider).updateQuantity(
                familyId,
                item.id,
                double.tryParse(quantityController.text),
                unitController.text.isEmpty ? null : unitController.text,
              );

              Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    switch (action) {
      case 'clear_checked':
        ref.read(shoppingRepositoryProvider).clearChecked(familyId);
        break;
      case 'clear_all':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tout effacer ?'),
            content: const Text('Cette action supprimera tous les articles de la liste.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(shoppingRepositoryProvider).clearAll(familyId);
                },
                child: const Text('Effacer', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
        break;
    }
  }
}
