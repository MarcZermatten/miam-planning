import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routing/app_router.dart';
import '../../../wine/data/wine_repository.dart';
import '../../../wine/domain/wine_bottle.dart';

/// Widget displaying wines that should be consumed soon on home screen
class WinesAlertCard extends ConsumerWidget {
  const WinesAlertCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final winesAsync = ref.watch(wineBottlesProvider);

    return winesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (wines) {
        if (wines.isEmpty) return const SizedBox.shrink();

        // Filter wines to consume soon:
        // 1. Wines with consumeBefore date within 60 days
        // 2. Wines added more than 2 years ago without consumeBefore date
        final now = DateTime.now();
        final twoYearsAgo = now.subtract(const Duration(days: 365 * 2));

        final toConsume = wines.where((wine) {
          // Priority 1: Wines with consumeBefore date approaching
          if (wine.consumeBefore != null) {
            final daysLeft = wine.consumeBefore!.difference(now).inDays;
            return daysLeft <= 60; // Within 60 days or expired
          }
          // Priority 2: Old wines without consume date
          return wine.addedAt.isBefore(twoYearsAgo);
        }).toList();

        if (toConsume.isEmpty) return const SizedBox.shrink();

        // Sort: expired first, then by consumeBefore date, then by age
        toConsume.sort((a, b) {
          // Both have consumeBefore
          if (a.consumeBefore != null && b.consumeBefore != null) {
            return a.consumeBefore!.compareTo(b.consumeBefore!);
          }
          // One has consumeBefore
          if (a.consumeBefore != null) return -1;
          if (b.consumeBefore != null) return 1;
          // Both are old wines - sort by addedAt
          return a.addedAt.compareTo(b.addedAt);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.wine_bar, size: 20, color: AppColors.error),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Vins a consommer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.pantry),
                  child: const Text('Cave'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Content card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  ...toConsume.take(3).map((wine) => _buildWineItem(context, wine)),
                  if (toConsume.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+${toConsume.length - 3} autre${toConsume.length - 3 > 1 ? 's' : ''}',
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

  Widget _buildWineItem(BuildContext context, WineBottle wine) {
    final typeColor = switch (wine.type) {
      WineType.red => Colors.red.shade700,
      WineType.white => Colors.amber.shade700,
      WineType.rose => Colors.pink.shade400,
    };

    // Determine urgency and message
    String urgencyText;
    Color urgencyColor;

    if (wine.consumeBefore != null) {
      final daysLeft = wine.daysUntilConsumeBefore ?? 0;
      if (daysLeft < 0) {
        urgencyText = 'Expire';
        urgencyColor = AppColors.error;
      } else if (daysLeft == 0) {
        urgencyText = 'Aujourd\'hui';
        urgencyColor = AppColors.error;
      } else if (daysLeft <= 7) {
        urgencyText = '$daysLeft j';
        urgencyColor = AppColors.error;
      } else if (daysLeft <= 30) {
        urgencyText = '$daysLeft j';
        urgencyColor = AppColors.warning;
      } else {
        urgencyText = '${(daysLeft / 30).round()} mois';
        urgencyColor = AppColors.info;
      }
    } else {
      // Old wine without consume date
      final yearsOld = DateTime.now().difference(wine.addedAt).inDays ~/ 365;
      urgencyText = '$yearsOld ans';
      urgencyColor = AppColors.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Wine type icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.wine_bar, color: typeColor, size: 18),
          ),
          const SizedBox(width: 10),
          // Wine info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wine.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${wine.typeLabel}${wine.year != null ? ' ${wine.year}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colorTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Urgency badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              urgencyText,
              style: TextStyle(
                color: urgencyColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          // Quantity
          if (wine.quantity > 1) ...[
            const SizedBox(width: 6),
            Text(
              'x${wine.quantity}',
              style: TextStyle(
                color: context.colorTextHint,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
