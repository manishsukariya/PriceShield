import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/features/profile/presentation/screens/profile_screen.dart';

void main() {
  group('ProfileScreen Guest Mode Widget Tests', () {
    testWidgets('renders guest mode UI when no user is signed in', (tester) async {
      await AuthSession.clear();

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pump();

      // Guest banner elements
      expect(find.text('Shield Scout (Guest Mode)'), findsOneWidget);
      expect(find.text('You can scan, verify MRP, and play law cards freely.'), findsOneWidget);

      // Sign In or Register CTA
      expect(find.text('Unlock Shield Scout Rewards'), findsOneWidget);
      expect(find.text('Sign In or Register'), findsOneWidget);

      // Guest Mode Feature Access checklist
      expect(find.text('Guest Mode Feature Access'), findsOneWidget);
      expect(find.text('Instant Barcode & OCR Scan (Unlimited)'), findsOneWidget);
      expect(find.text('De-escalation Law Cards & Audio Co-Pilot'), findsOneWidget);
      expect(find.text('Stealth Safe-Exit & Legal Notice Generator'), findsOneWidget);
      expect(find.text('Formal Complaint Tracking & Status Sync (Login required)'), findsOneWidget);

      // Legal & Helpline shortcuts
      expect(find.text('Consumer Rights & Laws'), findsOneWidget);
      expect(find.text('National Consumer Helpline'), findsOneWidget);
    });
  });
}
