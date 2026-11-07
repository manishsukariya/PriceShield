import 'package:flutter_test/flutter_test.dart';
import 'package:priceshield/core/services/gs1_india_brand_resolver.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';

void main() {
  group('PriceShieldApiClient in-memory product cache (0ms lookup)', () {
    test('contains pre-seeded catalog of common Indian FMCG products for instant 0ms lookups', () {
      final client = PriceShieldApiClient();

      // Common daily-use products are pre-cached out of the box
      final amulMilk = client.getCachedProduct('8901262150057');
      expect(amulMilk, isNotNull);
      expect(amulMilk!['name'], 'Amul Taaza Homogenised Toned Milk 500ml');
      expect(amulMilk['mrp'], 27.00);

      final parleG = client.getCachedProduct('8901719101037');
      expect(parleG, isNotNull);
      expect(parleG!['name'], 'Parle-G Original Gluco Biscuits 800g');
      expect(parleG['mrp'], 80.00);

      final maggi = client.getCachedProduct('8901058852493');
      expect(maggi, isNotNull);
      expect(maggi!['name'], 'Maggi 2-Minute Masala Instant Noodles 70g');
      expect(maggi['mrp'], 14.00);
    });

    test('caches and retrieves newly scanned product instantly without network call', () {
      final client = PriceShieldApiClient();
      const customBarcode = '9991234567890';
      expect(client.getCachedProduct(customBarcode), isNull);

      final productData = {
        'id': 'test-1',
        'barcode': customBarcode,
        'name': 'Custom Kirana Item 1kg',
        'mrp': 120.00,
      };

      client.cacheProduct(customBarcode, productData);

      final retrieved = client.getCachedProduct(customBarcode);
      expect(retrieved, isNotNull);
      expect(retrieved!['name'], 'Custom Kirana Item 1kg');
      expect(retrieved['mrp'], 120.00);

      // Verify trimming works
      expect(client.getCachedProduct('  $customBarcode  '), isNotNull);

      // Clearing cache
      client.clearProductCache();
      expect(client.getCachedProduct(customBarcode), isNull);
      expect(client.getCachedProduct('8901262150057'), isNull);

      // Reset restores defaults
      client.resetProductCache();
      expect(client.getCachedProduct('8901262150057'), isNotNull);
    });
  });

  group('OCR printed MRP regex tests', () {
    final mrpRegex = RegExp(
      r'(?:(?:M\.?\s*R\.?\s*P\.?|MAX(?:IMUM)?\.?\s*RETAIL\s*PRICE)(?:\s*\([^)]*\))?|INCL\.?\s*OF\s*ALL\s*TAXES|Rs\.?|INR|₹)\s*[:\.\-]?\s*(?:Rs\.?|INR|₹)?\s*(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );

    test('matches standard MRP Rs. format', () {
      final match = mrpRegex.firstMatch('Batch: 124\nMRP Rs. 20\nNet Wt: 100g');
      expect(match, isNotNull);
      expect(match!.group(1), '20');
    });

    test('matches MRP with colon and rupee symbol', () {
      final match = mrpRegex.firstMatch('MRP: ₹15.00 (INCL. OF ALL TAXES)');
      expect(match, isNotNull);
      expect(match!.group(1), '15.00');
    });

    test('matches MRP with incl of all taxes in parentheses before amount', () {
      final match1 = mrpRegex.firstMatch('MRP (INCL. OF ALL TAXES) 50.00');
      expect(match1, isNotNull);
      expect(match1!.group(1), '50.00');

      final match2 = mrpRegex.firstMatch('MRP (INCLUSIVE OF ALL TAXES) : 35.00');
      expect(match2, isNotNull);
      expect(match2!.group(1), '35.00');
    });

    test('matches MAXIMUM RETAIL PRICE variant', () {
      final match = mrpRegex.firstMatch('MAXIMUM RETAIL PRICE (INCL. OF ALL TAXES) 100');
      expect(match, isNotNull);
      expect(match!.group(1), '100');
    });

    test('matches punctuated M.R.P. 25.00', () {
      final match = mrpRegex.firstMatch('M.R.P. 25.00');
      expect(match, isNotNull);
      expect(match!.group(1), '25.00');
    });

    test('matches spaced M. R. P. : 30', () {
      final match = mrpRegex.firstMatch('M. R. P. : 30');
      expect(match, isNotNull);
      expect(match!.group(1), '30');
    });

    test('matches isolated Rs. 10.50', () {
      final match = mrpRegex.firstMatch('Packed on: 01/26\nRs. 10.50');
      expect(match, isNotNull);
      expect(match!.group(1), '10.50');
    });

    test('matches standalone rupee symbol ₹ 99.50', () {
      final match = mrpRegex.firstMatch('Special Offer\n₹ 99.50');
      expect(match, isNotNull);
      expect(match!.group(1), '99.50');
    });
  });

  group('OCR title extraction heuristics', () {
    test('filters packaging metadata lines and picks true product title', () {
      const ocrLines = [
        'PKD. 12/24',
        'BATCH NO: B202',
        'FSSAI LIC NO: 10014022002652',
        'NET QTY: 75g',
        'Sunfeast Dark Fantasy Choco Fills',
        'MRP Rs. 40.00',
      ];

      String? detectedName;
      for (final line in ocrLines) {
        final lower = line.toLowerCase();
        if (!lower.startsWith('mrp') &&
            !lower.startsWith('mfg') &&
            !lower.startsWith('exp') &&
            !lower.startsWith('batch') &&
            !lower.startsWith('net') &&
            !lower.startsWith('pkd') &&
            !lower.startsWith('packed') &&
            !lower.startsWith('use by') &&
            !lower.startsWith('best before') &&
            !lower.startsWith('fssai') &&
            !lower.startsWith('lic') &&
            !lower.startsWith('qty') &&
            !lower.startsWith('weight') &&
            !lower.startsWith('ingredients') &&
            !lower.startsWith('nutrition') &&
            !RegExp(r'^\d+$').hasMatch(line)) {
          detectedName = line;
          break;
        }
      }

      expect(detectedName, 'Sunfeast Dark Fantasy Choco Fills');
    });
  });

  group('Decimal price parsing tests', () {
    test('safely parses decimal amounts without crashing or truncating', () {
      const input = '27.50';
      final parsed = num.tryParse(input);
      expect(parsed, isNotNull);
      expect(parsed, 27.50);
      expect(parsed! > 27, isTrue);
    });

    test('handles integers smoothly', () {
      const input = '40';
      final parsed = num.tryParse(input);
      expect(parsed, 40);
    });

    test('returns null for invalid strings safely without throwing', () {
      expect(num.tryParse('invalid'), isNull);
      expect(num.tryParse(''), isNull);
    });
  });

  group('Regional FMCG Staples in 0ms Offline Catalog', () {
    test('contains Indian railway & regional dairy staples for 0ms offline lookups', () {
      final client = PriceShieldApiClient();

      // Rail Neer 1L (Railway staple)
      final railNeer = client.getCachedProduct('8908001150013');
      expect(railNeer, isNotNull);
      expect(railNeer!['name'], contains('Rail Neer'));
      expect(railNeer['mrp'], 15.00);

      // Bisleri 1L
      final bisleri = client.getCachedProduct('8901023000018');
      expect(bisleri, isNotNull);
      expect(bisleri!['mrp'], 20.00);

      // Nandini Toned Milk 500ml (Karnataka)
      final nandini = client.getCachedProduct('8906010010012');
      expect(nandini, isNotNull);
      expect(nandini!['name'], contains('Nandini'));
      expect(nandini['mrp'], 24.00);

      // Saras Milk 500ml (Rajasthan)
      final saras = client.getCachedProduct('8908005110011');
      expect(saras, isNotNull);
      expect(saras!['mrp'], 25.00);

      // Balaji Wafers (Gujarat & Western India)
      final balaji = client.getCachedProduct('8906001010015');
      expect(balaji, isNotNull);
      expect(balaji!['mrp'], 10.00);
    });
  });

  group('Gs1IndiaBrandResolver Unit Tests', () {
    test('resolves regional and national brands from Indian 890 barcode prefix', () {
      // Nandini KMF
      final nandini = Gs1IndiaBrandResolver.resolve('8906010999999');
      expect(nandini, isNotNull);
      expect(nandini!.brandName, contains('Nandini'));

      // Saras Dairy
      final saras = Gs1IndiaBrandResolver.resolve('8908005123456');
      expect(saras, isNotNull);
      expect(saras!.brandName, contains('Saras'));

      // Verka Dairy
      final verka = Gs1IndiaBrandResolver.resolve('8908006123456');
      expect(verka, isNotNull);
      expect(verka!.brandName, contains('Verka'));

      // Rail Neer IRCTC
      final railNeer = Gs1IndiaBrandResolver.resolve('8908001999999');
      expect(railNeer, isNotNull);
      expect(railNeer!.brandName, contains('Rail Neer'));

      // Balaji Wafers
      final balaji = Gs1IndiaBrandResolver.resolve('8906001999999');
      expect(balaji, isNotNull);
      expect(balaji!.brandName, contains('Balaji'));

      // Non-Indian or non-GS1 barcode returns null
      expect(Gs1IndiaBrandResolver.resolve('012345678905'), isNull);
      expect(Gs1IndiaBrandResolver.resolve(''), isNull);
      expect(Gs1IndiaBrandResolver.resolve(null), isNull);
    });
  });
}
