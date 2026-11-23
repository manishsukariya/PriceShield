import 'package:flutter/foundation.dart';

@immutable
class DualBatchVariant {
  const DualBatchVariant({
    required this.mrp,
    required this.label,
    this.badge,
  });

  final num mrp;
  final String label;
  final String? badge;
}

/// Intelligent resolver for products that have multiple coexisting price batches
/// in the Indian market (e.g. Sprite 750ml Promo ₹35 vs Regular ₹40,
/// Lipton Green Tea ₹165 vs ₹190, Rail Neer ₹10 vs ₹15).
class IndianDualBatchResolver {
  const IndianDualBatchResolver._();

  static List<DualBatchVariant> resolveVariants({
    required String barcode,
    required String productName,
    num? catalogMrp,
    num? ocrExtractedMrp,
  }) {
    final cleanBarcode = barcode.trim();
    final lowerName = productName.toLowerCase();
    final variants = <DualBatchVariant>[];
    final addedMrps = <num>{};

    void addVariant(num mrp, String label, {String? badge}) {
      if (!addedMrps.contains(mrp)) {
        addedMrps.add(mrp);
        variants.add(DualBatchVariant(mrp: mrp, label: label, badge: badge));
      }
    }

    // 1. Lipton Green Tea (25 Tea Bags / 25N)
    if (cleanBarcode == '8901030779312' ||
        (lowerName.contains('lipton') && lowerName.contains('green tea'))) {
      addVariant(165, '₹165 (Old Batch)', badge: 'Old Batch');
      addVariant(190, '₹190 (New Batch)', badge: 'New Batch');
      return variants;
    }

    // 2. Sprite / Coca-Cola / Thums Up / Fanta / Limca (750ml / 600ml / 2.25L)
    final isColaBrand = lowerName.contains('sprite') ||
        lowerName.contains('coca-cola') ||
        lowerName.contains('coca cola') ||
        lowerName.contains('coke') ||
        lowerName.contains('thums up') ||
        lowerName.contains('fanta') ||
        lowerName.contains('limca');

    if (isColaBrand) {
      if (lowerName.contains('750') || lowerName.contains('600')) {
        addVariant(35, '₹35 (Promo Batch)', badge: 'PROMO');
        addVariant(40, '₹40 (Standard MRP)', badge: 'STANDARD');
        return variants;
      }
      if (lowerName.contains('2.25') || lowerName.contains('2l') || lowerName.contains('2 ltr')) {
        addVariant(95, '₹95 (Promo Batch)', badge: 'PROMO');
        addVariant(100, '₹100 (Standard MRP)', badge: 'STANDARD');
        return variants;
      }
      // General cola default promo vs standard
      addVariant(35, '₹35 (Promo)', badge: 'PROMO');
      addVariant(40, '₹40 (Standard)', badge: 'STANDARD');
      return variants;
    }

    // 3. IRCTC Rail Neer
    if (cleanBarcode == '8908001150013' ||
        cleanBarcode == '8908001150037' ||
        lowerName.contains('rail neer') ||
        lowerName.contains('railneer')) {
      addVariant(10, '₹10 (500ml)', badge: '500ML');
      addVariant(15, '₹15 (1L Standard)', badge: '1L');
      return variants;
    }

    // 4. Dynamic batch pairing: If catalog MRP differs from OCR-extracted MRP
    if (catalogMrp != null && ocrExtractedMrp != null && catalogMrp != ocrExtractedMrp) {
      if (catalogMrp < ocrExtractedMrp) {
        addVariant(catalogMrp, '₹$catalogMrp (Catalog Ref)', badge: 'PREV');
        addVariant(ocrExtractedMrp, '₹$ocrExtractedMrp (Packet OCR)', badge: 'CURRENT');
      } else {
        addVariant(ocrExtractedMrp, '₹$ocrExtractedMrp (Packet OCR)', badge: 'PROMO');
        addVariant(catalogMrp, '₹$catalogMrp (Catalog Ref)', badge: 'STANDARD');
      }
    }

    return variants;
  }
}
