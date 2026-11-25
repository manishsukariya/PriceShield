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
    '8904417': Gs1BrandInfo(
      brandName: 'Aqualogica / Mamaearth (Honasa)',
      company: 'Honasa Consumer Ltd',
      category: 'Personal Care & Sunscreen',
      suggestedMrps: [299, 399, 499, 599, 699],
    ),
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
    '8901648': Gs1BrandInfo(
      brandName: 'Mother Dairy',
      company: 'Mother Dairy Fruit & Vegetable Pvt Ltd',
      category: 'Dairy & Beverages',
      suggestedMrps: [15, 20, 27, 33, 54, 66],
    ),
    '8901719': Gs1BrandInfo(
      brandName: 'Parle (Parle-G / Frooti / Appy Fizz)',
      company: 'Parle Products & Parle Agro',
      category: 'Biscuits & Beverages',
      suggestedMrps: [5, 10, 15, 20, 38, 40, 70, 110],
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
    '8901058': Gs1BrandInfo(
      brandName: 'Nestlé (Maggi / KitKat / Munch)',
      company: 'Nestlé India Ltd',
      category: 'Instant Noodles & Confectionery',
      suggestedMrps: [5, 10, 14, 18, 20, 25, 30, 56],
    ),
    '8901725': Gs1BrandInfo(
      brandName: 'ITC (Sunfeast / Bingo! / YiPPee!)',
      company: 'ITC Limited',
      category: 'Biscuits, Snacks & Noodles',
      suggestedMrps: [5, 10, 12, 14, 20, 25, 40, 50],
    ),
    '8902579': Gs1BrandInfo(
      brandName: 'Parle Agro (Appy Fizz / Frooti / Bailley)',
      company: 'Parle Agro Pvt Ltd',
      category: 'Beverages & Soft Drinks',
      suggestedMrps: [10, 15, 20, 40, 60, 70, 110],
    ),
    '8901030': Gs1BrandInfo(
      brandName: 'Hindustan Unilever (HUL)',
      company: 'Hindustan Unilever Limited',
      category: 'FMCG & Tea/Beverages',
      suggestedMrps: [10, 20, 30, 50, 75],
    ),
    '8909106': Gs1BrandInfo(
      brandName: "Pond's / HUL",
      company: 'Hindustan Unilever Limited',
      category: 'Personal Care & Sunscreen Powder',
      suggestedMrps: [117, 120, 125, 150],
    ),
    '8901088': Gs1BrandInfo(
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
    '8901207': Gs1BrandInfo(
      brandName: 'Godrej (Cinthol / Goodknight / Hit)',
      company: 'Godrej Consumer Products Ltd',
      category: 'Soaps & Insecticides',
      suggestedMrps: [10, 20, 35, 50, 75],
    ),
    '8901314': Gs1BrandInfo(
      brandName: 'Colgate',
      company: 'Colgate-Palmolive (India) Ltd',
      category: 'Oral Care & Toothpaste',
      suggestedMrps: [10, 20, 35, 55, 99],
    ),
    '8901526': Gs1BrandInfo(
      brandName: 'Emami (BoroPlus / Navratna / Zandu)',
      company: 'Emami Limited',
      category: 'Personal Care & Healthcare',
      suggestedMrps: [10, 20, 35, 60, 99],
    ),
    '8901027': Gs1BrandInfo(
      brandName: 'Cadbury / Mondelez (Dairy Milk / Oreo)',
      company: 'Mondelez India Foods Pvt Ltd',
      category: 'Chocolates & Confectionery',
      suggestedMrps: [5, 10, 20, 40, 80],
    ),
    '8901042': Gs1BrandInfo(
      brandName: 'Reckitt (Dettol / Harpic / Lizol)',
      company: 'Reckitt Benckiser (India) Pvt Ltd',
      category: 'Antiseptic & Home Care',
      suggestedMrps: [10, 25, 40, 70, 110],
    ),
    '8901012': Gs1BrandInfo(
      brandName: 'Horlicks / Boost',
      company: 'Hindustan Unilever Limited',
      category: 'Health Food Drinks',
      suggestedMrps: [10, 30, 60, 120, 250],
    ),
    '8906002': Gs1BrandInfo(
      brandName: 'Wipro (Santoor / Yardley)',
      company: 'Wipro Consumer Care',
      category: 'Soaps & Personal Wash',
      suggestedMrps: [10, 20, 35, 55, 75],
    ),
    '8901072': Gs1BrandInfo(
      brandName: 'P&G (Gillette / Oral-B / Whisper / Pantene)',
      company: 'Procter & Gamble India',
      category: 'Personal Care & Hygiene',
      suggestedMrps: [15, 25, 45, 90, 150],
    ),
    '8901138': Gs1BrandInfo(
      brandName: 'Tata Consumer (Tata Salt / Tata Tea / Sampann)',
      company: 'Tata Consumer Products Ltd',
      category: 'Tea, Salt & Staples',
      suggestedMrps: [10, 28, 50, 95, 140],
    ),
    '8901537': Gs1BrandInfo(
      brandName: 'LT Foods (Daawat Basmati Rice)',
      company: 'LT Foods Limited',
      category: 'Packaged Rice & Grains',
      suggestedMrps: [110, 160, 280, 550],
    ),
    '8901425': Gs1BrandInfo(
      brandName: 'Adani Wilmar (Fortune Oil / Atta)',
      company: 'Adani Wilmar Limited',
      category: 'Edible Oils & Wheat Atta',
      suggestedMrps: [90, 140, 180, 350],
    ),
    '8901052': Gs1BrandInfo(
      brandName: "Johnson's / Clean & Clear",
      company: 'Kenvue / Johnson & Johnson',
      category: 'Baby Care & Skincare',
      suggestedMrps: [45, 75, 120, 180],
    ),
    '8901131': Gs1BrandInfo(
      brandName: 'Nivea',
      company: 'Nivea India Pvt Ltd',
      category: 'Skin & Body Care',
      suggestedMrps: [60, 120, 199, 299],
    ),
    '8902519': Gs1BrandInfo(
      brandName: "L'Oréal / Garnier",
      company: "L'Oréal India Pvt Ltd",
      category: 'Hair & Skin Care',
      suggestedMrps: [99, 149, 199, 299, 499],
    ),
    '8904047': Gs1BrandInfo(
      brandName: 'Himalaya',
      company: 'Himalaya Wellness Company',
      category: 'Face Wash & Ayurvedic Care',
      suggestedMrps: [45, 75, 120, 180, 240],
    ),
    '8904109': Gs1BrandInfo(
      brandName: 'CavinKare (Chik / Meera / Nyle)',
      company: 'CavinKare Pvt Ltd',
      category: 'Hair Care & Personal Care',
      suggestedMrps: [10, 20, 45, 85, 140],
    ),
    '8904245': Gs1BrandInfo(
      brandName: 'Nykaa',
      company: 'FSN E-Commerce Ventures',
      category: 'Cosmetics & Beauty',
      suggestedMrps: [199, 299, 399, 499],
    ),
    '8904336': Gs1BrandInfo(
      brandName: 'WOW Skin Science',
      company: 'Fit & Glow Healthcare',
      category: 'Hair & Skincare',
      suggestedMrps: [199, 299, 399, 499],
    ),
    '8904314': Gs1BrandInfo(
      brandName: 'Plum Goodness',
      company: 'Pureplay Skin Sciences',
      category: 'Vegan Skincare',
      suggestedMrps: [199, 299, 399, 499],
    ),
    '8904227': Gs1BrandInfo(
      brandName: 'SUGAR Cosmetics',
      company: 'Vellvette Lifestyle',
      category: 'Cosmetics & Makeup',
      suggestedMrps: [199, 299, 499, 699],
    ),
    '8904265': Gs1BrandInfo(
      brandName: 'mCaffeine',
      company: 'PEP Technologies',
      category: 'Caffeine Personal Care',
      suggestedMrps: [199, 299, 399, 499],
    ),
    '8904288': Gs1BrandInfo(
      brandName: 'Minimalist',
      company: 'Uprising Science',
      category: 'Skincare & Sunscreen',
      suggestedMrps: [299, 399, 499, 599, 699],
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

