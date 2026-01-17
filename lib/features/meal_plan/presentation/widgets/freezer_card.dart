import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routing/app_router.dart';
import '../../../dishes/data/dish_repository.dart';
import '../../../dishes/domain/dish.dart';

/// Widget displaying frozen dishes summary on home screen
class FreezerCard extends ConsumerWidget {
  const FreezerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frozenDishesAsync = ref.watch(frozenDishesProvider);

    return frozenDishesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (dishes) {
        if (dishes.isEmpty) return const SizedBox.shrink();

        // Sort by portions (most portions first)
        final sortedDishes = List<Dish>.from(dishes)
          ..sort((a, b) => b.frozenPortions.compareTo(a.frozenPortions));

        final totalPortions = dishes.fold<int>(0, (sum, d) => sum + d.frozenPortions);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.ac_unit, size: 20, color: AppColors.info),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Congelateur',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.pantry),
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Content card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total portions badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.info,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$totalPortions portions',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${dishes.length} plat${dishes.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: context.colorTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Dish list (max 5 items)
                  ...sortedDishes.take(5).map((dish) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Text(
                          dish.categoriesIcons,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dish.name,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryMedium.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${dish.frozenPortions}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                  if (dishes.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${dishes.length - 5} autre${dishes.length - 5 > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colorTextHint,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
