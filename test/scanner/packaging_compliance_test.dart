import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:priceshield/features/complaints/services/escalation_pack_service.dart';
import 'package:priceshield/features/scanner/presentation/screens/scan_result_screen.dart';
import 'package:priceshield/features/scanner/services/packaging_compliance_service.dart';

void main() {
  group('PackagingComplianceService Unit Tests', () {
    test('returns compliant result for clean OCR text', () {
      const cleanOcr = '''
        Amul Taaza Homogenised Toned Milk 500ml
        Batch No: B1024
        MFG: 01/24 EXP: 07/24
        MRP Rs. 27.00 (INCL. OF ALL TAXES)
        FSSAI Lic. No. 10014021001234
      ''';

      final result = PackagingComplianceService.analyze(cleanOcr);
      expect(result.hasViolation, isFalse);
      expect(result.violationType, PackagingViolationType.none);
      expect(result.title, 'Packaging Compliant');
    });

    test('returns compliant result for null or empty input', () {
      expect(PackagingComplianceService.analyze(null).hasViolation, isFalse);
      expect(PackagingComplianceService.analyze('').hasViolation, isFalse);
      expect(PackagingComplianceService.analyze('   \n  \t ').hasViolation, isFalse);
    });

    group('Multipack splitting detection', () {
      test('flags "not for individual sale"', () {
        const text = 'Britannia Good Day 600g\nNOT FOR INDIVIDUAL SALE\nBatch 99';
        final result = PackagingComplianceService.analyze(text);

        expect(result.hasViolation, isTrue);
        expect(result.violationType, PackagingViolationType.multipack);
        expect(result.title, contains('Multipack Splitting'));
        expect(result.matchedSnippet, 'NOT FOR INDIVIDUAL SALE');
        expect(result.legalAdvice, contains('Rule 24'));
        expect(result.legalAdvice, contains('Rule 18(2)'));
      });

      test('flags "not for loose sale"', () {
        const text = 'Nestle KitKat Mini\nNot For Loose Sale\nNet Wt 12g';
        final result = PackagingComplianceService.analyze(text);

        expect(result.hasViolation, isTrue);
        expect(result.violationType, PackagingViolationType.multipack);
        expect(result.matchedSnippet, 'Not For Loose Sale');
      });

      test('flags "part of multipack" and "part of a multipack"', () {
        final r1 = PackagingComplianceService.analyze('Item 1 - Part of multipack');
        expect(r1.hasViolation, isTrue);
        expect(r1.violationType, PackagingViolationType.multipack);

        final r2 = PackagingComplianceService.analyze('Snack unit - PART OF A MULTIPACK');
        expect(r2.hasViolation, isTrue);
        expect(r2.violationType, PackagingViolationType.multipack);
      });

      test('flags "for promotional pack only"', () {
        const text = 'Colgate Dental Cream\nFor promotional pack only\n100g';
        final result = PackagingComplianceService.analyze(text);

        expect(result.hasViolation, isTrue);
        expect(result.violationType, PackagingViolationType.multipack);
      });

      test('flags fuzzy multipack variations caused by chilled package water drops or optical noise', () {
        // '1' for 'i' and 'l'
        final r1 = PackagingComplianceService.analyze('CHILLED DRINK - NOT FOR IND1V1DUAL SA1E');
        expect(r1.hasViolation, isTrue);
        expect(r1.violationType, PackagingViolationType.multipack);

        // 'l' for 'i'
        final r2 = PackagingComplianceService.analyze('BEVERAGE CAN - not for indivldual sale');
        expect(r2.hasViolation, isTrue);
        expect(r2.violationType, PackagingViolationType.multipack);
      });
    });

    group('Freebie / Sample resale detection', () {
      test('flags "free sample"', () {
        const text = 'Dettol Hand Wash 50ml\nFREE SAMPLE\nManufactured by Reckitt';
        final result = PackagingComplianceService.analyze(text);

        expect(result.hasViolation, isTrue);
        expect(result.violationType, PackagingViolationType.freebie);
        expect(result.title, contains('Free Sample'));
        expect(result.matchedSnippet, 'FREE SAMPLE');
        expect(result.legalAdvice, contains('Rule 18'));
      });

      test('flags "not for sale"', () {
        const text = 'Sample sachet\nNot for Sale\nBatch 400';
        final result = PackagingComplianceService.analyze(text);

        expect(result.hasViolation, isTrue);
        expect(result.violationType, PackagingViolationType.freebie);
        expect(result.matchedSnippet, 'Not for Sale');
      });

      test('flags "complimentary pack"', () {
        const text = 'Special Gift Sachet - Complimentary Pack';
        final result = PackagingComplianceService.analyze(text);

        expect(result.hasViolation, isTrue);
        expect(result.violationType, PackagingViolationType.freebie);
      });
    });

    group('Outer pack MRP requirement detection', () {
      test('flags "see outer pack for mrp"', () {
        const text = 'Pouch 1 of 4\nSee Outer Pack for MRP\nBatch 887';
        final result = PackagingComplianceService.analyze(text);

        expect(result.hasViolation, isTrue);
        expect(result.violationType, PackagingViolationType.outerPackMrp);
        expect(result.title, contains('Missing Unit MRP'));
        expect(result.matchedSnippet, 'See Outer Pack for MRP');
        expect(result.legalAdvice, contains('Rule 6'));
      });

      test('flags "mrp on outer carton"', () {
        const text = 'Individual cup\nMRP ON OUTER CARTON\nBest before 6 months';
        final result = PackagingComplianceService.analyze(text);

        expect(result.hasViolation, isTrue);
        expect(result.violationType, PackagingViolationType.outerPackMrp);
        expect(result.matchedSnippet, 'MRP ON OUTER CARTON');
      });
    });

    group('Promotional discount regex detection', () {
      test('matches rupee off variants like ₹10 off and ₹ 15 off', () {
        final r1 = PackagingComplianceService.analyze('Special Offer! ₹10 off on this pack!');
        expect(r1.hasViolation, isTrue);
        expect(r1.violationType, PackagingViolationType.promotionalDiscount);
        expect(r1.matchedSnippet, '₹10 off');

        final r2 = PackagingComplianceService.analyze('Limited Period: ₹  25  OFF');
        expect(r2.hasViolation, isTrue);
        expect(r2.violationType, PackagingViolationType.promotionalDiscount);
      });

      test('matches Rs. off variants', () {
        final r1 = PackagingComplianceService.analyze('Rs. 5 off today');
        expect(r1.hasViolation, isTrue);
        expect(r1.violationType, PackagingViolationType.promotionalDiscount);

        final r2 = PackagingComplianceService.analyze('Save now! Rs 20 off');
        expect(r2.hasViolation, isTrue);
        expect(r2.violationType, PackagingViolationType.promotionalDiscount);
      });

      test('matches percentage extra variants like 20% extra', () {
        final result = PackagingComplianceService.analyze('Mega Value: 25% extra free volume');
        expect(result.hasViolation, isTrue);
        expect(result.violationType, PackagingViolationType.promotionalDiscount);
        expect(result.matchedSnippet, '25% extra');
      });
    });

    group('Sticker / Tampered MRP detection', () {
      test('flags "sticker price" and "tampered mrp"', () {
        final r1 = PackagingComplianceService.analyze('Beverage can\nSticker Price: Rs 50\nBatch 101');
        expect(r1.hasViolation, isTrue);
        expect(r1.violationType, PackagingViolationType.stickerTampering);
        expect(r1.title, contains('Sticker Overwrite'));
        expect(r1.legalAdvice, contains('Rule 18(2)'));

        final r2 = PackagingComplianceService.analyze('Item with TAMPERED MRP tag');
        expect(r2.hasViolation, isTrue);
        expect(r2.violationType, PackagingViolationType.stickerTampering);
      });

      test('PackagingComplianceResult.stickerTampered constant creates valid violation', () {
        const result = PackagingComplianceResult.stickerTampered;
        expect(result.hasViolation, isTrue);
        expect(result.violationType, PackagingViolationType.stickerTampering);
        expect(result.title, contains('Sticker Overwrite'));
        expect(result.legalAdvice, contains('Rule 18(2)'));
        expect(result.legalAdvice, contains('25,000'));
      });
    });

    test('maintains value equality and toString integrity', () {
      final r1 = PackagingComplianceService.analyze('Not for loose sale');
      final r2 = PackagingComplianceService.analyze('Not for loose sale');
      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
      expect(r1.toString(), contains('Multipack Splitting'));
    });
  });

  group('EscalationPackService Unit Tests', () {
    test('generateWhatsAppNotice formats notice with citations and overcharge details', () {
      final notice = EscalationPackService.generateWhatsAppNotice(
        productName: 'Cadbury Dairy Milk Silk 150g',
        barcode: '8901234567890',
        mrp: 175.00,
        chargedPrice: 195.00,
        merchantName: 'Sharma General Store',
        storeAddress: 'Shop 12, Main Market',
        date: DateTime(2026, 11, 6),
      );

      expect(notice, contains('Rule 18(2) of the Legal Metrology (Packaged Commodities) Rules, 2011'));
      expect(notice, contains('Section 36(1) of the Legal Metrology Act, 2009'));
      expect(notice, contains('Cadbury Dairy Milk Silk 150g'));
      expect(notice, contains('Sharma General Store'));
      expect(notice, contains('₹175.00'));
      expect(notice, contains('₹195.00'));
      expect(notice, contains('₹20.00'));
      expect(notice, contains('National Consumer Helpline (NCH: 1915)'));
    });

    test('generateWhatsAppNotice incorporates packaging compliance violation details', () {
      final compliance = PackagingComplianceService.analyze('NOT FOR INDIVIDUAL SALE');
      final notice = EscalationPackService.generateWhatsAppNotice(
        productName: 'Mini Multipack Pack',
        barcode: '8901111222333',
        mrp: 50.00,
        chargedPrice: 50.00,
        complianceResult: compliance,
      );

      expect(notice, contains('Packaging Issue Detected'));
      expect(notice, contains('Multipack Splitting'));
      expect(notice, contains('Rule 24'));
    });

    test('generateOfficialDocket generates structured complaint formatted for NCH 1915 and DCDRC', () {
      final docket = EscalationPackService.generateOfficialDocket(
        docketId: 'PS-TEST-DOCKET-01',
        productName: 'Amul Salted Butter 500g',
        barcode: '8901262010054',
        mrp: 275.00,
        chargedPrice: 300.00,
        merchantName: 'Super Mart Retail Ltd',
        storeAddress: 'Sector 18, Commercial Hub',
        incidentDate: DateTime(2026, 11, 6),
        evidenceSummary: 'Clear store invoice photo and barcode photo attached',
      );

      expect(docket, contains('FORMAL CONSUMER GRIEVANCE DOCKET'));
      expect(docket, contains('National Consumer Helpline (NCH - 1915)'));
      expect(docket, contains('PS-TEST-DOCKET-01'));
      expect(docket, contains('Amul Salted Butter 500g'));
      expect(docket, contains('Super Mart Retail Ltd'));
      expect(docket, contains('₹275.00'));
      expect(docket, contains('₹300.00'));
      expect(docket, contains('₹25.00'));
      expect(docket, contains('Rule 18(2), Legal Metrology (Packaged Commodities) Rules, 2011'));
      expect(docket, contains('Section 36(1), Legal Metrology Act, 2009'));
      expect(docket, contains('Section 2(47), Consumer Protection Act, 2019'));
      expect(docket, contains('Clear store invoice photo and barcode photo attached'));
    });
  });

  group('ScanResultScreen Widget Tests', () {
    testWidgets('renders celebratory Shield Scout Points chip and standard overcharge cards',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ScanResultScreen(
            name: 'Bisleri Mineral Water 1L',
            barcode: '8906017290048',
            mrp: 20.00,
            charged: 25.00,
          ),
        ),
      );
      await tester.pump();

      // Verify celebratory Shield Scout Points Chip
      expect(find.text('🛡️ +50 ShieldPoints Earned! (Scout Level 1)'), findsWidgets);

      // Verify Overcharge details
      expect(find.text('Overcharge detected'), findsOneWidget);
      expect(find.text('Bisleri Mineral Water 1L'), findsOneWidget);
      expect(find.text('Barcode: 8906017290048'), findsOneWidget);

      // Verify Escalation pack buttons
      expect(find.text('Copy Legal Notice (WhatsApp/Email)'), findsOneWidget);
      expect(find.text('Export Official Grievance Docket'), findsOneWidget);

      // Verify Deescalation and Complaint action buttons
      expect(find.text('De-escalation Co-Pilot & Law Card'), findsOneWidget);
      expect(find.text('File a formal complaint'), findsOneWidget);
    });

    testWidgets('renders Packaging Compliance Alert card when compliance violation is present',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final compliance = PackagingComplianceService.analyze('Britannia Good Day\nNOT FOR INDIVIDUAL SALE');

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(
            name: 'Good Day Butter 50g',
            barcode: '8901030001234',
            mrp: 10.00,
            charged: 10.00,
            complianceResult: compliance,
          ),
        ),
      );
      await tester.pump();

      // Verify Packaging Compliance Alert card
      expect(find.text('PACKAGING COMPLIANCE ALERT'), findsOneWidget);
      expect(find.text(compliance.title), findsOneWidget);
      expect(find.textContaining('NOT FOR INDIVIDUAL SALE'), findsWidgets);
      expect(find.text(compliance.legalAdvice), findsOneWidget);

      // Points badge should also be displayed
      expect(find.text('🛡️ +50 ShieldPoints Earned! (Scout Level 1)'), findsWidgets);

      // Escalation buttons are accessible
      expect(find.text('Copy Legal Notice (WhatsApp/Email)'), findsOneWidget);
      expect(find.text('Export Official Grievance Docket'), findsOneWidget);
    });

    testWidgets('renders Dine-in Venue Context warning when venueType is RESTAURANT',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ScanResultScreen(
            name: 'Thums Up 300ml Glass',
            barcode: '8901764012234',
            mrp: 20.00,
            charged: 45.00,
            venueType: 'RESTAURANT',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('DINE-IN VENUE CONTEXT (SC FHRAI 2017)'), findsOneWidget);
      expect(find.textContaining('seated restaurants providing table service'), findsOneWidget);
    });

    testWidgets('renders Stealth Safe-Exit button and opens bottom sheet on tap',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ScanResultScreen(
            name: 'Amul Taaza Milk 500ml',
            barcode: '8901262010054',
            mrp: 27.00,
            charged: 32.00,
          ),
        ),
      );
      await tester.pump();

      // Find and tap Stealth Safe-Exit button
      final stealthBtn = find.text('🛡️ Stealth Safe-Exit ("Lado Mat, Baad Me Ghero")');
      expect(stealthBtn, findsOneWidget);

      await tester.tap(stealthBtn);
      await tester.pumpAndSettle();

      // Verify bottom sheet modal opened
      expect(find.text('Stealth Safe-Exit Mode'), findsOneWidget);
      expect(find.text('“Lado Mat, Baad Me Ghero” • Safety #1'), findsOneWidget);
      expect(find.text('Pay Digitally via UPI & Keep Digital Proof'), findsOneWidget);
      expect(find.text('Leave Calmly Without Argument'), findsOneWidget);
      expect(find.text('File Formal Complaint from Home'), findsOneWidget);
      expect(find.text('Save Evidence & File Complaint from Home'), findsOneWidget);
    });
  });
}
