/**
 * Service to fetch product information from Open Food Facts API (fallback).
 */

const OFF_BASE_URL = 'https://world.openfoodfacts.org/api/v2/product';
const DEFAULT_TIMEOUT_MS = 2500;
const USER_AGENT = 'PriceShield - Android - Version 1.0 (support@priceshield.app)';

export function formatProductName(product, barcode) {
  const brand = (
    product.brands ||
    product.brand_owner ||
    product.brands_tags?.[0] ||
    ''
  ).split(',')[0].replace(/^en:/, '').trim();

  const rawName = (
    product.product_name_en ||
    product.product_name ||
    product.generic_name_en ||
    product.generic_name ||
    product.product_name_hi ||
    ''
  ).trim();

  const quantity = (product.quantity || '').trim();

  let displayName = rawName;
  if (brand && rawName) {
    if (!rawName.toLowerCase().includes(brand.toLowerCase())) {
      displayName = `${brand} ${rawName}`;
    }
  } else if (brand && !rawName) {
    displayName = brand;
  }

  if (!displayName) {
    displayName = `Product ${barcode}`;
  }

  if (quantity && !displayName.toLowerCase().includes(quantity.toLowerCase())) {
    displayName = `${displayName} (${quantity})`;
  }

  return displayName.slice(0, 255);
}

export function extractProductMrp(product) {
  // 1. Direct numeric price fields (including Open Prices fields)
  const raw = product.price ??
    product.mrp ??
    product.product_mrp ??
    product.price_per_item ??
    product.prices?.[0]?.price ??
    product.prices?.[0]?.price_per_unit ??
    product.prices?.[0]?.amount;

  if (raw != null) {
    const parsed = typeof raw === 'number' ? raw : parseFloat(String(raw).replace(/[^0-9.]/g, ''));
    if (!isNaN(parsed) && parsed > 0 && parsed <= 999999.99) {
      return Math.round(parsed * 100) / 100;
    }
  }

  // 2. Infer MRP from textual names or packaging common on Indian FMCG goods
  const candidateTexts = [
    product.product_name,
    product.product_name_en,
    product.generic_name,
    product.generic_name_en,
    product.packaging_text,
    product.quantity,
  ].filter(Boolean);

  for (const text of candidateTexts) {
    // Matches "Rs. 20", "MRP: ₹15.00", "₹50", "Rs 10", etc.
    const m1 = /(?:(?:MRP|Rs\.?|INR|₹)\s*[:.\-]?\s*|(?:\bRs\.?\s*))(\d+(?:\.\d{1,2})?)/i.exec(text);
    if (m1) {
      const parsed = parseFloat(m1[1]);
      if (!isNaN(parsed) && parsed > 0 && parsed <= 999999.99) {
        return Math.round(parsed * 100) / 100;
      }
    }
    // Matches "10/-", "20 rupees", etc.
    const m2 = /\b(\d+(?:\.\d{1,2})?)\s*(?:\/[-–]|rupees?\b)/i.exec(text);
    if (m2) {
      const parsed = parseFloat(m2[1]);
      if (!isNaN(parsed) && parsed > 0 && parsed <= 999999.99) {
        return Math.round(parsed * 100) / 100;
      }
    }
  }

  return 0.00;
}

export async function fetchFromOpenFoodFacts(barcode, { fetchFn = fetch, timeoutMs = DEFAULT_TIMEOUT_MS } = {}) {
  try {
    const url = `${OFF_BASE_URL}/${encodeURIComponent(barcode)}.json`;
    const response = await fetchFn(url, {
      headers: {
        'User-Agent': USER_AGENT,
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(timeoutMs),
    });

    if (!response || !response.ok) {
      return null;
    }

    const body = await response.json();
    if (!body || body.status !== 1 || !body.product) {
      return null;
    }

    const name = formatProductName(body.product, barcode);
    const mrp = extractProductMrp(body.product);
    const brand = (
      body.product.brands ||
      body.product.brand_owner ||
      body.product.brands_tags?.[0] ||
      ''
    ).split(',')[0].replace(/^en:/, '').trim() || null;
    const imageUrl = body.product.image_url ||
      body.product.image_front_url ||
      body.product.image_small_url ||
      null;
    const category = (
      body.product.categories ||
      body.product.categories_tags?.[0] ||
      ''
    ).split(',')[0].replace(/^en:/, '').trim() || null;
    const quantity = (body.product.quantity || '').trim() || null;

    return {
      barcode,
      name,
      mrp,
      brand,
      imageUrl,
      category,
      quantity,
    };
  } catch (error) {
    // Network error, abort timeout, or parse failure - return null for smooth 404 fallback
    return null;
  }
}
