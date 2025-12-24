import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

/// Service pour rechercher des recettes sur les sites externes
class RecipeSearchService {
  /// Recherche sur plusieurs sources et combine les resultats
  static Future<List<ExternalRecipe>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final results = await Future.wait([
      _searchMarmiton(query),
      _searchBettyBossi(query),
    ]);

    // Combiner et melanger les resultats
    final combined = <ExternalRecipe>[];
    final maxLen = results.map((r) => r.length).fold(0, (a, b) => a > b ? a : b);

    for (var i = 0; i < maxLen; i++) {
      for (final list in results) {
        if (i < list.length) {
          combined.add(list[i]);
        }
      }
    }

    return combined;
  }

  /// Recherche sur Marmiton
  static Future<List<ExternalRecipe>> _searchMarmiton(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final url = 'https://www.marmiton.org/recettes/recherche.aspx?aqt=$encoded';

      final response = await http.get(
        Uri.parse(url),
        headers: _defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final results = <ExternalRecipe>[];

      // Marmiton utilise des cartes de recettes
      final cards = document.querySelectorAll('[class*="recipe-card"], [class*="MRTN__sc"]');

      for (final card in cards.take(10)) {
        try {
          // Titre
          final titleEl = card.querySelector('h4, [class*="title"], a');
          final title = titleEl?.text.trim();
          if (title == null || title.isEmpty) continue;

          // URL
          final linkEl = card.querySelector('a[href*="/recettes/"]');
          var recipeUrl = linkEl?.attributes['href'];
          if (recipeUrl != null && !recipeUrl.startsWith('http')) {
            recipeUrl = 'https://www.marmiton.org$recipeUrl';
          }
          if (recipeUrl == null) continue;

          // Image
          final imgEl = card.querySelector('img');
          var imageUrl = imgEl?.attributes['src'] ?? imgEl?.attributes['data-src'];

          // Rating
          final ratingEl = card.querySelector('[class*="rating"], [class*="note"]');
          final ratingText = ratingEl?.text ?? '';
          final ratingMatch = RegExp(r'[\d,\.]+').firstMatch(ratingText);
          final rating = ratingMatch != null
              ? double.tryParse(ratingMatch.group(0)!.replaceAll(',', '.'))
              : null;

          results.add(ExternalRecipe(
            title: title,
            url: recipeUrl,
            imageUrl: imageUrl,
            source: 'Marmiton',
            rating: rating,
          ));
        } catch (_) {
          continue;
        }
      }

      return results;
    } catch (e) {
      print('Erreur recherche Marmiton: $e');
      return [];
    }
  }

  /// Recherche sur Betty Bossi
  static Future<List<ExternalRecipe>> _searchBettyBossi(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final url = 'https://www.bettybossi.ch/fr/Rezept/Suche?query=$encoded';

      final response = await http.get(
        Uri.parse(url),
        headers: _defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final results = <ExternalRecipe>[];

      // Betty Bossi utilise des cartes
      final cards = document.querySelectorAll('[class*="recipe"], [class*="teaser"], article');

      for (final card in cards.take(10)) {
        try {
          // Titre
          final titleEl = card.querySelector('h2, h3, [class*="title"], a');
          final title = titleEl?.text.trim();
          if (title == null || title.isEmpty || title.length < 3) continue;

          // URL
          final linkEl = card.querySelector('a[href*="Rezept"]');
          var recipeUrl = linkEl?.attributes['href'];
          if (recipeUrl != null && !recipeUrl.startsWith('http')) {
            recipeUrl = 'https://www.bettybossi.ch$recipeUrl';
          }
          if (recipeUrl == null) continue;

          // Image
          final imgEl = card.querySelector('img');
          var imageUrl = imgEl?.attributes['src'] ?? imgEl?.attributes['data-src'];
          if (imageUrl != null && !imageUrl.startsWith('http')) {
            imageUrl = 'https://www.bettybossi.ch$imageUrl';
          }

          // Temps de preparation
          final timeEl = card.querySelector('[class*="time"], [class*="duration"]');
          final timeText = timeEl?.text ?? '';
          final timeMatch = RegExp(r'(\d+)\s*min').firstMatch(timeText);
          final prepTime = timeMatch != null ? int.tryParse(timeMatch.group(1)!) : null;

          results.add(ExternalRecipe(
            title: title,
            url: recipeUrl,
            imageUrl: imageUrl,
            source: 'Betty Bossi',
            prepTime: prepTime,
          ));
        } catch (_) {
          continue;
        }
      }

      return results;
    } catch (e) {
      print('Erreur recherche Betty Bossi: $e');
      return [];
    }
  }

  static const _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
  };
}

/// Resultat d'une recherche de recette externe
class ExternalRecipe {
  final String title;
  final String url;
  final String? imageUrl;
  final String source;
  final double? rating;
  final int? prepTime;

  ExternalRecipe({
    required this.title,
    required this.url,
    this.imageUrl,
    required this.source,
    this.rating,
    this.prepTime,
  });
}
