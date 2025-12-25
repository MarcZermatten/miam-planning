import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

/// Recipe search providers
enum RecipeProvider {
  bettyBossi,
  marmiton,
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
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
    'Cache-Control': 'no-cache',
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
      // Marmiton uses this search URL format
      final url = 'https://www.marmiton.org/recettes/recherche.aspx?aqt=$encodedQuery';

      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) return [];

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final document = html_parser.parse(body);

      final results = <RecipeSearchResult>[];

      // Try multiple selector strategies
      var cards = document.querySelectorAll('a[href*="/recettes/recette_"]');
      if (cards.isEmpty) {
        cards = document.querySelectorAll('.recipe-card');
      }
      if (cards.isEmpty) {
        cards = document.querySelectorAll('[class*="MRTN__sc"]'); // New Marmiton classes
      }

      final seenUrls = <String>{};

      for (final card in cards) {
        if (results.length >= maxResults) break;

        try {
          // Get link - might be the card itself or a child
          String? link = card.attributes['href'];
          if (link == null || link.isEmpty) {
            final linkEl = card.querySelector('a[href*="/recettes/"]');
            link = linkEl?.attributes['href'];
          }
          if (link == null || link.isEmpty) continue;
          if (!link.contains('recette')) continue;

          final fullUrl = link.startsWith('http') ? link : 'https://www.marmiton.org$link';
          if (seenUrls.contains(fullUrl)) continue;
          seenUrls.add(fullUrl);

          // Get title from various possible elements
          var title = card.querySelector('h4, h3, h2, [class*="title"]')?.text.trim();
          title ??= card.text.trim().split('\n').first;
          if (title.isEmpty || title.length < 3 || title.length > 200) continue;

          // Get image
          final imgEl = card.querySelector('img');
          String? imageUrl = imgEl?.attributes['data-src'] ??
              imgEl?.attributes['data-lazy-src'] ??
              imgEl?.attributes['src'];

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
      print('Marmiton search error: $e');
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
      // Betty Bossi new URL structure (2024+)
      final url = 'https://www.bettybossi.ch/fr/suche?query=$encodedQuery&tab=rezepte';

      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) {
        // Try alternative URL
        final altUrl = 'https://www.bettybossi.ch/fr/Rezept/Suche?query=$encodedQuery';
        final altResponse = await http.get(Uri.parse(altUrl), headers: _headers);
        if (altResponse.statusCode != 200) return [];
      }

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final document = html_parser.parse(body);

      final results = <RecipeSearchResult>[];
      final seenUrls = <String>{};

      // Try multiple selector strategies
      var cards = document.querySelectorAll('a[href*="/rezept/"], a[href*="/Rezept/"]');
      if (cards.isEmpty) {
        cards = document.querySelectorAll('[class*="recipe"], article, .teaser, [class*="card"]');
      }

      for (final card in cards) {
        if (results.length >= maxResults) break;

        try {
          // Get link
          String? link = card.attributes['href'];
          if (link == null || link.isEmpty) {
            final linkEl = card.querySelector('a[href*="/rezept/"], a[href*="/Rezept/"]');
            link = linkEl?.attributes['href'];
          }
          if (link == null || link.isEmpty) continue;
          if (!link.toLowerCase().contains('rezept')) continue;

          final fullUrl = link.startsWith('http') ? link : 'https://www.bettybossi.ch$link';
          if (seenUrls.contains(fullUrl)) continue;
          seenUrls.add(fullUrl);

          // Get title
          var title = card.querySelector('h2, h3, h4, [class*="title"]')?.text.trim();
          title ??= card.text.trim().split('\n').first;
          if (title.isEmpty || title.length < 3 || title.length > 200) continue;

          // Get image
          final imgEl = card.querySelector('img');
          String? imageUrl = imgEl?.attributes['data-src'] ??
              imgEl?.attributes['data-lazy-src'] ??
              imgEl?.attributes['src'];

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
      print('Betty Bossi search error: $e');
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
