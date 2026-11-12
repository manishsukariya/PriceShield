import crypto from 'node:crypto';
import { Router } from 'express';
import { z } from 'zod';
import { AppError } from '../../middleware/errors.js';
import { validate } from '../../middleware/validate.js';
import { trustedMediaUrl } from '../../utils/media-url.js';
import { pageResult, parseCursor, parseLimit } from '../../utils/query.js';

const money = z.coerce.number().positive().max(99999999.99);
const submission = z.object({
  barcode: z.string().trim().min(1).max(128),
  productName: z.string().trim().min(1).max(255).optional(),
  printedMrp: money.optional(),
  ocrText: z.string().trim().max(10000).optional(),
  frontImageUrl: trustedMediaUrl.optional(),
  backImageUrl: trustedMediaUrl.optional(),
}).refine((value) => value.productName || value.printedMrp || value.ocrText || value.frontImageUrl || value.backImageUrl, {
  message: 'Provide product details or at least one package image.',
});

const moderateSubmission = z.object({
  status: z.enum(['REVIEWED', 'REJECTED']),
  productName: z.string().trim().min(1).max(255).optional(),
  printedMrp: money.optional(),
});

function hasValidAdminKey(providedKey, configuredKey) {
  if (typeof providedKey !== 'string' || !providedKey.trim()) return false;
  const a = crypto.createHash('sha256').update(providedKey.trim()).digest();
  const b = crypto.createHash('sha256').update(configuredKey).digest();
  return crypto.timingSafeEqual(a, b);
}

function requireModerationKey(env) {
  return (request, _response, next) => {
    const configuredKey = env?.ADMIN_MODERATION_KEY;
    if (!configuredKey) {
      return next(
        new AppError(
          503,
          'MODERATION_NOT_CONFIGURED',
          'Product submission moderation key is not configured on this server.',
        ),
      );
    }
    const providedKey = request.get('x-admin-key');
    if (!hasValidAdminKey(providedKey, configuredKey)) {
      return next(new AppError(403, 'FORBIDDEN', 'Invalid moderation credentials.'));
    }
    return next();
  };
}

export function productSubmissionRoutes({ authenticate, prisma, env }) {
  const router = Router();

  // Moderation endpoints protected by server-side ADMIN_MODERATION_KEY
  const adminAuth = requireModerationKey(env);
  router.get('/admin/product-submissions', adminAuth, async (request, response, next) => {
    try {
      const rawStatus = typeof request.query.status === 'string'
        ? request.query.status.trim().toUpperCase()
        : 'PENDING';
      const allowedStatuses = ['PENDING', 'REVIEWED', 'REJECTED', 'ALL'];
      if (!allowedStatuses.includes(rawStatus)) {
        throw new AppError(400, 'VALIDATION_ERROR', 'Invalid submission status filter.');
      }
      const limit = parseLimit(request.query.limit);
      const cursor = parseCursor(request.query.cursor);
      const items = await prisma.productSubmission.findMany({
        where: rawStatus === 'ALL' ? {} : { status: rawStatus },
        orderBy: { createdAt: 'desc' },
        take: limit + 1,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      });
      response.json(pageResult(items, limit));
    } catch (error) {
      next(error);
    }
  });

  router.patch('/admin/product-submissions/:id', adminAuth, validate(moderateSubmission), async (request, response, next) => {
    try {
      const existing = await prisma.productSubmission.findUnique({ where: { id: request.params.id } });
      if (!existing) {
        throw new AppError(404, 'SUBMISSION_NOT_FOUND', 'Product submission not found.');
      }

      const { status, productName, printedMrp } = request.body;
      const finalMrp = printedMrp ?? (existing.printedMrp != null ? Number(existing.printedMrp) : 0);
      if (status === 'REVIEWED' && (!Number.isFinite(finalMrp) || finalMrp <= 0)) {
        throw new AppError(
          400,
          'VALIDATION_ERROR',
          'Approving a submission requires a positive printedMrp.',
        );
      }

      const finalName = productName ?? existing.productName ?? `Product ${existing.barcode}`;
      const updated = await prisma.productSubmission.update({
        where: { id: existing.id },
        data: {
          status,
          ...(productName ? { productName } : {}),
          ...(printedMrp != null ? { printedMrp } : {}),
        },
      });

      let catalogProduct = null;
      if (status === 'REVIEWED') {
        catalogProduct = await prisma.product.upsert({
          where: { barcode: existing.barcode },
          update: { name: finalName, mrp: finalMrp },
          create: { barcode: existing.barcode, name: finalName, mrp: finalMrp },
        });
      }

      response.json({ data: { submission: updated, catalogProduct } });
    } catch (error) {
      next(error);
    }
  });

  router.use('/product-submissions', authenticate);
  router.post('/product-submissions', validate(submission), async (request, response, next) => {
    try {
      // Submissions stay in PENDING status until moderated; they never overwrite
      // the authoritative product catalog directly.
      const item = await prisma.productSubmission.create({
        data: { ...request.body, userId: request.user.id },
      });
      response.status(201).json({ data: item });
    } catch (error) {
      next(error);
    }
  });
  router.get('/product-submissions', async (request, response, next) => {
    try {
      const limit = parseLimit(request.query.limit);
      const cursor = parseCursor(request.query.cursor);
      const data = await prisma.productSubmission.findMany({
        where: { userId: request.user.id },
        orderBy: { createdAt: 'desc' },
        take: limit + 1,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      });
      response.json(pageResult(data, limit));
    } catch (error) {
      next(error);
    }
  });
  return router;
}
