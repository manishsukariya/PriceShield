/**
 * Standard Indian FMCG Legal Metrology pack-size to printed MRP heuristics.
 * Covers staples where net quantity directly maps to nationally fixed price points.
 */

function parseQuantity(text) {
  if (!text || typeof text !== 'string') return null;
  const match = /(\d+(?:\.\d+)?)\s*(kg|g|gm|gms|l|ltr|litre|litres|ml)\b/i.exec(text);
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
    // Barcode prefix 8902579 specific detection
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
    return 20.00; // iconic 250ml PET price point
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
    if (ml > 260 && ml <= 350) return 40.00; // can
    if (ml > 500 && ml <= 780) return 40.00; // 600ml / 750ml PET
    if (ml > 1100 && ml <= 1600) return 65.00; // 1.25L / 1.5L
    if (ml > 1900 && ml <= 2400) return 95.00; // 2L / 2.25L
  }

  // 6. Maggi 2-Minute Noodles / YiPPee!
  if (combined.includes('maggi') || combined.includes('yippee')) {
    if (qty && qty.kind === 'mass') {
      const g = qty.value;
      if (g >= 55 && g <= 80) return 14.00;
      if (g > 80 && g <= 160) return 28.00;
      if (g > 160 && g <= 320) return 56.00;
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

  // 9. Potato Chips & Namkeen (Lay's, Kurkure, Bingo, Balaji)
  const isCrisps =
    combined.includes("lay's") ||
    combined.includes('lays') ||
    combined.includes('kurkure') ||
    combined.includes('bingo') ||
    combined.includes('balaji');

  if (isCrisps && qty && qty.kind === 'mass') {
    const g = qty.value;
    if (g >= 15 && g <= 30) return 5.00;
    if (g > 30 && g <= 55) return 10.00;
    if (g > 55 && g <= 100) return 20.00;
    if (g > 100 && g <= 160) return 30.00;
  }

  return 0.0;
}
