import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:priceshield/core/services/mrp_enrichment_service.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/features/scanner/presentation/screens/product_details_screen.dart';

void main() {
  group('MrpEnrichmentService.extractMrpFromText', () {
    test('extracts standard MRP formats and textual packet prices', () {
      expect(MrpEnrichmentService.extractMrpFromText('MRP Rs. 20'), 20);
      expect(
        MrpEnrichmentService.extractMrpFromText('MRP: ₹15.00 (INCL. OF ALL TAXES)'),
        15,
      );
      expect(
        MrpEnrichmentService.extractMrpFromText('MRP (INCL. OF ALL TAXES) 50.00'),
        50,
      );
      expect(
        MrpEnrichmentService.extractMrpFromText('MRP (INCLUSIVE OF ALL TAXES) : 35.00'),
        35,
      );
      expect(
        MrpEnrichmentService.extractMrpFromText('MAXIMUM RETAIL PRICE (INCL. OF ALL TAXES) 100'),
        100,
      );
      expect(MrpEnrichmentService.extractMrpFromText('M.R.P. 25.00'), 25);
      expect(MrpEnrichmentService.extractMrpFromText('M. R. P. : 30'), 30);
      expect(MrpEnrichmentService.extractMrpFromText('Lays Classics Salted 20rs'), 20);
      expect(MrpEnrichmentService.extractMrpFromText('Kurkure Masala 10/-'), 10);
      expect(
        MrpEnrichmentService.extractMrpFromText('MRP\n₹35.00 (Incl. of all taxes)'),
        35,
      );
    });

    test('extracts Legal Metrology inkjet MRP from Britannia Jimjam OCR (8901063029279)', () {
      const jimjamOcr = 'LOT NO.\n35.00\nRs.0.25 per g\n17/08/23\n16/02/24\nK50823E';
      expect(
        MrpEnrichmentService.extractMrpFromText(jimjamOcr, quantityText: '138 g'),
        35,
      );
    });

    test('extracts MRP while ignoring promo offers, unit rates, dates, and quantities', () {
      const promoPlusMrp =
          'GET A FLAT ₹50 CASHBACK SCRATCH CARD ON GOOGLE PAY\n'
          'MRP Rs. 20/- (INCL. OF ALL TAXES)\n'
          'Rs. 0.40 per g';
      expect(
        MrpEnrichmentService.extractMrpFromText(promoPlusMrp, quantityText: '50 g'),
        20,
      );

      expect(
        MrpEnrichmentService.extractMrpFromText('Rs. 0.25 per g\nNET WT 138 g'),
        isNull,
      );
      expect(
        MrpEnrichmentService.extractMrpFromText('2 Rs. per g\n10/12/25'),
        isNull,
      );
      expect(
        MrpEnrichmentService.extractMrpFromText('WIN FLAT ₹100 VOUCHER OFFER'),
        isNull,
      );
    });

    test('extractMrpFromOcr handles chilled condensation noise cleanly', () {
      expect(MrpEnrichmentService.extractMrpFromOcr('MRP ₹ 2O'), 20);
      expect(
        MrpEnrichmentService.extractMrpFromOcr('Rs. 0.25 per g'),
        isNull,
      );
    });
  });

  group('MrpEnrichmentService.resolveMissingMrp', () {
    test('resolves MRP from product name locally without making HTTP requests', () async {
      var httpCalls = 0;
      final service = MrpEnrichmentService(
        client: MockClient((_) async {
          httpCalls++;
          return http.Response('{}', 200);
        }),
      );

      final result = await service.resolveMissingMrp(
        barcode: '8901491101837',
        productName: 'Lays Classics Salted 20rs (50 g)',
        source: 'open_food_facts',
      );

      expect(result, isNotNull);
      expect(result!.mrp, 20);
      expect(httpCalls, 0);
    });

    test('resolves MRP from Open Food Facts packaging image OCR JSON', () async {
      final service = MrpEnrichmentService(
        client: MockClient((request) async {
          final url = request.url.toString();
          if (url.contains('prices.openfoodfacts.org')) {
            return http.Response(jsonEncode({'items': []}), 200);
          }
          if (url.contains('world.openfoodfacts.org/api/v2/product/8901063029279.json')) {
            return http.Response(
              jsonEncode({
                'status': 1,
                'product': {
                  'product_name': 'Jimjam',
                  'brands': 'Britannia',
                  'quantity': '138 g',
                  'image_url':
                      'https://images.openfoodfacts.org/images/products/890/106/302/9279/front_en.3.400.jpg',
                  'images': {
                    'packaging_en': {'imgid': '4'},
                  },
                },
              }),
              200,
            );
          }
          if (url == 'https://images.openfoodfacts.org/images/products/890/106/302/9279/4.json') {
            return http.Response(
              jsonEncode({
                'responses': [
                  {
                    'fullTextAnnotation': {
                      'text': '35.00\nRs.0.25 per g\n17/08/23\n16/02/24',
                    },
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final result = await service.resolveMissingMrp(
        barcode: '8901063029279',
        productName: 'Britannia Jimjam (138 g)',
        source: 'catalog_db',
      );

      expect(result, isNotNull);
      expect(result!.mrp, 35);
      expect(result.source, 'open_food_facts_ocr');
    });

    test('resolves MRP from Open Prices INR feed', () async {
      final service = MrpEnrichmentService(
        client: MockClient((request) async {
          final url = request.url.toString();
          if (url.contains('prices.openfoodfacts.org')) {
            return http.Response(
              jsonEncode({
                'items': [
                  {'currency': 'INR', 'price': 18, 'price_without_discount': 20},
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'status': 0}), 200);
        }),
      );

      final result = await service.resolveMissingMrp(
        barcode: '8901491103046',
        productName: 'Kurkure Green Chutney',
      );

      expect(result, isNotNull);
      expect(result!.mrp, 20);
      expect(result.source, 'open_prices');
    });
  });

  group('ProductDetailsScreen auto-enrichment & UI', () {
    testWidgets('auto-fills Printed MRP when backend returns mrp="0" for 8901063029279', (
      tester,
    ) async {
      final apiClient = PriceShieldApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/products/8901063029279')) {
            return http.Response(
              jsonEncode({
                'data': {
                  'id': 'cmwbxt0jw0001d73cc3bs0mpu',
                  'barcode': '8901063029279',
                  'name': 'Britannia Jimjam (138 g)',
                  'mrp': '0',
                  'source': 'catalog_db',
                },
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
        tokenProvider: () async => null,
      );

      final enrichment = MrpEnrichmentService(
        client: MockClient((request) async {
          final url = request.url.toString();
          if (url.contains('prices.openfoodfacts.org')) {
            return http.Response(jsonEncode({'items': []}), 200);
          }
          if (url.contains('world.openfoodfacts.org/api/v2/product/8901063029279.json')) {
            return http.Response(
              jsonEncode({
                'status': 1,
                'product': {
                  'product_name': 'Jimjam',
                  'brands': 'Britannia',
                  'quantity': '138 g',
                  'image_url':
                      'https://images.openfoodfacts.org/images/products/890/106/302/9279/front_en.3.400.jpg',
                  'images': {
                    'packaging_en': {'imgid': '4'},
                  },
                },
              }),
              200,
            );
          }
          if (url == 'https://images.openfoodfacts.org/images/products/890/106/302/9279/4.json') {
            return http.Response(
              jsonEncode({
                'responses': [
                  {
                    'fullTextAnnotation': {
                      'text': '35.00\nRs.0.25 per g\n17/08/23',
                    },
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProductDetailsScreen(
            barcode: '8901063029279',
            apiClient: apiClient,
            enrichmentService: enrichment,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Britannia Jimjam (138 g)'), findsOneWidget);
      expect(find.text('35'), findsOneWidget);
      expect(find.textContaining('Open Food Facts Packaging OCR'), findsOneWidget);
      expect(find.byTooltip('Scan MRP from packet'), findsOneWidget);
    });

    testWidgets('shows GS1 brand MRP chips and scan icon when online MRP is truly unavailable', (
      tester,
    ) async {
      final apiClient = PriceShieldApiClient(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'data': {
                'barcode': '8901063999999',
                'name': 'Britannia Unlisted Biscuit',
                'mrp': '0',
                'source': 'catalog_db',
              },
            }),
            200,
          );
        }),
        tokenProvider: () async => null,
      );

      final enrichment = MrpEnrichmentService(
        client: MockClient((_) async => http.Response(jsonEncode({'status': 0, 'items': []}), 200)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProductDetailsScreen(
            barcode: '8901063999999',
            apiClient: apiClient,
            enrichmentService: enrichment,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Britannia Unlisted Biscuit'), findsOneWidget);
      expect(
        find.textContaining('MRP isn\'t listed in online catalogs yet'),
        findsOneWidget,
      );
      expect(find.byTooltip('Scan MRP from packet'), findsOneWidget);
      // Britannia GS1 prefix chips are available (first chip ₹5)
      expect(find.text('₹5'), findsOneWidget);
    });
  });
}
