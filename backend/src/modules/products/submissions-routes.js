import { Router } from 'express';
import { z } from 'zod';
import { validate } from '../../middleware/validate.js';
import { pageResult, parseCursor, parseLimit } from '../../utils/query.js';

const money = z.coerce.number().positive().max(99999999.99);
const submission = z.object({
  barcode: z.string().trim().min(1).max(128),
  productName: z.string().trim().min(1).max(255).optional(),
  printedMrp: money.optional(),
  ocrText: z.string().trim().max(10000).optional(),
  frontImageUrl: z.string().url().optional(),
  backImageUrl: z.string().url().optional(),
}).refine((value) => value.productName || value.printedMrp || value.ocrText || value.frontImageUrl || value.backImageUrl, {
  message: 'Provide product details or at least one package image.',
});

export function productSubmissionRoutes({ authenticate, prisma }) {
  const router = Router();
  router.use(authenticate);
  router.post('/product-submissions', validate(submission), async (request, response, next) => {
    try {
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
