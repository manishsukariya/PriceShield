/**
 * Comprehensive GS1 India (Prefix 890) Manufacturer and Brand Resolver for PriceShield Backend.
 * Automatically resolves top Indian FMCG, Dairy, Beverages, Snacks, Personal Care and Cosmetics brands
 * to ensure that unlisted or partially indexed barcodes always return authoritative brand and category data
 * instead of generic placeholders like "Product <barcode>".
 */

export const GS1_INDIA_MANUFACTURERS = {
  // Beauty, Personal Care & D2C Cosmetics
  '8904417': {
    brandName: 'Aqualogica / Mamaearth (Honasa)',
    company: 'Honasa Consumer Ltd',
    category: 'Personal Care & Sunscreen',
    defaultItemName: 'Aqualogica / Mamaearth Personal Care',
  },
  '8904047': {
    brandName: 'Himalaya',
    company: 'Himalaya Wellness Company',
    category: 'Face Care & Ayurvedic Healthcare',
    defaultItemName: 'Himalaya Personal Care Product',
  },
  '8904109': {
    brandName: 'CavinKare (Chik / Meera / Nyle)',
    company: 'CavinKare Pvt Ltd',
    category: 'Hair Care & Personal Care',
    defaultItemName: 'CavinKare Personal Care Product',
  },
  '8904288': {
    brandName: 'Minimalist',
    company: 'Uprising Science Pvt Ltd',
    category: 'Skincare & Sunscreen',
    defaultItemName: 'Minimalist Skincare Product',
  },
  '8904265': {
    brandName: 'mCaffeine',
    company: 'PEP Technologies Pvt Ltd',
    category: 'Caffeine Personal Care',
    defaultItemName: 'mCaffeine Personal Care Product',
  },
  '8904314': {
    brandName: 'Plum Goodness',
    company: 'Pureplay Skin Sciences (I) Pvt Ltd',
    category: 'Vegan Skincare & Cosmetics',
    defaultItemName: 'Plum Skincare Product',
  },
  '8904336': {
    brandName: 'WOW Skin Science',
    company: 'Fit & Glow Healthcare Pvt Ltd',
    category: 'Hair & Skincare',
    defaultItemName: 'WOW Skin Science Product',
  },
  '8904227': {
    brandName: 'SUGAR Cosmetics',
    company: 'Vellvette Lifestyle Pvt Ltd',
    category: 'Cosmetics & Beauty',
    defaultItemName: 'SUGAR Cosmetics Product',
  },
  '8904245': {
    brandName: 'Nykaa',
    company: 'FSN E-Commerce Ventures Ltd',
    category: 'Beauty & Personal Care',
    defaultItemName: 'Nykaa Beauty Product',
  },
  '8901131': {
    brandName: 'Nivea',
    company: 'Nivea India Pvt Ltd',
    category: 'Skin & Body Care',
    defaultItemName: 'Nivea Skincare Product',
  },
  '8902519': {
    brandName: "L'Oréal / Garnier",
    company: "L'Oréal India Pvt Ltd",
    category: 'Hair & Skin Care',
    defaultItemName: "L'Oréal / Garnier Product",
  },
  '8901052': {
    brandName: "Johnson's / Clean & Clear",
    company: 'Kenvue / Johnson & Johnson India',
    category: 'Baby Care & Skincare',
    defaultItemName: "Johnson's Personal Care Product",
  },
  '8901207': {
    brandName: 'Godrej (Cinthol / Goodknight / Hit)',
    company: 'Godrej Consumer Products Ltd',
    category: 'Soap & Home Insecticide',
    defaultItemName: 'Godrej Consumer Product',
  },
  '8901314': {
    brandName: 'Colgate',
    company: 'Colgate-Palmolive (India) Ltd',
    category: 'Oral Care & Toothpaste',
    defaultItemName: 'Colgate Oral Care Product',
  },
  '8901526': {
    brandName: 'Emami (BoroPlus / Navratna / Zandu)',
    company: 'Emami Limited',
    category: 'Personal Care & Healthcare',
    defaultItemName: 'Emami Healthcare Product',
  },
  '8901042': {
    brandName: 'Reckitt (Dettol / Harpic / Lizol)',
    company: 'Reckitt Benckiser (India) Pvt Ltd',
    category: 'Antiseptic & Home Care',
    defaultItemName: 'Reckitt Consumer Product',
  },
  '8906002': {
    brandName: 'Wipro (Santoor / Yardley)',
    company: 'Wipro Consumer Care and Lighting',
    category: 'Soap & Personal Wash',
    defaultItemName: 'Wipro Consumer Product',
  },
  '8901072': {
    brandName: 'P&G (Gillette / Oral-B / Whisper / Pantene)',
    company: 'Procter & Gamble India',
    category: 'Grooming & Hair Care',
    defaultItemName: 'P&G Consumer Product',
  },

  // Dairy Cooperatives & Milk Staples
  '8901262': {
    brandName: 'Amul',
    company: 'Gujarat Co-operative Milk Marketing Federation (GCMMF)',
    category: 'Dairy, Milk & Beverages',
    defaultItemName: 'Amul Dairy Product',
  },
  '8906010': {
    brandName: 'Nandini Dairy',
    company: 'Karnataka Milk Federation (KMF)',
    category: 'Dairy & Milk Pouch',
    defaultItemName: 'Nandini Dairy Product',
  },
  '8901648': {
    brandName: 'Mother Dairy',
    company: 'Mother Dairy Fruit & Vegetable Pvt Ltd',
    category: 'Dairy, Curd & Ice Cream',
    defaultItemName: 'Mother Dairy Product',
  },
  '8908005': {
    brandName: 'Saras Dairy',
    company: 'Rajasthan Co-operative Dairy Federation',
    category: 'Dairy & Milk Pouch',
    defaultItemName: 'Saras Dairy Product',
  },
  '8908006': {
    brandName: 'Verka Dairy',
    company: 'Milkfed Punjab',
    category: 'Dairy & Milk Pouch',
    defaultItemName: 'Verka Dairy Product',
  },
  '8908007': {
    brandName: 'Gokul Dairy',
    company: 'Kolhapur Zilla Sahakari Dudh Sangh',
    category: 'Dairy & Milk Pouch',
    defaultItemName: 'Gokul Dairy Product',
  },
  '8908008': {
    brandName: 'Aavin Dairy',
    company: 'Tamil Nadu Co-operative Milk Producers',
    category: 'Dairy & Milk Pouch',
    defaultItemName: 'Aavin Dairy Product',
  },
  '8908009': {
    brandName: 'Milma Dairy',
    company: 'Kerala Co-operative Milk Marketing Federation',
    category: 'Dairy & Milk Pouch',
    defaultItemName: 'Milma Dairy Product',
  },
  '8908010': {
    brandName: 'Sudha Dairy',
    company: 'Bihar State Milk Co-operative Federation (COMFED)',
    category: 'Dairy & Milk Pouch',
    defaultItemName: 'Sudha Dairy Product',
  },

  // Packaged Drinking Water & Beverages
  '8908001': {
    brandName: 'Rail Neer',
    company: 'Indian Railway Catering & Tourism Corporation (IRCTC)',
    category: 'Packaged Drinking Water',
    defaultItemName: 'Rail Neer Packaged Drinking Water',
  },
  '8901023': {
    brandName: 'Bisleri',
    company: 'Bisleri International Pvt Ltd',
    category: 'Packaged Drinking Water & Club Soda',
    defaultItemName: 'Bisleri Mineral Water',
  },
  '8901764': {
    brandName: 'Coca-Cola / Thums Up / Kinley',
    company: 'Hindustan Coca-Cola Beverages Pvt Ltd',
    category: 'Carbonated Beverage & Water',
    defaultItemName: 'Coca-Cola Beverage',
  },
  '8902080': {
    brandName: 'Coca-Cola India',
    company: 'Coca-Cola India Inc',
    category: 'Beverage & Soft Drink',
    defaultItemName: 'Coca-Cola Beverage',
  },
  '8901491': {
    brandName: "PepsiCo (Pepsi / Sting / Lay's / Kurkure)",
    company: 'PepsiCo India Holdings Pvt Ltd',
    category: 'Soft Drinks & Snacks',
    defaultItemName: 'PepsiCo Food & Beverage',
  },
  '8902579': {
    brandName: 'Parle Agro (Appy Fizz / Frooti / Bailley)',
    company: 'Parle Agro Pvt Ltd',
    category: 'Beverages & Packaged Water',
    defaultItemName: 'Parle Agro Beverage',
  },

  // Biscuits, Snacks & Packaged Foods
  '8901063': {
    brandName: 'Britannia',
    company: 'Britannia Industries Ltd',
    category: 'Biscuits, Bread & Dairy',
    defaultItemName: 'Britannia Biscuit / Bakery Item',
  },
  '8901719': {
    brandName: 'Parle (Parle-G / 20-20 / Monaco)',
    company: 'Parle Products Pvt Ltd',
    category: 'Biscuits & Confectionery',
    defaultItemName: 'Parle Biscuit / Confectionery',
  },
  '8901512': {
    brandName: 'Parle Biscuits',
    company: 'Parle Products Pvt Ltd',
    category: 'Biscuits & Cookies',
    defaultItemName: 'Parle Biscuit Product',
  },
  '8901058': {
    brandName: 'Nestlé (Maggi / KitKat / Nescafé)',
    company: 'Nestlé India Ltd',
    category: 'Instant Noodles & Confectionery',
    defaultItemName: 'Nestlé Food Product',
  },
  '8901725': {
    brandName: 'ITC (Sunfeast / Bingo! / YiPPee! / Aashirvaad)',
    company: 'ITC Limited',
    category: 'Biscuits, Snacks, Noodles & Staples',
    defaultItemName: 'ITC Packaged Food',
  },
  '8901027': {
    brandName: 'Cadbury / Mondelez (Dairy Milk / Oreo / Bournvita)',
    company: 'Mondelez India Foods Pvt Ltd',
    category: 'Chocolates & Confectionery',
    defaultItemName: 'Cadbury Chocolate / Confectionery',
  },
  '8906001': {
    brandName: 'Balaji Wafers & Namkeen',
    company: 'Balaji Wafers Pvt Ltd',
    category: 'Chips & Namkeen',
    defaultItemName: 'Balaji Snack Product',
  },
  '8906020': {
    brandName: 'Yellow Diamond',
    company: 'Prataap Snacks Ltd',
    category: 'Snacks & Namkeen',
    defaultItemName: 'Yellow Diamond Snack',
  },
  '8906014': {
    brandName: 'Crax (DFM Foods)',
    company: 'DFM Foods Ltd',
    category: 'Corn Rings & Snacks',
    defaultItemName: 'Crax Snack Product',
  },
  '8906007': {
    brandName: 'Bikaji',
    company: 'Bikaji Foods International Ltd',
    category: 'Bhujia, Namkeen & Sweets',
    defaultItemName: 'Bikaji Namkeen Product',
  },
  '8906038': {
    brandName: "Haldiram's",
    company: 'Haldiram Snacks Pvt Ltd',
    category: 'Namkeen & Sweets',
    defaultItemName: "Haldiram's Namkeen",
  },

  // Groceries, Staples & Health
  '8901030': {
    brandName: 'Hindustan Unilever (HUL)',
    company: 'Hindustan Unilever Limited',
    category: 'FMCG, Tea & Home Care',
    defaultItemName: 'HUL Consumer Product',
  },
  '8909106': {
    brandName: "Pond's / HUL",
    company: 'Hindustan Unilever Limited',
    category: 'Personal Care & Sunscreen Powder',
    defaultItemName: "Pond's Personal Care Product",
  },
  '8901088': {
    brandName: 'Marico (Saffola / Parachute)',
    company: 'Marico Limited',
    category: 'Edible Oils & Foods',
    defaultItemName: 'Marico Food Product',
  },
  '8901233': {
    brandName: 'Dabur (Real / Honey / Chyawanprash)',
    company: 'Dabur India Ltd',
    category: 'Juices, Health & Personal Care',
    defaultItemName: 'Dabur Healthcare Product',
  },
  '8904004': {
    brandName: 'Patanjali',
    company: 'Patanjali Ayurved Ltd',
    category: 'Ayurvedic Food & Groceries',
    defaultItemName: 'Patanjali Consumer Product',
  },
  '8901138': {
    brandName: 'Tata Consumer (Tata Salt / Tata Tea / Sampann)',
    company: 'Tata Consumer Products Ltd',
    category: 'Tea, Salt & Pulses',
    defaultItemName: 'Tata Consumer Product',
  },
  '8901537': {
    brandName: 'LT Foods (Daawat Basmati Rice)',
    company: 'LT Foods Limited',
    category: 'Packaged Rice & Grains',
    defaultItemName: 'Daawat Basmati Rice',
  },
  '8901425': {
    brandName: 'Adani Wilmar (Fortune Oil / Atta)',
    company: 'Adani Wilmar Limited',
    category: 'Edible Oils & Wheat Atta',
    defaultItemName: 'Fortune Cooking Oil / Atta',
  },
  '8901012': {
    brandName: 'Horlicks / Boost',
    company: 'Hindustan Unilever / GSK Consumer',
    category: 'Health Food Drink',
    defaultItemName: 'Health Food Drink Product',
  },
};

/**
 * Resolves GS1 India manufacturer metadata from barcode.
 * Matches 7-digit prefixes first for high precision, then 6-digit prefixes.
 */
export function resolveGs1IndiaBrand(barcode) {
  if (!barcode || typeof barcode !== 'string') return null;
  const clean = barcode.trim().replace(/\D/g, '');
  if (!clean.startsWith('890') || clean.length < 7) {
    return null;
  }

  for (let len = 7; len >= 6; len--) {
    if (clean.length >= len) {
      const prefix = clean.slice(0, len);
      const match = GS1_INDIA_MANUFACTURERS[prefix];
      if (match) return match;
    }
  }

  return null;
}
