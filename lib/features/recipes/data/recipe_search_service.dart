import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../../core/config/api_keys.dart';

/// Recipe search providers
enum RecipeProvider {
  marmiton,
  cuisineAz,
  spoonacular,
  bettyBossi, // En développement - nécessite backend Python
}

extension RecipeProviderExtension on RecipeProvider {
  String get label {
    switch (this) {
      case RecipeProvider.spoonacular:
        return 'Spoonacular';
      case RecipeProvider.marmiton:
        return 'Marmiton';
      case RecipeProvider.cuisineAz:
        return 'Cuisine AZ';
      case RecipeProvider.bettyBossi:
        return 'Betty Bossi';
    }
  }

  String get baseUrl {
    switch (this) {
      case RecipeProvider.spoonacular:
        return 'https://api.spoonacular.com';
      case RecipeProvider.marmiton:
        return 'https://www.marmiton.org';
      case RecipeProvider.cuisineAz:
        return 'https://www.cuisineaz.com';
      case RecipeProvider.bettyBossi:
        return 'https://www.bettybossi.ch';
    }
  }

  String get icon {
    switch (this) {
      case RecipeProvider.spoonacular:
        return '🥄';
      case RecipeProvider.marmiton:
        return '🇫🇷';
      case RecipeProvider.cuisineAz:
        return '🍳';
      case RecipeProvider.bettyBossi:
        return '🇨🇭';
    }
  }

  /// Whether this provider is currently available
  bool get isAvailable {
    switch (this) {
      case RecipeProvider.spoonacular:
      case RecipeProvider.marmiton:
      case RecipeProvider.cuisineAz:
      case RecipeProvider.bettyBossi:
        return true;
    }
  }

  /// Status message for unavailable providers
  String? get statusMessage {
    return null;
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
    // Check if provider is available
    if (!provider.isAvailable) {
      return [];
    }

    switch (provider) {
      case RecipeProvider.spoonacular:
        return _searchSpoonacular(query, maxResults);
      case RecipeProvider.marmiton:
        return _searchMarmiton(query, maxResults);
      case RecipeProvider.cuisineAz:
        return _searchCuisineAz(query, maxResults);
      case RecipeProvider.bettyBossi:
        return _searchBettyBossi(query, maxResults);
    }
  }

