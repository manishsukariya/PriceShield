/**
 * Service to fetch product information from Open Food Facts, sister Open Facts
 * APIs (Beauty/Products), Open Prices INR feeds, and OFF image Cloud Vision OCR JSONs.
 */

import { inferFmcgMrp } from './indian-fmcg-heuristics.js';

const OFF_BASE_URL = 'https://world.openfoodfacts.org/api/v2/product';
const OBF_BASE_URL = 'https://world.openbeautyfacts.org/api/v2/product';
const OPF_BASE_URL = 'https://world.openproductsfacts.org/api/v2/product';
const OPEN_PRICES_BASE_URL = 'https://prices.openfoodfacts.org/api/v1/prices';

const IMAGE_CDN_BY_SOURCE = {
  open_food_facts: 'https://images.openfoodfacts.org/images/products',
  open_beauty_facts: 'https://images.openbeautyfacts.org/images/products',
  open_products_facts: 'https://images.openproductsfacts.org/images/products',
};

const DEFAULT_TIMEOUT_MS = 5000;
const DEFAULT_ENRICH_TIMEOUT_MS = 12000;
const USER_AGENT = 'PriceShield - Android - Version 1.0 (support@priceshield.app)';

function roundMrp(value) {
  const num = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(num) || num <= 0 || num > 999999.99) {
    return 0;
  }
  return Math.round(num * 100) / 100;
}

function parseQuantityInBaseUnits(quantityText) {
  if (!quantityText || typeof quantityText !== 'string') return null;
  const match = /(\d+(?:\.\d+)?)\s*(kg|g|gm|gms|l|ltr|litre|litres|ml)\b/i.exec(quantityText);
  if (!match) return null;
  const amount = parseFloat(match[1]);
  if (!Number.isFinite(amount) || amount <= 0) return null;
  const rawUnit = match[2].toLowerCase();
  if (rawUnit === 'kg' || rawUnit === 'l' || rawUnit === 'ltr' || rawUnit.startsWith('litre')) {
    return { value: amount * 1000, kind: rawUnit === 'kg' ? 'mass' : 'volume' };
  }
  return {
    value: amount,
    kind: rawUnit === 'ml' ? 'volume' : 'mass',
  };
}

function isUnitRateSuffix(afterText) {
  return /^\s*(?:\/[-–]\s*)?(?:per\s*(?:\d+\s*)?(?:g|gm|gms|gram|grams|kg|ml|l|ltr|litre|litres|unit|pc|pcs)\b|\/\s*(?:\d+\s*)?(?:g|gm|gms|kg|ml|l|ltr|unit|pc)\b)/i.test(
    afterText,
  );
}

function isQuantityOrOtherSuffix(afterText) {
  return /^\s*(?:g|gm|gms|kg|mg|mcg|ml|l|ltr|kcal|cal|%|mm|cm|m)\b/i.test(afterText);
}

function hasUnexpectedAlphaSuffix(afterText) {
  if (!/^[A-Za-z]/.test(afterText)) return false;
  return !/^(?:rs|inr|rupees?|only)\b/i.test(afterText);
}

function isDateOrFraction(fullText, matchIndex, matchedDigits) {
  const prevChar = matchIndex > 0 ? fullText[matchIndex - 1] : '';
  const endIdx = matchIndex + matchedDigits.length;
  const nextChar = fullText[endIdx] ?? '';
  if (prevChar === '/') return true;
  if (nextChar === '/') {
    const afterSlash = fullText[endIdx + 1] ?? '';
    // Allow Indian MRP notation like "10/-" or "10/–", reject dates/fractions like "17/08"
    if (afterSlash !== '-' && afterSlash !== '–') {
      return true;
    }
  }
  if (prevChar === '.' && !/\.\d{1,2}$/.test(fullText.slice(0, matchIndex))) return true;
  return false;
}

function isPromoLine(line) {
  if (/\b(?:m\.?\s*r\.?\s*p|maximum\s*retail\s*price|incl\.?\s*of\s*all\s*taxes)\b/i.test(line)) {
    return false;
  }
  return /\b(?:scratch\s*card|cashback|paytm|google\s*pay|gpay|phonepe|voucher|coupon|win\s+|offer|worth|off\s+on)\b/i.test(
    line,
  );
}

