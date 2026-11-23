import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:priceshield/core/services/indian_dual_batch_resolver.dart';
import 'package:priceshield/features/scanner/presentation/screens/no_barcode_scan_screen.dart';

void main() {
  group('IndianDualBatchResolver Unit Tests', () {
    test('resolves Sprite 750ml promo vs standard batch variants', () {
      final variants = IndianDualBatchResolver.resolveVariants(
        barcode: '8901764012241',
        productName: 'Sprite 750ml Bottle',
      );
      expect(variants.length, 2);
      expect(variants[0].mrp, 35);
      expect(variants[0].label, contains('Promo'));
      expect(variants[1].mrp, 40);
      expect(variants[1].label, contains('Standard'));
    });

    test('resolves Lipton Green Tea old vs new inflation batch variants', () {
      final variants = IndianDualBatchResolver.resolveVariants(
        barcode: '8901030779312',
        productName: 'Lipton Clear & Light Green Tea (25N)',
      );
      expect(variants.length, 2);
      expect(variants[0].mrp, 165);
      expect(variants[0].label, contains('Old Batch'));
      expect(variants[1].mrp, 190);
      expect(variants[1].label, contains('New Batch'));
    });

    test('resolves Rail Neer 500ml vs 1L variants', () {
      final variants = IndianDualBatchResolver.resolveVariants(
        barcode: '8908001150013',
        productName: 'IRCTC Rail Neer Packaged Drinking Water 1L',
      );
      expect(variants.length, 2);
      expect(variants[0].mrp, 10);
      expect(variants[1].mrp, 15);
    });

    test('resolves dynamic mismatch when catalog MRP differs from packet OCR MRP', () {
      final variants = IndianDualBatchResolver.resolveVariants(
        barcode: '8909999999999',
        productName: 'Generic Local Biscuits',
        catalogMrp: 45,
        ocrExtractedMrp: 50,
      );
      expect(variants.length, 2);
      expect(variants[0].mrp, 45);
      expect(variants[1].mrp, 50);
    });
  });

  group('NoBarcodeScanScreen Widget Tests', () {
    testWidgets('renders No Barcode screen with Legal Metrology rule advisory and categories', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NoBarcodeScanScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Report Item Without Barcode'), findsOneWidget);
      expect(find.textContaining('Rule 18(2) Legal Metrology & DPCO 2013'), findsOneWidget);
      expect(find.text('💊 Medicine / Tablet Strip'), findsOneWidget);
      expect(find.text('Step 1: Capture Packaging Photo'), findsOneWidget);
      expect(find.text('Step 2: Verify Product & Price Details'), findsOneWidget);
    });

    testWidgets('tapping Rail Neer category and 1-tap preset auto-fills name and official MRP', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NoBarcodeScanScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Rail Neer category chip
      await tester.tap(find.text('🚆 Water / Rail Neer'));
      await tester.pumpAndSettle();

      // Check preset chips appear
      expect(find.text('🚆 Rail Neer 1L'), findsOneWidget);
      expect(find.text('Official MRP: ₹15.00'), findsOneWidget);

      // Tap preset
      await tester.tap(find.text('🚆 Rail Neer 1L'));
      await tester.pumpAndSettle();

      // Verify TextFormField pre-filled
      final nameField = find.widgetWithText(TextFormField, 'IRCTC Rail Neer Packaged Drinking Water 1L');
      expect(nameField, findsOneWidget);
      final mrpField = find.widgetWithText(TextFormField, '15');
      expect(mrpField, findsOneWidget);
    });

    testWidgets('entering charged price higher than MRP triggers live overcharge alert banner', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NoBarcodeScanScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Select Rail Neer 1L
      await tester.tap(find.text('🚆 Water / Rail Neer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🚆 Rail Neer 1L'));
      await tester.pumpAndSettle();

      // Enter 20 in price charged
      final chargedField = find.widgetWithText(TextFormField, 'Price Charged');
      await tester.enterText(chargedField, '20');
      await tester.pumpAndSettle();

      // Overcharge alert should be rendered live: 20 - 15 = 5 extra (+33.3%)
      expect(find.textContaining('🚨 ₹5 Extra Charged (+33.3%)'), findsOneWidget);
      expect(find.textContaining('Violation under Sec 36 Legal Metrology Act'), findsOneWidget);
      expect(find.text('File Overcharge Complaint (₹5 Extra)'), findsOneWidget);
    });
  });
}
