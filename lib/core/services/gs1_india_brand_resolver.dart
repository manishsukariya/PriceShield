import 'package:flutter/foundation.dart';

/// Structured information resolved from GS1 India manufacturer prefix.
@immutable
class Gs1BrandInfo {
  const Gs1BrandInfo({
    required this.brandName,
    required this.company,
    required this.category,
    this.suggestedMrps = const [10, 15, 20, 25, 30, 40, 50],
  });

  final String brandName;
  final String company;
  final String category;
  final List<num> suggestedMrps;
}

/// Intelligent offline GS1 India manufacturer barcode prefix resolver.
/// Barcodes starting with 890 are registered by GS1 India.
/// The subsequent 4 to 7 digits identify the Indian manufacturer or regional brand.
class Gs1IndiaBrandResolver {
  const Gs1IndiaBrandResolver._();

  static const Map<String, Gs1BrandInfo> _manufacturerPrefixes = {
    // Top Dairy & Regional Cooperatives
    '8901262': Gs1BrandInfo(
      brandName: 'Amul',
      company: 'Gujarat Co-operative Milk Marketing Federation (GCMMF)',
      category: 'Dairy & Beverages',
      suggestedMrps: [15, 20, 27, 33, 54, 66],
    ),
    '8906010': Gs1BrandInfo(
      brandName: 'Nandini Dairy',
      company: 'Karnataka Milk Federation (KMF)',
      category: 'Dairy & Milk Pouch',
      suggestedMrps: [12, 24, 26, 48, 52],
    ),
    '8901719': Gs1BrandInfo(
      brandName: 'Mother Dairy',
      company: 'Mother Dairy Fruit & Vegetable Pvt Ltd',
      category: 'Dairy & Beverages',
      suggestedMrps: [15, 20, 27, 33, 54, 66],
    ),
    '8908005': Gs1BrandInfo(
      brandName: 'Saras Dairy',
      company: 'Rajasthan Co-operative Dairy Federation (RCDF)',
      category: 'Dairy & Milk Pouch',
      suggestedMrps: [15, 25, 33, 50, 66],
    ),
    '8908006': Gs1BrandInfo(
      brandName: 'Verka Dairy',
      company: 'Milkfed Punjab',
      category: 'Dairy & Milk Pouch',
      suggestedMrps: [15, 26, 30, 52, 60],
    ),
    '8908007': Gs1BrandInfo(
      brandName: 'Gokul Dairy',
      company: 'Kolhapur Zilla Sahakari Dudh Sangh',
      category: 'Dairy & Milk Pouch',
      suggestedMrps: [15, 27, 34, 54, 68],
    ),
    '8908008': Gs1BrandInfo(
      brandName: 'Aavin Dairy',
      company: 'Tamil Nadu Co-operative Milk Producers',
      category: 'Dairy & Milk Pouch',
      suggestedMrps: [12, 20, 25, 40, 50],
    ),
    '8908009': Gs1BrandInfo(
      brandName: 'Milma Dairy',
      company: 'Kerala Co-operative Milk Marketing Federation',
      category: 'Dairy & Milk Pouch',
      suggestedMrps: [14, 26, 28, 52, 56],
    ),
    '8908010': Gs1BrandInfo(
      brandName: 'Sudha Dairy',
      company: 'Bihar State Milk Co-operative Federation (COMFED)',
      category: 'Dairy & Milk Pouch',
      suggestedMrps: [12, 23, 30, 46, 60],
    ),

    // Railway & Packaged Drinking Water Staples
    '8908001': Gs1BrandInfo(
      brandName: 'Rail Neer',
      company: 'Indian Railway Catering & Tourism Corporation (IRCTC)',
      category: 'Packaged Drinking Water',
      suggestedMrps: [10, 15],
    ),
    '8901023': Gs1BrandInfo(
      brandName: 'Bisleri',
      company: 'Bisleri International Pvt Ltd',
      category: 'Packaged Drinking Water & Beverages',
      suggestedMrps: [6, 10, 20, 30],
    ),
    '8901764': Gs1BrandInfo(
      brandName: 'Coca-Cola / Kinley / Thums Up',
      company: 'Hindustan Coca-Cola Beverages',
      category: 'Carbonated Beverage & Water',
      suggestedMrps: [10, 20, 25, 35, 40, 45],
    ),
    '8902080': Gs1BrandInfo(
      brandName: 'Coca-Cola Beverages',
      company: 'Coca-Cola India',
      category: 'Beverage & Soft Drink',
      suggestedMrps: [10, 20, 25, 35, 40, 45],
    ),
    '8901491': Gs1BrandInfo(
      brandName: 'PepsiCo (Pepsi / Sting / Lay\'s)',
      company: 'PepsiCo India Holdings',
      category: 'Soft Drinks & Snacks',
      suggestedMrps: [10, 20, 25, 30, 40, 50],
    ),

    // Regional & National Snacks / Namkeen
    '8906001': Gs1BrandInfo(
      brandName: 'Balaji Wafers & Namkeen',
      company: 'Balaji Wafers Pvt Ltd',
      category: 'Chips & Namkeen',
      suggestedMrps: [5, 10, 20, 30, 50],
    ),
    '8906020': Gs1BrandInfo(
      brandName: 'Yellow Diamond',
      company: 'Prataap Snacks Ltd',
      category: 'Snacks & Extruded Rings',
      suggestedMrps: [5, 10, 20],
    ),
    '8906014': Gs1BrandInfo(
      brandName: 'Crax',
      company: 'DFM Foods Ltd',
      category: 'Corn Rings & Curls',
      suggestedMrps: [5, 10, 20],
    ),
    '8906007': Gs1BrandInfo(
      brandName: 'Bikaji',
      company: 'Bikaji Foods International Ltd',
      category: 'Bhujia, Namkeen & Sweets',
      suggestedMrps: [10, 20, 30, 50, 60],
    ),
    '8906038': Gs1BrandInfo(
      brandName: 'Haldiram\'s',
      company: 'Haldiram Snacks Pvt Ltd',
      category: 'Namkeen & Sweets',
      suggestedMrps: [10, 20, 30, 45, 55],
    ),

    // Biscuits, Groceries & Personal Care
    '8901063': Gs1BrandInfo(
      brandName: 'Britannia',
      company: 'Britannia Industries Ltd',
      category: 'Biscuits, Bread & Dairy',
      suggestedMrps: [5, 10, 20, 25, 30, 40],
    ),
    '8901512': Gs1BrandInfo(
      brandName: 'Parle',
      company: 'Parle Products Pvt Ltd',
      category: 'Biscuits & Beverages (Frooti/Appy)',
      suggestedMrps: [5, 10, 20, 25, 35],
    ),
    '8901725': Gs1BrandInfo(
      brandName: 'Nestlé (Maggi / KitKat)',
      company: 'Nestlé India Ltd',
      category: 'Instant Noodles & Confectionery',
      suggestedMrps: [14, 20, 25, 30, 40, 60],
    ),
    '8902579': Gs1BrandInfo(
      brandName: 'ITC (Sunfeast / Bingo!)',
      company: 'ITC Limited',
      category: 'Biscuits & Snacks',
      suggestedMrps: [5, 10, 20, 25, 30],
    ),
    '8901030': Gs1BrandInfo(
      brandName: 'Hindustan Unilever (HUL)',
      company: 'Hindustan Unilever Limited',
      category: 'FMCG & Tea/Beverages',
      suggestedMrps: [10, 20, 30, 50, 75],
    ),
    '8901058': Gs1BrandInfo(
      brandName: 'Marico (Saffola / Parachute)',
      company: 'Marico Limited',
      category: 'Edible Oils & Foods',
      suggestedMrps: [20, 40, 55, 90],
    ),
    '8901233': Gs1BrandInfo(
      brandName: 'Dabur (Real Juice / Honey)',
      company: 'Dabur India Ltd',
      category: 'Juices & Healthcare',
      suggestedMrps: [20, 25, 40, 70, 110],
    ),
    '8904004': Gs1BrandInfo(
      brandName: 'Patanjali',
      company: 'Patanjali Ayurved Ltd',
      category: 'Ayurvedic Food & Groceries',
      suggestedMrps: [10, 20, 35, 50],
    ),
  };

  /// Resolves manufacturer and brand metadata from an Indian GS1 barcode (starting with 890).
  /// Returns null if barcode is not GS1 India or manufacturer is unrecognized.
  static Gs1BrandInfo? resolve(String? barcode) {
    if (barcode == null) return null;
    final clean = barcode.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (!clean.startsWith('890') || clean.length < 7) {
      return null;
    }

    // Match 7-digit prefix first for fine precision, then 6-digit prefix
    for (int len = 7; len >= 6; len--) {
      if (clean.length >= len) {
        final prefix = clean.substring(0, len);
        final match = _manufacturerPrefixes[prefix];
        if (match != null) return match;
      }
    }

    return null;
  }
}
