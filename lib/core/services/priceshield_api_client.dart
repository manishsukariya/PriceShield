import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:priceshield/core/data/default_products_catalog.dart';
import 'package:priceshield/core/services/auth_session.dart';

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
  PriceShieldApiClient({http.Client? client})
      : _client = client ?? http.Client() {
    _initProductCache();
  }

  static const _configuredBaseUrl = String.fromEnvironment(
    'PRICESHIELD_API_BASE_URL',
  );
  static const _debugLocalBaseUrl = 'http://192.168.0.107:3000';
  static const _defaultProductionBaseUrl = 'https://priceshield-r4v5.onrender.com';
  static const _timeout = Duration(seconds: 35);

  final http.Client _client;
  final Map<String, Map<String, dynamic>> _productCache = {};

  void _initProductCache() {
    for (final entry in defaultIndianProductsCatalog.entries) {
      _productCache[entry.key] = Map<String, dynamic>.from(entry.value);
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

  Future<Map<String, dynamic>> getProduct(String barcode) async {
    final clean = barcode.trim();
    final cached = getCachedProduct(clean);
    if (cached != null) return cached;

    final result = await _requestMap(
      'GET',
      '/products/${Uri.encodeComponent(clean)}',
      authenticated: false,
    );
    cacheProduct(clean, result);
    return result;
  }

  Future<void> logout() async {}

  Future<Map<String, dynamic>> getProfile() => _requestMap('GET', '/me');

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> changes) =>
      _requestMap('PATCH', '/me', body: changes);

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

  Future<List<Map<String, dynamic>>> listScans({int limit = 20}) =>
      _requestList('GET', '/scans?limit=$limit');

  Future<Map<String, dynamic>> createComplaint({
    required String barcode,
    required String productName,
    required num mrp,
    required num chargedPrice,
    required String address,
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
      'barcode': barcode,
      'productName': productName,
      'mrp': mrp,
      'chargedPrice': chargedPrice,
      'address': address,
      if (purchaseDate != null) 'purchaseDate': purchaseDate.toIso8601String(),
      'latitude': ?latitude,
      'longitude': ?longitude,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (evidence != null && evidence.isNotEmpty) 'evidence': evidence,
      'clientRequestId': ?clientRequestId,
    },
  );

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

  Future<List<Map<String, dynamic>>> listComplaints({
    String? status,
    int limit = 20,
  }) {
    final query = <String, String>{'limit': '$limit'};
    if (status != null && status.isNotEmpty) query['status'] = status;
    return _requestList(
      'GET',
      '/complaints?${Uri(queryParameters: query).query}',
    );
  }

  Future<Map<String, dynamic>> _requestMap(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final data = await _request(
      method,
      path,
      body: body,
      authenticated: authenticated,
    );
    if (data is! Map<String, dynamic>) {
      throw const PriceShieldApiException(
        'The server returned an invalid response.',
      );
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> _requestList(
    String method,
    String path,
  ) async {
    final data = await _request(method, path);
    if (data is! List) {
      throw const PriceShieldApiException(
        'The server returned an invalid response.',
      );
    }
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
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
    final token = await AuthSession.refreshToken();
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
      final streamed = await _client.send(request).timeout(_timeout);
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
      if (decoded is! Map<String, dynamic> || !decoded.containsKey('data')) {
        throw const PriceShieldApiException(
          'Unable to process server response. Please try again.',
        );
      }
      return decoded['data'];
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
