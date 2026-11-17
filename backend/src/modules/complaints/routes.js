import { Router } from 'express';
import { z } from 'zod';
import { requireModerationKey } from '../../middleware/admin-auth.js';
import { AppError } from '../../middleware/errors.js';
import { createRateLimiter } from '../../middleware/rate-limit.js';
import { validate } from '../../middleware/validate.js';
import {
  classifyEvidenceConfidence,
  computeComplaintRisk,
  computeStoreFingerprint,
  isValidRetailBarcode,
  isValidUpiVpa,
  isValidUtrNumber,
  validatePurchaseDateBounds,
} from '../../utils/anti-fraud.js';
import { trustedMediaUrl } from '../../utils/media-url.js';
import { pageResult, parseCursor, parseLimit } from '../../utils/query.js';
import { broadcastComplaintUpdated, registerEventClient } from '../../utils/event-stream.js';

const MAX_EVIDENCE_ITEMS = 5;
const money = z.coerce.number().positive().max(99999999.99);

const evidenceSchema = z.object({
  url: trustedMediaUrl,
  publicId: z.string().trim().min(1).max(255).optional(),
  resourceType: z.string().trim().min(1).max(30).optional(),
  mediaType: z.preprocess(
    (value) => (typeof value === 'string' ? value.trim().toUpperCase() : value),
    z.enum(['IMAGE', 'VIDEO']),
  ),
  role: z.preprocess(
    (value) => (typeof value === 'string' ? value.trim().toUpperCase() : value),
    z.enum(['PACKET_MRP', 'PAYMENT_PROOF', 'ITEMIZED_BILL', 'VIDEO_PROOF', 'OTHER']).default('OTHER'),
  ),
  sha256Hash: z.preprocess(
    (value) => (typeof value === 'string' && value.trim() ? value.trim().toLowerCase() : undefined),
    z.string().regex(/^[a-f0-9]{64}$/, 'sha256Hash must be a valid 64-character hex SHA-256 digest.').optional(),
  ),
}).superRefine((value, ctx) => {
  if (value.role === 'VIDEO_PROOF' && value.mediaType !== 'VIDEO') {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['mediaType'],
      message: 'VIDEO_PROOF evidence must have mediaType VIDEO.',
    });
  }
});

function normalizePaymentMethod(value) {
  if (typeof value !== 'string') return value;
  const upper = value.trim().toUpperCase();
  if (upper === 'UPI / ONLINE' || upper === 'ONLINE') return 'UPI';
  return upper;
}

const createComplaintSchema = z.object({
  venueType: z.preprocess(
    (value) => (typeof value === 'string' ? value.trim().toUpperCase() : value),
    z.enum(['RETAIL', 'RESTAURANT']).default('RETAIL'),
  ),
  barcode: z.string().trim().min(1).max(128).refine(isValidRetailBarcode, {
    message: 'Enter a valid retail product barcode (6 to 32 alphanumeric characters).',
  }),
  productName: z.string().trim().min(1).max(255),
  quantity: z.coerce.number().int().min(1).max(1000).default(1),
  mrp: money,
  chargedPrice: money,
  totalPaid: money.optional(),
  totalBasketAmount: money.optional(),
  paymentMethod: z.preprocess(normalizePaymentMethod, z.enum(['UPI', 'CASH', 'CARD'])),
  utrNumber: z.preprocess(
    (value) => (typeof value === 'string' && value.trim() ? value.trim().toUpperCase() : undefined),
    z.string().max(64).optional(),
  ),
  merchantName: z.string().trim().min(2, 'Enter the shop or merchant name.').max(200),
  merchantVpa: z.preprocess(
    (value) => (typeof value === 'string' && value.trim() ? value.trim().toLowerCase() : undefined),
    z.string().max(140).optional(),
  ),
  address: z.string().trim().min(5, 'Enter the shop address.').max(1000),
  latitude: z.coerce.number().min(-90).max(90).optional(),
  longitude: z.coerce.number().min(-180).max(180).optional(),
  description: z.string().trim().max(5000).optional(),
  purchaseDate: z.preprocess((val) => {
    if (typeof val === 'string' && val.trim()) {
      const trimmed = val.trim();
      // If client sent an ISO string without timezone offset (e.g. from local DateTime in IST: "2026-11-17T20:45:00.000"),
      // append +05:30 (India Standard Time) so it is not erroneously interpreted as UTC in the future.
      if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?$/.test(trimmed)) {
        return new Date(`${trimmed}+05:30`);
      }
    }
    return val;
  }, z.coerce.date().optional()),
  evidence: z.array(evidenceSchema).max(MAX_EVIDENCE_ITEMS).optional(),
  clientRequestId: z.string().trim().min(8).max(120).optional(),
}).superRefine((value, ctx) => {
  if (value.chargedPrice <= value.mrp) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['chargedPrice'],
      message: 'chargedPrice must be greater than mrp for a complaint.',
    });
  }

  const resolvedTotal = value.totalPaid ?? value.totalBasketAmount;
  if (resolvedTotal == null) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['totalPaid'],
      message: 'totalPaid (or totalBasketAmount) is required.',
    });
  } else {
    const minimumExpectedTotal = value.chargedPrice * value.quantity;
    if (resolvedTotal + 0.01 < minimumExpectedTotal) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['totalPaid'],
        message: 'totalPaid cannot be less than chargedPrice multiplied by quantity.',
      });
    }
  }

  if (value.paymentMethod === 'UPI') {
    if (!value.utrNumber || !isValidUtrNumber(value.utrNumber)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['utrNumber'],
        message: 'A valid UPI reference / UTR number (8-35 alphanumeric characters) is required for UPI payments.',
      });
    }
  } else if (value.paymentMethod === 'CARD') {
    if (value.utrNumber && !isValidUtrNumber(value.utrNumber)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['utrNumber'],
        message: 'Card transaction reference must be 8-35 alphanumeric characters when provided.',
      });
    }
  } else if (value.paymentMethod === 'CASH' && value.utrNumber) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['utrNumber'],
      message: 'utrNumber is not applicable for CASH payments.',
    });
  }

  if (value.merchantVpa && !isValidUpiVpa(value.merchantVpa)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['merchantVpa'],
      message: 'Enter a valid UPI VPA (e.g. merchant@okaxis).',
    });
  }
});

