import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../domain/recipe.dart';

/// Service pour importer des recettes depuis une URL
class RecipeScraper {
  /// Importe une recette depuis une URL
  /// Utilise les donnees structurees JSON-LD (schema.org/Recipe)
  static Future<ScrapedRecipe?> scrapeFromUrl(String url) async {
    try {
      // Telecharger la page
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
          'Accept-Charset': 'utf-8',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }

      // Decoder en UTF-8 (le body par defaut utilise latin1)
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final document = html_parser.parse(body);

      // Chercher les scripts JSON-LD
      final scripts = document.querySelectorAll('script[type="application/ld+json"]');

      for (final script in scripts) {
        try {
          final jsonText = script.text;
          final data = json.decode(jsonText);

          // Peut etre un objet ou une liste
          final recipes = _findRecipes(data);
          if (recipes.isNotEmpty) {
            return _parseRecipe(recipes.first, url);
          }
        } catch (_) {
          // Ignorer les erreurs de parsing JSON
          continue;
        }
      }

      // Si pas de JSON-LD, essayer le parsing HTML basique
      return _parseHtmlFallback(document, url);
    } catch (e) {
      throw Exception('Impossible d\'importer: $e');
    }
  }

  /// Trouve les objets Recipe dans les donnees JSON-LD
  static List<Map<String, dynamic>> _findRecipes(dynamic data) {
    final recipes = <Map<String, dynamic>>[];

    if (data is Map<String, dynamic>) {
      final type = data['@type'];
      if (type == 'Recipe' || (type is List && type.contains('Recipe'))) {
        recipes.add(data);
      }

      // Chercher dans @graph
      if (data['@graph'] is List) {
        for (final item in data['@graph']) {
          recipes.addAll(_findRecipes(item));
        }
      }
    } else if (data is List) {
      for (final item in data) {
        recipes.addAll(_findRecipes(item));
      }
    }

    return recipes;
  }

  /// Parse un objet Recipe JSON-LD en ScrapedRecipe
  static ScrapedRecipe _parseRecipe(Map<String, dynamic> data, String url) {
    // Titre
    final title = data['name']?.toString() ?? 'Sans titre';

    // Description
    final description = data['description']?.toString();

    // Image
    String? imageUrl;
    final image = data['image'];
    if (image is String) {
      imageUrl = image;
    } else if (image is List && image.isNotEmpty) {
      imageUrl = image.first is String ? image.first : image.first['url'];
    } else if (image is Map) {
      imageUrl = image['url']?.toString();
    }

    // Temps
    final prepTime = _parseDuration(data['prepTime']?.toString());
    final cookTime = _parseDuration(data['cookTime']?.toString());

    // Portions
    int servings = 4;
    final yield = data['recipeYield'];
    if (yield is int) {
      servings = yield;
    } else if (yield is String) {
      final match = RegExp(r'\d+').firstMatch(yield);
      if (match != null) {
        servings = int.tryParse(match.group(0)!) ?? 4;
      }
    } else if (yield is List && yield.isNotEmpty) {
      final first = yield.first;
      if (first is int) {
        servings = first;
      } else if (first is String) {
        final match = RegExp(r'\d+').firstMatch(first);
        if (match != null) {
          servings = int.tryParse(match.group(0)!) ?? 4;
        }
      }
    }

    // Ingredients
    final ingredients = <Ingredient>[];
    final ingredientList = data['recipeIngredient'];
    if (ingredientList is List) {
      for (final item in ingredientList) {
        if (item is String && item.trim().isNotEmpty) {
          ingredients.add(_parseIngredient(item));
        }
      }
    }

    // Instructions
    final instructions = <String>[];
    final instructionList = data['recipeInstructions'];
    if (instructionList is List) {
      for (final item in instructionList) {
        if (item is String) {
          instructions.add(item.trim());
        } else if (item is Map) {
          final text = item['text']?.toString() ?? item['name']?.toString();
          if (text != null && text.isNotEmpty) {
            instructions.add(text.trim());
          }
        }
      }
    } else if (instructionList is String) {
      instructions.addAll(
        instructionList.split(RegExp(r'\n|<br\s*/?>'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      );
    }

    return ScrapedRecipe(
      title: title,
      description: description,
      imageUrl: imageUrl,
      sourceUrl: url,
      prepTime: prepTime,
      cookTime: cookTime,
      servings: servings,
      ingredients: ingredients,
      instructions: instructions,
    );
  }

  /// Parse une duree ISO 8601 (PT30M, PT1H30M, etc.)
  static int _parseDuration(String? duration) {
    if (duration == null) return 0;

    // Format ISO 8601: PT1H30M, PT30M, PT2H, etc.
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(duration);

    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
      return hours * 60 + minutes;
    }

    // Essayer de parser un nombre simple
    final simpleMatch = RegExp(r'\d+').firstMatch(duration);
    if (simpleMatch != null) {
      return int.tryParse(simpleMatch.group(0)!) ?? 0;
    }

    return 0;
  }

  /// Parse une ligne d'ingredient en Ingredient
  static Ingredient _parseIngredient(String text) {
    // Patterns courants: "500 g de farine", "2 oeufs", "1/2 cuillere"
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Essayer de parser quantite + unite + nom
    final regex = RegExp(
      r'^([\d\s,./]+)?\s*(g|kg|ml|cl|l|dl|cs|cc|pcs?|tranches?)?\s*(?:de\s+)?(.+)$',
      caseSensitive: false,
    );

    final match = regex.firstMatch(cleaned);

    if (match != null) {
      final amountStr = match.group(1)?.trim();
      final unit = match.group(2)?.trim();
      final name = match.group(3)?.trim() ?? cleaned;

      double? amount;
      if (amountStr != null && amountStr.isNotEmpty) {
        // Gerer les fractions
        if (amountStr.contains('/')) {
          final parts = amountStr.split('/');
          if (parts.length == 2) {
            final num = double.tryParse(parts[0].trim());
            final den = double.tryParse(parts[1].trim());
            if (num != null && den != null && den != 0) {
              amount = num / den;
            }
          }
        } else {
          amount = double.tryParse(amountStr.replaceAll(',', '.'));
        }
      }

      return Ingredient(
        name: name.isEmpty ? cleaned : name,
        amount: amount,
        unit: unit,
      );
    }

    return Ingredient(name: cleaned);
  }

  /// Fallback: parser le HTML si pas de JSON-LD
  static ScrapedRecipe? _parseHtmlFallback(dynamic document, String url) {
    // Chercher le titre
    final title = document.querySelector('h1')?.text.trim() ?? 'Recette importee';

    // Chercher une image
    String? imageUrl;
    final img = document.querySelector('img[src*="recipe"], img[src*="recette"], article img');
    if (img != null) {
      imageUrl = img.attributes['src'];
    }

    return ScrapedRecipe(
      title: title,
      sourceUrl: url,
      imageUrl: imageUrl,
      ingredients: [],
      instructions: [],
    );
  }
}

/// Resultat du scraping d'une recette
class ScrapedRecipe {
  final String title;
  final String? description;
  final String? imageUrl;
  final String sourceUrl;
  final int prepTime;
  final int cookTime;
  final int servings;
  final List<Ingredient> ingredients;
  final List<String> instructions;

  ScrapedRecipe({
    required this.title,
    this.description,
    this.imageUrl,
    required this.sourceUrl,
    this.prepTime = 0,
    this.cookTime = 0,
    this.servings = 4,
    required this.ingredients,
    required this.instructions,
  });
}
