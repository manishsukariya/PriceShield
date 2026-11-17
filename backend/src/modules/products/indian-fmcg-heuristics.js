/**
 * Standard Indian FMCG Legal Metrology pack-size to printed MRP heuristics.
 * Covers staples where net quantity directly maps to nationally fixed price points.
 */

function parseQuantity(text) {
  if (!text || typeof text !== 'string') return null;
  const match = /(\d+(?:\.\d+)?)\s*(kg|g|gm|gms|gram|grams|l|ltr|litre|litres|ml)\b/i.exec(text);
  if (!match) return null;
  const amount = parseFloat(match[1]);
  if (!Number.isFinite(amount) || amount <= 0) return null;
  const unit = match[2].toLowerCase();
  if (unit === 'kg' || unit === 'l' || unit === 'ltr' || unit.startsWith('litre')) {
    return { value: amount * 1000, kind: unit === 'kg' ? 'mass' : 'volume', rawAmount: amount };
  }
  return { value: amount, kind: unit === 'ml' ? 'volume' : 'mass', rawAmount: amount };
}

export function inferFmcgMrp({ name = '', brand = '', quantity = '', barcode = '' }) {
  const combined = `${name} ${brand} ${quantity}`.toLowerCase();
  const qty = parseQuantity(quantity) || parseQuantity(name);

  // 1. Appy & Appy Fizz (Parle Agro)
  if (combined.includes('appy fizz') || combined.includes('appy')) {
    if (qty && qty.kind === 'volume') {
      const ml = qty.value;
      if (ml >= 120 && ml <= 175) return 10.00;
      if (ml > 175 && ml <= 300) return 20.00;
      if (ml > 300 && ml <= 650) return 40.00;
      if (ml > 650 && ml <= 1300) return 60.00;
      if (ml > 1300 && ml <= 2200) return 100.00;
    }
    if (barcode.startsWith('89025790039') || barcode.startsWith('89025790024') || barcode.startsWith('890171920201')) {
      return 10.00;
    }
  }

  // 2. Frooti (Parle Agro)
  if (combined.includes('frooti')) {
    if (qty && qty.kind === 'volume') {
      const ml = qty.value;
      if (ml >= 120 && ml <= 170) return 10.00;
      if (ml > 170 && ml <= 220) return 15.00;
      if (ml > 220 && ml <= 300) return 20.00;
      if (ml > 300 && ml <= 650) return 38.00;
      if (ml > 650 && ml <= 1300) return 70.00;
      if (ml > 1300 && ml <= 2200) return 110.00;
    }
  }

  // 3. Sting Energy Drink (PepsiCo)
  if (combined.includes('sting')) {
    if (qty && qty.kind === 'volume') {
      const ml = qty.value;
      if (ml >= 200 && ml <= 300) {
        return combined.includes('can') ? 35.00 : 20.00;
      }
    }
    return 20.00;
  }

  // 4. Packaged Drinking Water (Bisleri, Kinley, Aquafina, Bailley, Rail Neer)
  if (combined.includes('rail neer') || combined.includes('railneer')) {
    if (qty && qty.kind === 'volume') {
      return qty.value >= 750 ? 15.00 : 10.00;
    }
    return 15.00;
  }
  if (
    combined.includes('bisleri') ||
    combined.includes('kinley') ||
    combined.includes('aquafina') ||
    combined.includes('bailley')
  ) {
    if (qty && qty.kind === 'volume') {
      const ml = qty.value;
      if (ml <= 550) return 10.00;
      if (ml > 550 && ml <= 1200) return 20.00;
      if (ml > 1200 && ml <= 2200) return 30.00;
      if (ml > 4000 && ml <= 6000) return 70.00;
    }
  }

  // 5. Major Carbonated Drinks (Coca-Cola, Thums Up, Sprite, Fanta, Limca, Pepsi, Mountain Dew, 7up, Mirinda)
  const isMajorCola =
    combined.includes('coca-cola') ||
    combined.includes('coca cola') ||
    combined.includes('thums up') ||
    combined.includes('sprite') ||
    combined.includes('fanta') ||
    combined.includes('limca') ||
    combined.includes('pepsi') ||
    combined.includes('mountain dew') ||
    combined.includes('7up') ||
    combined.includes('mirinda');

  if (isMajorCola && qty && qty.kind === 'volume') {
    const ml = qty.value;
    if (ml >= 200 && ml <= 260) {
      return combined.includes('can') ? 35.00 : 20.00;
    }
    if (ml > 260 && ml <= 350) return 40.00;
    if (ml > 500 && ml <= 780) return 40.00;
    if (ml > 1100 && ml <= 1600) return 65.00;
    if (ml > 1900 && ml <= 2400) return 95.00;
  }

  // 6. Maggi 2-Minute Noodles / YiPPee!
  if (combined.includes('maggi') || combined.includes('yippee') || combined.includes('wai wai') || combined.includes('top ramen')) {
    if (qty && qty.kind === 'mass') {
      const g = qty.value;
      if (g >= 55 && g <= 80) return 14.00;
      if (g > 80 && g <= 160) return 28.00;
      if (g > 160 && g <= 320) return 56.00;
      if (g > 320 && g <= 580) return 95.00;
    }
  }

  // 7. Parle-G Biscuits
  if (combined.includes('parle-g') || combined.includes('parle g')) {
    if (qty && qty.kind === 'mass') {
      const g = qty.value;
      if (g >= 40 && g <= 70) return 5.00;
      if (g > 70 && g <= 150) return 10.00;
      if (g > 150 && g <= 300) return 25.00;
      if (g > 700 && g <= 900) return 80.00;
    }
  }

  // 8. Amul Milk Pouches (Taaza / Gold / Cow Milk)
  if (combined.includes('amul') && (combined.includes('milk') || combined.includes('doodh'))) {
    if (qty && qty.kind === 'volume') {
      const ml = qty.value;
      const isGold = combined.includes('gold');
      if (ml >= 450 && ml <= 550) return isGold ? 33.00 : 27.00;
      if (ml >= 950 && ml <= 1100) return isGold ? 66.00 : 54.00;
    }
  }

  // 9. Potato Chips, Puffs & Namkeen (Lay's, Kurkure, Uncle Chipps, Bingo, Balaji, Haldiram, Bikaji, Crax)
  const isCrisps =
    combined.includes("lay's") ||
    combined.includes('lays') ||
    combined.includes('kurkure') ||
    combined.includes('bingo') ||
    combined.includes('balaji') ||
    combined.includes('uncle chipps') ||
    combined.includes('haldiram') ||
    combined.includes('bikaji') ||
    combined.includes('bikano') ||
    combined.includes('crax') ||
    combined.includes('doritos') ||
    combined.includes('pringles') ||
    combined.includes('namkeen') ||
    combined.includes('bhujia');

  if (isCrisps && qty && qty.kind === 'mass') {
    const g = qty.value;
    if (g >= 14 && g <= 30) return 5.00;
    if (g > 30 && g <= 55) return 10.00;
    if (g > 55 && g <= 100) return 20.00;
    if (g > 100 && g <= 150) return 30.00;
    if (g > 150 && g <= 250) return 50.00;
    if (g > 250 && g <= 450) return 90.00;
    if (g > 800 && g <= 1200) return 240.00;
  }

  // 10. Popular Biscuits & Cookies
  const isBiscuit =
    combined.includes('biscuit') ||
    combined.includes('cookie') ||
    combined.includes('good day') ||
    combined.includes('marie') ||
    combined.includes('bourbon') ||
    combined.includes('50-50') ||
    combined.includes('milk bikis') ||
    combined.includes('little hearts') ||
    combined.includes('jim jam') ||
    combined.includes('jimjam') ||
    combined.includes('nutrichoice') ||
    combined.includes('dark fantasy') ||
    combined.includes("mom's magic") ||
    combined.includes('moms magic') ||
    combined.includes('bounce') ||
    combined.includes('oreo') ||
    combined.includes('unibic') ||
    combined.includes('monaco') ||
    combined.includes('krackjack') ||
    combined.includes('hide & seek') ||
    combined.includes('hide and seek') ||
    combined.includes('20-20') ||
    combined.includes('rusk');

  if (isBiscuit && qty && qty.kind === 'mass') {
    const g = qty.value;
    if (g >= 20 && g <= 48) return 5.00;
    if (g > 48 && g <= 85) return 10.00;
    if (g > 85 && g <= 160) return 20.00;
    if (g > 160 && g <= 250) return 30.00;
    if (g > 250 && g <= 360) return 45.00;
    if (g > 360 && g <= 550) return 70.00;
    if (g > 550 && g <= 900) return 100.00;
  }

  // 11. Chocolates & Confectionery
  const isChoc =
    combined.includes('dairy milk') ||
    combined.includes('cadbury') ||
    combined.includes('5 star') ||
    combined.includes('perk') ||
    combined.includes('fuse') ||
    combined.includes('gems') ||
    combined.includes('kitkat') ||
    combined.includes('kit kat') ||
    combined.includes('munch') ||
    combined.includes('milkybar') ||
    combined.includes('bar-one') ||
    combined.includes('snickers') ||
    combined.includes('kinder joy') ||
    combined.includes('chocolate');

  if (isChoc && qty && qty.kind === 'mass') {
    const g = qty.value;
    if (combined.includes('silk')) {
      return g > 100 ? 175.00 : 80.00;
    }
    if (combined.includes('kinder joy')) return 45.00;
    if (g >= 10 && g <= 15) return 5.00;
    if (g > 15 && g <= 26) return 10.00;
    if (g > 26 && g <= 52) return 20.00;
    if (g > 52 && g <= 85) return 45.00;
    if (g > 85 && g <= 150) return 60.00;
    if (g > 150 && g <= 220) return 100.00;
  }

  // 12. Fruit Juices
  const isJuice =
    combined.includes('maaza') ||
    combined.includes('slice') ||
    combined.includes('real ') ||
    combined.includes('real fruit') ||
    combined.includes('tropicana') ||
    combined.includes('paper boat') ||
    combined.includes('b-natural') ||
    combined.includes('juice');

  if (isJuice && qty && qty.kind === 'volume') {
    const ml = qty.value;
    if (ml >= 140 && ml <= 170) return 10.00;
    if (ml > 170 && ml <= 220) return 15.00;
    if (ml > 220 && ml <= 300) return 20.00;
    if (ml > 500 && ml <= 650) return 40.00;
    if (ml > 900 && ml <= 1300) {
      return combined.includes('real') || combined.includes('tropicana') ? 110.00 : 75.00;
    }
    if (ml > 1800 && ml <= 2200) return 110.00;
  }

  // 13. Energy Drinks
  if (combined.includes('red bull') || combined.includes('redbull')) return 125.00;
  if (combined.includes('monster energy') || combined.includes('monster')) return 110.00;
  if (combined.includes('hell energy')) return 60.00;

  // 14. Soaps & Body Wash
  const isSoap =
    combined.includes('soap') ||
    combined.includes('dettol') ||
    combined.includes('lifebuoy') ||
    combined.includes('lux') ||
    combined.includes('santoor') ||
    combined.includes('cinthol') ||
    combined.includes('godrej no') ||
    combined.includes('medimix') ||
    combined.includes('mysore sandal') ||
    combined.includes('pears') ||
    combined.includes('dove');

  if (isSoap && qty && qty.kind === 'mass') {
    const g = qty.value;
    if (combined.includes('dove') || combined.includes('pears')) {
      return g > 85 ? 90.00 : 60.00;
    }
    if (g >= 40 && g <= 58) return 10.00;
    if (g > 58 && g <= 85) return 30.00;
    if (g > 85 && g <= 130) return 50.00;
    if (g > 200 && g <= 500) return 140.00;
  }

  // 15. Toothpaste
  const isToothpaste =
    combined.includes('toothpaste') ||
    combined.includes('colgate') ||
    combined.includes('close up') ||
    combined.includes('closeup') ||
    combined.includes('sensodyne') ||
    combined.includes('dabur red') ||
    combined.includes('meswak') ||
    combined.includes('pepsodent') ||
    combined.includes('dant kanti');

  if (isToothpaste && qty && qty.kind === 'mass') {
    const g = qty.value;
    if (combined.includes('sensodyne')) {
      return g > 100 ? 250.00 : 135.00;
    }
    if (g >= 18 && g <= 35) return 10.00;
    if (g > 35 && g <= 60) return 28.00;
    if (g > 60 && g <= 110) return 60.00;
    if (g > 110 && g <= 220) return 115.00;
    if (g > 220 && g <= 350) return 195.00;
  }

  // 16. Shampoos
  const isShampoo =
    combined.includes('shampoo') ||
    combined.includes('clinic plus') ||
    combined.includes('sunsilk') ||
    combined.includes('head & shoulders') ||
    combined.includes('head and shoulders') ||
    combined.includes('pantene') ||
    combined.includes('tresemme') ||
    combined.includes('vatika');

  if (isShampoo && qty && qty.kind === 'volume') {
    const ml = qty.value;
    if (ml >= 4 && ml <= 8) return 2.00;
    if (ml > 8 && ml <= 90) return 65.00;
    if (ml > 90 && ml <= 210) return 150.00;
    if (ml > 210 && ml <= 420) return 310.00;
    if (ml > 420 && ml <= 1000) return 520.00;
  }

  // 17. Detergents & Cleaning
  const isDetergent =
    combined.includes('surf excel') ||
    combined.includes('ariel') ||
    combined.includes('tide') ||
    combined.includes('rin') ||
    combined.includes('ghari') ||
    combined.includes('wheel') ||
    combined.includes('detergent') ||
    combined.includes('washing powder');

  if (isDetergent && qty && qty.kind === 'mass') {
    const g = qty.value;
    if (g >= 70 && g <= 120) return 10.00;
    if (g > 120 && g <= 550) return 65.00;
    if (g > 550 && g <= 1100) {
      if (combined.includes('surf') || combined.includes('ariel')) return 150.00;
      if (combined.includes('tide')) return 120.00;
      if (combined.includes('ghari')) return 70.00;
      return 130.00;
    }
    if (g > 1100 && g <= 2200) return 260.00;
    if (g > 3500 && g <= 4500) return 520.00;
  }

  // 18. Staples
  if (combined.includes('tata salt') || combined.includes('salt')) {
    if (combined.includes('lite')) return 45.00;
    if (qty && qty.value >= 900 && qty.value <= 1100) return 28.00;
  }
  if (combined.includes('atta') || combined.includes('flour')) {
    if (qty && qty.kind === 'mass') {
      const g = qty.value;
      if (g >= 900 && g <= 1100) return 52.00;
      if (g > 4500 && g <= 5500) return 245.00;
      if (g > 9000 && g <= 11000) return 475.00;
    }
  }

  // 19. Universal Volume / Mass Fallback
  if (qty) {
    if (qty.kind === 'volume') {
      const ml = qty.value;
      if (ml >= 140 && ml <= 220) return 15.00;
      if (ml > 220 && ml <= 300) return combined.includes('can') ? 35.00 : 20.00;
      if (ml > 500 && ml <= 780) return 40.00;
      if (ml > 900 && ml <= 1300) return 65.00;
      if (ml > 1800 && ml <= 2400) return 95.00;
    }
  }

  return 0.0;
}
