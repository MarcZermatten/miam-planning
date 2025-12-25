import 'dart:convert';
import 'package:flutter/foundation.dart';
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

      if (response.statusCode != 200) {
        debugPrint('Marmiton: HTTP ${response.statusCode}');
        return [];
      }

      // Decoder en UTF-8
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final document = html_parser.parse(body);
      final results = <ExternalRecipe>[];

      // Marmiton structure 2024: chercher les liens de recettes
      final links = document.querySelectorAll('a[href*="/recettes/recette_"]');
      final seenUrls = <String>{};

      for (final link in links.take(20)) {
        try {
          var recipeUrl = link.attributes['href'];
          if (recipeUrl == null) continue;
          if (!recipeUrl.startsWith('http')) {
            recipeUrl = 'https://www.marmiton.org$recipeUrl';
          }

          // Eviter les doublons
          if (seenUrls.contains(recipeUrl)) continue;
          seenUrls.add(recipeUrl);

          // Titre depuis le lien ou un element parent
          var title = link.text.trim();
          if (title.isEmpty || title.length < 3) {
            final titleEl = link.querySelector('h4, [class*="title"]') ??
                           link.parent?.querySelector('h4, [class*="title"]');
            title = titleEl?.text.trim() ?? '';
          }
          if (title.isEmpty || title.length < 3) continue;

          // Image
          final card = link.parent?.parent?.parent;
          final imgEl = card?.querySelector('img') ?? link.querySelector('img');
          var imageUrl = imgEl?.attributes['src'] ??
                        imgEl?.attributes['data-src'] ??
                        imgEl?.attributes['data-lazy-src'];

          results.add(ExternalRecipe(
            title: title,
            url: recipeUrl,
            imageUrl: imageUrl,
            source: 'Marmiton',
          ));

          if (results.length >= 10) break;
        } catch (_) {
          continue;
        }
      }

      debugPrint('Marmiton: ${results.length} resultats');
      return results;
    } catch (e) {
      debugPrint('Erreur recherche Marmiton: $e');
      return [];
    }
  }

  /// Recherche sur Betty Bossi
  static Future<List<ExternalRecipe>> _searchBettyBossi(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      // Betty Bossi utilise une API de recherche
      final url = 'https://www.bettybossi.ch/fr/Rezept/Suche?search=$encoded';

      final response = await http.get(
        Uri.parse(url),
        headers: _defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('Betty Bossi: HTTP ${response.statusCode}');
        return [];
      }

      // Decoder en UTF-8
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final document = html_parser.parse(body);
      final results = <ExternalRecipe>[];
      final seenUrls = <String>{};

      // Betty Bossi: chercher tous les liens vers des recettes
      final links = document.querySelectorAll('a[href*="/Rezept/Detail/"]');

      for (final link in links.take(20)) {
        try {
          var recipeUrl = link.attributes['href'];
          if (recipeUrl == null) continue;
          if (!recipeUrl.startsWith('http')) {
            recipeUrl = 'https://www.bettybossi.ch$recipeUrl';
          }

          // Eviter les doublons
          if (seenUrls.contains(recipeUrl)) continue;
          seenUrls.add(recipeUrl);

          // Titre
          var title = link.text.trim();
          if (title.isEmpty || title.length < 3) {
            final parent = link.parent;
            final titleEl = parent?.querySelector('h2, h3, h4, [class*="title"]');
            title = titleEl?.text.trim() ?? '';
          }
          if (title.isEmpty || title.length < 3) continue;
          // Nettoyer le titre (enlever les espaces multiples)
          title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (title.length > 100) title = title.substring(0, 100);

          // Image - chercher dans le parent
          final card = link.parent?.parent?.parent;
          final imgEl = card?.querySelector('img') ?? link.querySelector('img');
          var imageUrl = imgEl?.attributes['src'] ??
                        imgEl?.attributes['data-src'];
          if (imageUrl != null && !imageUrl.startsWith('http')) {
            imageUrl = 'https://www.bettybossi.ch$imageUrl';
          }

          results.add(ExternalRecipe(
            title: title,
            url: recipeUrl,
            imageUrl: imageUrl,
            source: 'Betty Bossi',
          ));

          if (results.length >= 10) break;
        } catch (_) {
          continue;
        }
      }

      debugPrint('Betty Bossi: ${results.length} resultats');
      return results;
    } catch (e) {
      debugPrint('Erreur recherche Betty Bossi: $e');
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
