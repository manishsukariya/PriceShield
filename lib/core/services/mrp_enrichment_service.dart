import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

@immutable
class MrpResolution {
  const MrpResolution({
    required this.mrp,
    required this.source,
    this.quantityText,
  });

  final num mrp;
  final String source;
  final String? quantityText;
}

class _ParsedQuantity {
  const _ParsedQuantity({required this.value, required this.kind});

  final double value;
  final String kind;
}

/// Resolves printed MRP for Indian consumer products from packaging OCR text,
/// product names, Open Prices INR submissions, and Open Food Facts Cloud Vision
/// packaging image OCR JSONs.
class MrpEnrichmentService {
  MrpEnrichmentService({
    http.Client? client,
    Duration timeout = const Duration(milliseconds: 3000),
  }) : _client = client ?? http.Client(),
       _timeout = timeout;

  static const _offBaseUrl = 'https://world.openfoodfacts.org/api/v2/product';
  static const _obfBaseUrl = 'https://world.openbeautyfacts.org/api/v2/product';
  static const _opfBaseUrl = 'https://world.openproductsfacts.org/api/v2/product';
  static const _openPricesBaseUrl = 'https://prices.openfoodfacts.org/api/v1/prices';
  static const _userAgent =
      'PriceShield - Android - Version 1.0 (support@priceshield.app)';

  static const Map<String, String> _imageCdnBySource = {
    'open_food_facts': 'https://images.openfoodfacts.org/images/products',
    'open_beauty_facts': 'https://images.openbeautyfacts.org/images/products',
    'open_products_facts': 'https://images.openproductsfacts.org/images/products',
  };

  final http.Client _client;
  final Duration _timeout;

  static num? _roundMrp(double? raw) {
    if (raw == null || !raw.isFinite || raw <= 0 || raw > 999999.99) {
      return null;
    }
    final rounded = (raw * 100).roundToDouble() / 100;
    if (rounded == rounded.roundToDouble()) {
      return rounded.round();
    }
    return rounded;
  }

  /// Formats an MRP value concisely (e.g. `35.0` -> `35`, `10.5` -> `10.5`).
  static String formatMrp(num value) {
    final rounded = (value * 100).roundToDouble() / 100;
    if (rounded == rounded.roundToDouble()) {
      return rounded.round().toString();
    }
    final fixed = rounded.toStringAsFixed(2);
    return fixed.endsWith('0') ? fixed.substring(0, fixed.length - 1) : fixed;
  }

