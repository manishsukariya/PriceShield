import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:priceshield/features/deescalation/models/deescalation_data.dart';
import 'package:priceshield/features/deescalation/presentation/screens/fullscreen_showcard_screen.dart';
import 'package:priceshield/features/deescalation/presentation/widgets/helpline_card.dart';
import 'package:priceshield/features/deescalation/presentation/widgets/showcard_view.dart';

void main() {
  group('De-escalation Widgets Tests', () {
    testWidgets('ShowcardView displays statutory rule 18(2) and Jan Vishwas Act', (tester) async {
      const testData = DeescalationData(
        productName: 'Sprite 750ml',
        mrp: 40,
        chargedPrice: 50,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShowcardView(
                data: testData,
                selectedLanguage: ShowcardLanguage.bilingual,
              ),
            ),
          ),
        ),
      );

      // Verify Authority Header
      expect(find.textContaining('CONSUMER RIGHTS LAW CARD'), findsOneWidget);

      // Verify Product and Price breakdown
      expect(find.text('Sprite 750ml'), findsOneWidget);
      expect(find.text('₹40'), findsOneWidget);
      expect(find.text('₹50'), findsOneWidget);
      expect(find.text('+₹10'), findsOneWidget);

      // Verify Rule 18(2) Section
      expect(find.textContaining('RULE 18(2)'), findsOneWidget);
      expect(find.textContaining('Legal Metrology (Packaged Commodities) Rules, 2011'), findsOneWidget);
      expect(find.textContaining('फ्रिज/कूलिंग'), findsOneWidget);
      expect(find.textContaining('refrigeration / chilling expenses'), findsOneWidget);

      // Verify Jan Vishwas Act Section
      expect(find.textContaining('JAN VISHWAS ACT, 2023'), findsOneWidget);
      expect(find.textContaining('5,00,000'), findsWidgets);
    });

    testWidgets('ShowcardView respects language filter (Hindi only vs English only)', (tester) async {
      const testData = DeescalationData(
        productName: 'Cold Drink',
        mrp: 30,
        chargedPrice: 35,
      );

      // Hindi Only
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShowcardView(
                data: testData,
                selectedLanguage: ShowcardLanguage.hindi,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('पैकेज्ड वस्तुओं पर छपे अधिकतम खुदरा मूल्य'), findsOneWidget);
      expect(find.textContaining('No retail dealer shall sell any commodity'), findsNothing);

      // English Only
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShowcardView(
                data: testData,
                selectedLanguage: ShowcardLanguage.english,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('No retail dealer shall sell any commodity'), findsOneWidget);
      expect(find.textContaining('पैकेज्ड वस्तुओं पर छपे अधिकतम खुदरा मूल्य'), findsNothing);
    });

    testWidgets('HelplineCard renders WhatsApp assistant and helpline actions', (tester) async {
      const testData = DeescalationData(
        productName: 'Milk Pack 500ml',
        mrp: 30,
        chargedPrice: 35,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HelplineCard(data: testData),
          ),
        ),
      );

      expect(find.text('1-Tap WhatsApp Helpline'), findsOneWidget);
      expect(find.textContaining('+91 8800001915'), findsWidgets);
      expect(find.text('Open WhatsApp Complaint (+91 8800001915)'), findsOneWidget);
      expect(find.text('Copy Report'), findsOneWidget);
      expect(find.text('Call 1915'), findsOneWidget);
    });

    testWidgets('FullscreenShowcardScreen renders in full-screen mode', (tester) async {
      const testData = DeescalationData(
        productName: 'Ice Cream Cup',
        mrp: 25,
        chargedPrice: 30,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FullscreenShowcardScreen(
            data: testData,
            initialLanguage: ShowcardLanguage.bilingual,
          ),
        ),
      );

      expect(find.text('Show to Vendor (दुकानदार को दिखाएं)'), findsOneWidget);
      expect(find.textContaining('Hold screen towards shopkeeper'), findsOneWidget);
      expect(find.text('Ice Cream Cup'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('Dual / दोनों भाषाएं'), findsOneWidget);
      expect(find.textContaining('Play Statutory Voice-Out'), findsOneWidget);

      // Tap English chip
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Play Audio Law (English)'), findsOneWidget);
    });
  });
}
