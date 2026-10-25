import { Router } from 'express';
import { z } from 'zod';
import { AppError } from '../../middleware/errors.js';
import { validate } from '../../middleware/validate.js';
import { pageResult, parseCursor, parseLimit } from '../../utils/query.js';

const money = z.coerce.number().positive().max(99999999.99);
const evidence = z.object({
  url: z.string().url(),
  publicId: z.string().trim().min(1).max(255).optional(),
  resourceType: z.string().trim().min(1).max(30).optional(),
  mediaType: z.preprocess(
    (value) => typeof value === 'string' ? value.toUpperCase() : value,
    z.enum(['IMAGE', 'VIDEO']),
  ),
});
const createComplaint = z.object({
  barcode: z.string().trim().min(1).max(128),
  productName: z.string().trim().min(1).max(255),
  mrp: money,
  chargedPrice: money,
  address: z.string().trim().min(1).max(1000),
  latitude: z.coerce.number().min(-90).max(90).optional(),
  longitude: z.coerce.number().min(-180).max(180).optional(),
  description: z.string().trim().max(5000).optional(),
  purchaseDate: z.coerce.date().optional(),
  evidence: z.array(evidence).max(5).optional(),
  clientRequestId: z.string().trim().min(8).max(120).optional(),
}).refine((value) => value.chargedPrice > value.mrp, {
  message: 'chargedPrice must be greater than mrp for a complaint.',
  path: ['chargedPrice'],
});

export function complaintRoutes({ authenticate, prisma }) {
  const router = Router();
  router.use(authenticate);

  router.post('/complaints', validate(createComplaint), async (request, response, next) => {
    try {
      const { evidence: evidenceItems = [], mrp, chargedPrice, clientRequestId, ...data } = request.body;
      if (clientRequestId) {
        const existing = await prisma.complaint.findUnique({
          where: { userId_clientRequestId: { userId: request.user.id, clientRequestId } },
          include: { evidence: true },
        });
        if (existing) return response.status(200).json({ data: existing });
      }
      const complaint = await prisma.complaint.create({
        data: {
          ...data,
          mrp,
          chargedPrice,
          overcharge: chargedPrice - mrp,
          userId: request.user.id,
          clientRequestId,
          evidence: evidenceItems.length ? { create: evidenceItems } : undefined,
        },
        include: { evidence: true },
      });
      response.status(201).json({ data: complaint });
    } catch (error) {
      next(error);
    }
  });

  router.get('/complaints', async (request, response, next) => {
    try {
      const status = typeof request.query.status === 'string'
        ? request.query.status.toUpperCase()
        : request.query.status;
      const allowed = ['PENDING', 'RESOLVED', 'REJECTED', 'WITHDRAWN'];
      if (status && !allowed.includes(status)) throw new AppError(400, 'VALIDATION_ERROR', 'Invalid complaint status.');
      const limit = parseLimit(request.query.limit);
      const cursor = parseCursor(request.query.cursor);
      const complaints = await prisma.complaint.findMany({
        where: { userId: request.user.id, ...(status ? { status } : {}) },
        orderBy: { createdAt: 'desc' },
        take: limit + 1,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        include: { evidence: true },
      });
      response.json(pageResult(complaints, limit));
    } catch (error) {
      next(error);
    }
  });

  router.get('/complaints/:id', async (request, response, next) => {
    try {
      const complaint = await prisma.complaint.findFirst({ where: { id: request.params.id, userId: request.user.id }, include: { evidence: true } });
      if (!complaint) throw new AppError(404, 'COMPLAINT_NOT_FOUND', 'Complaint not found.');
      response.json({ data: complaint });
    } catch (error) {
      next(error);
    }
  });

  router.post('/complaints/:id/evidence', validate(evidence), async (request, response, next) => {
    try {
      const complaint = await prisma.complaint.findFirst({
        where: { id: request.params.id, userId: request.user.id, status: { not: 'WITHDRAWN' } },
      });
      if (!complaint) throw new AppError(404, 'COMPLAINT_NOT_FOUND', 'Complaint not found.');
      const item = await prisma.evidence.create({
        data: { ...request.body, complaintId: complaint.id },
      });
      response.status(201).json({ data: item });
    } catch (error) {
      next(error);
    }
  });

  router.delete('/complaints/:id', async (request, response, next) => {
    try {
      const result = await prisma.complaint.updateMany({
        where: { id: request.params.id, userId: request.user.id, status: { not: 'WITHDRAWN' } },
        data: { status: 'WITHDRAWN', withdrawnAt: new Date() },
      });
      if (!result.count) throw new AppError(404, 'COMPLAINT_NOT_FOUND', 'Complaint not found or already withdrawn.');
      response.status(204).send();
    } catch (error) {
      next(error);
    }
  });
  return router;
}
