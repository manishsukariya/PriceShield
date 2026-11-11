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

      // 1. Fast local database lookup (indexed by unique barcode).
      // Only treat rows with a positive MRP as complete; rows cached earlier
      // with mrp <= 0 self-heal via OFF image OCR, Open Prices, or reviewed submissions.
      const localProduct = await prisma.product.findUnique({ where: { barcode } });
      if (localProduct && Number(localProduct.mrp) > 0) {
        return response.json({
          data: {
            ...localProduct,
            source: 'catalog_db',
            isReferenceEstimate: true,
            mrpDisclaimer: 'Reference MRP only. Always verify the printed MRP on the package.',
          },
        });
      }

      // 2. Real-time Open Food Facts + Open Prices + OFF Image OCR fallback
      const offProduct = await fetchFromOpenFoodFacts(barcode, { fetchFn });
      if (offProduct) {
        let resolvedMrp = offProduct.mrp;
        let mrpSource = offProduct.mrpSource;

        if (resolvedMrp <= 0 && typeof prisma.productSubmission?.findFirst === 'function') {
          try {
            const approved = await prisma.productSubmission.findFirst({
              where: { barcode, status: 'REVIEWED', printedMrp: { gt: 0 } },
              orderBy: { updatedAt: 'desc' },
            });
            if (approved?.printedMrp != null && Number(approved.printedMrp) > 0) {
              resolvedMrp = Number(approved.printedMrp);
              mrpSource = 'community_reviewed';
            }
          } catch {
            // Optional fallback only
          }
        }

        const resolvedName = localProduct?.name || offProduct.name;
        let savedProduct;
        try {
          const existingPositiveMrp =
            localProduct && Number(localProduct.mrp) > 0 ? Number(localProduct.mrp) : 0;
          const persistedMrp = existingPositiveMrp > 0 ? existingPositiveMrp : resolvedMrp;
          savedProduct = await prisma.product.upsert({
            where: { barcode },
            update: {
              name: resolvedName,
              ...(persistedMrp > 0 ? { mrp: persistedMrp } : {}),
            },
            create: {
              barcode,
              name: resolvedName,
              mrp: persistedMrp,
            },
          });
        } catch {
          // If concurrent upsert or db error, fallback to in-memory representation
          savedProduct = {
            id: localProduct?.id ?? `off-${barcode}`,
            barcode,
            name: resolvedName,
            mrp: resolvedMrp,
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
            mrpSource: mrpSource || undefined,
            isReferenceEstimate: true,
            mrpDisclaimer: resolvedMrp > 0
              ? 'External catalog estimate. Always verify the printed MRP on the package.'
              : 'Product identified, but printed MRP was not listed in external catalogs. Confirm from the package.',
          },
        });
      }

      if (localProduct) {
        let healedProduct = localProduct;
        let mrpSource;
        if (typeof prisma.productSubmission?.findFirst === 'function') {
          try {
            const approved = await prisma.productSubmission.findFirst({
              where: { barcode, status: 'REVIEWED', printedMrp: { gt: 0 } },
              orderBy: { updatedAt: 'desc' },
            });
            if (approved?.printedMrp != null && Number(approved.printedMrp) > 0) {
              const printedMrp = Number(approved.printedMrp);
              mrpSource = 'community_reviewed';
              healedProduct = await prisma.product.upsert({
                where: { barcode },
                update: { mrp: printedMrp },
                create: { barcode, name: localProduct.name, mrp: printedMrp },
              });
            }
          } catch {
            // Optional fallback only
          }
        }
        return response.json({
          data: {
            ...healedProduct,
            source: 'catalog_db',
            ...(mrpSource ? { mrpSource } : {}),
            isReferenceEstimate: true,
            mrpDisclaimer: Number(healedProduct.mrp) > 0
              ? 'Reference MRP only. Always verify the printed MRP on the package.'
              : 'Product identified, but printed MRP was not listed. Confirm from the package.',
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
