import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:priceshield/features/scanner/models/terrain_context.dart';
import 'package:priceshield/features/scanner/presentation/screens/scan_result_screen.dart';

void main() {
  group('Mountain & Terrain Intelligence Widget Tests', () {
    testWidgets('renders Cooked Dhaba Food (MRP Exempt) card correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ScanResultScreen(
            name: 'Pahadi Maggi (Hot Cooked)',
            barcode: '8901058852345',
            mrp: 30.00,
            charged: 70.00,
            itemFormType: ItemFormType.cookedDhaba,
            terrainType: TerrainType.remoteTrek,
          ),
        ),
      );
      await tester.pump();

      // Verify Cooked Food Card
      expect(find.text('Cooked Dhaba Food (MRP Exempt)'), findsOneWidget);
      expect(find.textContaining('Under SC FHRAI 2017: Service meal is exempt'), findsOneWidget);
      expect(find.text('DHABA / COOKED FOOD REGULATION'), findsOneWidget);
      expect(find.text('Formal MRP Docket Not Applicable (Cooked Meal)'), findsOneWidget);
      expect(find.text('File a formal complaint'), findsNothing);
    });

    testWidgets('renders Fair Mountain Porterage when within DM porterage allowance', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ScanResultScreen(
            name: 'Kinley Water 1L Packaged',
            barcode: '8901764012234',
            mrp: 20.00,
            charged: 25.00,
            itemFormType: ItemFormType.sealedPack,
            terrainType: TerrainType.remoteTrek,
          ),
        ),
      );
      await tester.pump();

      // Verify Fair Porterage display
      expect(find.text('Fair Mountain Porterage'), findsOneWidget);
      expect(find.textContaining('within DM / Shrine Board porterage guidelines'), findsOneWidget);
      expect(find.text('REMOTE TREK & MULE PORTERAGE CONTEXT'), findsOneWidget);
      expect(find.text('No Legal Violation (Fair Porterage Allowance)'), findsOneWidget);
      expect(find.text('File a formal complaint'), findsNothing);
      expect(find.textContaining('Fair Mountain Porterage: This markup is within District Magistrate approved porterage allowances'), findsOneWidget);
    });

    testWidgets('renders Predatory Mountain Price Gouging alert and Mountain Safe-Exit button', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ScanResultScreen(
            name: 'Bisleri Mineral Water 1L',
            barcode: '8906017290048',
            mrp: 20.00,
            charged: 80.00,
            itemFormType: ItemFormType.sealedPack,
            terrainType: TerrainType.remoteTrek,
          ),
        ),
      );
      await tester.pump();

      // Verify Predatory Price Gouging Card
      expect(find.text('Predatory Mountain Price Gouging'), findsOneWidget);
      expect(find.textContaining('Extortionate demand: ₹80 on ₹20 pack (+₹60)'), findsOneWidget);
      expect(find.text('REMOTE TREK & MULE PORTERAGE CONTEXT'), findsOneWidget);

      // Verify Mountain Safe-Exit Button
      final mountainBtn = find.text('🏔️ Mountain Safe-Exit ("Pehle Suraksha, Baad Me Ghero")');
      expect(mountainBtn, findsOneWidget);

      // Tap Mountain Safe-Exit button to open sheet
      await tester.tap(mountainBtn);
      await tester.pumpAndSettle();

      // Verify Mountain Safe-Exit BottomSheet items
      expect(find.text('Mountain Safe-Exit Mode'), findsOneWidget);
      expect(find.textContaining('“Pehle Suraksha, Baad Me Ghero” • Life & Safety First'), findsOneWidget);
      expect(find.text('Prioritize Physical Survival & Stay Calm'), findsOneWidget);
      expect(find.text('Note Tent/Stall ID or UPI QR Code'), findsOneWidget);
      expect(find.text('Queue Offline on Local Device Storage'), findsOneWidget);
      expect(find.text('File at Base Camp / Roadhead'), findsOneWidget);
      expect(find.text('Save Offline & File from Base Camp'), findsOneWidget);
      expect(find.text('Close / I Am Safe on the Trail'), findsOneWidget);
    });

    testWidgets('renders Illegal Hill Station Surcharge on motorable hill station (Shimla/Manali)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ScanResultScreen(
            name: 'Coca Cola 750ml PET',
            barcode: '8901764032112',
            mrp: 40.00,
            charged: 55.00,
            itemFormType: ItemFormType.sealedPack,
            terrainType: TerrainType.motorableHill,
          ),
        ),
      );
      await tester.pump();

      // Verify Motorable Hill Surcharge
      expect(find.text('Illegal Hill Station Surcharge'), findsOneWidget);
      expect(find.textContaining('Road-connected hill station • Transport surcharge illegal'), findsOneWidget);
      expect(find.text('MOTORABLE HILL STATION LOGISTICS'), findsOneWidget);
      expect(find.text('File a formal complaint'), findsOneWidget);
      expect(find.text('🛡️ Stealth Safe-Exit ("Lado Mat, Baad Me Ghero")'), findsOneWidget);
    });
  });
}
