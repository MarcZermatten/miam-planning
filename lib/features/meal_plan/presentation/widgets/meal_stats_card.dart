import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/meal_statistics_provider.dart';
import '../../domain/meal_statistics.dart';

/// Widget displaying meal planning statistics
class MealStatsCard extends ConsumerWidget {
  const MealStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(mealStatisticsStreamProvider);

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        // Don't show if no data
        if (stats.topDishes.isEmpty && stats.mealsPlannedThisWeek == 0) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Statistiques',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatsGrid(context, stats),
          ],
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, MealStatistics stats) {
    return Column(
      children: [
        // Row 1: Completion + Top dishes
        Row(
          children: [
            Expanded(
              child: _buildCompletionCard(stats),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTopDishesCard(stats),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: Accompaniments alert or variety tip
        if (stats.overusedAccompaniment != null)
          _buildAlertCard(
            icon: Icons.warning_amber_rounded,
            color: AppColors.warning,
            title: 'Attention',
            message:
                '${stats.overusedAccompaniment} servi ${stats.accompanimentFrequency[stats.overusedAccompaniment]}x cette semaine',
          )
        else if (stats.neglectedDish != null)
          _buildAlertCard(
            icon: Icons.lightbulb_outline,
            color: AppColors.info,
            title: 'Suggestion',
            message:
                'Ca fait ${stats.neglectedDish!.value} jours sans ${_getDishName(stats, stats.neglectedDish!.key)}',
          ),
      ],
    );
  }

  Widget _buildCompletionCard(MealStatistics stats) {
    final percent = (stats.completionRate * 100).round();
    final color = percent >= 70
        ? AppColors.success
        : percent >= 40
            ? AppColors.warning
            : AppColors.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: color),
                const SizedBox(width: 6),
                const Text(
                  'Cette semaine',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${stats.mealsPlannedThisWeek}/${stats.totalMealsThisWeek}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: stats.completionRate,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopDishesCard(MealStatistics stats) {
    final topDishes = stats.topDishes.take(3).toList();

    if (topDishes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite, size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  const Text(
                    'Favoris du mois',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Pas encore de donnees',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                const Text(
                  'Favoris du mois',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...topDishes.asMap().entries.map((entry) {
              final index = entry.key;
              final dish = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Text(
                      '${index + 1}.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        dish.dishName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '${dish.usageCount}x',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDishName(MealStatistics stats, String dishId) {
    final dish = stats.topDishes.where((d) => d.dishId == dishId).firstOrNull;
    if (dish != null) return dish.dishName;
    // Fallback - just return a shortened ID
    return dishId.length > 10 ? '${dishId.substring(0, 10)}...' : dishId;
  }
}
