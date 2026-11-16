import 'package:flutter/foundation.dart';

/// Intelligent Legal Metrology pack-size to printed MRP heuristics for Indian FMCG staples.
/// Ensures that when an iconic consumer product is identified (e.g. Appy Fizz, Frooti,
/// Sting, Bisleri, Maggi, Parle-G), its exact nationally standard printed MRP is resolved
/// even if external global catalogs (Open Food Facts) omitted price fields.
class IndianFmcgMrpHeuristics {
  const IndianFmcgMrpHeuristics._();

  static ({double value, String kind})? _parseQuantity(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*(kg|g|gm|gms|l|ltr|litre|litres|ml)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final amount = double.tryParse(match.group(1)!);
    if (amount == null || !amount.isFinite || amount <= 0) return null;
    final unit = match.group(2)!.toLowerCase();
    if (unit == 'kg' || unit == 'l' || unit == 'ltr' || unit.startsWith('litre')) {
      return (value: amount * 1000, kind: unit == 'kg' ? 'mass' : 'volume');
    }
    return (value: amount, kind: unit == 'ml' ? 'volume' : 'mass');
  }

  /// Infers standard Legal Metrology printed reference MRP from brand, title, and volume/weight.
  static double? inferMrp({
    required String productName,
    String? brand,
    String? quantityText,
    String? barcode,
  }) {
    final combined = '${productName.toLowerCase()} ${brand?.toLowerCase() ?? ''} ${quantityText?.toLowerCase() ?? ''}';
    final qty = _parseQuantity(quantityText) ?? _parseQuantity(productName);
    final cleanBarcode = barcode?.trim() ?? '';

    // 1. Appy & Appy Fizz (Parle Agro)
    if (combined.contains('appy fizz') || combined.contains('appy')) {
      if (qty != null && qty.kind == 'volume') {
        final ml = qty.value;
        if (ml >= 120 && ml <= 175) return 10.00;
        if (ml > 175 && ml <= 300) return 20.00;
        if (ml > 300 && ml <= 650) return 40.00;
        if (ml > 650 && ml <= 1300) return 60.00;
        if (ml > 1300 && ml <= 2200) return 100.00;
      }
      if (cleanBarcode.startsWith('89025790039') ||
          cleanBarcode.startsWith('89025790024') ||
          cleanBarcode.startsWith('890171920201')) {
        return 10.00;
      }
    }

    // 2. Frooti (Parle Agro)
    if (combined.contains('frooti')) {
      if (qty != null && qty.kind == 'volume') {
        final ml = qty.value;
        if (ml >= 120 && ml <= 170) return 10.00;
        if (ml > 170 && ml <= 220) return 15.00;
        if (ml > 220 && ml <= 300) return 20.00;
        if (ml > 300 && ml <= 650) return 38.00;
        if (ml > 650 && ml <= 1300) return 70.00;
        if (ml > 1300 && ml <= 2200) return 110.00;
      }
    }

    // 3. Sting Energy Drink (PepsiCo)
    if (combined.contains('sting')) {
      if (qty != null && qty.kind == 'volume') {
        final ml = qty.value;
        if (ml >= 200 && ml <= 300) {
          return combined.contains('can') ? 35.00 : 20.00;
        }
      }
      return 20.00;
    }

    // 4. Packaged Drinking Water (Bisleri, Kinley, Aquafina, Bailley, Rail Neer)
    if (combined.contains('rail neer') || combined.contains('railneer')) {
      if (qty != null && qty.kind == 'volume') {
        return qty.value >= 750 ? 15.00 : 10.00;
      }
      return 15.00;
    }
    if (combined.contains('bisleri') ||
        combined.contains('kinley') ||
        combined.contains('aquafina') ||
        combined.contains('bailley')) {
      if (qty != null && qty.kind == 'volume') {
        final ml = qty.value;
        if (ml <= 550) return 10.00;
        if (ml > 550 && ml <= 1200) return 20.00;
        if (ml > 1200 && ml <= 2200) return 30.00;
        if (ml > 4000 && ml <= 6000) return 70.00;
      }
    }

    // 5. Major Carbonated Drinks (Coca-Cola, Thums Up, Sprite, Fanta, Limca, Pepsi, Mountain Dew, 7UP, Mirinda)
    final isMajorCola = combined.contains('coca-cola') ||
        combined.contains('coca cola') ||
        combined.contains('thums up') ||
        combined.contains('sprite') ||
        combined.contains('fanta') ||
        combined.contains('limca') ||
        combined.contains('pepsi') ||
        combined.contains('mountain dew') ||
        combined.contains('7up') ||
        combined.contains('mirinda');

    if (isMajorCola && qty != null && qty.kind == 'volume') {
      final ml = qty.value;
      if (ml >= 200 && ml <= 260) {
        return combined.contains('can') ? 35.00 : 20.00;
      }
      if (ml > 260 && ml <= 350) return 40.00;
      if (ml > 500 && ml <= 780) return 40.00;
      if (ml > 1100 && ml <= 1600) return 65.00;
      if (ml > 1900 && ml <= 2400) return 95.00;
    }

    // 6. Maggi 2-Minute Noodles / YiPPee!
    if (combined.contains('maggi') || combined.contains('yippee')) {
      if (qty != null && qty.kind == 'mass') {
        final g = qty.value;
        if (g >= 55 && g <= 80) return 14.00;
        if (g > 80 && g <= 160) return 28.00;
        if (g > 160 && g <= 320) return 56.00;
      }
    }

    // 7. Parle-G Biscuits
    if (combined.contains('parle-g') || combined.contains('parle g')) {
      if (qty != null && qty.kind == 'mass') {
        final g = qty.value;
        if (g >= 40 && g <= 70) return 5.00;
        if (g > 70 && g <= 150) return 10.00;
        if (g > 150 && g <= 300) return 25.00;
        if (g > 700 && g <= 900) return 80.00;
      }
    }

    // 8. Amul Milk Pouches (Taaza / Gold / Cow Milk)
    if (combined.contains('amul') &&
        (combined.contains('milk') || combined.contains('doodh'))) {
      if (qty != null && qty.kind == 'volume') {
        final ml = qty.value;
        final isGold = combined.contains('gold');
        if (ml >= 450 && ml <= 550) return isGold ? 33.00 : 27.00;
        if (ml >= 950 && ml <= 1100) return isGold ? 66.00 : 54.00;
      }
    }

    // 9. Potato Chips & Namkeen (Lay's, Kurkure, Bingo, Balaji)
    final isCrisps = combined.contains("lay's") ||
        combined.contains('lays') ||
        combined.contains('kurkure') ||
        combined.contains('bingo') ||
        combined.contains('balaji');

    if (isCrisps && qty != null && qty.kind == 'mass') {
      final g = qty.value;
      if (g >= 15 && g <= 30) return 5.00;
      if (g > 30 && g <= 55) return 10.00;
      if (g > 55 && g <= 100) return 20.00;
      if (g > 100 && g <= 160) return 30.00;
    }

    return null;
  }
}
