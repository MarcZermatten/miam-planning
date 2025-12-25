import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

/// Recipe search providers
enum RecipeProvider {
  marmiton,
  bettyBossi,
  cuisineAz,
}

extension RecipeProviderExtension on RecipeProvider {
  String get label {
    switch (this) {
      case RecipeProvider.marmiton:
        return 'Marmiton';
      case RecipeProvider.bettyBossi:
        return 'Betty Bossi';
      case RecipeProvider.cuisineAz:
        return 'Cuisine AZ';
    }
  }

  String get baseUrl {
    switch (this) {
      case RecipeProvider.marmiton:
        return 'https://www.marmiton.org';
      case RecipeProvider.bettyBossi:
        return 'https://www.bettybossi.ch';
      case RecipeProvider.cuisineAz:
        return 'https://www.cuisineaz.com';
    }
  }

  String get icon {
    switch (this) {
      case RecipeProvider.marmiton:
        return '🇫🇷';
      case RecipeProvider.bettyBossi:
        return '🇨🇭';
      case RecipeProvider.cuisineAz:
        return '🍳';
    }
  }
}

/// A search result from a recipe provider
class RecipeSearchResult {
  final String title;
  final String url;
  final String? imageUrl;
  final String? description;
  final int? prepTime;
  final int? rating;
  final RecipeProvider provider;

  RecipeSearchResult({
    required this.title,
    required this.url,
    this.imageUrl,
    this.description,
    this.prepTime,
    this.rating,
    required this.provider,
  });
}

/// Service for searching recipes across multiple providers
class RecipeSearchService {
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
  };

  /// Search for recipes on a specific provider
  static Future<List<RecipeSearchResult>> search(
    String query,
    RecipeProvider provider, {
    int maxResults = 20,
  }) async {
    switch (provider) {
      case RecipeProvider.marmiton:
        return _searchMarmiton(query, maxResults);
      case RecipeProvider.bettyBossi:
        return _searchBettyBossi(query, maxResults);
      case RecipeProvider.cuisineAz:
        return _searchCuisineAz(query, maxResults);
    }
  }

  /// Search Marmiton
  static Future<List<RecipeSearchResult>> _searchMarmiton(
    String query,
    int maxResults,
  ) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://www.marmiton.org/recettes/recherche.aspx?aqt=$encodedQuery';

      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) return [];

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final document = html_parser.parse(body);

      final results = <RecipeSearchResult>[];
      final cards = document.querySelectorAll('.recipe-card, [class*="recipe"]');

      for (final card in cards) {
        if (results.length >= maxResults) break;

        try {
          final titleEl = card.querySelector('.recipe-card__title, h4, h3, [class*="title"]');
          final title = titleEl?.text.trim() ?? '';
          if (title.isEmpty || title.length < 3) continue;

          final linkEl = card.querySelector('a[href*="/recettes/"]');
          final link = linkEl?.attributes['href'] ?? '';
          if (link.isEmpty || !link.contains('recette')) continue;
          final fullUrl = link.startsWith('http') ? link : 'https://www.marmiton.org$link';

          final imgEl = card.querySelector('img');
          String? imageUrl = imgEl?.attributes['data-src'] ?? imgEl?.attributes['src'];

          results.add(RecipeSearchResult(
            title: title,
            url: fullUrl,
            imageUrl: imageUrl,
            provider: RecipeProvider.marmiton,
          ));
        } catch (_) {
          continue;
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Search Betty Bossi
  static Future<List<RecipeSearchResult>> _searchBettyBossi(
    String query,
    int maxResults,
  ) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://www.bettybossi.ch/fr/Rezept/Suche?query=$encodedQuery';

      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) return [];

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final document = html_parser.parse(body);

      final results = <RecipeSearchResult>[];
      final cards = document.querySelectorAll('[class*="recipe"], article, .teaser');

      for (final card in cards) {
        if (results.length >= maxResults) break;

        try {
          final titleEl = card.querySelector('h2, h3, [class*="title"]');
          final title = titleEl?.text.trim() ?? '';
          if (title.isEmpty || title.length < 3) continue;

          final linkEl = card.querySelector('a[href*="/Rezept/"]');
          final link = linkEl?.attributes['href'] ?? '';
          if (link.isEmpty) continue;
          final fullUrl = link.startsWith('http') ? link : 'https://www.bettybossi.ch$link';

          final imgEl = card.querySelector('img');
          String? imageUrl = imgEl?.attributes['data-src'] ?? imgEl?.attributes['src'];

          results.add(RecipeSearchResult(
            title: title,
            url: fullUrl,
            imageUrl: imageUrl,
            provider: RecipeProvider.bettyBossi,
          ));
        } catch (_) {
          continue;
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Search Cuisine AZ
  static Future<List<RecipeSearchResult>> _searchCuisineAz(
    String query,
    int maxResults,
  ) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://www.cuisineaz.com/recettes/recherche_terme.aspx?recherche=$encodedQuery';

      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) return [];

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final document = html_parser.parse(body);

      final results = <RecipeSearchResult>[];
      final cards = document.querySelectorAll('[class*="recipe"], article');

      for (final card in cards) {
        if (results.length >= maxResults) break;

        try {
          final titleEl = card.querySelector('h2, h3, [class*="title"]');
          final title = titleEl?.text.trim() ?? '';
          if (title.isEmpty || title.length < 3) continue;

          final linkEl = card.querySelector('a[href*="/recettes/"]');
          final link = linkEl?.attributes['href'] ?? '';
          if (link.isEmpty) continue;
          final fullUrl = link.startsWith('http') ? link : 'https://www.cuisineaz.com$link';

          final imgEl = card.querySelector('img');
          String? imageUrl = imgEl?.attributes['data-src'] ?? imgEl?.attributes['src'];

          results.add(RecipeSearchResult(
            title: title,
            url: fullUrl,
            imageUrl: imageUrl,
            provider: RecipeProvider.cuisineAz,
          ));
        } catch (_) {
          continue;
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }
}