/**
 * Extracts Indian retail MRP from product titles, packaging descriptions, or raw OCR text.
 * Rejects unit rates (e.g. "Rs.0.25 per g"), dates, promo vouchers, and gram/ml quantities,
 * while supporting both explicit MRP labels ("MRP Rs. 10/-", "20rs") and Legal Metrology
 * inkjet price+USP blocks (e.g. "35.00\nRs.0.25 per g").
 */
export function extractMrpFromText(text, { quantityText = '' } = {}) {
  if (!text || typeof text !== 'string') return 0.0;
  const lines = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  if (lines.length === 0) return 0.0;

  // Pass 1: Explicit MRP / Maximum Retail Price label on same line or next line
  const mrpLabelRegex = /(?:M\.?\s*R\.?\s*P\.?|MAX(?:IMUM)?\.?\s*RETAIL\s*PRICE)\b/i;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const labelMatch = mrpLabelRegex.exec(line);
    if (!labelMatch) continue;

    const tail = line.slice(labelMatch.index + labelMatch[0].length);
    const sameLineCandidates = tail.matchAll(
      /(?:Rs\.?|INR|₹|P\.?|R)?\s*[:.\-=]?\s*(\d{1,5}(?:\.\d{1,2})?)/gi,
    );
    for (const candidate of sameLineCandidates) {
      const digits = candidate[1];
      const matchEnd = candidate.index + candidate[0].length;
      const digitStart = candidate.index + candidate[0].lastIndexOf(digits);
      const after = tail.slice(matchEnd);
      if (isDateOrFraction(tail, digitStart, digits)) continue;
      if (hasUnexpectedAlphaSuffix(after) || isUnitRateSuffix(after) || isQuantityOrOtherSuffix(after)) continue;
      const rounded = roundMrp(parseFloat(digits));
      if (rounded >= 1) return rounded;
    }

    if (i + 1 < lines.length) {
      const nextLine = lines[i + 1];
      const nextMatch =
        /^(?:Rs\.?|INR|₹)?\s*[:.\-=]?\s*(\d{1,5}(?:\.\d{1,2})?)\s*(?:\/[-–]|only)?(?:\s*\(?incl\.?\s*of\s*all\s*taxes\)?)?$/i.exec(
          nextLine,
        );
      if (nextMatch) {
        const rounded = roundMrp(parseFloat(nextMatch[1]));
        if (rounded >= 1) return rounded;
      }
    }
  }

  // Pass 2: Explicit Indian currency token (₹, Rs., INR, 20rs, 10/-, 20 rupees)
  for (const line of lines) {
    if (isPromoLine(line)) continue;

    for (const match of line.matchAll(/(?:Rs\.?|INR|₹)\s*[:.\-]?\s*(\d{1,5}(?:\.\d{1,2})?)/gi)) {
      const digits = match[1];
      const digitStart = match.index + match[0].lastIndexOf(digits);
      const after = line.slice(match.index + match[0].length);
      if (isDateOrFraction(line, digitStart, digits)) continue;
      if (hasUnexpectedAlphaSuffix(after) || isUnitRateSuffix(after) || isQuantityOrOtherSuffix(after)) continue;
      const rounded = roundMrp(parseFloat(digits));
      if (rounded >= 1) return rounded;
    }

    for (const match of line.matchAll(/\b(\d{1,5}(?:\.\d{1,2})?)\s*(?:\/[-–]|rupees?\b|rs\b\.?)/gi)) {
      const digits = match[1];
      const after = line.slice(match.index + match[0].length);
      if (isUnitRateSuffix(after) || isQuantityOrOtherSuffix(after)) continue;
      const rounded = roundMrp(parseFloat(digits));
      if (rounded >= 1) return rounded;
    }
  }

  // Pass 3: Legal Metrology inkjet MRP line directly adjacent to Unit Sale Price ("Rs.0.25 per g")
  const parsedQty = parseQuantityInBaseUnits(quantityText);
  const uspRegex =
    /(?:Rs\.?|₹|INR)\s*[:.\-]?\s*(\d+(?:\.\d{1,3})?)\s*(?:\/[-–])?\s*(?:per\s*(?:\d+\s*)?(?:g|gm|gms|kg|ml|l|ltr|litre|unit)|\/\s*(?:\d+\s*)?(?:g|gm|kg|ml|l)\b)/i;

  for (let i = 0; i < lines.length; i++) {
    const uspMatch = uspRegex.exec(lines[i]);
    if (!uspMatch) continue;
    const unitRate = parseFloat(uspMatch[1]);
    if (!Number.isFinite(unitRate) || unitRate <= 0) continue;

    const neighborIndexes = [i - 1, i - 2, i + 1].filter((idx) => idx >= 0 && idx < lines.length);
    for (const idx of neighborIndexes) {
      const candidateLine = lines[idx];
      const standalone = /^(?:₹|Rs\.?)?\s*(\d{1,5}(?:\.\d{2})?)\s*(?:\/[-–])?$/i.exec(candidateLine);
      if (!standalone) continue;

      const amount = roundMrp(parseFloat(standalone[1]));
      if (amount < 1 || amount <= unitRate) continue;

      const hasTwoDecimals = /\.\d{2}$/.test(standalone[1]);
      if (parsedQty) {
        const implied = unitRate * parsedQty.value;
        const ratio = implied > 0 ? amount / implied : 0;
        if (ratio >= 0.5 && ratio <= 2.0) {
          return amount;
        }
      }
      if (hasTwoDecimals && amount <= 9999) {
        return amount;
      }
    }
  }

  return 0.0;
}

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

