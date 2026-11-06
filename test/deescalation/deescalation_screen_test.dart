import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:priceshield/features/deescalation/models/deescalation_data.dart';
import 'package:priceshield/features/deescalation/presentation/screens/deescalation_screen.dart';

void main() {
  group('DeescalationScreen Full Screen Integration Tests', () {
    testWidgets('DeescalationScreen renders all 3 key features and opens customize sheet', (tester) async {
      const data = DeescalationData(
        productName: 'Coca-Cola 750ml',
        barcode: '8901764012271',
        mrp: 40,
        chargedPrice: 45,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: DeescalationScreen(initialData: data),
        ),
      );

      // Verify Screen Title
      expect(find.text('De-escalation Co-Pilot'), findsOneWidget);

      // Verify Feature 1: Authoritative Law Card & Rule 18(2) & Jan Vishwas Act
      expect(find.text('Authoritative Law Card'), findsOneWidget);
      expect(find.textContaining('RULE 18(2)'), findsOneWidget);
      expect(find.textContaining('JAN VISHWAS ACT, 2023'), findsOneWidget);
      expect(find.text('Coca-Cola 750ml'), findsOneWidget);
      expect(find.text('+₹5'), findsOneWidget);

      // Verify Feature 2: 15s Audio Voice-Out
      expect(find.text('15s Audio Voice-Out'), findsOneWidget);
      expect(find.text('Play Hindi Voice-Out (दुकानदार को सुनाएं)'), findsOneWidget);

      // Verify Feature 3: 1-Tap WhatsApp Consumer Helpline
      expect(find.text('1-Tap WhatsApp Helpline'), findsOneWidget);
      expect(find.textContaining('+91 8800001915'), findsWidgets);

      // Test opening customize sheet
      final customizeButton = find.byTooltip('Customize dispute figures');
      expect(customizeButton, findsOneWidget);
      await tester.tap(customizeButton);
      await tester.pumpAndSettle();

      expect(find.text('Dispute Figures'), findsOneWidget);
      expect(find.text('Update Showcard & Dispute Report'), findsOneWidget);

      // Close customize sheet
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Dispute Figures'), findsNothing);
    });

    testWidgets('Showcard language switcher toggles Dual, Hindi, Eng tabs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeescalationScreen(),
        ),
      );

      expect(find.text('Dual'), findsOneWidget);
      expect(find.text('हिंदी'), findsWidgets);
      expect(find.text('Eng'), findsOneWidget);

      // Tap 'Eng' tab
      await tester.tap(find.text('Eng'));
      await tester.pumpAndSettle();

      // Verify English law text is present
      expect(find.textContaining('No retail dealer shall sell any commodity'), findsOneWidget);
    });

    testWidgets('DeescalationScreen receives dispute data via Navigator route arguments', (tester) async {
      const customData = DeescalationData(
        productName: 'Cold Coffee 200ml',
        mrp: 35,
        chargedPrice: 40,
      );

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (context) => Builder(
                  builder: (ctx) => TextButton(
                    onPressed: () => Navigator.pushNamed(
                      ctx,
                      '/deescalation',
                      arguments: customData,
                    ),
                    child: const Text('Go'),
                  ),
                ),
            '/deescalation': (context) => const DeescalationScreen(),
          },
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.text('Cold Coffee 200ml'), findsOneWidget);
      expect(find.text('₹35'), findsOneWidget);
      expect(find.text('₹40'), findsOneWidget);
      expect(find.text('+₹5'), findsOneWidget);
    });
  });
}
