/// Utility class for standardizing and converting quantities
class QuantityUtils {
  /// Standard units with their abbreviations and conversions
  static const Map<String, UnitInfo> standardUnits = {
    // Weight
    'g': UnitInfo(name: 'gramme', category: UnitCategory.weight, baseUnit: 'g', factor: 1),
    'kg': UnitInfo(name: 'kilogramme', category: UnitCategory.weight, baseUnit: 'g', factor: 1000),
    'mg': UnitInfo(name: 'milligramme', category: UnitCategory.weight, baseUnit: 'g', factor: 0.001),

    // Volume
    'ml': UnitInfo(name: 'millilitre', category: UnitCategory.volume, baseUnit: 'ml', factor: 1),
    'cl': UnitInfo(name: 'centilitre', category: UnitCategory.volume, baseUnit: 'ml', factor: 10),
    'dl': UnitInfo(name: 'decilitre', category: UnitCategory.volume, baseUnit: 'ml', factor: 100),
    'l': UnitInfo(name: 'litre', category: UnitCategory.volume, baseUnit: 'ml', factor: 1000),

    // Spoons
    'cc': UnitInfo(name: 'cuillere a cafe', category: UnitCategory.volume, baseUnit: 'ml', factor: 5),
    'cs': UnitInfo(name: 'cuillere a soupe', category: UnitCategory.volume, baseUnit: 'ml', factor: 15),

    // Pieces
    'pc': UnitInfo(name: 'piece', category: UnitCategory.count, baseUnit: 'pc', factor: 1),
    'tranche': UnitInfo(name: 'tranche', category: UnitCategory.count, baseUnit: 'pc', factor: 1),
    'gousse': UnitInfo(name: 'gousse', category: UnitCategory.count, baseUnit: 'pc', factor: 1),
    'feuille': UnitInfo(name: 'feuille', category: UnitCategory.count, baseUnit: 'pc', factor: 1),
    'brin': UnitInfo(name: 'brin', category: UnitCategory.count, baseUnit: 'pc', factor: 1),
    'pincee': UnitInfo(name: 'pincee', category: UnitCategory.count, baseUnit: 'pc', factor: 1),

    // Packaging
    'sachet': UnitInfo(name: 'sachet', category: UnitCategory.packaging, baseUnit: 'sachet', factor: 1),
    'boite': UnitInfo(name: 'boite', category: UnitCategory.packaging, baseUnit: 'boite', factor: 1),
    'pot': UnitInfo(name: 'pot', category: UnitCategory.packaging, baseUnit: 'pot', factor: 1),
    'botte': UnitInfo(name: 'botte', category: UnitCategory.packaging, baseUnit: 'botte', factor: 1),
  };

  /// Common unit aliases for parsing
  static const Map<String, String> unitAliases = {
    // Weight
    'gramme': 'g', 'grammes': 'g', 'gr': 'g',
    'kilogramme': 'kg', 'kilogrammes': 'kg', 'kilo': 'kg', 'kilos': 'kg',
    'milligramme': 'mg', 'milligrammes': 'mg',

    // Volume
    'millilitre': 'ml', 'millilitres': 'ml',
    'centilitre': 'cl', 'centilitres': 'cl',
    'decilitre': 'dl', 'decilitres': 'dl',
    'litre': 'l', 'litres': 'l',

    // Spoons
    'cuillere a cafe': 'cc', 'cuilleres a cafe': 'cc', 'c. a cafe': 'cc', 'cac': 'cc',
    'cuillere a soupe': 'cs', 'cuilleres a soupe': 'cs', 'c. a soupe': 'cs', 'cas': 'cs',

    // Pieces
    'piece': 'pc', 'pieces': 'pc', 'unite': 'pc', 'unites': 'pc',
    'tranches': 'tranche',
    'gousses': 'gousse',
    'feuilles': 'feuille',
    'brins': 'brin',
    'pincees': 'pincee',

    // Packaging
    'sachets': 'sachet',
    'boites': 'boite',
    'pots': 'pot',
    'bottes': 'botte',
  };

  /// Normalize a unit string to its standard form
  static String? normalizeUnit(String? unit) {
    if (unit == null || unit.isEmpty) return null;

    final lower = unit.toLowerCase().trim();

    // Check if it's already a standard unit
    if (standardUnits.containsKey(lower)) return lower;

    // Check aliases
    if (unitAliases.containsKey(lower)) return unitAliases[lower];

    return lower; // Return as-is if not recognized
  }

