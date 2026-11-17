import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/services/realtime_complaint_service.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaint_details_screen.dart';
import 'package:priceshield/features/profile/presentation/screens/plans_screen.dart';

void main() {
  group('RealtimeComplaintService & Live Status Synchronization', () {
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

    testWidgets('renders initial complaint and reflects live SSE status updates without page reload',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final initialComplaint = {
        'id': 'cmp_live_1',
        'productName': 'Dairy Fresh Milk 500ml',
        'barcode': '8901030000000',
        'venueType': 'RETAIL',
        'quantity': 1,
        'mrp': 30,
        'chargedPrice': 35,
        'overcharge': 5,
        'totalPaid': 35,
        'paymentMethod': 'UPI',
        'merchantName': 'City Mart',
        'address': 'MG Road, Pune',
        'status': 'PENDING',
        'confidenceLevel': 'BASIC',
        'riskFlags': <String>[],
        'evidence': [],
      };

      final client = mockClientFor(initialComplaint);

      await tester.pumpWidget(
        MaterialApp(
          home: ComplaintDetailsScreen(
            complaintId: 'cmp_live_1',
            apiClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending Review'), findsOneWidget);
      expect(find.text('⚡ Apply Priority Boost Now'), findsOneWidget);

      // Simulate live update from Admin Dashboard via Realtime SSE Hub
      RealtimeComplaintService.instance.notifyComplaintUpdated({
        'type': 'COMPLAINT_UPDATED',
        'complaintId': 'cmp_live_1',
        'status': 'INVESTIGATING',
        'complaint': {
          ...initialComplaint,
          'status': 'INVESTIGATING',
          'riskFlags': ['STAGE_INVESTIGATING'],
        },
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Live Update: Status set to INVESTIGATING'), findsOneWidget);
      expect(find.text('Under Investigation'), findsOneWidget);

      // Simulate second live update to SETTLEMENT_PROPOSED
      RealtimeComplaintService.instance.notifyComplaintUpdated({
        'type': 'COMPLAINT_UPDATED',
        'complaintId': 'cmp_live_1',
        'status': 'SETTLEMENT_PROPOSED',
        'complaint': {
          ...initialComplaint,
          'status': 'SETTLEMENT_PROPOSED',
          'riskFlags': ['STAGE_SETTLEMENT_PROPOSED'],
        },
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Live Update: Status set to SETTLEMENT PROPOSED'), findsOneWidget);
      expect(find.text('Settlement Offered'), findsOneWidget);

      // Simulate live priority boost activation
      RealtimeComplaintService.instance.notifyComplaintUpdated({
        'type': 'COMPLAINT_UPDATED',
        'complaintId': 'cmp_live_1',
        'isBoosted': true,
        'complaint': {
          ...initialComplaint,
          'status': 'SETTLEMENT_PROPOSED',
          'isBoosted': true,
          'riskFlags': ['STAGE_SETTLEMENT_PROPOSED', 'PRIORITY_BOOST_24H'],
        },
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('⚡ PRIORITY BOOST ACTIVE'), findsOneWidget);
    });

    testWidgets('resolves double-defense stage status from riskFlags when status is PENDING',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final stagedComplaint = {
        'id': 'cmp_stage_lm',
        'productName': 'Packaged Snack 200g',
        'barcode': '8901030999999',
        'venueType': 'RETAIL',
        'quantity': 1,
        'mrp': 40,
        'chargedPrice': 50,
        'overcharge': 10,
        'paymentMethod': 'CASH',
        'merchantName': 'Highway Stall',
        'address': 'NH 48',
        'status': 'PENDING',
        'confidenceLevel': 'BASIC',
        'riskFlags': ['STAGE_ESCALATED_LEGAL_METROLOGY', 'PRIORITY_BOOST_24H'],
        'evidence': [],
      };

      final client = mockClientFor(stagedComplaint);

      await tester.pumpWidget(
        MaterialApp(
          home: ComplaintDetailsScreen(
            complaintId: 'cmp_stage_lm',
            apiClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Escalated to LM Dept'), findsOneWidget);
      expect(find.text('⚡ PRIORITY BOOST ACTIVE'), findsOneWidget);
    });
  });

  group('PlansScreen Widget Tests', () {
    testWidgets('renders corporate protection plans header and plan cards cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': {
              'currentPlan': {'id': 'free_shield', 'name': 'Free Shield'},
              'availableBoostCredits': 0,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = PriceShieldApiClient(
        client: mockHttp,
        tokenProvider: () async => 'test-token',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PlansScreen(apiClient: client),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PriceShield Priority'), findsOneWidget);
      expect(find.text('PriceShield Basic'), findsOneWidget);
      expect(find.text('PriceShield Pro'), findsOneWidget);
      expect(find.text('Shield Guardian VIP'), findsOneWidget);
      expect(find.text('₹49'), findsOneWidget);
      expect(find.text('₹149'), findsOneWidget);
    });
  });
}
