import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/features/home/presentation/screens/home_screen.dart';

void main() {
  group('HomeScreen Guest Mode & Offline Graceful Degradation Tests', () {
    testWidgets('renders home screen cleanly in Guest Mode without any dashboard error', (tester) async {
      await AuthSession.clear();

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      // Settle the async FutureBuilder
      await tester.pumpAndSettle();

      // Verify that the error banner is NEVER shown
      expect(find.text('We could not load your dashboard.'), findsNothing);

      // Verify Guest Greeting
      expect(find.text('Hello, Scout'), findsOneWidget);
      expect(find.text('Shield Scout Guest Mode. Scan any product to verify MRP.'), findsOneWidget);

      // Verify Hero Check a product card
      expect(find.text('Check a product'), findsOneWidget);
      expect(find.text('Start scanning'), findsOneWidget);

      // Verify Quick Summary
      expect(find.text('Scans'), findsOneWidget);
      expect(find.text('Complaints'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);

      // Verify Co-Pilot card
      expect(find.text('Cooling Charge Dispute?'), findsOneWidget);

      // Verify Empty Scans section
      expect(find.text('No scans yet'), findsOneWidget);
      expect(find.text('Scan a product to start protecting your purchases.'), findsOneWidget);

      // Verify Consumer Rights card
      expect(find.text('Know your rights'), findsOneWidget);
    });

    testWidgets('renders home screen cleanly in Normal Login (Authenticated Mode) with user name and avatar', (tester) async {
      await AuthSession.save(
        token: 'test-valid-jwt-token',
        user: {
          'id': 'usr_test_123',
          'displayName': 'Manish Sharma',
          'email': 'manish@priceshield.org',
        },
      );

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() async {
        await AuthSession.clear();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      // Settle the async FutureBuilder
      await tester.pumpAndSettle();

      // Verify that the error banner is NEVER shown
      expect(find.text('We could not load your dashboard.'), findsNothing);

      // Verify Personalized Authenticated Greeting
      expect(find.text('Hello, Manish'), findsOneWidget);
      expect(find.text('Stay informed. Pay the right price.'), findsOneWidget);

      // Verify User Avatar Initials 'M'
      expect(find.text('M'), findsOneWidget);

      // Verify Action Cards & Navigation
      expect(find.text('Check a product'), findsOneWidget);
      expect(find.text('Cooling Charge Dispute?'), findsOneWidget);
      expect(find.text('Know your rights'), findsOneWidget);
    });
  });
}
