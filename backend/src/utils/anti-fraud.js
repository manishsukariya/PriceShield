const THIRTY_ONE_DAYS_MS = 31 * 24 * 60 * 60 * 1000;
const FUTURE_SKEW_MS = 15 * 60 * 1000;

/**
 * Normalizes email addresses for duplicate-account and corroboration risk scoring.
 * - Lowercases domain and local part.
 * - Strips `+alias` suffixes across providers.
 * - For Gmail / Googlemail, strips dots in the local part and normalizes domain to `gmail.com`.
 */
export function normalizeCanonicalEmail(email) {
  if (typeof email !== 'string') return '';
  const trimmed = email.trim().toLowerCase();
  const atIndex = trimmed.lastIndexOf('@');
  if (atIndex <= 0 || atIndex === trimmed.length - 1) return trimmed;

  let local = trimmed.slice(0, atIndex);
  let domain = trimmed.slice(atIndex + 1);

  const plusIndex = local.indexOf('+');
  if (plusIndex !== -1) {
    local = local.slice(0, plusIndex);
  }

  if (domain === 'gmail.com' || domain === 'googlemail.com') {
    domain = 'gmail.com';
    local = local.replace(/\./g, '');
  }

  return `${local}@${domain}`;
}

export function isValidRetailBarcode(barcode) {
  if (typeof barcode !== 'string') return false;
  const clean = barcode.trim();
  if (!/^[A-Za-z0-9-]{6,32}$/.test(clean)) return false;
  // Reject repeated identical character strings like 00000000 or 111111
  const stripped = clean.replace(/-/g, '');
  if (stripped.length < 6) return false;
  if (/^(.)\1+$/.test(stripped)) return false;
  return true;
}

export function isValidUtrNumber(utr) {
  if (typeof utr !== 'string') return false;
  const clean = utr.trim().toUpperCase();
  if (!/^[A-Z0-9]{8,35}$/.test(clean)) return false;
  if (/^(.)\1+$/.test(clean)) return false;
  return true;
}

export function isValidUpiVpa(vpa) {
  if (typeof vpa !== 'string') return false;
  const clean = vpa.trim().toLowerCase();
  return /^[a-z0-9.\-_]{2,100}@[a-z0-9]{2,30}$/.test(clean);
}

function normalizeStoreText(value) {
  return String(value ?? '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function computeStoreFingerprint({ merchantVpa, merchantName, address }) {
  const cleanVpa = typeof merchantVpa === 'string' ? merchantVpa.trim().toLowerCase() : '';
  if (cleanVpa && isValidUpiVpa(cleanVpa)) {
    return `vpa:${cleanVpa}`;
  }
  const normName = normalizeStoreText(merchantName);
  const normAddr = normalizeStoreText(address).slice(0, 80);
  if (!normName || !normAddr) return null;
  return `store:${normName}|${normAddr}`;
}

/**
 * Classifies complaint evidence confidence level.
 * PACKET_MRP is strictly required for any non-UNVERIFIED level.
 */
export function classifyEvidenceConfidence({ evidence = [] } = {}) {
  const items = Array.isArray(evidence) ? evidence : [];
  const hasPacketMrp = items.some((item) => item?.role === 'PACKET_MRP');
  if (!hasPacketMrp) {
    return 'UNVERIFIED';
  }
  const hasItemizedBill = items.some((item) => item?.role === 'ITEMIZED_BILL');
  const hasVideoProof = items.some(
    (item) => item?.role === 'VIDEO_PROOF' && String(item?.mediaType ?? '').toUpperCase() === 'VIDEO',
  );
  if (hasItemizedBill || hasVideoProof) {
    return 'STRONG';
  }
  const hasPaymentProof = items.some((item) => item?.role === 'PAYMENT_PROOF');
  if (hasPaymentProof) {
    return 'BASIC';
  }
  return 'UNVERIFIED';
}

export function validatePurchaseDateBounds(purchaseDate, nowMs = Date.now()) {
  if (!purchaseDate) return { valid: true };
  const ts = purchaseDate instanceof Date ? purchaseDate.getTime() : new Date(purchaseDate).getTime();
  if (!Number.isFinite(ts)) {
    return { valid: false, message: 'Purchase date is invalid.' };
  }
  if (ts > nowMs + FUTURE_SKEW_MS) {
    return { valid: false, message: 'Purchase date cannot be in the future.' };
  }
  if (ts < nowMs - THIRTY_ONE_DAYS_MS) {
    return { valid: false, message: 'Purchase date cannot be older than 30 days.' };
  }
  return { valid: true };
}

export function computeComplaintRisk({
  confidenceLevel,
  paymentMethod,
  merchantVpa,
  mrp,
  chargedPrice,
  latitude,
  longitude,
  hasDuplicateCanonicalAccount = false,
  recentUserComplaintsCount = 0,
  sameUserSameStoreCount = 0,
}) {
  let riskScore = 0;
  const riskFlags = [];

  if (confidenceLevel === 'UNVERIFIED') {
    riskScore += 25;
    riskFlags.push('UNVERIFIED_CLAIM');
  }
  if (hasDuplicateCanonicalAccount) {
    riskScore += 20;
    riskFlags.push('DUPLICATE_CANONICAL_EMAIL_ACCOUNT');
  }
  if (mrp > 0 && chargedPrice > mrp * 3) {
    riskScore += 20;
    riskFlags.push('EXTREME_OVERCHARGE_RATIO');
  }
  if (recentUserComplaintsCount >= 3) {
    riskScore += 15;
    riskFlags.push('HIGH_FREQUENCY_REPORTER');
  }
  if (paymentMethod === 'UPI' && !merchantVpa) {
    riskScore += 10;
    riskFlags.push('MISSING_MERCHANT_VPA');
  }
  if (latitude == null || longitude == null) {
    riskScore += 10;
    riskFlags.push('NO_GPS_METADATA');
  }
  if (sameUserSameStoreCount > 0) {
    riskScore += 15;
    riskFlags.push('REPEAT_STORE_SAME_REPORTER');
  }

  return {
    riskScore: Math.min(100, riskScore),
    riskFlags,
  };
}
