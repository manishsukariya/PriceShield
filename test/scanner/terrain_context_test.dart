import 'package:flutter_test/flutter_test.dart';
import 'package:priceshield/features/scanner/models/terrain_context.dart';

void main() {
  group('TerrainEvaluation Unit Tests', () {
    test('Within printed MRP is always non-violation regardless of terrain', () {
      final eval = TerrainEvaluation.evaluate(
        mrp: 20,
        charged: 20,
        terrain: TerrainType.plains,
        itemForm: ItemFormType.sealedPack,
      );

      expect(eval.verdictType, equals(TerrainVerdictType.withinMrp));
      expect(eval.isViolation, isFalse);
      expect(eval.title, contains('within printed MRP'));
      expect(eval.difference, equals(0));
    });

    test('Cooked food / Dhaba meal is legally exempt from MRP under SC FHRAI 2017', () {
      final eval = TerrainEvaluation.evaluate(
        mrp: 40,
        charged: 80,
        terrain: TerrainType.remoteTrek,
        itemForm: ItemFormType.cookedDhaba,
      );

      expect(eval.verdictType, equals(TerrainVerdictType.cookedExempt));
      expect(eval.isViolation, isFalse);
      expect(eval.isExempt, isTrue);
      expect(eval.title, contains('Cooked Food Service (MRP Exempt)'));
      expect(eval.subtitle, contains('FHRAI 2017'));
      expect(eval.explanation, contains('hot Maggi'));
    });

    test('Plains standard retail overcharge is flagged under Rule 18(2)', () {
      final eval = TerrainEvaluation.evaluate(
        mrp: 20,
        charged: 25,
        terrain: TerrainType.plains,
        itemForm: ItemFormType.sealedPack,
      );

      expect(eval.verdictType, equals(TerrainVerdictType.illegalPlainsOvercharge));
      expect(eval.isViolation, isTrue);
      expect(eval.title, equals('Overcharge detected'));
      expect(eval.difference, equals(5));
      expect(eval.legalAdvice, contains('Rule 18(2)'));
    });

    test('Motorable hill stations (Shimla, Manali) cannot add freight surcharge', () {
      final eval = TerrainEvaluation.evaluate(
        mrp: 20,
        charged: 28,
        terrain: TerrainType.motorableHill,
        itemForm: ItemFormType.sealedPack,
      );

      expect(eval.verdictType, equals(TerrainVerdictType.illegalHillSurcharge));
      expect(eval.isViolation, isTrue);
      expect(eval.title, contains('Illegal Hill Station Surcharge'));
      expect(eval.subtitle, contains('Motorable road access exists'));
      expect(eval.explanation, contains('Shimla, Manali'));
    });

    test('Remote trek fair porterage allowance (<= ₹10 or <= 25%) is approved by DM', () {
      final eval = TerrainEvaluation.evaluate(
        mrp: 20,
        charged: 25, // ₹5 extra on ₹20 = 25% (within porterage threshold)
        terrain: TerrainType.remoteTrek,
        itemForm: ItemFormType.sealedPack,
      );

      expect(eval.verdictType, equals(TerrainVerdictType.fairPorterageAllowance));
      expect(eval.isViolation, isFalse);
      expect(eval.isFairAllowance, isTrue);
      expect(eval.title, contains('Fair Porterage Allowance'));
      expect(eval.legalAdvice, contains('अनुमोदित दर सूची'));
      expect(eval.explanation, contains('mules or porters'));
    });

    test('Remote trek extortionate price gouging is flagged as alert', () {
      final eval = TerrainEvaluation.evaluate(
        mrp: 20,
        charged: 70, // ₹50 extra on ₹20 (grossly exceeds porterage rate)
        terrain: TerrainType.remoteTrek,
        itemForm: ItemFormType.sealedPack,
      );

      expect(eval.verdictType, equals(TerrainVerdictType.extortionPriceGouging));
      expect(eval.isViolation, isTrue);
      expect(eval.title, contains('Predatory Mountain Price Gouging Alert'));
      expect(eval.explanation, contains('black marketing'));
      expect(eval.legalAdvice, contains('do not confront stall owners'));
    });
  });
}