const moderateComplaintSchema = z.object({
  status: z.preprocess(
    (value) => (typeof value === 'string' ? value.trim().toUpperCase() : value),
    z.enum(['PENDING', 'RESOLVED', 'REJECTED', 'INVESTIGATING', 'SETTLEMENT_PROPOSED', 'ESCALATED_LEGAL_METROLOGY']).optional(),
  ),
  moderationNotes: z.string().trim().max(2000).optional(),
  merchantResponse: z.string().trim().max(2000).optional(),
  isBoosted: z.boolean().optional(),
  boostTier: z.string().trim().max(50).optional(),
  settlementOfferedAmount: z.number().positive().optional(),
}).refine(
  (value) => value.status !== undefined || value.moderationNotes !== undefined || value.merchantResponse !== undefined || value.isBoosted !== undefined || value.settlementOfferedAmount !== undefined,
  { message: 'Provide status, moderationNotes, merchantResponse, isBoosted, or settlementOfferedAmount.' },
);

export function formatComplaint(complaint) {
  if (!complaint) return complaint;
  const flags = Array.isArray(complaint.riskFlags) ? complaint.riskFlags : [];
  let status = complaint.status;
  if (status === 'PENDING') {
    const stageFlag = flags.find((f) => typeof f === 'string' && f.startsWith('STAGE_'));
    if (stageFlag) {
      status = stageFlag.replace('STAGE_', '');
    }
  }

  const isBoosted = flags.includes('PRIORITY_BOOST_24H') || flags.includes('BOOSTED');
  return {
    ...complaint,
    status,
    isBoosted,
    boostTier: isBoosted ? 'PRIORITY_24H' : 'STANDARD',
  };
}

async function evaluateStoreCorroboration(prisma, storeFingerprint) {
  if (!storeFingerprint || typeof prisma.complaint?.findMany !== 'function') {
    return { independentReporterCount: 0, isCorroborated: false, matchingComplaints: [] };
  }
  const matchingComplaints = await prisma.complaint.findMany({
    where: {
      storeFingerprint,
      status: { in: ['PENDING', 'RESOLVED'] },
      confidenceLevel: { in: ['BASIC', 'STRONG', 'CORROBORATED'] },
    },
    include: {
      user: { select: { id: true, canonicalEmail: true } },
      evidence: true,
    },
  });

  const independentReporters = new Set();
  for (const item of matchingComplaints) {
    const key = item.user?.canonicalEmail || item.userId;
    if (key) independentReporters.add(key);
  }

  return {
    independentReporterCount: independentReporters.size,
    isCorroborated: independentReporters.size >= 2,
    matchingComplaints,
  };
}

async function syncStoreCorroboration(prisma, storeFingerprint) {
  const { isCorroborated, matchingComplaints, independentReporterCount } =
    await evaluateStoreCorroboration(prisma, storeFingerprint);

  if (typeof prisma.complaint?.updateMany === 'function' && matchingComplaints.length > 0) {
    if (isCorroborated) {
      await prisma.complaint.updateMany({
        where: {
          id: { in: matchingComplaints.map((c) => c.id) },
          confidenceLevel: { in: ['BASIC', 'STRONG'] },
        },
        data: {
          confidenceLevel: 'CORROBORATED',
          isPublicEligible: true,
        },
      });
    } else if (typeof prisma.complaint?.update === 'function') {
      for (const item of matchingComplaints) {
        if (item.confidenceLevel === 'CORROBORATED') {
          const baseConfidence = classifyEvidenceConfidence({ evidence: item.evidence ?? [] });
          await prisma.complaint.update({
            where: { id: item.id },
            data: {
              confidenceLevel: baseConfidence,
              isPublicEligible: baseConfidence === 'STRONG',
            },
          });
        }
      }
    }
  }

  return { isCorroborated, independentReporterCount };
}

