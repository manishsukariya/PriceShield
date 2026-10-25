import { Router } from 'express';
import { complaintRoutes } from '../modules/complaints/routes.js';
import { productRoutes } from '../modules/products/routes.js';
import { productSubmissionRoutes } from '../modules/products/submissions-routes.js';
import { scanRoutes } from '../modules/scans/routes.js';
import { userRoutes } from '../modules/users/routes.js';
import { authRoutes } from '../modules/auth/routes.js';

export function apiRoutes(context) {
  const router = Router();
  router.use(authRoutes(context));
  router.get('/health', async (_request, response, next) => {
    try {
      await context.prisma.$queryRawUnsafe('SELECT 1');
      response.json({ data: { status: 'ok' } });
    } catch (error) {
      next(error);
    }
  });
  router.use(userRoutes(context));
  router.use(productRoutes(context));
  router.use(productSubmissionRoutes(context));
  router.use(scanRoutes(context));
  router.use(complaintRoutes(context));
  return router;
}
