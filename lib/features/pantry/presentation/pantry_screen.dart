import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../family/data/family_repository.dart';
import '../../dishes/data/dish_repository.dart';
import '../../dishes/domain/dish.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/domain/recipe.dart';
import '../../wine/data/wine_repository.dart';
import '../../wine/domain/wine_bottle.dart';
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
  MealType? _freezerMealTypeFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pantryItems = ref.watch(pantryItemsProvider);
    final wineBottles = ref.watch(wineBottlesProvider);
    final frozenDishes = ref.watch(frozenDishesProvider);
    final frozenCount = frozenDishes.when(
      data: (dishes) => dishes.fold<int>(0, (sum, d) => sum + d.frozenPortions),
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(
              icon: Icon(Icons.kitchen),
              text: 'Frigo',
            ),
            Tab(
              icon: const Icon(Icons.ac_unit),
              text: 'Congelo${frozenCount > 0 ? ' ($frozenCount)' : ''}',
            ),
            Tab(
              icon: const Icon(Icons.wine_bar),
              text: wineBottles.when(
                data: (wines) => wines.isEmpty ? 'Vin' : 'Vin (${wines.fold<int>(0, (sum, w) => sum + w.quantity)})',
                loading: () => 'Vin',
                error: (_, __) => 'Vin',
              ),
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
          // Tab 2: Freezer (Congelo)
          frozenDishes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (dishes) => dishes.isEmpty
                ? _buildEmptyFreezerState()
                : _buildFreezerList(dishes),
          ),
          // Tab 3: Wine cellar
          wineBottles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (wines) => wines.isEmpty
                ? _buildEmptyWineState()
                : _buildWineList(wines),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          switch (_tabController.index) {
            case 0:
              _showAddDialog();
            case 1:
              _showAddFreezerDialog();
            case 2:
              _showAddWineDialog();
          }
        },
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
            color: context.colorTextHint,
          ),
          const SizedBox(height: 16),
          Text(
            'Frigo vide',
            style: TextStyle(
              fontSize: 18,
              color: context.colorTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez les ingredients que vous avez',
            style: TextStyle(color: context.colorTextHint),
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
        // Bouton ajout rapide toujours visible
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: OutlinedButton.icon(
            onPressed: _showQuickAddDialog,
            icon: const Icon(Icons.flash_on),
            label: const Text('Ajout rapide'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: context.colorTextSecondary,
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

  Widget _buildEmptyWineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wine_bar,
            size: 64,
            color: context.colorTextHint,
          ),
          const SizedBox(height: 16),
          Text(
            'Cave vide',
            style: TextStyle(
              fontSize: 18,
              color: context.colorTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez vos bouteilles de vin',
            style: TextStyle(color: context.colorTextHint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddWineDialog,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une bouteille'),
          ),
        ],
      ),
    );
  }

  // ===== FREEZER TAB =====

  Widget _buildEmptyFreezerState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.ac_unit,
            size: 64,
            color: context.colorTextHint,
          ),
          const SizedBox(height: 16),
          Text(
            'Congelateur vide',
            style: TextStyle(
              fontSize: 18,
              color: context.colorTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des plats prepares que vous avez congeles',
            style: TextStyle(color: context.colorTextHint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddFreezerDialog,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un plat'),
          ),
        ],
      ),
    );
  }

  Widget _buildFreezerList(List<Dish> dishes) {
    // Filter by MealType if selected
    final filteredDishes = _freezerMealTypeFilter == null
        ? dishes
        : dishes.where((d) => d.mealType == _freezerMealTypeFilter).toList();

    return Column(
      children: [
        // MealType filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: _freezerMealTypeFilter == null,
                  onSelected: (_) => setState(() => _freezerMealTypeFilter = null),
                ),
                const SizedBox(width: 8),
                ...MealType.values.map((type) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('${type.icon} ${type.label}'),
                    selected: _freezerMealTypeFilter == type,
                    onSelected: (_) => setState(() {
                      _freezerMealTypeFilter = _freezerMealTypeFilter == type ? null : type;
                    }),
                  ),
                )),
              ],
            ),
          ),
        ),
        // Dish list
        Expanded(
          child: filteredDishes.isEmpty
              ? Center(
                  child: Text(
                    _freezerMealTypeFilter != null
                        ? 'Aucun plat "${_freezerMealTypeFilter!.label}" congele'
                        : 'Aucun plat congele',
                    style: TextStyle(color: context.colorTextHint),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDishes.length + 1, // +1 for add button
                  itemBuilder: (context, index) {
                    if (index == filteredDishes.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          onPressed: _showAddFreezerDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter un plat'),
                        ),
                      );
                    }
                    return _buildFreezerDishCard(filteredDishes[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFreezerDishCard(Dish dish) {
    final daysInFreezer = dish.frozenAt != null
        ? DateTime.now().difference(dish.frozenAt!).inDays
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon/Image
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: dish.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            dish.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.ac_unit,
                              color: AppColors.info,
                            ),
                          ),
                        )
                      : const Icon(Icons.ac_unit, color: AppColors.info),
                ),
                const SizedBox(width: 12),
                // Name and category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          if (dish.mealType != null) ...[
                            Text(
                              dish.mealType!.icon,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              dish.mealType != null
                                  ? '${dish.mealType!.label} - ${dish.categoriesDisplay}'
                                  : dish.categoriesDisplay,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colorTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Portions badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMedium,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.restaurant, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${dish.frozenPortions}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Actions row
            Row(
              children: [
                // Days in freezer
                if (daysInFreezer != null)
                  Text(
                    'Congele il y a $daysInFreezer jours',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorTextHint,
                    ),
                  ),
                const Spacer(),
                // Remove portion button
                TextButton.icon(
                  onPressed: () => _useFreezerPortion(dish),
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('Utiliser'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                // Add portion button
                TextButton.icon(
                  onPressed: () => _addFreezerPortion(dish),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Ajouter'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFreezerDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _AddFreezerSheet(
            scrollController: scrollController,
            onAddManual: (name, categories, mealType, portions) async {
              Navigator.pop(context);
              final familyId = ref.read(currentFamilyIdProvider);
              if (familyId == null) return;

              final userId = ref.read(currentUserProvider)?.uid ?? '';

              await ref.read(dishRepositoryProvider).createDish(
                    familyId: familyId,
                    name: name,
                    createdBy: userId,
                    categories: categories.isNotEmpty ? categories : [DishCategory.complete],
                    mealType: mealType,
                    isFrozen: true,
                    frozenPortions: portions,
                  );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$portions portion(s) ajoutee(s) au congelateur'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            onAddFromRecipe: (recipe, portions) async {
              Navigator.pop(context);
              final familyId = ref.read(currentFamilyIdProvider);
              if (familyId == null) return;

              final userId = ref.read(currentUserProvider)?.uid ?? '';

              // Check if dish already exists for this recipe
              if (recipe.dishId != null) {
                // Add portions to existing dish
                await ref.read(dishRepositoryProvider).addToFreezer(
                      familyId: familyId,
                      dishId: recipe.dishId!,
                      portions: portions,
                    );
              } else {
                // Create new dish from recipe
                await ref.read(dishRepositoryProvider).createDish(
                      familyId: familyId,
                      name: recipe.title,
                      createdBy: userId,
                      categories: [DishCategory.complete],
                      isFrozen: true,
                      frozenPortions: portions,
                    );
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${recipe.title}: $portions portion(s) ajoutee(s)'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _useFreezerPortion(Dish dish) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    await ref.read(dishRepositoryProvider).useFromFreezer(
          familyId: familyId,
          dishId: dish.id,
          portions: 1,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('1 portion de ${dish.name} utilisee'),
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () => _addFreezerPortion(dish),
          ),
        ),
      );
    }
  }

  Future<void> _addFreezerPortion(Dish dish) async {
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    await ref.read(dishRepositoryProvider).addToFreezer(
          familyId: familyId,
          dishId: dish.id,
          portions: 1,
        );
  }

  // ===== WINE TAB =====

  String _sortBy = 'addedAt';
  String? _filterType;
  String _searchQuery = '';

  Widget _buildWineList(List<WineBottle> wines) {
    // Filter wines
    var filteredWines = wines.where((wine) {
      if (_filterType != null && wine.type.name != _filterType) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return wine.name.toLowerCase().contains(query) ||
            (wine.grape?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    // Sort wines
    filteredWines.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return a.name.compareTo(b.name);
        case 'year':
          return (b.year ?? 0).compareTo(a.year ?? 0);
        case 'type':
          return a.type.index.compareTo(b.type.index);
        case 'consumeBefore':
          // Wines with consumeBefore first, sorted by date (soonest first)
          if (a.consumeBefore == null && b.consumeBefore == null) return 0;
          if (a.consumeBefore == null) return 1;
          if (b.consumeBefore == null) return -1;
          return a.consumeBefore!.compareTo(b.consumeBefore!);
        case 'rating':
          return (b.rating ?? 0).compareTo(a.rating ?? 0);
        default:
          return b.addedAt.compareTo(a.addedAt);
      }
    });

    return Column(
      children: [
        // Search and filter bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Type filter chips
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('Tous'),
                            selected: _filterType == null,
                            onSelected: (_) => setState(() => _filterType = null),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Rouge'),
                            selected: _filterType == 'red',
                            selectedColor: Colors.red.shade100,
                            onSelected: (_) => setState(() => _filterType = _filterType == 'red' ? null : 'red'),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Blanc'),
                            selected: _filterType == 'white',
                            selectedColor: Colors.amber.shade100,
                            onSelected: (_) => setState(() => _filterType = _filterType == 'white' ? null : 'white'),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Rosé'),
                            selected: _filterType == 'rose',
                            selectedColor: Colors.pink.shade100,
                            onSelected: (_) => setState(() => _filterType = _filterType == 'rose' ? null : 'rose'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Sort dropdown
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort),
                    tooltip: 'Trier',
                    onSelected: (value) => setState(() => _sortBy = value),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'addedAt',
                        child: Row(
                          children: [
                            Icon(_sortBy == 'addedAt' ? Icons.check : null, size: 18),
                            const SizedBox(width: 8),
                            const Text('Date d\'ajout'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'name',
                        child: Row(
                          children: [
                            Icon(_sortBy == 'name' ? Icons.check : null, size: 18),
                            const SizedBox(width: 8),
                            const Text('Nom'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'year',
                        child: Row(
                          children: [
                            Icon(_sortBy == 'year' ? Icons.check : null, size: 18),
                            const SizedBox(width: 8),
                            const Text('Annee'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'type',
                        child: Row(
                          children: [
                            Icon(_sortBy == 'type' ? Icons.check : null, size: 18),
                            const SizedBox(width: 8),
                            const Text('Type'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'consumeBefore',
                        child: Row(
                          children: [
                            Icon(_sortBy == 'consumeBefore' ? Icons.check : null, size: 18),
                            const SizedBox(width: 8),
                            const Text('A consommer'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rating',
                        child: Row(
                          children: [
                            Icon(_sortBy == 'rating' ? Icons.check : null, size: 18),
                            const SizedBox(width: 8),
                            const Text('Note'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        // Wine list
        Expanded(
          child: filteredWines.isEmpty
              ? Center(
                  child: Text(
                    'Aucun vin trouvé',
                    style: TextStyle(color: context.colorTextHint),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredWines.length,
                  itemBuilder: (context, index) {
                    return _buildWineCard(filteredWines[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWineCard(WineBottle wine) {
    final typeColor = switch (wine.type) {
      WineType.red => Colors.red.shade700,
      WineType.white => Colors.amber.shade700,
      WineType.rose => Colors.pink.shade400,
    };

    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return const SizedBox.shrink();

    return Dismissible(
      key: Key(wine.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Colors.green,
        child: const Icon(Icons.remove, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Decrease quantity
          await ref.read(wineRepositoryProvider).updateQuantity(
            familyId,
            wine.id,
            wine.quantity - 1,
          );
          return false;
        } else {
          // Delete confirmation
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Supprimer'),
              content: Text('Supprimer "${wine.name}" ?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Supprimer', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ) ?? false;
        }
      },
      onDismissed: (_) {
        ref.read(wineRepositoryProvider).deleteWineBottle(familyId, wine.id);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Wine icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.wine_bar, color: typeColor),
                  ),
                  const SizedBox(width: 12),
                  // Name and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wine.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          [
                            wine.typeLabel,
                            if (wine.grape != null) wine.grape,
                            if (wine.year != null) wine.year.toString(),
                          ].join(' - '),
                          style: TextStyle(color: context.colorTextSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  // Quantity controls
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () {
                      ref.read(wineRepositoryProvider).updateQuantity(
                        familyId,
                        wine.id,
                        wine.quantity - 1,
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${wine.quantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () {
                      ref.read(wineRepositoryProvider).updateQuantity(
                        familyId,
                        wine.id,
                        wine.quantity + 1,
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              // Rating and consume before row
              if (wine.rating != null || wine.consumeBefore != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Rating stars
                    if (wine.rating != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          return Icon(
                            index < wine.rating! ? Icons.star : Icons.star_border,
                            size: 16,
                            color: index < wine.rating! ? AppColors.warning : context.colorTextHint,
                          );
                        }),
                      ),
                      const SizedBox(width: 16),
                    ],
                    // Consume before date
                    if (wine.consumeBefore != null) ...[
                      Icon(
                        wine.isExpired ? Icons.error_outline :
                        wine.shouldConsumeSoon ? Icons.schedule : Icons.event,
                        size: 14,
                        color: wine.isExpired ? AppColors.error :
                               wine.shouldConsumeSoon ? AppColors.warning : context.colorTextHint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Avant le ${wine.consumeBefore!.day}/${wine.consumeBefore!.month}/${wine.consumeBefore!.year}',
                        style: TextStyle(
                          fontSize: 12,
                          color: wine.isExpired ? AppColors.error :
                                 wine.shouldConsumeSoon ? AppColors.warning : context.colorTextHint,
                          fontWeight: wine.shouldConsumeSoon || wine.isExpired ? FontWeight.w500 : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddWineDialog() {
    final nameController = TextEditingController();
    final grapeController = TextEditingController();
    final yearController = TextEditingController();
    WineType selectedType = WineType.red;
    int quantity = 1;
    DateTime? consumeBefore;
    int? rating;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ajouter une bouteille',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du vin *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                // Wine type selector
                SegmentedButton<WineType>(
                  segments: const [
                    ButtonSegment(
                      value: WineType.red,
                      label: Text('Rouge'),
                      icon: Icon(Icons.wine_bar),
                    ),
                    ButtonSegment(
                      value: WineType.white,
                      label: Text('Blanc'),
                      icon: Icon(Icons.wine_bar),
                    ),
                    ButtonSegment(
                      value: WineType.rose,
                      label: Text('Rose'),
                      icon: Icon(Icons.wine_bar),
                    ),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (types) {
                    setSheetState(() => selectedType = types.first);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: grapeController,
                        decoration: const InputDecoration(
                          labelText: 'Cepage',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: yearController,
                        decoration: const InputDecoration(
                          labelText: 'Annee',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Consume before date picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: consumeBefore ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
                      helpText: 'A consommer avant',
                    );
                    if (picked != null) {
                      setSheetState(() => consumeBefore = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'A consommer avant',
                      border: const OutlineInputBorder(),
                      suffixIcon: consumeBefore != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setSheetState(() => consumeBefore = null),
                            )
                          : const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      consumeBefore != null
                          ? '${consumeBefore!.day}/${consumeBefore!.month}/${consumeBefore!.year}'
                          : 'Optionnel',
                      style: TextStyle(
                        color: consumeBefore != null ? null : context.colorTextHint,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Rating selector
                Row(
                  children: [
                    const Text('Note: '),
                    const SizedBox(width: 8),
                    ...List.generate(5, (index) {
                      final starIndex = index + 1;
                      return IconButton(
                        icon: Icon(
                          rating != null && starIndex <= rating! ? Icons.star : Icons.star_border,
                          color: rating != null && starIndex <= rating! ? AppColors.warning : null,
                        ),
                        onPressed: () {
                          setSheetState(() {
                            rating = rating == starIndex ? null : starIndex;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      );
                    }),
                    if (rating != null) ...[
                      const SizedBox(width: 8),
                      Text('$rating/5', style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Quantity selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Quantite: '),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: quantity > 1
                          ? () => setSheetState(() => quantity--)
                          : null,
                    ),
                    Text(
                      '$quantity',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setSheetState(() => quantity++),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Le nom est requis')),
                      );
                      return;
                    }
                    final familyId = ref.read(currentFamilyIdProvider);
                    if (familyId == null) return;

                    await ref.read(wineRepositoryProvider).addWineBottle(
                      familyId: familyId,
                      name: nameController.text.trim(),
                      type: selectedType,
                      grape: grapeController.text.trim().isEmpty
                          ? null
                          : grapeController.text.trim(),
                      year: int.tryParse(yearController.text),
                      quantity: quantity,
                      consumeBefore: consumeBefore,
                      rating: rating,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Ajouter'),
                ),
                const SizedBox(height: 16),
              ],
            ),
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
        title: const Text('Vider le stock?'),
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

/// Bottom sheet for adding frozen dishes
/// Supports manual entry or selection from existing recipes
class _AddFreezerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final Future<void> Function(String name, List<DishCategory> categories, MealType? mealType, int portions) onAddManual;
  final Future<void> Function(Recipe recipe, int portions) onAddFromRecipe;

  const _AddFreezerSheet({
    required this.scrollController,
    required this.onAddManual,
    required this.onAddFromRecipe,
  });

  @override
  ConsumerState<_AddFreezerSheet> createState() => _AddFreezerSheetState();
}

enum _FreezerAddMode { manual, fromRecipe }

class _AddFreezerSheetState extends ConsumerState<_AddFreezerSheet> {
  _FreezerAddMode _mode = _FreezerAddMode.manual;

  // Manual mode state
  final _nameController = TextEditingController();
  final Set<DishCategory> _selectedCategories = {DishCategory.complete};
  MealType? _selectedMealType;
  int _manualPortions = 1;

  // Recipe mode state
  Recipe? _selectedRecipe;
  int _recipePortions = 1;
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(familyRecipesProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colorTextHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.ac_unit, color: AppColors.info),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ajouter au congelateur',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Mode selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<_FreezerAddMode>(
              segments: const [
                ButtonSegment(
                  value: _FreezerAddMode.manual,
                  label: Text('Entree manuelle'),
                  icon: Icon(Icons.edit),
                ),
                ButtonSegment(
                  value: _FreezerAddMode.fromRecipe,
                  label: Text('Depuis recette'),
                  icon: Icon(Icons.menu_book),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (Set<_FreezerAddMode> selected) {
                setState(() => _mode = selected.first);
              },
            ),
          ),

          const SizedBox(height: 16),

          // Content based on mode
          Expanded(
            child: _mode == _FreezerAddMode.manual
                ? _buildManualMode()
                : _buildRecipeMode(recipesAsync),
          ),

          // Add button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _canAdd() ? _handleAdd : null,
                  icon: const Icon(Icons.add),
                  label: Text(_getAddButtonLabel()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualMode() {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Name field
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Nom du plat *',
            hintText: 'Ex: Lasagnes, Soupe de legumes...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 20),

        // Categories
        const Text(
          'Categories',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DishCategory.values.map((category) {
            final isSelected = _selectedCategories.contains(category);
            return FilterChip(
              label: Text(category.label),
              avatar: Text(category.icon),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories.add(category);
                  } else {
                    _selectedCategories.remove(category);
                  }
                });
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Meal type selector
        const Text(
          'Type de repas',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Non defini'),
              selected: _selectedMealType == null,
              onSelected: (_) => setState(() => _selectedMealType = null),
            ),
            ...MealType.values.map((type) => FilterChip(
              label: Text('${type.icon} ${type.label}'),
              selected: _selectedMealType == type,
              onSelected: (_) => setState(() => _selectedMealType = type),
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
            )),
          ],
        ),

        const SizedBox(height: 20),

        // Portions selector
        _buildPortionsSelector(_manualPortions, (value) {
          setState(() => _manualPortions = value);
        }),
      ],
    );
  }

  Widget _buildRecipeMode(AsyncValue<List<Recipe>> recipesAsync) {
    return Column(
      children: [
        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher une recette...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          ),
        ),

        const SizedBox(height: 12),

        // Recipe list
        Expanded(
          child: recipesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (recipes) {
              final filtered = recipes.where((r) {
                if (_searchQuery.isEmpty) return true;
                return r.title.toLowerCase().contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book, size: 48, color: context.colorTextHint),
                      const SizedBox(height: 12),
                      Text(
                        recipes.isEmpty
                            ? 'Aucune recette'
                            : 'Aucune recette trouvee',
                        style: TextStyle(color: context.colorTextSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final recipe = filtered[index];
                  final isSelected = _selectedRecipe?.id == recipe.id;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? const BorderSide(color: AppColors.primary, width: 2)
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedRecipe = isSelected ? null : recipe;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Image
                            Container(
                              width: 50,
                              height: 50,
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
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.restaurant,
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.restaurant,
                                      color: context.colorTextHint,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // Title
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recipe.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (recipe.servings > 0)
                                    Text(
                                      '${recipe.servings} portions',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.colorTextSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Selection indicator
                            if (isSelected)
                              const Icon(Icons.check_circle, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Portions selector (only if recipe selected)
        if (_selectedRecipe != null)
          Container(
            padding: const EdgeInsets.all(16),
            child: _buildPortionsSelector(_recipePortions, (value) {
              setState(() => _recipePortions = value);
            }),
          ),
      ],
    );
  }

  Widget _buildPortionsSelector(int value, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.restaurant, color: AppColors.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Nombre de portions',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          // Decrease button
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.primary,
          ),
          // Value
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          // Increase button
          IconButton(
            onPressed: value < 20 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  bool _canAdd() {
    if (_mode == _FreezerAddMode.manual) {
      return _nameController.text.trim().isNotEmpty;
    } else {
      return _selectedRecipe != null;
    }
  }

  String _getAddButtonLabel() {
    final portions = _mode == _FreezerAddMode.manual ? _manualPortions : _recipePortions;
    if (_mode == _FreezerAddMode.manual) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        return 'Ajouter';
      }
      return 'Ajouter $portions portion${portions > 1 ? 's' : ''}';
    } else {
      if (_selectedRecipe == null) {
        return 'Selectionnez une recette';
      }
      return 'Ajouter $portions portion${portions > 1 ? 's' : ''}';
    }
  }

  void _handleAdd() {
    if (_mode == _FreezerAddMode.manual) {
      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        widget.onAddManual(name, _selectedCategories.toList(), _selectedMealType, _manualPortions);
      }
    } else {
      if (_selectedRecipe != null) {
        widget.onAddFromRecipe(_selectedRecipe!, _recipePortions);
      }
    }
  }
}