  /// Search Spoonacular API
  static Future<List<RecipeSearchResult>> _searchSpoonacular(
    String query,
    int maxResults,
  ) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://api.spoonacular.com/recipes/complexSearch'
          '?apiKey=$spoonacularApiKey'
          '&query=$encodedQuery'
          '&number=$maxResults'
          '&addRecipeInformation=true'
          '&fillIngredients=false'
          '&instructionsRequired=true';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        print('Spoonacular API error: ${response.statusCode} - ${response.body}');
        return [];
      }

      final data = json.decode(response.body);
      final results = <RecipeSearchResult>[];

      for (final recipe in data['results'] ?? []) {
        results.add(RecipeSearchResult(
          title: recipe['title'] ?? '',
          url: recipe['sourceUrl'] ?? 'https://spoonacular.com/recipes/${recipe['id']}',
          imageUrl: recipe['image'],
          prepTime: recipe['readyInMinutes'],
          rating: recipe['spoonacularScore'] != null
              ? (recipe['spoonacularScore'] / 20).round() // Convert 0-100 to 0-5
              : null,
          provider: RecipeProvider.spoonacular,
        ));
      }

      return results;
    } catch (e) {
      print('Spoonacular search error: $e');
      return [];
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

          // Get image - try multiple attribute strategies
          final imgEl = card.querySelector('img');
          String? imageUrl = imgEl?.attributes['data-src'] ??
              imgEl?.attributes['data-lazy-src'] ??
              imgEl?.attributes['src'];

          // Try srcset if no direct URL found
          if (imageUrl == null || imageUrl.isEmpty) {
            final srcset = imgEl?.attributes['srcset'];
            if (srcset != null && srcset.isNotEmpty) {
              // Take first URL from srcset (format: "url1 1x, url2 2x")
              imageUrl = srcset.split(',').first.split(' ').first.trim();
            }
          }

          // Convert relative URLs to absolute
          if (imageUrl != null && imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
            if (imageUrl.startsWith('//')) {
              imageUrl = 'https:$imageUrl';
            } else if (imageUrl.startsWith('/')) {
              imageUrl = 'https://www.marmiton.org$imageUrl';
            }
          }

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

  /// Search Betty Bossi with multiple robust fallback strategies
  static Future<List<RecipeSearchResult>> _searchBettyBossi(
    String query,
    int maxResults,
  ) async {
    final results = <RecipeSearchResult>[];
    final seenUrls = <String>{};

    // Strategy 1: Try direct Betty Bossi search endpoints
    try {
      final directResults = await _bettyBossiDirectSearch(query, maxResults);
      for (final r in directResults) {
        if (!seenUrls.contains(r.url)) {
          seenUrls.add(r.url);
          results.add(r);
        }
      }
    } catch (e) {
      print('Betty Bossi direct search failed: $e');
    }

    // Strategy 2: Scrape the recipe hub page filtered by query
    if (results.length < maxResults) {
      try {
        final hubResults = await _bettyBossiHubScrape(query, maxResults - results.length);
        for (final r in hubResults) {
          if (!seenUrls.contains(r.url)) {
            seenUrls.add(r.url);
            results.add(r);
          }
        }
      } catch (e) {
        print('Betty Bossi hub scrape failed: $e');
      }
    }

    // Strategy 3: Use DuckDuckGo as fallback to find Betty Bossi recipes
    if (results.length < maxResults) {
      try {
        final ddgResults = await _bettyBossiViaDuckDuckGo(query, maxResults - results.length);
        for (final r in ddgResults) {
          if (!seenUrls.contains(r.url)) {
            seenUrls.add(r.url);
            results.add(r);
          }
        }
      } catch (e) {
        print('Betty Bossi DuckDuckGo fallback failed: $e');
      }
    }

    return results;
  }

  /// Direct search on Betty Bossi site
  static Future<List<RecipeSearchResult>> _bettyBossiDirectSearch(
    String query,
    int maxResults,
  ) async {
    final encodedQuery = Uri.encodeComponent(query);
    final results = <RecipeSearchResult>[];

    // Try multiple URL patterns
    final urls = [
      'https://www.bettybossi.ch/fr/recettes/?query=$encodedQuery',
      'https://www.bettybossi.ch/fr/Rezept/ShowResults/?text=$encodedQuery',
      'https://www.bettybossi.ch/fr/suche?query=$encodedQuery&tab=rezepte',
      'https://www.bettybossi.ch/de/Rezept/ShowResults/?text=$encodedQuery',
    ];

    for (final url in urls) {
      if (results.length >= maxResults) break;

      try {
        final response = await http.get(Uri.parse(url), headers: _headers);
        if (response.statusCode != 200) continue;

        final body = utf8.decode(response.bodyBytes, allowMalformed: true);
        final parsed = _parseBettyBossiPage(body, maxResults - results.length);
        results.addAll(parsed);
      } catch (_) {
        continue;
      }
    }

    return results;
  }

  /// Scrape the Betty Bossi recipe hub and filter by query
  static Future<List<RecipeSearchResult>> _bettyBossiHubScrape(
    String query,
    int maxResults,
  ) async {
    final results = <RecipeSearchResult>[];
    final queryWords = query.toLowerCase().split(' ');

    // Try the main recipe pages
    final hubUrls = [
      'https://www.bettybossi.ch/fr/recettes/',
      'https://www.bettybossi.ch/fr/recettes/poulet/',
      'https://www.bettybossi.ch/fr/recettes/pates/',
      'https://www.bettybossi.ch/fr/recettes/soupes/',
    ];

    for (final url in hubUrls) {
      if (results.length >= maxResults) break;

      try {
        final response = await http.get(Uri.parse(url), headers: _headers);
        if (response.statusCode != 200) continue;

        final body = utf8.decode(response.bodyBytes, allowMalformed: true);
        final allRecipes = _parseBettyBossiPage(body, 100);

        // Filter by query words
        for (final recipe in allRecipes) {
          if (results.length >= maxResults) break;

          final titleLower = recipe.title.toLowerCase();
          final urlLower = recipe.url.toLowerCase();

          // Check if any query word matches
          final matches = queryWords.any((word) =>
            titleLower.contains(word) || urlLower.contains(word));

          if (matches) {
            results.add(recipe);
          }
        }
      } catch (_) {
        continue;
      }
    }

    return results;
  }

  /// Fallback: Search via DuckDuckGo for Betty Bossi recipes
  static Future<List<RecipeSearchResult>> _bettyBossiViaDuckDuckGo(
    String query,
    int maxResults,
  ) async {
    final results = <RecipeSearchResult>[];
    final encodedQuery = Uri.encodeComponent('site:bettybossi.ch recette $query');

    try {
      // DuckDuckGo HTML search
      final url = 'https://html.duckduckgo.com/html/?q=$encodedQuery';
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode != 200) return results;

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final document = html_parser.parse(body);

      // Parse DuckDuckGo results
      final searchResults = document.querySelectorAll('.result, .results_links');

      for (final result in searchResults) {
        if (results.length >= maxResults) break;

        try {
          // Get the link
          final linkEl = result.querySelector('a.result__a, a[href*="bettybossi"]');
          var link = linkEl?.attributes['href'];

          if (link == null) continue;

          // DuckDuckGo wraps URLs, extract the actual URL
          if (link.contains('uddg=')) {
            final match = RegExp(r'uddg=([^&]+)').firstMatch(link);
            if (match != null) {
              link = Uri.decodeComponent(match.group(1)!);
            }
          }

          // Only Betty Bossi recipe links
          if (!link.contains('bettybossi.ch')) continue;
          if (!link.toLowerCase().contains('recette') &&
              !link.toLowerCase().contains('rezept')) continue;

          // Get title
          final title = linkEl?.text.trim() ??
              result.querySelector('.result__title, h2, h3')?.text.trim();

          if (title == null || title.isEmpty) continue;

          results.add(RecipeSearchResult(
            title: title.replaceAll(RegExp(r'\s+'), ' ').trim(),
            url: link,
            provider: RecipeProvider.bettyBossi,
          ));
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      print('DuckDuckGo search error: $e');
    }

    return results;
  }

  /// Parse Betty Bossi page HTML for recipe cards
  static List<RecipeSearchResult> _parseBettyBossiPage(String body, int maxResults) {
    final results = <RecipeSearchResult>[];
    final seenUrls = <String>{};
    final document = html_parser.parse(body);

    // Multiple selector strategies for different page layouts
    final selectorStrategies = [
      // Modern card-based layouts
      'a[href*="/recettes/recette/"]',
      'a[href*="/fr/recettes/recette/"]',
      'a[href*="/Rezept/Show/"]',
      'a[href*="/rezept/"]',
      // Class-based selectors
      '[class*="recipe-card"] a',
      '[class*="RecipeCard"] a',
      '[class*="recipe-tile"] a',
      'article[class*="recipe"] a',
      // Generic fallbacks
      '.teaser a[href*="recette"]',
      '.card a[href*="recette"]',
    ];

    for (final selector in selectorStrategies) {
      if (results.length >= maxResults) break;

      try {
        final elements = document.querySelectorAll(selector);

        for (final el in elements) {
          if (results.length >= maxResults) break;

          String? link = el.attributes['href'];
          if (link == null || link.isEmpty) continue;

          // Validate it's a recipe link
          final lowerLink = link.toLowerCase();
          if (!lowerLink.contains('recette') && !lowerLink.contains('rezept')) continue;
          if (lowerLink.contains('?query=') || lowerLink.contains('/search')) continue;

          // Make absolute URL
          final fullUrl = link.startsWith('http') ? link : 'https://www.bettybossi.ch$link';
          if (seenUrls.contains(fullUrl)) continue;
          seenUrls.add(fullUrl);

          // Extract title
          String? title;

          // Try various title sources
          final parent = el.parent;
          title ??= el.querySelector('h2, h3, h4, [class*="title"]')?.text.trim();
          title ??= parent?.querySelector('h2, h3, h4, [class*="title"]')?.text.trim();
          title ??= el.attributes['title']?.trim();
          title ??= el.attributes['aria-label']?.trim();

          // Extract from URL as last resort
          if (title == null || title.isEmpty || title.length < 3) {
            final urlTitle = fullUrl.split('/').last.replaceAll('-', ' ').replaceAll('_', ' ');
            if (urlTitle.length >= 3) title = urlTitle;
          }

          if (title == null || title.isEmpty || title.length > 200) continue;
          title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

          // Extract image
          String? imageUrl;
          final imgEl = el.querySelector('img') ?? parent?.querySelector('img');
          if (imgEl != null) {
            imageUrl = imgEl.attributes['data-src'] ??
                imgEl.attributes['data-lazy-src'] ??
                imgEl.attributes['srcset']?.split(' ').first ??
                imgEl.attributes['src'];

            if (imageUrl != null && !imageUrl.startsWith('http')) {
              imageUrl = 'https://www.bettybossi.ch$imageUrl';
            }
          }

          results.add(RecipeSearchResult(
            title: title,
            url: fullUrl,
            imageUrl: imageUrl,
            provider: RecipeProvider.bettyBossi,
          ));
        }
      } catch (_) {
        continue;
      }
    }

    return results;
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
          String? imageUrl = imgEl?.attributes['data-src'] ??
              imgEl?.attributes['data-lazy-src'] ??
              imgEl?.attributes['src'];

          // Try srcset if no direct URL found
          if (imageUrl == null || imageUrl.isEmpty) {
            final srcset = imgEl?.attributes['srcset'];
            if (srcset != null && srcset.isNotEmpty) {
              imageUrl = srcset.split(',').first.split(' ').first.trim();
            }
          }

          // Convert relative URLs to absolute
          if (imageUrl != null && imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
            if (imageUrl.startsWith('//')) {
              imageUrl = 'https:$imageUrl';
            } else if (imageUrl.startsWith('/')) {
              imageUrl = 'https://www.cuisineaz.com$imageUrl';
            }
          }

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
