import 'package:flutter_test/flutter_test.dart';
import 'package:priceshield/features/deescalation/models/deescalation_data.dart';

void main() {
  group('DeescalationData Model Tests', () {
    test('Default generic dispute has expected values', () {
      const data = DeescalationData.generic;
      expect(data.productName, isNotEmpty);
      expect(data.mrp, 40);
      expect(data.chargedPrice, 50);
      expect(data.hasOvercharge, isTrue);
      expect(data.overchargeAmount, 10);
    });

    test('hasOvercharge returns false when charged price <= mrp', () {
      const dataWithin = DeescalationData(mrp: 50, chargedPrice: 50);
      expect(dataWithin.hasOvercharge, isFalse);
      expect(dataWithin.overchargeAmount, 0);

      const dataDiscount = DeescalationData(mrp: 50, chargedPrice: 45);
      expect(dataDiscount.hasOvercharge, isFalse);
      expect(dataDiscount.overchargeAmount, 0);
    });

    test('displayName returns fallback when productName is null or empty', () {
      const nullData = DeescalationData();
      expect(nullData.displayName, 'Packaged Commodity');

      const emptyData = DeescalationData(productName: '   ');
      expect(emptyData.displayName, 'Packaged Commodity');

      const validData = DeescalationData(productName: 'Cold Drink 750ml');
      expect(validData.displayName, 'Cold Drink 750ml');
    });

    test('copyWith updates fields selectively', () {
      const initial = DeescalationData(
        productName: 'Mineral Water 1L',
        mrp: 20,
        chargedPrice: 25,
      );

      final updated = initial.copyWith(
        chargedPrice: 30,
        shopName: 'Sharma General Store',
      );

      expect(updated.productName, 'Mineral Water 1L');
      expect(updated.mrp, 20);
      expect(updated.chargedPrice, 30);
      expect(updated.overchargeAmount, 10);
      expect(updated.shopName, 'Sharma General Store');
    });

    test('formatCurrency and formatted getters produce clean display strings without float artifacts', () {
      expect(DeescalationData.formatCurrency(40), '40');
      expect(DeescalationData.formatCurrency(40.0), '40');
      expect(DeescalationData.formatCurrency(45.5), '45.50');

      const floatData = DeescalationData(
        mrp: 20.1,
        chargedPrice: 25.0,
      );
      expect(floatData.formattedMrp, '20.10');
      expect(floatData.formattedChargedPrice, '25');
      expect(floatData.formattedOvercharge, '4.90');
    });
  });
}
