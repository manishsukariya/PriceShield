import 'package:flutter_test/flutter_test.dart';
import 'package:priceshield/features/deescalation/models/deescalation_data.dart';
import 'package:priceshield/features/deescalation/services/helpline_service.dart';

void main() {
  group('HelplineService Tests', () {
    test('WhatsApp number and toll-free numbers are accurate', () {
      expect(HelplineService.whatsappNumber, '918800001915');
      expect(HelplineService.whatsappDisplayNumber, '+91 8800001915');
      expect(HelplineService.tollFreeNumber, '1915');
    });

    test('buildComplaintMessage contains statutory citations and product info', () {
      const data = DeescalationData(
        productName: 'Amul Taaza Milk 500ml',
        barcode: '8901262010053',
        mrp: 27,
        chargedPrice: 30,
        shopName: 'Gupta Dairy',
        location: 'Sector 14, Gurugram',
      );

      final message = HelplineService.buildComplaintMessage(data);

      // Verify Rule 18(2) citation
      expect(message, contains('Rule 18(2), Legal Metrology (Packaged Commodities) Rules, 2011'));
      expect(message, contains('refrigeration expenses'));

      // Verify Jan Vishwas Act citation
      expect(message, contains('Jan Vishwas (Amendment of Provisions) Act, 2023'));
      expect(message, contains('₹5,00,000'));

      // Verify Dispute Data
      expect(message, contains('Amul Taaza Milk 500ml'));
      expect(message, contains('8901262010053'));
      expect(message, contains('Printed MRP: ₹27'));
      expect(message, contains('Demanded Price: ₹30'));
      expect(message, contains('Excess Surcharge: ₹3 (Reported above MRP)'));
      expect(message, contains('Gupta Dairy'));
      expect(message, contains('Sector 14, Gurugram'));
    });

    test('buildComplaintMessage handles missing optional fields gracefully', () {
      const data = DeescalationData(
        mrp: 40,
        chargedPrice: 40,
      );

      final message = HelplineService.buildComplaintMessage(data);
      expect(message, contains('Packaged Commodity'));
      expect(message, isNot(contains('Excess Surcharge:')));
      expect(message, isNot(contains('Barcode:')));
      expect(message, isNot(contains('Shop / Vendor:')));
    });
  });
}