  /// Parse a quantity string like "500g", "2 cs", "1.5 kg"
  static ParsedQuantity? parseQuantity(String input) {
    if (input.isEmpty) return null;

    final cleaned = input.trim().toLowerCase();

    // Try to extract number and unit
    final regex = RegExp(r'^(\d+(?:[.,]\d+)?)\s*([a-zA-Z\u00e0-\u00ff\s]+)?$');
    final match = regex.firstMatch(cleaned);

    if (match == null) return null;

    final numberStr = match.group(1)?.replaceAll(',', '.');
    final unitStr = match.group(2)?.trim();

    final amount = double.tryParse(numberStr ?? '');
    if (amount == null) return null;

    final unit = normalizeUnit(unitStr);

    return ParsedQuantity(amount: amount, unit: unit);
  }

  /// Convert a quantity to a different unit (if compatible)
  static double? convert(double amount, String fromUnit, String toUnit) {
    final from = standardUnits[normalizeUnit(fromUnit)];
    final to = standardUnits[normalizeUnit(toUnit)];

    if (from == null || to == null) return null;
    if (from.category != to.category) return null;
    if (from.baseUnit != to.baseUnit) return null;

    // Convert to base unit, then to target
    final inBase = amount * from.factor;
    return inBase / to.factor;
  }

  /// Get the best display unit for a quantity (e.g., 1500g -> 1.5kg)
  static ParsedQuantity optimizeDisplay(double amount, String unit) {
    final normalized = normalizeUnit(unit);
    final info = standardUnits[normalized];

    if (info == null) return ParsedQuantity(amount: amount, unit: unit);

    // Convert to base unit first
    final inBase = amount * info.factor;

    // Find best unit for display
    if (info.category == UnitCategory.weight) {
      if (inBase >= 1000) {
        return ParsedQuantity(amount: inBase / 1000, unit: 'kg');
      } else if (inBase < 1) {
        return ParsedQuantity(amount: inBase * 1000, unit: 'mg');
      }
      return ParsedQuantity(amount: inBase, unit: 'g');
    }

    if (info.category == UnitCategory.volume) {
      if (inBase >= 1000) {
        return ParsedQuantity(amount: inBase / 1000, unit: 'l');
      } else if (inBase >= 100) {
        return ParsedQuantity(amount: inBase / 100, unit: 'dl');
      }
      return ParsedQuantity(amount: inBase, unit: 'ml');
    }

    return ParsedQuantity(amount: amount, unit: normalized ?? unit);
  }

  /// Format a quantity for display
  static String formatQuantity(double? amount, String? unit) {
    if (amount == null) return unit ?? '';

    // Format number: remove decimal if whole number
    String numStr;
    if (amount == amount.roundToDouble()) {
      numStr = amount.toInt().toString();
    } else {
      numStr = amount.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    }

    if (unit == null || unit.isEmpty) return numStr;
    return '$numStr $unit';
  }

  /// Aggregate quantities (for shopping list)
  static List<AggregatedQuantity> aggregateQuantities(
    List<ParsedQuantity> quantities,
  ) {
    final byUnit = <String, double>{};

    for (final q in quantities) {
      final unit = q.unit ?? 'pc';
      final normalized = normalizeUnit(unit) ?? unit;
      byUnit[normalized] = (byUnit[normalized] ?? 0) + q.amount;
    }

    return byUnit.entries.map((e) {
      final optimized = optimizeDisplay(e.value, e.key);
      return AggregatedQuantity(
        amount: optimized.amount,
        unit: optimized.unit ?? e.key,
        displayText: formatQuantity(optimized.amount, optimized.unit),
      );
    }).toList();
  }
}

/// Unit categories
enum UnitCategory {
  weight,
  volume,
  count,
  packaging,
}

/// Information about a unit
class UnitInfo {
  final String name;
  final UnitCategory category;
  final String baseUnit;
  final double factor;

  const UnitInfo({
    required this.name,
    required this.category,
    required this.baseUnit,
    required this.factor,
  });
}

/// A parsed quantity with amount and unit
class ParsedQuantity {
  final double amount;
  final String? unit;

  const ParsedQuantity({required this.amount, this.unit});

  @override
  String toString() => QuantityUtils.formatQuantity(amount, unit);
}

/// An aggregated quantity for shopping lists
class AggregatedQuantity {
  final double amount;
  final String unit;
  final String displayText;

  const AggregatedQuantity({
    required this.amount,
    required this.unit,
    required this.displayText,
  });
}