export function isIndianCurrency(currency) {
  if (!currency) return false;
  const clean = String(currency).trim().toUpperCase();
  return clean === 'INR' || clean === '₹' || clean === 'RS' || clean === 'RS.' || clean === 'RUPEE' || clean === 'RUPEES';
}

export function hasForeignCurrency(text) {
  if (!text) return false;
  return /[$€£¥₩₽₫฿]|\b(?:USD|EUR|GBP|AUD|CAD|SGD|AED|JPY|CNY|CHF|NZD|BRL|ZAR|RUB|THB)\b/i.test(String(text));
}

export function extractProductMrp(product) {
  if (!product || typeof product !== 'object') return 0.0;

  const topCurrency = product.currency || product.currency_code || product.price_currency || product.price_currency_code;
  if (topCurrency && (!isIndianCurrency(topCurrency) || hasForeignCurrency(topCurrency))) {
    // Explicit foreign currency declared on product (e.g. EUR, USD). Never treat as Indian MRP.
    return 0.0;
  }

  // 1. Direct numeric price fields in embedded prices array (strictly INR)
  if (Array.isArray(product.prices)) {
    for (const item of product.prices) {
      if (!item || typeof item !== 'object') continue;
      const itemCurrency = item.currency || item.currency_code;
      if (itemCurrency) {
        if (!isIndianCurrency(itemCurrency) || hasForeignCurrency(itemCurrency)) {
          continue;
        }
      } else if (topCurrency && !isIndianCurrency(topCurrency)) {
        continue;
      }
      const rawItemPrice =
        item.price_without_discount ??
        item.price ??
        item.price_per_unit ??
        item.amount;
      if (rawItemPrice != null && !hasForeignCurrency(rawItemPrice)) {
        const parsed = typeof rawItemPrice === 'number'
          ? rawItemPrice
          : parseFloat(String(rawItemPrice).replace(/[^0-9.]/g, ''));
        const rounded = roundMrp(parsed);
        if (rounded > 0) {
          return rounded;
        }
      }
    }
  }

  // 2. Direct numeric price fields on the product object
  const raw =
    product.price_without_discount ??
    product.price ??
    product.mrp ??
    product.product_mrp ??
    product.price_per_item;

  if (raw != null && !hasForeignCurrency(raw)) {
    const parsed = typeof raw === 'number' ? raw : parseFloat(String(raw).replace(/[^0-9.]/g, ''));
    const rounded = roundMrp(parsed);
    if (rounded > 0) {
      return rounded;
    }
  }

  // 3. Infer MRP from textual names, labels, or packaging fields
  const candidateTexts = [
    product.packaging_text_en,
    product.packaging_text,
    product.product_name_en,
    product.product_name,
    product.generic_name_en,
    product.generic_name,
    product.labels,
    product.packaging,
  ].filter(Boolean);

  for (const text of candidateTexts) {
    if (hasForeignCurrency(text) && !/\b(?:INR|₹|Rs\.?)\b/i.test(text)) {
      continue;
    }
    const extracted = extractMrpFromText(String(text), { quantityText: product.quantity });
    if (extracted > 0) {
      return extracted;
    }
  }

  return 0.0;
}

