import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:priceshield/core/data/default_products_catalog.dart';
import 'package:priceshield/core/services/auth_session.dart';

class PagedResult<T> {
  const PagedResult({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

class PriceShieldApiException implements Exception {
  const PriceShieldApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Client for the staged Node/Express migration API.
///
/// Supply the API origin with `--dart-define=PRICESHIELD_API_BASE_URL=...`.
/// For Android emulators use `http://10.0.2.2:3000`; for a physical device,
/// use the development computer's LAN address. The debug-only fallback keeps
/// local USB-device runs working when VS Code is started without launch.json.
/// Release builds still require an explicit HTTPS configuration.
class PriceShieldApiClient {
  PriceShieldApiClient({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
  }) : _client = client ?? http.Client(),
       _tokenProvider = tokenProvider ?? AuthSession.refreshToken {
    _initProductCache();
  }

  static const _configuredBaseUrl = String.fromEnvironment(
    'PRICESHIELD_API_BASE_URL',
  );
  static const _debugLocalBaseUrl = 'http://192.168.0.107:3000';
  static const _defaultProductionBaseUrl = 'https://priceshield-r4v5.onrender.com';
  static const _timeout = Duration(seconds: 35);

  final http.Client _client;
  final Future<String?> Function() _tokenProvider;
  final Map<String, Map<String, dynamic>> _productCache = {};

  void _initProductCache() {
    for (final entry in defaultIndianProductsCatalog.entries) {
      final item = Map<String, dynamic>.from(entry.value);
      item['source'] = 'offline_reference_catalog';
      item['isReferenceEstimate'] = true;
      _productCache[entry.key] = item;
    }
  }

  String get _baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kDebugMode) return _debugLocalBaseUrl;
    return _defaultProductionBaseUrl;
  }

  bool get isConfigured => _baseUrl.isNotEmpty;

  Map<String, dynamic>? getCachedProduct(String barcode) {
    final clean = barcode.trim();
    final cached = _productCache[clean];
    return cached != null ? Map<String, dynamic>.from(cached) : null;
  }

  void cacheProduct(String barcode, Map<String, dynamic> product) {
    final clean = barcode.trim();
    if (clean.isNotEmpty) {
      _productCache[clean] = Map<String, dynamic>.from(product);
    }
  }

  void clearProductCache() {
    _productCache.clear();
  }

  /// Fire-and-forget warm-up ping to wake up the Render backend container
  /// as soon as the app is launched, completely avoiding cold-start delays.
  Future<void> warmUpBackend() async {
    if (!isConfigured) return;
    try {
      await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      // Warmup ping failures are non-blocking and silently ignored.
    }
  }

  void resetProductCache() {
    _productCache.clear();
    _initProductCache();
  }

  Future<Map<String, dynamic>?> _fetchDirectFromOpenFacts(String barcode) async {
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/${Uri.encodeComponent(barcode)}.json',
      );
      final res = await _client.get(
        uri,
        headers: const {
          'User-Agent': 'PriceShield - Android - Version 1.0 (support@priceshield.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(milliseconds: 2500));
      if (res.statusCode != 200 || res.body.isEmpty) return null;
      final data = jsonDecode(res.body);
      if (data is! Map || data['status'] != 1 || data['product'] is! Map) return null;
      final p = data['product'] as Map;
      final rawName = p['product_name_en']?.toString() ??
          p['product_name']?.toString() ??
          p['generic_name']?.toString() ??
          '';
      final brand = (p['brands']?.toString() ?? p['brand_owner']?.toString() ?? '')
          .split(',')
          .first
          .trim();
      final quantity = p['quantity']?.toString();
      var name = rawName.trim();
      if (brand.isNotEmpty && !name.toLowerCase().contains(brand.toLowerCase())) {
        name = '$brand $name'.trim();
      }
      if (name.isEmpty) name = 'Product $barcode';
      if (quantity != null &&
          quantity.isNotEmpty &&
          !name.toLowerCase().contains(quantity.toLowerCase())) {
        name = '$name ($quantity)';
      }
      return {
        'barcode': barcode,
        'name': name,
        'mrp': 0,
        'quantity': quantity,
        'brand': brand.isNotEmpty ? brand : null,
        'imageUrl': p['image_url']?.toString() ?? p['image_front_url']?.toString(),
        'source': 'open_food_facts',
        'isReferenceEstimate': true,
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getProduct(String barcode) async {
    final clean = barcode.trim();
    final cached = getCachedProduct(clean);

    if (isConfigured) {
      try {
        final result = await _requestMap(
          'GET',
          '/products/${Uri.encodeComponent(clean)}',
          authenticated: false,
          timeout: const Duration(milliseconds: 3200),
        );
        cacheProduct(clean, result);
        return result;
      } catch (e) {
        if (cached != null) return cached;
        final direct = await _fetchDirectFromOpenFacts(clean);
        if (direct != null) {
          cacheProduct(clean, direct);
          return direct;
        }
        rethrow;
      }
    }

    if (cached != null) return cached;

    final direct = await _fetchDirectFromOpenFacts(clean);
    if (direct != null) {
      cacheProduct(clean, direct);
      return direct;
    }

    final result = await _requestMap(
      'GET',
      '/products/${Uri.encodeComponent(clean)}',
      authenticated: false,
      timeout: const Duration(milliseconds: 3500),
    );
    cacheProduct(clean, result);
    return result;
  }

  Future<void> logout() async {}

  Future<Map<String, dynamic>> getProfile() => _requestMap('GET', '/me');

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> changes) =>
      _requestMap('PATCH', '/me', body: changes);

  Future<void> deleteAccount() => _request('DELETE', '/me').then((_) {});

  Future<Map<String, dynamic>> getComplaint(String id) =>
      _requestMap('GET', '/complaints/${Uri.encodeComponent(id)}');

  Future<void> withdrawComplaint(String id) =>
      _request('DELETE', '/complaints/${Uri.encodeComponent(id)}').then((_) {});

  Future<Map<String, dynamic>> createScan({
    required String barcode,
    required String productName,
    required num mrp,
    required num chargedPrice,
    String? clientRequestId,
  }) => _requestMap(
    'POST',
    '/scans',
    body: {
      'barcode': barcode,
      'productName': productName,
      'mrp': mrp,
      'chargedPrice': chargedPrice,
      'clientRequestId': ?clientRequestId,
    },
  );

  Future<PagedResult<Map<String, dynamic>>> listScansPage({
    int limit = 20,
    String? cursor,
  }) {
    final query = <String, String>{'limit': '$limit'};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    return _requestPaged('GET', '/scans?${Uri(queryParameters: query).query}');
  }

  Future<List<Map<String, dynamic>>> listScans({int limit = 20}) async =>
      (await listScansPage(limit: limit)).items;

  Future<Map<String, dynamic>> createComplaint({
    required String barcode,
    required String productName,
    required num mrp,
    required num chargedPrice,
    required String address,
    String venueType = 'RETAIL',
    int quantity = 1,
    num? totalPaid,
    String paymentMethod = 'CASH',
    String? utrNumber,
    String? merchantName,
    String? merchantVpa,
    DateTime? purchaseDate,
    double? latitude,
    double? longitude,
    String? description,
    List<Map<String, dynamic>>? evidence,
    String? clientRequestId,
  }) => _requestMap(
    'POST',
    '/complaints',
    body: {
      'venueType': venueType,
      'barcode': barcode,
      'productName': productName,
      'quantity': quantity,
      'mrp': mrp,
      'chargedPrice': chargedPrice,
      'totalPaid': totalPaid ?? (chargedPrice * quantity),
      'paymentMethod': paymentMethod,
      if (utrNumber != null && utrNumber.trim().isNotEmpty)
        'utrNumber': utrNumber.trim().toUpperCase(),
      if (merchantName != null && merchantName.trim().isNotEmpty)
        'merchantName': merchantName.trim(),
      if (merchantVpa != null && merchantVpa.trim().isNotEmpty)
        'merchantVpa': merchantVpa.trim().toLowerCase(),
      'address': address,
      if (purchaseDate != null) 'purchaseDate': purchaseDate.toUtc().toIso8601String(),
      'latitude': ?latitude,
      'longitude': ?longitude,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (evidence != null && evidence.isNotEmpty) 'evidence': evidence,
      'clientRequestId': ?clientRequestId,
    },
  );

  Future<Map<String, dynamic>> addComplaintEvidence(
    String complaintId,
    Map<String, dynamic> evidenceItem,
  ) => _requestMap(
    'POST',
    '/complaints/${Uri.encodeComponent(complaintId)}/evidence',
    body: evidenceItem,
  );

  Future<Map<String, dynamic>> getStoreRisk({
    String? storeFingerprint,
    String? merchantVpa,
    String? merchantName,
    String? address,
  }) {
    final query = <String, String>{};
    if (storeFingerprint != null && storeFingerprint.trim().isNotEmpty) {
      query['storeFingerprint'] = storeFingerprint.trim();
    }
    if (merchantVpa != null && merchantVpa.trim().isNotEmpty) {
      query['merchantVpa'] = merchantVpa.trim().toLowerCase();
    }
    if (merchantName != null && merchantName.trim().isNotEmpty) {
      query['merchantName'] = merchantName.trim();
    }
    if (address != null && address.trim().isNotEmpty) {
      query['address'] = address.trim();
    }
    return _requestMap(
      'GET',
      '/stores/risk?${Uri(queryParameters: query).query}',
      authenticated: false,
    );
  }

  Future<Map<String, dynamic>> createProductSubmission({
    required String barcode,
    String? productName,
    num? printedMrp,
    String? ocrText,
    String? frontImageUrl,
    String? backImageUrl,
  }) => _requestMap(
    'POST',
    '/product-submissions',
    body: {
      'barcode': barcode,
      if (productName != null && productName.trim().isNotEmpty)
        'productName': productName.trim(),
      'printedMrp': ?printedMrp,
      if (ocrText != null && ocrText.trim().isNotEmpty)
        'ocrText': ocrText.trim(),
      'frontImageUrl': ?frontImageUrl,
      'backImageUrl': ?backImageUrl,
    },
  );

  Future<PagedResult<Map<String, dynamic>>> listComplaintsPage({
    String? status,
    int limit = 20,
    String? cursor,
  }) {
    final query = <String, String>{'limit': '$limit'};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    return _requestPaged(
      'GET',
      '/complaints?${Uri(queryParameters: query).query}',
    );
  }

  Future<List<Map<String, dynamic>>> listComplaints({
    String? status,
    int limit = 20,
  }) async =>
      (await listComplaintsPage(status: status, limit: limit)).items;

  String get streamUrl => '$_baseUrl/api/v1/complaints/stream';

  Future<Map<String, dynamic>> boostComplaint(String id) =>
      _requestMap('POST', '/complaints/${Uri.encodeComponent(id)}/boost');

  Future<List<Map<String, dynamic>>> getPlans() async {
    final res = await _requestEnvelope('GET', '/plans', authenticated: false);
    final data = res['data'];
    if (data is Map && data['plans'] is List) {
      return (data['plans'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getMyPlan() =>
      _requestMap('GET', '/plans/my-plan');

  Future<Map<String, dynamic>> subscribePlan(String planId) =>
      _requestMap('POST', '/plans/subscribe', body: {'planId': planId});

  Future<Map<String, dynamic>> _requestMap(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration? timeout,
  }) async {
    final data = await _request(
      method,
      path,
      body: body,
      authenticated: authenticated,
      timeout: timeout,
    );
    if (data is! Map<String, dynamic>) {
      throw const PriceShieldApiException(
        'The server returned an invalid response.',
      );
    }
    return data;
  }

  Future<PagedResult<Map<String, dynamic>>> _requestPaged(
    String method,
    String path,
  ) async {
    final envelope = await _requestEnvelope(method, path);
    final rawData = envelope['data'];
    if (rawData is! List) {
      throw const PriceShieldApiException(
        'The server returned an invalid response.',
      );
    }
    final meta = envelope['meta'];
    final nextCursor = meta is Map<String, dynamic>
        ? meta['nextCursor']?.toString()
        : null;
    final items = rawData
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return PagedResult<Map<String, dynamic>>(
      items: items,
      nextCursor: (nextCursor != null && nextCursor.isNotEmpty)
          ? nextCursor
          : null,
    );
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration? timeout,
  }) async {
    final envelope = await _requestEnvelope(
      method,
      path,
      body: body,
      authenticated: authenticated,
      timeout: timeout,
    );
    return envelope['data'];
  }

  Future<Map<String, dynamic>> _requestEnvelope(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration? timeout,
  }) async {
    if (!isConfigured) {
      throw const PriceShieldApiException(
        'PriceShield service is temporarily connecting. Please try again.',
      );
    }
    final baseUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null ||
        !baseUri.hasAuthority ||
        (baseUri.scheme != 'http' && baseUri.scheme != 'https') ||
        (baseUri.path.isNotEmpty && baseUri.path != '/')) {
      throw const PriceShieldApiException(
        'Server connection configuration is invalid.',
      );
    }
    final token = await _tokenProvider();
    if (authenticated && (token == null || token.isEmpty)) {
      throw const PriceShieldApiException(
        'Session expired. Please sign in again.',
        statusCode: 401,
      );
    }

    final uri = Uri.parse('$baseUrl/api/v1$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final effectiveTimeout = timeout ?? _timeout;
      final streamed = await _client.send(request).timeout(effectiveTimeout);
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
        final message = error is Map<String, dynamic>
            ? error['message']?.toString()
            : null;
        throw PriceShieldApiException(
          message ?? 'Unable to complete this request. Please try again.',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode == 204 || response.body.isEmpty) {
        return <String, dynamic>{'data': null};
      }
      if (decoded is! Map<String, dynamic> || !decoded.containsKey('data')) {
        throw const PriceShieldApiException(
          'Unable to process server response. Please try again.',
        );
      }
      return decoded;
    } on TimeoutException {
      throw const PriceShieldApiException(
        'Connection timed out. Please check your internet connection.',
      );
    } on http.ClientException {
      throw const PriceShieldApiException(
        'Unable to connect to PriceShield. Please check your internet connection.',
      );
    } on FormatException {
      throw const PriceShieldApiException(
        'Unable to process server response. Please try again.',
      );
    }
  }
}

final priceShieldApi = PriceShieldApiClient();