  static _ParsedQuantity? _parseQuantityInBaseUnits(String? quantityText) {
    if (quantityText == null || quantityText.trim().isEmpty) return null;
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*(kg|g|gm|gms|l|ltr|litre|litres|ml)\b',
      caseSensitive: false,
    ).firstMatch(quantityText);
    if (match == null) return null;
    final amount = double.tryParse(match.group(1)!);
    if (amount == null || !amount.isFinite || amount <= 0) return null;
    final rawUnit = match.group(2)!.toLowerCase();
    if (rawUnit == 'kg' || rawUnit == 'l' || rawUnit == 'ltr' || rawUnit.startsWith('litre')) {
      return _ParsedQuantity(
        value: amount * 1000,
        kind: rawUnit == 'kg' ? 'mass' : 'volume',
      );
    }
    return _ParsedQuantity(
      value: amount,
      kind: rawUnit == 'ml' ? 'volume' : 'mass',
    );
  }

  static bool _isUnitRateSuffix(String afterText) {
    return RegExp(
      r'^\s*(?:\/[-–]\s*)?(?:per\s*(?:\d+\s*)?(?:g|gm|gms|gram|grams|kg|ml|l|ltr|litre|litres|unit|pc|pcs)\b|\/\s*(?:\d+\s*)?(?:g|gm|gms|kg|ml|l|ltr|unit|pc)\b)',
      caseSensitive: false,
    ).hasMatch(afterText);
  }

  static bool _isQuantityOrOtherSuffix(String afterText) {
    return RegExp(
      r'^\s*(?:g|gm|gms|kg|mg|mcg|ml|l|ltr|kcal|cal|%|mm|cm|m)\b',
      caseSensitive: false,
    ).hasMatch(afterText);
  }

  static bool _hasUnexpectedAlphaSuffix(String afterText) {
    if (!RegExp(r'^[A-Za-z]').hasMatch(afterText)) return false;
    return !RegExp(r'^(?:rs|inr|rupees?|only)\b', caseSensitive: false)
        .hasMatch(afterText);
  }

  static bool _isDateOrFraction(String fullText, int matchIndex, String matchedDigits) {
    final prevChar = matchIndex > 0 ? fullText[matchIndex - 1] : '';
    final endIdx = matchIndex + matchedDigits.length;
    final nextChar = endIdx < fullText.length ? fullText[endIdx] : '';
    if (prevChar == '/') return true;
    if (nextChar == '/') {
      final afterSlash = (endIdx + 1) < fullText.length ? fullText[endIdx + 1] : '';
      // Allow Indian currency notation like "10/-", reject dates/fractions like "17/08"
      if (afterSlash != '-' && afterSlash != '–') {
        return true;
      }
    }
    if (prevChar == '.') {
      final prefix = fullText.substring(0, matchIndex);
      if (!RegExp(r'\.\d{1,2}$').hasMatch(prefix) && prefix.endsWith('.')) {
        // Guard against decimals/versions missing leading digit (e.g. ".35" or "2.35")
        if (prefix.length >= 2 && RegExp(r'\d').hasMatch(prefix[prefix.length - 2])) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _isPromoLine(String line) {
    if (RegExp(
      r'\b(?:m\.?\s*r\.?\s*p|maximum\s*retail\s*price|incl\.?\s*of\s*all\s*taxes)\b',
      caseSensitive: false,
    ).hasMatch(line)) {
      return false;
    }
    return RegExp(
      r'\b(?:scratch\s*card|cashback|paytm|google\s*pay|gpay|phonepe|voucher|coupon|win\s+|offer|worth|off\s+on)\b',
      caseSensitive: false,
    ).hasMatch(line);
  }

  /// Extracts Indian printed MRP from catalog names, packaging metadata, or OCR text.
  /// Rejects unit rates (e.g. `Rs.0.25 per g`), dates (`17/08/23`), promo vouchers,
  /// and weight/volume quantities (`138 g`), while handling both explicit labels
  /// (`MRP Rs. 10/-`, `20rs`) and Legal Metrology inkjet MRP+USP blocks (`35.00\nRs.0.25 per g`).
  static num? extractMrpFromText(String text, {String? quantityText}) {
    if (text.trim().isEmpty) return null;
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return null;

    // Pass 1a: Explicit MRP / Maximum Retail Price label on same or next line
    final mrpLabelRegex = RegExp(
      r'(?:M\.?\s*R\.?\s*P\.?|MAX(?:IMUM)?\.?\s*RETAIL\s*PRICE)\b',
      caseSensitive: false,
    );
    final taxLabelRegex = RegExp(
      r'INCL(?:USIVE)?\.?\s*OF\s*ALL\s*TAXES\b',
      caseSensitive: false,
    );

    num? matchExplicitLabel(RegExp labelRegex) {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final labelMatch = labelRegex.firstMatch(line);
        if (labelMatch == null) continue;

        final tail = line.substring(labelMatch.end);
        final candidateRegex = RegExp(
          r'(?:Rs\.?|INR|₹|P\.?|R)?\s*[:.\-=]?\s*(\d{1,5}(?:\.\d{1,2})?)',
          caseSensitive: false,
        );
        for (final candidate in candidateRegex.allMatches(tail)) {
          final digits = candidate.group(1)!;
          final full = candidate.group(0)!;
          final digitStart = candidate.start + full.lastIndexOf(digits);
          final after = tail.substring(candidate.end);
          if (_isDateOrFraction(tail, digitStart, digits)) continue;
          if (_hasUnexpectedAlphaSuffix(after) ||
              _isUnitRateSuffix(after) ||
              _isQuantityOrOtherSuffix(after)) {
            continue;
          }
          final rounded = _roundMrp(double.tryParse(digits));
          if (rounded != null && rounded >= 1) return rounded;
        }

        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1];
          final nextMatch = RegExp(
            r'^(?:Rs\.?|INR|₹)?\s*[:.\-=]?\s*(\d{1,5}(?:\.\d{1,2})?)\s*(?:\/[-–]|only)?(?:\s*\(?incl\.?\s*of\s*all\s*taxes\)?)?$',
            caseSensitive: false,
          ).firstMatch(nextLine);
          if (nextMatch != null) {
            final rounded = _roundMrp(double.tryParse(nextMatch.group(1)!));
            if (rounded != null && rounded >= 1) return rounded;
          }
        }
      }
      return null;
    }

    final pass1a = matchExplicitLabel(mrpLabelRegex);
    if (pass1a != null) return pass1a;

    // Pass 1b: Standalone "INCL. OF ALL TAXES" line when OCR cropped the "MRP" token
    final pass1b = matchExplicitLabel(taxLabelRegex);
    if (pass1b != null) return pass1b;

    // Pass 2: Explicit Indian currency token (₹, Rs., INR, 20rs, 10/-, 20 rupees)
    final prefixCurrencyRegex = RegExp(
      r'(?:Rs\.?|INR|₹)\s*[:.\-]?\s*(\d{1,5}(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final suffixCurrencyRegex = RegExp(
      r'\b(\d{1,5}(?:\.\d{1,2})?)\s*(?:\/[-–]|rupees?\b|rs\b\.?)',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (_isPromoLine(line)) continue;

      for (final match in prefixCurrencyRegex.allMatches(line)) {
        final digits = match.group(1)!;
        final full = match.group(0)!;
        final digitStart = match.start + full.lastIndexOf(digits);
        final after = line.substring(match.end);
        if (_isDateOrFraction(line, digitStart, digits)) continue;
        if (_hasUnexpectedAlphaSuffix(after) ||
            _isUnitRateSuffix(after) ||
            _isQuantityOrOtherSuffix(after)) {
          continue;
        }
        final rounded = _roundMrp(double.tryParse(digits));
        if (rounded != null && rounded >= 1) return rounded;
      }

      for (final match in suffixCurrencyRegex.allMatches(line)) {
        final digits = match.group(1)!;
        final after = line.substring(match.end);
        if (_isUnitRateSuffix(after) || _isQuantityOrOtherSuffix(after)) continue;
        final rounded = _roundMrp(double.tryParse(digits));
        if (rounded != null && rounded >= 1) return rounded;
      }
    }

    // Pass 3: Legal Metrology inkjet MRP line directly adjacent to Unit Sale Price ("Rs.0.25 per g")
    final parsedQty = _parseQuantityInBaseUnits(quantityText);
    final uspRegex = RegExp(
      r'(?:Rs\.?|₹|INR)\s*[:.\-]?\s*(\d+(?:\.\d{1,3})?)\s*(?:\/[-–])?\s*(?:per\s*(?:\d+\s*)?(?:g|gm|gms|kg|ml|l|ltr|litre|unit)|\/\s*(?:\d+\s*)?(?:g|gm|kg|ml|l)\b)',
      caseSensitive: false,
    );
    final standaloneAmountRegex = RegExp(
      r'^(?:₹|Rs\.?)?\s*(\d{1,5}(?:\.\d{2})?)\s*(?:\/[-–])?$',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final uspMatch = uspRegex.firstMatch(lines[i]);
      if (uspMatch == null) continue;
      final unitRate = double.tryParse(uspMatch.group(1)!);
      if (unitRate == null || !unitRate.isFinite || unitRate <= 0) continue;

      final neighborIndexes = [i - 1, i - 2, i + 1]
          .where((idx) => idx >= 0 && idx < lines.length);
      for (final idx in neighborIndexes) {
        final candidateLine = lines[idx];
        final standalone = standaloneAmountRegex.firstMatch(candidateLine);
        if (standalone == null) continue;

        final rawDigits = standalone.group(1)!;
        final amount = _roundMrp(double.tryParse(rawDigits));
        if (amount == null || amount < 1 || amount <= unitRate) continue;

        final hasTwoDecimals = RegExp(r'\.\d{2}$').hasMatch(rawDigits);
        if (parsedQty != null) {
          final implied = unitRate * parsedQty.value;
          final ratio = implied > 0 ? amount / implied : 0;
          if (ratio >= 0.5 && ratio <= 2.0) {
            return amount;
          }
        }
        if (hasTwoDecimals && amount <= 9999) {
          return amount;
        }
      }
    }

    return null;
  }

  /// Extracts MRP from live camera ML Kit OCR text, applying conservative
  /// de-noising (`2O` -> `20`) only after strict extraction misses.
  static num? extractMrpFromOcr(String text, {String? quantityText}) {
    final strict = extractMrpFromText(text, quantityText: quantityText);
    if (strict != null) return strict;

    final fuzzyRegex = RegExp(
      r'(?:M\.?\s*R\.?\s*P\.?|MAX\.?\s*PRICE|Rs\.?|₹)\s*[:.\-]?\s*(?:Rs\.?|₹)?\s*([0-9OoSlIB]{1,4}(?:[.,][0-9Oo]{1,2})?)',
      caseSensitive: false,
    );
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final trimLine = line.trim();
      if (trimLine.isEmpty || _isPromoLine(trimLine)) continue;
      for (final fuzzyMatch in fuzzyRegex.allMatches(trimLine)) {
        final after = trimLine.substring(fuzzyMatch.end);
        if (_isUnitRateSuffix(after) || _isQuantityOrOtherSuffix(after)) continue;
        final cleaned = fuzzyMatch
            .group(1)!
            .replaceAll(RegExp(r'[Oo]'), '0')
            .replaceAll(RegExp(r'[Ss]'), '5')
            .replaceAll(RegExp(r'[lIB]'), '1')
            .replaceAll(',', '.');
        final rounded = _roundMrp(double.tryParse(cleaned));
        if (rounded != null && rounded >= 1) return rounded;
      }
    }
    return null;
  }

  /// Resolves missing MRP using local product name patterns, Open Prices INR feed,
  /// and Open Food Facts Cloud Vision packaging image OCR JSONs.
  Future<MrpResolution?> resolveMissingMrp({
    required String barcode,
    String? productName,
    String? source,
  }) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    if (productName != null && productName.trim().isNotEmpty) {
      final fromName = extractMrpFromText(productName);
      if (fromName != null) {
        return MrpResolution(
          mrp: fromName,
          source: (source != null && source.isNotEmpty) ? source : 'catalog_name',
        );
      }
    }

    final results = await Future.wait<MrpResolution?>([
      _fetchFromOpenPricesInr(cleanBarcode),
      _fetchFromOpenFactsWithOcr(cleanBarcode, preferredSource: source),
    ]);

    return results[0] ?? results[1];
  }

  Future<MrpResolution?> _fetchFromOpenPricesInr(String barcode) async {
    try {
      final uri = Uri.parse(
        '$_openPricesBaseUrl?product_code=${Uri.encodeQueryComponent(barcode)}&currency=INR&size=5',
      );
      final response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent, 'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final items = decoded['items'];
      if (items is! List) return null;

      for (final rawItem in items) {
        if (rawItem is! Map) continue;
        if (rawItem['currency']?.toString().toUpperCase() != 'INR') continue;
        final withoutDiscount = double.tryParse(
          rawItem['price_without_discount']?.toString() ?? '',
        );
        final rawPrice = (withoutDiscount != null && withoutDiscount > 0)
            ? withoutDiscount
            : double.tryParse(rawItem['price']?.toString() ?? '');
        final rounded = _roundMrp(rawPrice);
        if (rounded != null && rounded >= 1) {
          return MrpResolution(mrp: rounded, source: 'open_prices');
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<MrpResolution?> _fetchFromOpenFactsWithOcr(
    String barcode, {
    String? preferredSource,
  }) async {
    final endpoints = _orderedEndpoints(preferredSource);
    for (final endpoint in endpoints) {
      final resolved = await _querySingleOpenFactsEndpoint(
        endpoint.baseUrl,
        endpoint.source,
        barcode,
      );
      if (resolved != null) return resolved;
    }
    return null;
  }

  List<({String baseUrl, String source})> _orderedEndpoints(String? preferredSource) {
    const off = (baseUrl: _offBaseUrl, source: 'open_food_facts');
    const obf = (baseUrl: _obfBaseUrl, source: 'open_beauty_facts');
    const opf = (baseUrl: _opfBaseUrl, source: 'open_products_facts');
    switch (preferredSource) {
      case 'open_beauty_facts':
        return [obf, off, opf];
      case 'open_products_facts':
        return [opf, off, obf];
      default:
        return [off, obf, opf];
    }
  }

  Future<MrpResolution?> _querySingleOpenFactsEndpoint(
    String baseUrl,
    String source,
    String barcode,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/${Uri.encodeComponent(barcode)}.json');
      final response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent, 'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 1) return null;
      final product = decoded['product'];
      if (product is! Map<String, dynamic>) return null;

      final quantityText = product['quantity']?.toString().trim();
      final directMrp = _extractDirectMrpFromOffProduct(product, quantityText: quantityText);
      if (directMrp != null) {
        return MrpResolution(
          mrp: directMrp,
          source: source,
          quantityText: quantityText,
        );
      }

      final imageIds = _selectOcrCandidateImageIds(product);
      if (imageIds.isEmpty) return null;
      final dirUrl = _resolveImageDirectoryUrl(product, barcode, source);
      if (dirUrl.isEmpty) return null;

      final perImageResults = await Future.wait<num?>(
        imageIds.map((id) async {
          try {
            final ocrRes = await _client
                .get(
                  Uri.parse('$dirUrl/$id.json'),
                  headers: const {'User-Agent': _userAgent, 'Accept': 'application/json'},
                )
                .timeout(_timeout);
            if (ocrRes.statusCode < 200 || ocrRes.statusCode >= 300) return null;
            final ocrJson = jsonDecode(ocrRes.body);
            if (ocrJson is! Map) return null;
            final responses = ocrJson['responses'];
            if (responses is! List || responses.isEmpty) return null;
            final first = responses.first;
            if (first is! Map) return null;
            final fullText = first['fullTextAnnotation']?['text']?.toString();
            if (fullText == null || fullText.isEmpty) return null;
            return extractMrpFromText(fullText, quantityText: quantityText);
          } catch (_) {
            return null;
          }
        }),
      );

      for (final mrp in perImageResults) {
        if (mrp != null && mrp >= 1) {
          return MrpResolution(
            mrp: mrp,
            source: '${source}_ocr',
            quantityText: quantityText,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  num? _extractDirectMrpFromOffProduct(
    Map<String, dynamic> product, {
    String? quantityText,
  }) {
    final pricesList = product['prices'];
    final firstPrice = (pricesList is List && pricesList.isNotEmpty && pricesList.first is Map)
        ? pricesList.first as Map
        : null;
    final raw = product['price_without_discount'] ??
        product['price'] ??
        product['mrp'] ??
        product['product_mrp'] ??
        product['price_per_item'] ??
        firstPrice?['price_without_discount'] ??
        firstPrice?['price'] ??
        firstPrice?['price_per_unit'] ??
        firstPrice?['amount'];
    if (raw != null) {
      final parsed = double.tryParse(raw.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
      final rounded = _roundMrp(parsed);
      if (rounded != null && rounded >= 1) return rounded;
    }

    final candidateTexts = [
      product['packaging_text_en'],
      product['packaging_text'],
      product['product_name_en'],
      product['product_name'],
      product['generic_name_en'],
      product['generic_name'],
      product['labels'],
      product['packaging'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty);

    for (final candidate in candidateTexts) {
      final extracted = extractMrpFromText(
        candidate.toString(),
        quantityText: quantityText,
      );
      if (extracted != null) return extracted;
    }
    return null;
  }

  List<String> _selectOcrCandidateImageIds(Map<String, dynamic> product) {
    final images = product['images'];
    if (images is! Map) return const [];

    final prioritized = <String>[];
    final seen = <String>{};
    void pushId(dynamic rawId) {
      if (rawId == null) return;
      final id = rawId.toString().trim();
      if (!RegExp(r'^\d+$').hasMatch(id) || seen.contains(id)) return;
      seen.add(id);
      prioritized.add(id);
    }

    final keys = images.keys.map((k) => k.toString()).toList(growable: false);
    for (final prefix in const ['packaging', 'nutrition', 'ingredients', 'front']) {
      for (final key in keys) {
        if (key.startsWith(prefix)) {
          final entry = images[key];
          if (entry is Map && entry['imgid'] != null) {
            pushId(entry['imgid']);
          }
        }
      }
    }

    for (final key in keys) {
      if (RegExp(r'^\d+$').hasMatch(key)) {
        pushId(key);
      }
    }

    return prioritized.take(5).toList(growable: false);
  }

  String _resolveImageDirectoryUrl(
    Map<String, dynamic> product,
    String barcode,
    String source,
  ) {
    final sample = (product['image_url'] ??
            product['image_front_url'] ??
            product['image_small_url'] ??
            product['image_packaging_url'] ??
            '')
        .toString()
        .trim();
    if (sample.startsWith('http')) {
      final lastSlash = sample.lastIndexOf('/');
      if (lastSlash > 8) {
        return sample.substring(0, lastSlash);
      }
    }
    final cdnBase = _imageCdnBySource[source] ?? _imageCdnBySource['open_food_facts']!;
    final digits = barcode.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.length <= 8) return '$cdnBase/$digits';
    final padded = digits.length < 13 ? digits.padLeft(13, '0') : digits;
    final partitioned =
        '${padded.substring(0, 3)}/${padded.substring(3, 6)}/${padded.substring(6, 9)}/${padded.substring(9)}';
    return '$cdnBase/$partitioned';
  }
}

final mrpEnrichmentService = MrpEnrichmentService();