function resolveImageDirectoryUrl(product, barcode, source) {
  const sampleImageUrl =
    product.image_url ||
    product.image_front_url ||
    product.image_small_url ||
    product.image_packaging_url ||
    '';
  if (typeof sampleImageUrl === 'string' && sampleImageUrl.startsWith('http')) {
    const lastSlash = sampleImageUrl.lastIndexOf('/');
    if (lastSlash > 8) {
      return sampleImageUrl.slice(0, lastSlash);
    }
  }

  const cdnBase = IMAGE_CDN_BY_SOURCE[source] ?? IMAGE_CDN_BY_SOURCE.open_food_facts;
  const digits = String(barcode ?? '').replace(/\D/g, '');
  if (!digits) return null;
  if (digits.length <= 8) {
    return `${cdnBase}/${digits}`;
  }
  const padded = digits.length < 13 ? digits.padStart(13, '0') : digits;
  const partitioned = padded.replace(/^(\d{3})(\d{3})(\d{3})(.*)$/, '$1/$2/$3/$4');
  return `${cdnBase}/${partitioned}`;
}

function selectOcrCandidateImageIds(product) {
  const images = product?.images;
  if (!images || typeof images !== 'object') return [];

  const prioritized = [];
  const seen = new Set();
  const pushId = (rawId) => {
    if (rawId == null) return;
    const id = String(rawId).trim();
    if (!/^\d+$/.test(id) || seen.has(id)) return;
    seen.add(id);
    prioritized.push(id);
  };

  // Packaging images are highest yield for Indian back-of-pack MRP blocks
  const keys = Object.keys(images);
  for (const prefix of ['packaging', 'nutrition', 'ingredients', 'front']) {
    for (const key of keys) {
      if (key.startsWith(prefix) && images[key]?.imgid != null) {
        pushId(images[key].imgid);
      }
    }
  }

  // Remaining raw numeric image IDs (back packets often aren't selected into front/ingredients)
  for (const key of keys) {
    if (/^\d+$/.test(key)) {
      pushId(key);
    }
  }

  return prioritized.slice(0, 3);
}

function raceFirstPositiveMrp(promises) {
  if (promises.length === 0) return Promise.resolve(0);
  return new Promise((resolve) => {
    let remaining = promises.length;
    let settled = false;
    for (const promise of promises) {
      Promise.resolve(promise)
        .then((value) => {
          if (!settled && value > 0) {
            settled = true;
            resolve(value);
          }
        })
        .catch(() => {})
        .finally(() => {
          remaining -= 1;
          if (!settled && remaining <= 0) {
            resolve(0);
          }
        });
    }
  });
}

