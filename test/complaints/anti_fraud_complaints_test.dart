import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:priceshield/core/services/cloudinary_upload_service.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaint_details_screen.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaint_screen.dart';
import 'package:priceshield/features/complaints/services/escalation_pack_service.dart';

void main() {
  group('EscalationPackService anti-fraud gating & watermarks', () {
    test('blocks premature, restaurant, non-overcharged, rejected, and withdrawn exports', () {
      expect(
        EscalationPackService.canExportLegalNotice(
          mrp: 20,
          chargedPrice: 25,
          hasLoggedComplaint: false,
        ),
        isFalse,
      );
      expect(
        EscalationPackService.canExportLegalNotice(
          mrp: 20,
          chargedPrice: 25,
          venueType: 'RESTAURANT',
          complaintStatus: 'PENDING',
          hasLoggedComplaint: true,
        ),
        isFalse,
      );
      expect(
        EscalationPackService.canExportLegalNotice(
          mrp: 20,
          chargedPrice: 20,
          complaintStatus: 'PENDING',
          hasLoggedComplaint: true,
        ),
        isFalse,
      );
      expect(
        EscalationPackService.canExportLegalNotice(
          mrp: 20,
          chargedPrice: 25,
          complaintStatus: 'REJECTED',
          hasLoggedComplaint: true,
        ),
        isFalse,
      );
      expect(
        EscalationPackService.canExportLegalNotice(
          mrp: 20,
          chargedPrice: 25,
          complaintStatus: 'WITHDRAWN',
          hasLoggedComplaint: true,
        ),
        isFalse,
      );

      // UNVERIFIED cannot export clean Official Grievance Docket
      expect(
        EscalationPackService.canExportOfficialDocket(
          mrp: 20,
          chargedPrice: 25,
          complaintStatus: 'PENDING',
          confidenceLevel: 'UNVERIFIED',
          hasLoggedComplaint: true,
        ),
        isFalse,
      );

      // BASIC / STRONG / CORROBORATED can export Official Grievance Docket
      expect(
        EscalationPackService.canExportOfficialDocket(
          mrp: 20,
          chargedPrice: 25,
          complaintStatus: 'PENDING',
          confidenceLevel: 'BASIC',
          hasLoggedComplaint: true,
        ),
        isTrue,
      );
      expect(
        EscalationPackService.canExportOfficialDocket(
          mrp: 20,
          chargedPrice: 25,
          complaintStatus: 'RESOLVED',
          confidenceLevel: 'STRONG',
          hasLoggedComplaint: true,
        ),
        isTrue,
      );
    });

    test('watermarks BASIC/UNVERIFIED dockets and includes structured merchant metadata', () {
      final docket = EscalationPackService.generateOfficialDocket(
        docketId: 'cmp_basic_1',
        productName: 'Bisleri 1L',
        barcode: '8906017290048',
        mrp: 20,
        chargedPrice: 25,
        quantity: 2,
        totalPaid: 50,
        paymentMethod: 'UPI',
        utrNumber: '412345678901',
        merchantName: 'Gupta Cold Point',
        merchantVpa: 'gupta@okaxis',
        storeAddress: 'Main Road, Delhi',
        confidenceLevel: 'BASIC',
        complaintStatus: 'PENDING',
      );

      expect(docket, contains('REPORTED CLAIM — VERIFICATION PENDING'));
      expect(docket, contains('Gupta Cold Point'));
      expect(docket, contains('gupta@okaxis'));
      expect(docket, contains('412345678901'));
      expect(docket, contains('Quantity              : 2'));
      expect(docket, contains('Total Basket Paid     : ₹50.00'));
      expect(docket, contains('Confidence Tier  : BASIC'));

      final verifiedDocket = EscalationPackService.generateOfficialDocket(
        docketId: 'cmp_strong_resolved',
        productName: 'Bisleri 1L',
        barcode: '8906017290048',
        mrp: 20,
        chargedPrice: 25,
        confidenceLevel: 'STRONG',
        complaintStatus: 'RESOLVED',
      );
      expect(verifiedDocket, isNot(contains('REPORTED CLAIM — VERIFICATION PENDING')));
    });
  });

  group('ComplaintScreen confidence prediction & widget behavior', () {
    test('predictConfidenceLevel enforces PACKET_MRP for BASIC and STRONG', () {
      expect(ComplaintScreen.predictConfidenceLevel(const []), 'UNVERIFIED');
      expect(
        ComplaintScreen.predictConfidenceLevel([
          (role: 'PAYMENT_PROOF', isVideo: false),
        ]),
        'UNVERIFIED',
      );
      expect(
        ComplaintScreen.predictConfidenceLevel([
          (role: 'PACKET_MRP', isVideo: false),
          (role: 'PAYMENT_PROOF', isVideo: false),
        ]),
        'BASIC',
      );
      expect(
        ComplaintScreen.predictConfidenceLevel([
          (role: 'PACKET_MRP', isVideo: false),
          (role: 'ITEMIZED_BILL', isVideo: false),
        ]),
        'STRONG',
      );
      expect(
        ComplaintScreen.predictConfidenceLevel([
          (role: 'PACKET_MRP', isVideo: false),
          (role: 'VIDEO_PROOF', isVideo: true),
        ]),
        'STRONG',
      );
    });

    testWidgets('blocks RESTAURANT dine-in complaint submission', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ComplaintScreen(
            name: 'Cold Drink 300ml',
            barcode: '8901764012234',
            mrp: 20,
            charged: 50,
            venueType: 'RESTAURANT',
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Dine-In Restaurant Venue (SC FHRAI 2017)'), findsOneWidget);
      expect(find.text('Not Applicable for Dine-In'), findsOneWidget);
    });

    testWidgets('renders structured fields, quantity stepper, and live confidence badge',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ComplaintScreen(
            name: 'Amul Butter 100g',
            barcode: '8901262010054',
            mrp: 58,
            charged: 65,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tier: UNVERIFIED'), findsOneWidget);
      expect(find.text('Packet MRP'), findsOneWidget);
      expect(find.text('Payment Proof'), findsOneWidget);
      expect(find.text('Itemized Bill'), findsOneWidget);
      expect(find.text('Purchase Video'), findsOneWidget);

      // Increment quantity from 1 -> 2 and verify excess updates (7 * 2 = 14)
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(find.text('Excess paid: ₹14.00'), findsOneWidget);
    });
  });

  group('ComplaintDetailsScreen gating & watermark rendering', () {
    PriceShieldApiClient mockClientFor(Map<String, dynamic> complaintData) {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({'data': complaintData}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      return PriceShieldApiClient(
        client: mockHttp,
        tokenProvider: () async => 'test-token',
      );
    }

    testWidgets('locks Official Grievance Docket on UNVERIFIED complaint and shows watermark',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final client = mockClientFor({
        'id': 'cmp_unv',
        'productName': 'Chips 30g',
        'barcode': '8901491103046',
        'venueType': 'RETAIL',
        'quantity': 1,
        'mrp': 10,
        'chargedPrice': 15,
        'totalPaid': 15,
        'overcharge': 5,
        'paymentMethod': 'CASH',
        'merchantName': 'Corner Stall',
        'address': 'Station Road',
        'status': 'PENDING',
        'confidenceLevel': 'UNVERIFIED',
        'evidence': [],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ComplaintDetailsScreen(
            complaintId: 'cmp_unv',
            apiClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UNVERIFIED'), findsOneWidget);
      expect(find.textContaining('Reported claim — verification pending'), findsOneWidget);
      expect(
        find.textContaining('Official Grievance Docket locked: This is a private UNVERIFIED record'),
        findsOneWidget,
      );
      expect(find.text('Export Official Grievance Docket'), findsNothing);
    });

    testWidgets('displays watermark and unlocks docket on BASIC complaint with structured metadata',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final client = mockClientFor({
        'id': 'cmp_basic',
        'productName': 'Water Bottle 1L',
        'barcode': '8906017290048',
        'venueType': 'RETAIL',
        'quantity': 2,
        'mrp': 20,
        'chargedPrice': 25,
        'totalPaid': 50,
        'overcharge': 5,
        'paymentMethod': 'UPI',
        'utrNumber': '412345678901',
        'merchantName': 'Metro Kiosk',
        'merchantVpa': 'metro@okaxis',
        'address': 'Platform 1, Central',
        'status': 'PENDING',
        'confidenceLevel': 'BASIC',
        'evidence': [
          {
            'url': 'https://res.cloudinary.com/mpz1wxhc/image/upload/v1/p.jpg',
            'mediaType': 'IMAGE',
            'role': 'PACKET_MRP',
          },
          {
            'url': 'https://res.cloudinary.com/mpz1wxhc/image/upload/v1/u.jpg',
            'mediaType': 'IMAGE',
            'role': 'PAYMENT_PROOF',
          },
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ComplaintDetailsScreen(
            complaintId: 'cmp_basic',
            apiClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BASIC'), findsOneWidget);
      expect(find.text('Reported claim — verification pending'), findsOneWidget);
      expect(find.text('Metro Kiosk'), findsOneWidget);
      expect(find.text('metro@okaxis'), findsOneWidget);
      expect(find.text('412345678901'), findsOneWidget);
      expect(find.text('Export Official Grievance Docket'), findsOneWidget);
    });

    testWidgets('blocks Legal Notice & Official Grievance Docket on REJECTED complaint',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final client = mockClientFor({
        'id': 'cmp_rej',
        'productName': 'Water Bottle 1L',
        'barcode': '8906017290048',
        'venueType': 'RETAIL',
        'quantity': 1,
        'mrp': 20,
        'chargedPrice': 25,
        'overcharge': 5,
        'paymentMethod': 'UPI',
        'merchantName': 'Metro Kiosk',
        'address': 'Platform 1',
        'status': 'REJECTED',
        'confidenceLevel': 'BASIC',
        'moderationNotes': 'Blurry MRP',
        'merchantResponse': 'Verified invoice attached',
        'evidence': [],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ComplaintDetailsScreen(
            complaintId: 'cmp_rej',
            apiClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Copy Legal Notice (WhatsApp/Email)'), findsNothing);
      expect(find.text('Export Official Grievance Docket'), findsNothing);
      expect(
        find.textContaining('Legal Notice and Official Grievance Docket export are unavailable'),
        findsOneWidget,
      );
      expect(find.text('Blurry MRP'), findsOneWidget);
      expect(find.text('Verified invoice attached'), findsOneWidget);
      expect(
        find.textContaining('Store-level risk signal'),
        findsNothing,
      );
    });

    testWidgets('hides Store-level risk signal banner on REJECTED CORROBORATED complaint',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final client = mockClientFor({
        'id': 'cmp_rej_corr',
        'productName': 'Water Bottle 1L',
        'barcode': '8906017290048',
        'venueType': 'RETAIL',
        'quantity': 1,
        'mrp': 20,
        'chargedPrice': 25,
        'overcharge': 5,
        'paymentMethod': 'UPI',
        'merchantName': 'Metro Kiosk',
        'address': 'Platform 1',
        'status': 'REJECTED',
        'confidenceLevel': 'CORROBORATED',
        'evidence': [],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ComplaintDetailsScreen(
            complaintId: 'cmp_rej_corr',
            apiClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Store-level risk signal'), findsNothing);
    });
  });

  group('API Client & SHA-256 upload hashing', () {
    test('createComplaint sends all structured anti-fraud fields', () async {
      Map<String, dynamic>? sentBody;
      final mockHttp = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'data': {'id': 'cmp_1', ...sentBody!}}),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = PriceShieldApiClient(
        client: mockHttp,
        tokenProvider: () async => 'token',
      );
      await client.createComplaint(
        barcode: '8901764012241',
        productName: 'Coke 750ml',
        mrp: 40,
        chargedPrice: 50,
        address: 'Shop 4, Market',
        venueType: 'RETAIL',
        quantity: 2,
        totalPaid: 100,
        paymentMethod: 'UPI',
        utrNumber: '412345678901',
        merchantName: 'Ravi Store',
        merchantVpa: 'ravi@okicici',
        evidence: [
          {
            'url': 'https://res.cloudinary.com/mpz1wxhc/image/upload/v1/a.jpg',
            'mediaType': 'IMAGE',
            'role': 'PACKET_MRP',
            'sha256Hash': 'a' * 64,
          },
        ],
      );

      expect(sentBody, isNotNull);
      expect(sentBody!['venueType'], 'RETAIL');
      expect(sentBody!['quantity'], 2);
      expect(sentBody!['totalPaid'], 100);
      expect(sentBody!['paymentMethod'], 'UPI');
      expect(sentBody!['utrNumber'], '412345678901');
      expect(sentBody!['merchantName'], 'Ravi Store');
      expect(sentBody!['merchantVpa'], 'ravi@okicici');
      expect((sentBody!['evidence'] as List).first['role'], 'PACKET_MRP');
      expect((sentBody!['evidence'] as List).first['sha256Hash'], 'a' * 64);
    });

    test('computeSha256 computes deterministic lowercase hex digest', () async {
      final tempDir = await Directory.systemTemp.createTemp('ps_sha_test');
      try {
        final file = File('${tempDir.path}/sample.bin');
        await file.writeAsBytes(utf8.encode('priceshield-proof'));
        final digest = await CloudinaryUploadService.computeSha256(file);
        expect(digest, hasLength(64));
        expect(digest, matches(RegExp(r'^[a-f0-9]{64}$')));
        // Calling twice returns identical hash
        expect(await CloudinaryUploadService.computeSha256(file), digest);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
