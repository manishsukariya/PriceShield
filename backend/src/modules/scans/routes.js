import { Router } from 'express';
import { z } from 'zod';
import { validate } from '../../middleware/validate.js';
import { pageResult, parseCursor, parseLimit } from '../../utils/query.js';

const money = z.coerce.number().positive().max(99999999.99);
const createScan = z.object({
  barcode: z.string().trim().min(1).max(128),
  productName: z.string().trim().min(1).max(255),
  mrp: money,
  chargedPrice: money,
  clientRequestId: z.string().trim().min(8).max(120).optional(),
});

export function scanRoutes({ authenticate, prisma }) {
  const router = Router();
  router.use(authenticate);
  router.post('/scans', validate(createScan), async (request, response, next) => {
    try {
      const { mrp, chargedPrice, clientRequestId, ...data } = request.body;
      if (clientRequestId) {
        const existing = await prisma.scan.findUnique({
          where: { userId_clientRequestId: { userId: request.user.id, clientRequestId } },
        });
        if (existing) return response.status(200).json({ data: existing });
      }
      const overcharge = Math.max(0, chargedPrice - mrp);
      const scan = await prisma.scan.create({
        data: { ...data, mrp, chargedPrice, overcharge, clientRequestId, status: overcharge > 0 ? 'OVERCHARGED' : 'WITHIN_MRP', userId: request.user.id },
      });
      response.status(201).json({ data: scan });
    } catch (error) {
      next(error);
    }
  });
  router.get('/scans', async (request, response, next) => {
    try {
      const limit = parseLimit(request.query.limit);
      const cursor = parseCursor(request.query.cursor);
      const scans = await prisma.scan.findMany({
        where: { userId: request.user.id }, orderBy: { createdAt: 'desc' }, take: limit + 1,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      });
      response.json(pageResult(scans, limit));
    } catch (error) {
      next(error);
    }
  });
  return router;
}