async function fetchFromOpenPricesInr(barcode, fetchFn, timeoutMs) {
  try {
    const url = `${OPEN_PRICES_BASE_URL}?product_code=${encodeURIComponent(barcode)}&currency=INR&size=5`;
    const response = await fetchFn(url, {
      headers: {
        'User-Agent': USER_AGENT,
        Accept: 'application/json',
      },
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!response || !response.ok) return 0;

    const payload = await response.json();
    const items = Array.isArray(payload?.items) ? payload.items : [];
    for (const item of items) {
      if (String(item?.currency ?? '').toUpperCase() !== 'INR') continue;
      const rawPrice =
        Number(item?.price_without_discount) > 0
          ? item.price_without_discount
          : item?.price;
      const rounded = roundMrp(rawPrice);
      if (rounded >= 1) {
        return rounded;
      }
    }
    return 0;
  } catch {
    return 0;
  }
}

async function fetchMrpFromOffImageOcr(product, barcode, source, fetchFn, timeoutMs) {
  try {
    const imageIds = selectOcrCandidateImageIds(product);
    if (imageIds.length === 0) return 0;

    const dirUrl = resolveImageDirectoryUrl(product, barcode, source);
    if (!dirUrl) return 0;

    return await raceFirstPositiveMrp(
      imageIds.map(async (id) => {
        const res = await fetchFn(`${dirUrl}/${id}.json`, {
          headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' },
          signal: AbortSignal.timeout(timeoutMs),
        });
        if (!res || !res.ok) return 0;
        const json = await res.json();
        const ocrText = json?.responses?.[0]?.fullTextAnnotation?.text;
        if (!ocrText) return 0;
        return extractMrpFromText(ocrText, { quantityText: product.quantity });
      }),
    );
  } catch {
    return 0;
  }
}

function parseProductPayload(product, barcode, source) {
  const name = formatProductName(product, barcode);
  let mrp = extractProductMrp(product);
  const brand =
    (
      product.brands ||
      product.brand_owner ||
      product.brands_tags?.[0] ||
      ''
    )
      .split(',')[0]
      .replace(/^en:/, '')
      .trim() || null;
  const imageUrl =
    product.image_url ||
    product.image_front_url ||
    product.image_small_url ||
    null;
  const category =
    (
      product.categories ||
      product.categories_tags?.[0] ||
      ''
    )
      .split(',')[0]
      .replace(/^en:/, '')
      .trim() || null;
  const quantity = (product.quantity || '').trim() || null;

  const mrpSource = mrp > 0 ? source : null;

  return {
    barcode,
    name,
    mrp,
    brand,
    imageUrl,
    category,
    quantity,
    source,
    mrpSource,
  };
}

async function fetchFromEndpoint(
  baseUrl,
  source,
  barcode,
  fetchFn,
  timeoutMs,
  enrichTimeoutMs = DEFAULT_ENRICH_TIMEOUT_MS,
) {
  try {
    const url = `${baseUrl}/${encodeURIComponent(barcode)}.json`;
    const response = await fetchFn(url, {
      headers: {
        'User-Agent': USER_AGENT,
        Accept: 'application/json',
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

    const parsed = parseProductPayload(body.product, barcode, source);
    if (parsed.mrp <= 0) {
      const effectiveEnrichTimeout = Math.max(enrichTimeoutMs, timeoutMs);
      const ocrPromise = fetchMrpFromOffImageOcr(
        body.product,
        barcode,
        source,
        fetchFn,
        effectiveEnrichTimeout,
      );
      const openPricesMrp = await fetchFromOpenPricesInr(
        barcode,
        fetchFn,
        Math.min(effectiveEnrichTimeout, 5000),
      );
      if (openPricesMrp > 0) {
        parsed.mrp = openPricesMrp;
        parsed.mrpSource = 'open_prices';
      } else {
        const ocrMrp = await ocrPromise;
        if (ocrMrp > 0) {
          parsed.mrp = ocrMrp;
          parsed.mrpSource = `${source}_ocr`;
        }
      }

      if (parsed.mrp <= 0) {
        const inferred = inferFmcgMrp({
          name: parsed.name,
          brand: parsed.brand || '',
          quantity: parsed.quantity || '',
          barcode,
        });
        if (inferred > 0) {
          parsed.mrp = inferred;
          parsed.mrpSource = 'indian_fmcg_standard';
        }
      }
    }

    return parsed;
  } catch {
    return null;
  }
}

export async function fetchFromOpenFoodFacts(
  barcode,
  {
    fetchFn = fetch,
    timeoutMs = DEFAULT_TIMEOUT_MS,
    enrichTimeoutMs = DEFAULT_ENRICH_TIMEOUT_MS,
  } = {},
) {
  // 1. Primary lookup: Open Food Facts (fastest & largest food/groceries database)
  const primaryResult = await fetchFromEndpoint(
    OFF_BASE_URL,
    'open_food_facts',
    barcode,
    fetchFn,
    timeoutMs,
    enrichTimeoutMs,
  );
  if (primaryResult) {
    return primaryResult;
  }

  // 2. Multi-source fallback: Check Open Beauty Facts (soaps/shampoos) and Open Products Facts
  try {
    const fallbackTimeoutMs = Math.min(4000, timeoutMs);
    const fallbackResults = await Promise.allSettled([
      fetchFromEndpoint(OBF_BASE_URL, 'open_beauty_facts', barcode, fetchFn, fallbackTimeoutMs, enrichTimeoutMs),
      fetchFromEndpoint(OPF_BASE_URL, 'open_products_facts', barcode, fetchFn, fallbackTimeoutMs, enrichTimeoutMs),
    ]);

    for (const res of fallbackResults) {
      if (res.status === 'fulfilled' && res.value) {
        return res.value;
      }
    }
  } catch {
    // Non-blocking fallback
  }

  return null;
}
