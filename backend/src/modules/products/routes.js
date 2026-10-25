import { Router } from 'express';
import { AppError } from '../../middleware/errors.js';

export function productRoutes({ authenticate, prisma }) {
  const router = Router();
  router.use(authenticate);
  router.get('/products/:barcode', async (request, response, next) => {
    try {
      const barcode = request.params.barcode.trim();
      if (!barcode || barcode.length > 128) {
        throw new AppError(400, 'VALIDATION_ERROR', 'barcode must contain between 1 and 128 characters.');
      }
      const product = await prisma.product.findUnique({ where: { barcode } });
      if (!product) throw new AppError(404, 'PRODUCT_NOT_FOUND', 'No product exists for this barcode.');
      response.json({ data: product });
    } catch (error) {
      next(error);
    }
  });
  return router;
}
