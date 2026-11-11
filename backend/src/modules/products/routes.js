import { Router } from 'express';
import { AppError } from '../../middleware/errors.js';
import { fetchFromOpenFoodFacts } from './open-food-facts.js';

export function productRoutes({ authenticate, authenticateOptional, prisma, fetchFn }) {
  const router = Router();
  const authMiddleware = authenticateOptional ?? authenticate;

  router.get('/products/:barcode', authMiddleware, async (request, response, next) => {
    try {
      const barcode = request.params.barcode.trim();
      if (!barcode || barcode.length > 128) {
        throw new AppError(400, 'VALIDATION_ERROR', 'barcode must contain between 1 and 128 characters.');
      }

      // 1. Fast local database lookup (indexed by unique barcode)
      const localProduct = await prisma.product.findUnique({ where: { barcode } });
      if (localProduct) {
        return response.json({
          data: {
            ...localProduct,
            source: 'catalog_db',
            isReferenceEstimate: true,
            mrpDisclaimer: 'Reference MRP only. Always verify the printed MRP on the package.',
          },
        });
      }

      // 2. Real-time Open Food Facts fallback ingestion (strict 2.5s timeout)
      const offProduct = await fetchFromOpenFoodFacts(barcode, { fetchFn });
      if (offProduct) {
        let savedProduct;
        try {
          savedProduct = await prisma.product.upsert({
            where: { barcode },
            update: {
              name: offProduct.name,
              mrp: offProduct.mrp,
            },
            create: {
              barcode,
              name: offProduct.name,
              mrp: offProduct.mrp,
            },
          });
        } catch {
          // If concurrent upsert or db error, fallback to in-memory representation
          savedProduct = {
            id: `off-${barcode}`,
            barcode,
            name: offProduct.name,
            mrp: offProduct.mrp,
          };
        }
        return response.json({
          data: {
            ...savedProduct,
            brand: offProduct.brand || undefined,
            imageUrl: offProduct.imageUrl || undefined,
            category: offProduct.category || undefined,
            quantity: offProduct.quantity || undefined,
            source: offProduct.source || 'open_food_facts',
            isReferenceEstimate: true,
            mrpDisclaimer: 'External catalog estimate. Always verify the printed MRP on the package.',
          },
        });
      }

      // 3. Not found locally or in OFF
      throw new AppError(404, 'PRODUCT_NOT_FOUND', 'No product exists for this barcode.');
    } catch (error) {
      next(error);
    }
  });

  return router;
}