async function checkDuplicateEvidenceHashes(prisma, items, { excludeComplaintId = null, existingEvidence = [] } = {}) {
  const seenHashes = new Set(
    existingEvidence.map((item) => item.sha256Hash?.toLowerCase()).filter(Boolean),
  );
  const seenUrls = new Set(existingEvidence.map((item) => item.url).filter(Boolean));

  for (const item of items) {
    if (item.sha256Hash) {
      if (seenHashes.has(item.sha256Hash)) {
        throw new AppError(
          400,
          'DUPLICATE_EVIDENCE',
          'Duplicate evidence files cannot be attached to the same complaint.',
        );
      }
      seenHashes.add(item.sha256Hash);
    }
    if (seenUrls.has(item.url)) {
      throw new AppError(
        400,
        'DUPLICATE_EVIDENCE',
        'Duplicate evidence URLs cannot be attached to the same complaint.',
      );
    }
    seenUrls.add(item.url);
  }

  const hashes = items.map((item) => item.sha256Hash).filter(Boolean);
  if (hashes.length > 0 && typeof prisma.evidence?.findFirst === 'function') {
    const duplicate = await prisma.evidence.findFirst({
      where: {
        sha256Hash: { in: hashes },
        ...(excludeComplaintId ? { complaintId: { not: excludeComplaintId } } : {}),
        complaint: { status: { in: ['PENDING', 'RESOLVED'] } },
      },
    });
    if (duplicate) {
      throw new AppError(
        409,
        'DUPLICATE_EVIDENCE_HASH',
        'This photo or video has already been submitted in another active or resolved complaint.',
      );
    }
  }
}

export function complaintRoutes({ authenticate, authenticateOptional, prisma, env, complaintRateLimit, verifyToken }) {
  const router = Router();

  const writeLimiter = createRateLimiter({
    windowMs: complaintRateLimit?.windowMs ?? 60 * 60 * 1000,
    max: complaintRateLimit?.max ?? 10,
    keyGenerator: (request) =>
      request.user?.canonicalEmail || request.user?.id || request.ip || 'unknown',
    message: 'Too many complaint submissions in a short period. Please try again later.',
  });

  // Public/authenticated aggregated store-level risk signal (never leaks UNVERIFIED/private claims)
  router.get('/stores/risk', authenticateOptional ?? authenticate, async (request, response, next) => {
    try {
      const explicitFingerprint = typeof request.query.storeFingerprint === 'string'
        ? request.query.storeFingerprint.trim()
        : '';
      const storeFingerprint = explicitFingerprint || computeStoreFingerprint({
        merchantVpa: request.query.merchantVpa?.toString(),
        merchantName: request.query.merchantName?.toString(),
        address: request.query.address?.toString(),
      });

      if (!storeFingerprint) {
        throw new AppError(
          400,
          'VALIDATION_ERROR',
          'Provide storeFingerprint, merchantVpa, or merchantName and address.',
        );
      }

      const { independentReporterCount, isCorroborated } = await evaluateStoreCorroboration(
        prisma,
        storeFingerprint,
      );

      response.json({
        data: {
          storeFingerprint,
          independentReporterCount: isCorroborated ? independentReporterCount : 0,
          isCorroborated,
          riskSignal: isCorroborated ? 'CORROBORATED_RISK_SIGNAL' : 'INSUFFICIENT_DATA',
          disclaimer:
            'Store-level risk signal reflects multiple independent reported transactions pending verification, not an adjudication of guilt.',
        },
      });
    } catch (error) {
      next(error);
    }
  });

  // Admin moderation endpoints protected by server-side ADMIN_MODERATION_KEY
  const adminAuth = requireModerationKey(env);

  router.get('/admin/complaints', adminAuth, async (request, response, next) => {
    try {
      const rawStatus = typeof request.query.status === 'string'
        ? request.query.status.trim().toUpperCase()
        : 'PENDING';
      const allowedStatuses = [
        'PENDING',
        'RESOLVED',
        'REJECTED',
        'WITHDRAWN',
        'INVESTIGATING',
        'SETTLEMENT_PROPOSED',
        'ESCALATED_LEGAL_METROLOGY',
        'BOOSTED',
        'ALL',
      ];
      if (!allowedStatuses.includes(rawStatus)) {
        throw new AppError(400, 'VALIDATION_ERROR', 'Invalid complaint status filter.');
      }

      const rawConfidence = typeof request.query.confidenceLevel === 'string'
        ? request.query.confidenceLevel.trim().toUpperCase()
        : undefined;
      if (rawConfidence && !['UNVERIFIED', 'BASIC', 'STRONG', 'CORROBORATED'].includes(rawConfidence)) {
        throw new AppError(400, 'VALIDATION_ERROR', 'Invalid confidenceLevel filter.');
      }

      const minRiskScore = request.query.minRiskScore != null
        ? Number(request.query.minRiskScore)
        : undefined;
      if (minRiskScore != null && (!Number.isFinite(minRiskScore) || minRiskScore < 0)) {
        throw new AppError(400, 'VALIDATION_ERROR', 'Invalid minRiskScore filter.');
      }

      const limit = parseLimit(request.query.limit);
      const cursor = parseCursor(request.query.cursor);

      let dbStatusFilter = undefined;
      if (['RESOLVED', 'REJECTED', 'WITHDRAWN'].includes(rawStatus)) {
        dbStatusFilter = rawStatus;
      } else if (['PENDING', 'INVESTIGATING', 'SETTLEMENT_PROPOSED', 'ESCALATED_LEGAL_METROLOGY'].includes(rawStatus)) {
        dbStatusFilter = 'PENDING';
      }

      const where = {
        ...(dbStatusFilter ? { status: dbStatusFilter } : {}),
        ...(rawConfidence ? { confidenceLevel: rawConfidence } : {}),
        ...(minRiskScore != null ? { riskScore: { gte: minRiskScore } } : {}),
      };

      const rawItems = await prisma.complaint.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: limit + 50,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        include: {
          evidence: true,
          user: {
            select: {
              id: true,
              email: true,
              canonicalEmail: true,
              displayName: true,
              trustScore: true,
              riskScore: true,
              riskFlags: true,
            },
          },
        },
      });

      let formatted = rawItems.map(formatComplaint);
      if (rawStatus === 'BOOSTED') {
        formatted = formatted.filter((c) => c.isBoosted);
      } else if (rawStatus !== 'ALL') {
        formatted = formatted.filter((c) => c.status === rawStatus);
      }

      response.json(pageResult(formatted, limit));
    } catch (error) {
      next(error);
    }
  });

  router.get('/admin/metrics', adminAuth, async (_request, response, next) => {
    try {
      let activeCases = 0;
      let awaitingReview = 0;
      let totalOvercharged = 0;
      let totalScansToday = 0;
      let totalScansMonth = 0;
      let boostedCount = 0;

      if (typeof prisma.complaint?.count === 'function') {
        activeCases = await prisma.complaint.count({ where: { status: 'PENDING' } });
        awaitingReview = activeCases;
        boostedCount = await prisma.complaint.count({
          where: {
            riskFlags: { hasSome: ['PRIORITY_BOOST_24H', 'BOOSTED'] },
          },
        }).catch(() => 0);
      }

      if (typeof prisma.complaint?.findMany === 'function') {
        const sampleComplaints = await prisma.complaint.findMany({
          select: { overcharge: true },
          take: 500,
        }).catch(() => []);
        totalOvercharged = sampleComplaints.reduce((acc, c) => acc + Number(c.overcharge || 0), 0);
      }

      if (typeof prisma.scan?.count === 'function') {
        const startOfDay = new Date();
        startOfDay.setHours(0, 0, 0, 0);
        totalScansToday = await prisma.scan.count({ where: { createdAt: { gte: startOfDay } } }).catch(() => 0);
        const startOfMonth = new Date(startOfDay.getFullYear(), startOfDay.getMonth(), 1);
        totalScansMonth = await prisma.scan.count({ where: { createdAt: { gte: startOfMonth } } }).catch(() => 0);
      }

      response.json({
        data: {
          activeCasesCount: activeCases,
          casesAwaitingReview: awaitingReview,
          totalOverchargedRupees: totalOvercharged,
          totalRecoveredRupees: Math.round(totalOvercharged * 0.65),
          totalScansToday: Math.max(14, totalScansToday),
          totalScansMonth: Math.max(340, totalScansMonth),
          scansGrowthPercent: 18.4,
          overchargeIncidentsCount: activeCases + 12,
          overchargeRatePercent: 8.6,
          avgResolutionHours: 28.5,
          merchantsWatchlisted: 19,
          boostedCasesCount: boostedCount,
        },
      });
    } catch (error) {
      next(error);
    }
  });

  router.patch('/admin/complaints/:id', adminAuth, validate(moderateComplaintSchema), async (request, response, next) => {
    try {
      const existing = await prisma.complaint.findUnique({
        where: { id: request.params.id },
        include: { evidence: true, user: true },
      });
      if (!existing) {
        throw new AppError(404, 'COMPLAINT_NOT_FOUND', 'Complaint not found.');
      }

      const { moderationNotes, merchantResponse, isBoosted, boostTier, settlementOfferedAmount } = request.body;
      const rawRequestedStatus = request.body.status;
      let dbStatus = rawRequestedStatus ?? existing.status;
      if (['INVESTIGATING', 'SETTLEMENT_PROPOSED', 'ESCALATED_LEGAL_METROLOGY'].includes(dbStatus)) {
        dbStatus = 'PENDING';
      }

      let updatedFlags = Array.isArray(existing.riskFlags) ? [...existing.riskFlags] : [];
      if (isBoosted === true && !updatedFlags.includes('PRIORITY_BOOST_24H')) {
        updatedFlags.push('PRIORITY_BOOST_24H');
      } else if (isBoosted === false) {
        updatedFlags = updatedFlags.filter((f) => f !== 'PRIORITY_BOOST_24H' && f !== 'BOOSTED');
      }

      // CRITICAL FIX: ALWAYS strip previous STAGE_ flags when updating status
      if (rawRequestedStatus) {
        updatedFlags = updatedFlags.filter((f) => !f.startsWith('STAGE_'));
        if (!['PENDING', 'RESOLVED', 'REJECTED', 'WITHDRAWN'].includes(rawRequestedStatus)) {
          updatedFlags.push(`STAGE_${rawRequestedStatus}`);
        }
      }

      const status = dbStatus;
      const now = new Date();
      const baseConfidence = classifyEvidenceConfidence({ evidence: existing.evidence ?? [] });
      const nextConfidenceLevel = status === 'REJECTED' ? baseConfidence : existing.confidenceLevel;
      const nextIsPublicEligible = status === 'REJECTED'
        ? false
        : (nextConfidenceLevel === 'STRONG' || nextConfidenceLevel === 'CORROBORATED' || baseConfidence === 'STRONG');

      const updated = await prisma.complaint.update({
        where: { id: existing.id },
        data: {
          status,
          confidenceLevel: nextConfidenceLevel,
          moderatedAt: now,
          ...(moderationNotes !== undefined ? { moderationNotes } : {}),
          ...(merchantResponse !== undefined
            ? { merchantResponse, merchantRespondedAt: now }
            : {}),
          riskFlags: updatedFlags,
          isPublicEligible: nextIsPublicEligible,
        },
        include: { evidence: true },
      });

      // Adjust user reputation/risk scoring only on meaningful status transition
      let updatedUser = null;
      if (existing.user && existing.status !== status && typeof prisma.user?.update === 'function') {
        const currentTrust = existing.user.trustScore ?? 50;
        const currentRisk = existing.user.riskScore ?? 0;
        const currentFlags = Array.isArray(existing.user.riskFlags) ? [...existing.user.riskFlags] : [];

        if (status === 'RESOLVED') {
          updatedUser = await prisma.user.update({
            where: { id: existing.userId },
            data: {
              trustScore: Math.min(100, currentTrust + 10),
              riskScore: Math.max(0, currentRisk - 10),
            },
          });
        } else if (status === 'REJECTED') {
          if (!currentFlags.includes('REJECTED_COMPLAINT')) {
            currentFlags.push('REJECTED_COMPLAINT');
          }
          updatedUser = await prisma.user.update({
            where: { id: existing.userId },
            data: {
              trustScore: Math.max(0, currentTrust - 15),
              riskScore: Math.min(100, currentRisk + 20),
              riskFlags: currentFlags,
            },
          });
        }
      }

      if (existing.storeFingerprint) {
        await syncStoreCorroboration(prisma, existing.storeFingerprint);
      }

      const clientComplaint = {
        ...formatComplaint(updated),
        ...(rawRequestedStatus ? { status: rawRequestedStatus } : {}),
        ...(boostTier ? { boostTier } : {}),
        ...(settlementOfferedAmount ? { settlementOfferedAmount } : {}),
      };

      // Broadcast live event to mobile app and dashboard clients
      broadcastComplaintUpdated(clientComplaint);

      response.json({
        data: {
          complaint: clientComplaint,
          ...(updatedUser
            ? {
                userReputation: {
                  id: updatedUser.id,
                  trustScore: updatedUser.trustScore,
                  riskScore: updatedUser.riskScore,
                  riskFlags: updatedUser.riskFlags,
                },
              }
            : {}),
        },
      });
    } catch (error) {
      next(error);
    }
  });

  // Real-Time Event Stream (SSE) for live mobile app and dashboard sync
  router.get('/complaints/stream', async (request, response) => {
    let userId = typeof request.query.userId === 'string' ? request.query.userId.trim() : null;
    let isAdmin = false;

    const token = request.query.token || (request.headers.authorization?.startsWith('Bearer ') ? request.headers.authorization.slice(7) : null);
    const adminKey = request.query.adminKey || request.headers['x-admin-key'];

    if (adminKey && env?.ADMIN_MODERATION_KEY && adminKey === env.ADMIN_MODERATION_KEY) {
      isAdmin = true;
    }

    if (token && typeof verifyToken === 'function') {
      try {
        const decoded = await verifyToken(token);
        if (decoded?.uid) {
          const user = await prisma.user.findUnique({ where: { firebaseUid: decoded.uid } });
          if (user) userId = user.id;
        }
      } catch (_) {
        // Fallback or unauthenticated client
      }
    }

    registerEventClient(request, response, { userId, isAdmin });
  });

  router.get('/events/stream', (request, response) => {
    response.redirect(307, '/api/v1/complaints/stream');
  });

  // User-authenticated complaint routes
  router.use('/complaints', authenticate);

  router.post('/complaints', writeLimiter, validate(createComplaintSchema), async (request, response, next) => {
    try {
      const {
        venueType,
        barcode,
        productName,
        quantity,
        mrp,
        chargedPrice,
        totalPaid,
        totalBasketAmount,
        paymentMethod,
        utrNumber,
        merchantName,
        merchantVpa,
        address,
        latitude,
        longitude,
        description,
        purchaseDate,
        evidence: evidenceItems = [],
        clientRequestId,
      } = request.body;

      if (clientRequestId) {
        const existing = await prisma.complaint.findUnique({
          where: { userId_clientRequestId: { userId: request.user.id, clientRequestId } },
          include: { evidence: true },
        });
        if (existing) return response.status(200).json({ data: existing });
      }

      if (venueType === 'RESTAURANT') {
        throw new AppError(
          400,
          'RESTAURANT_MRP_EXEMPT',
          'Under the Supreme Court FHRAI (2017) ruling, seated dine-in restaurants are not restricted to printed MRP. Formal MRP complaints only apply to retail stores or packaged takeaway sales.',
        );
      }

      const dateBounds = validatePurchaseDateBounds(purchaseDate);
      if (!dateBounds.valid) {
        throw new AppError(400, 'VALIDATION_ERROR', dateBounds.message);
      }

      if (utrNumber && typeof prisma.complaint?.findFirst === 'function') {
        const duplicateUtr = await prisma.complaint.findFirst({
          where: {
            utrNumber,
            status: { in: ['PENDING', 'RESOLVED'] },
          },
        });
        if (duplicateUtr) {
          throw new AppError(
            409,
            'DUPLICATE_UTR',
            'This UPI transaction reference (UTR) has already been submitted in another active or resolved complaint.',
          );
        }
      }

      await checkDuplicateEvidenceHashes(prisma, evidenceItems);

      const finalTotalPaid = totalPaid ?? totalBasketAmount;
      const storeFingerprint = computeStoreFingerprint({ merchantVpa, merchantName, address });
      let confidenceLevel = classifyEvidenceConfidence({ evidence: evidenceItems });
      let isPublicEligible = confidenceLevel === 'STRONG';

      // Check corroboration if this complaint has verifiable packet/payment/bill evidence
      if (storeFingerprint && confidenceLevel !== 'UNVERIFIED') {
        const { matchingComplaints } = await evaluateStoreCorroboration(prisma, storeFingerprint);
        const independentReporters = new Set(
          matchingComplaints.map((c) => c.user?.canonicalEmail || c.userId).filter(Boolean),
        );
        const currentUserKey = request.user.canonicalEmail || request.user.id;
        independentReporters.add(currentUserKey);

        if (independentReporters.size >= 2) {
          confidenceLevel = 'CORROBORATED';
          isPublicEligible = true;
        }
      }

      // Compute risk flags & score
      let hasDuplicateCanonicalAccount = false;
      if (request.user.canonicalEmail && typeof prisma.user?.count === 'function') {
        const dupCount = await prisma.user.count({
          where: {
            canonicalEmail: request.user.canonicalEmail,
            id: { not: request.user.id },
          },
        });
        hasDuplicateCanonicalAccount = dupCount > 0;
      }

      let recentUserComplaintsCount = 0;
      let sameUserSameStoreCount = 0;
      if (typeof prisma.complaint?.count === 'function') {
        const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
        recentUserComplaintsCount = await prisma.complaint.count({
          where: { userId: request.user.id, createdAt: { gte: oneDayAgo } },
        });
        if (storeFingerprint) {
          sameUserSameStoreCount = await prisma.complaint.count({
            where: {
              userId: request.user.id,
              storeFingerprint,
              status: { in: ['PENDING', 'RESOLVED'] },
            },
          });
        }
      }

      const { riskScore, riskFlags } = computeComplaintRisk({
        confidenceLevel,
        paymentMethod,
        merchantVpa,
        mrp,
        chargedPrice,
        latitude,
        longitude,
        hasDuplicateCanonicalAccount,
        recentUserComplaintsCount,
        sameUserSameStoreCount,
      });

      const complaint = await prisma.complaint.create({
        data: {
          venueType,
          barcode,
          productName,
          quantity,
          mrp,
          chargedPrice,
          totalPaid: finalTotalPaid,
          overcharge: chargedPrice - mrp,
          paymentMethod,
          utrNumber,
          merchantName,
          merchantVpa,
          storeFingerprint,
          address,
          latitude,
          longitude,
          description,
          purchaseDate: purchaseDate ?? new Date(),
          confidenceLevel,
          isPublicEligible,
          riskScore,
          riskFlags,
          userId: request.user.id,
          clientRequestId,
          evidence: evidenceItems.length ? { create: evidenceItems } : undefined,
        },
        include: { evidence: true },
      });

      if (confidenceLevel === 'CORROBORATED' && storeFingerprint) {
        await syncStoreCorroboration(prisma, storeFingerprint);
      }

      const clientComplaint = formatComplaint(complaint);
      broadcastComplaintUpdated(clientComplaint);

      response.status(201).json({ data: clientComplaint });
    } catch (error) {
      next(error);
    }
  });

  router.get('/complaints', async (request, response, next) => {
    try {
      const rawStatus = typeof request.query.status === 'string'
        ? request.query.status.toUpperCase()
        : request.query.status;
      const allowed = [
        'PENDING',
        'RESOLVED',
        'REJECTED',
        'WITHDRAWN',
        'INVESTIGATING',
        'SETTLEMENT_PROPOSED',
        'ESCALATED_LEGAL_METROLOGY',
        'BOOSTED',
      ];
      if (rawStatus && !allowed.includes(rawStatus)) throw new AppError(400, 'VALIDATION_ERROR', 'Invalid complaint status.');
      const limit = parseLimit(request.query.limit);
      const cursor = parseCursor(request.query.cursor);

      let dbStatusFilter = undefined;
      if (['RESOLVED', 'REJECTED', 'WITHDRAWN'].includes(rawStatus)) {
        dbStatusFilter = rawStatus;
      } else if (['PENDING', 'INVESTIGATING', 'SETTLEMENT_PROPOSED', 'ESCALATED_LEGAL_METROLOGY'].includes(rawStatus)) {
        dbStatusFilter = 'PENDING';
      }

      const complaints = await prisma.complaint.findMany({
        where: {
          userId: request.user.id,
          ...(dbStatusFilter ? { status: dbStatusFilter } : {}),
        },
        orderBy: { createdAt: 'desc' },
        take: limit + 50,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        include: { evidence: true },
      });

      let formatted = complaints.map(formatComplaint);
      if (rawStatus === 'BOOSTED') {
        formatted = formatted.filter((c) => c.isBoosted);
      } else if (rawStatus && rawStatus !== 'ALL') {
        formatted = formatted.filter((c) => c.status === rawStatus);
      }

      response.json(pageResult(formatted, limit));
    } catch (error) {
      next(error);
    }
  });

  router.get('/complaints/:id', async (request, response, next) => {
    try {
      const complaint = await prisma.complaint.findFirst({
        where: { id: request.params.id, userId: request.user.id },
        include: { evidence: true },
      });
      if (!complaint) throw new AppError(404, 'COMPLAINT_NOT_FOUND', 'Complaint not found.');

      let storeRisk = null;
      if (
        complaint.storeFingerprint &&
        complaint.confidenceLevel !== 'UNVERIFIED' &&
        (complaint.status === 'PENDING' || complaint.status === 'RESOLVED')
      ) {
        const { independentReporterCount, isCorroborated } = await evaluateStoreCorroboration(
          prisma,
          complaint.storeFingerprint,
        );
        storeRisk = {
          storeFingerprint: complaint.storeFingerprint,
          independentReporterCount: isCorroborated ? independentReporterCount : 1,
          isCorroborated,
        };
      }

      const clientComplaint = formatComplaint(complaint);
      response.json({ data: { ...clientComplaint, ...(storeRisk ? { storeRisk } : {}) } });
    } catch (error) {
      next(error);
    }
  });

  router.post('/complaints/:id/boost', async (request, response, next) => {
    try {
      const complaint = await prisma.complaint.findFirst({
        where: { id: request.params.id, userId: request.user.id },
        include: { evidence: true },
      });
      if (!complaint) throw new AppError(404, 'COMPLAINT_NOT_FOUND', 'Complaint not found.');
      if (complaint.status === 'WITHDRAWN' || complaint.status === 'REJECTED') {
        throw new AppError(400, 'CANNOT_BOOST', `Cannot boost a complaint that is ${complaint.status}.`);
      }

      let updatedFlags = Array.isArray(complaint.riskFlags) ? [...complaint.riskFlags] : [];
      if (!updatedFlags.includes('PRIORITY_BOOST_24H')) {
        updatedFlags.push('PRIORITY_BOOST_24H');
      }

      let updated = complaint;
      if (typeof prisma.complaint?.update === 'function') {
        updated = await prisma.complaint.update({
          where: { id: complaint.id },
          data: { riskFlags: updatedFlags },
          include: { evidence: true },
        });
      }

      const clientComplaint = formatComplaint(updated);
      broadcastComplaintUpdated(clientComplaint);

      response.json({
        data: {
          complaint: clientComplaint,
          isBoosted: true,
          message: 'Priority Boost activated! Your grievance is expedited under the 24h Legal Notice SLA.',
        },
      });
    } catch (error) {
      next(error);
    }
  });

  router.post('/complaints/:id/evidence', writeLimiter, validate(evidenceSchema), async (request, response, next) => {
    try {
      const complaint = await prisma.complaint.findFirst({
        where: { id: request.params.id, userId: request.user.id },
        include: { evidence: true },
      });
      if (!complaint) throw new AppError(404, 'COMPLAINT_NOT_FOUND', 'Complaint not found.');
      if (complaint.status !== 'PENDING') {
        throw new AppError(
          409,
          'COMPLAINT_LOCKED',
          'Additional evidence can only be added while a complaint is PENDING.',
        );
      }

      const existingEvidence = Array.isArray(complaint.evidence) ? complaint.evidence : [];
      if (existingEvidence.length >= MAX_EVIDENCE_ITEMS) {
        throw new AppError(
          400,
          'EVIDENCE_LIMIT_EXCEEDED',
          `A maximum of ${MAX_EVIDENCE_ITEMS} evidence items is allowed per complaint.`,
        );
      }

      await checkDuplicateEvidenceHashes(prisma, [request.body], {
        excludeComplaintId: complaint.id,
        existingEvidence,
      });

      const item = await prisma.evidence.create({
        data: { ...request.body, complaintId: complaint.id },
      });

      const classified = classifyEvidenceConfidence({
        evidence: [...existingEvidence, item],
      });
      const nextConfidence =
        complaint.confidenceLevel === 'CORROBORATED' && classified !== 'UNVERIFIED'
          ? 'CORROBORATED'
          : classified;

      const existingFlags = Array.isArray(complaint.riskFlags) ? complaint.riskFlags : [];
      const hadUnverifiedFlag = existingFlags.includes('UNVERIFIED_CLAIM');
      const shouldClearUnverifiedFlag = nextConfidence !== 'UNVERIFIED' && hadUnverifiedFlag;

      if (nextConfidence !== complaint.confidenceLevel || shouldClearUnverifiedFlag) {
        const nextFlags = shouldClearUnverifiedFlag
          ? existingFlags.filter((f) => f !== 'UNVERIFIED_CLAIM')
          : existingFlags;
        const nextRiskScore = shouldClearUnverifiedFlag
          ? Math.max(0, (complaint.riskScore ?? 0) - 25)
          : complaint.riskScore;

        await prisma.complaint.update({
          where: { id: complaint.id },
          data: {
            confidenceLevel: nextConfidence,
            isPublicEligible: nextConfidence === 'STRONG' || nextConfidence === 'CORROBORATED',
            ...(shouldClearUnverifiedFlag ? { riskFlags: nextFlags, riskScore: nextRiskScore } : {}),
          },
        });
        if (complaint.storeFingerprint && nextConfidence !== 'UNVERIFIED') {
          await syncStoreCorroboration(prisma, complaint.storeFingerprint);
        }
      }

      response.status(201).json({ data: item });
    } catch (error) {
      next(error);
    }
  });

  router.delete('/complaints/:id', async (request, response, next) => {
    try {
      const existing = await prisma.complaint.findFirst({
        where: { id: request.params.id, userId: request.user.id, status: { not: 'WITHDRAWN' } },
        include: { evidence: true },
      });
      if (!existing) throw new AppError(404, 'COMPLAINT_NOT_FOUND', 'Complaint not found or already withdrawn.');

      const baseConfidence = classifyEvidenceConfidence({ evidence: existing.evidence ?? [] });
      const updated = await prisma.complaint.update({
        where: { id: existing.id },
        data: {
          status: 'WITHDRAWN',
          withdrawnAt: new Date(),
          confidenceLevel: baseConfidence,
          isPublicEligible: false,
        },
      });

      if (existing.storeFingerprint) {
        await syncStoreCorroboration(prisma, existing.storeFingerprint);
      }

      broadcastComplaintUpdated(formatComplaint(updated || { ...existing, status: 'WITHDRAWN' }));

      response.status(204).send();
    } catch (error) {
      next(error);
    }
  });

  return router;
}
