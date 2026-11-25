import { Router } from 'express';
import { z } from 'zod';
import { requireModerationKey } from '../../middleware/admin-auth.js';
import { AppError } from '../../middleware/errors.js';
import { validate } from '../../middleware/validate.js';
import { pageResult, parseCursor, parseLimit } from '../../utils/query.js';
import { fetchFromOpenFoodFacts } from './open-food-facts.js';
import { resolveGs1IndiaBrand } from './gs1-india-resolver.js';

const money = z.coerce.number().positive().max(99999999.99);

const adminProductSchema = z.object({
  barcode: z.string().trim().min(1).max(128),
  name: z.string().trim().min(1).max(255),
  mrp: money,
});

const adminUpdateProductSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  mrp: money.optional(),
}).refine((v) => v.name !== undefined || v.mrp !== undefined, {
  message: 'Provide name or mrp to update.',
});

export function productRoutes({ authenticate, authenticateOptional, prisma, fetchFn, env }) {
  const router = Router();
  const authMiddleware = authenticateOptional ?? authenticate;
  const adminAuth = requireModerationKey(env);

  // Admin Catalog Management Endpoints
  router.get('/admin/products', adminAuth, async (request, response, next) => {
    try {
      const search = typeof request.query.search === 'string' ? request.query.search.trim().toLowerCase() : '';
      const limit = parseLimit(request.query.limit);
      const cursor = parseCursor(request.query.cursor);

      const items = await prisma.product.findMany({
        where: search
          ? {
              OR: [
                { barcode: { contains: search } },
                { name: { contains: search } },
              ],
            }
          : {},
        orderBy: { updatedAt: 'desc' },
        take: limit + 1,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      });

      response.json(pageResult(items, limit));
    } catch (error) {
      next(error);
    }
  });

  router.post('/admin/products', adminAuth, validate(adminProductSchema), async (request, response, next) => {
    try {
      const { barcode, name, mrp } = request.body;
      const product = await prisma.product.upsert({
        where: { barcode },
        update: { name, mrp },
        create: { barcode, name, mrp },
      });
      response.status(201).json({ data: product });
    } catch (error) {
      next(error);
    }
  });

  router.patch('/admin/products/:id', adminAuth, validate(adminUpdateProductSchema), async (request, response, next) => {
    try {
      const { mrp, name } = request.body;
      const updated = await prisma.product.update({
        where: { id: request.params.id },
        data: {
          ...(mrp !== undefined ? { mrp } : {}),
          ...(name !== undefined ? { name } : {}),
        },
      });
      response.json({ data: updated });
    } catch (error) {
      next(error);
    }
  });

  router.get('/products/:barcode', authMiddleware, async (request, response, next) => {
    try {
      const barcode = request.params.barcode.trim();
      if (!barcode || barcode.length > 128) {
        throw new AppError(400, 'VALIDATION_ERROR', 'barcode must contain between 1 and 128 characters.');
      }

      const isPlaceholder = (name) => !name || /^Product\s+\d+$/i.test(name.trim());
      const isSuspectOcrMrp = (mrp) => {
        const n = Number(mrp);
        return n >= 7000 && n <= 7999 && (n % 100 === 99 || n % 100 === 0 || n % 100 === 50);
      };

      // 1. Fast local database lookup (indexed by unique barcode).
      // Only treat rows with a positive MRP and non-placeholder name as complete; rows cached earlier
      // with mrp <= 0, placeholder names, or suspect OCR artifacts self-heal via OFF/GS1/OCR.
      const localProduct = await prisma.product.findUnique({ where: { barcode } });
      if (
        localProduct &&
        Number(localProduct.mrp) > 0 &&
        !isPlaceholder(localProduct.name) &&
        !isSuspectOcrMrp(localProduct.mrp)
      ) {
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

        // Guard against OCR ₹-to-7 artifact in resolved prices (e.g. 7599 -> 599)
        if (isSuspectOcrMrp(resolvedMrp)) {
          const stripped = resolvedMrp - 7000;
          if (stripped >= 100 && stripped <= 999) {
            resolvedMrp = stripped;
          }
        }

        let resolvedName = localProduct?.name && !isPlaceholder(localProduct.name)
          ? localProduct.name
          : offProduct.name;
        if (isPlaceholder(resolvedName)) {
          const gs1 = resolveGs1IndiaBrand(barcode);
          if (gs1) {
            resolvedName = `${gs1.brandName} (${gs1.category})`;
          }
        }

        let savedProduct;
        try {
          const existingPositiveMrp =
            localProduct && Number(localProduct.mrp) > 0 && !isSuspectOcrMrp(localProduct.mrp)
              ? Number(localProduct.mrp)
              : 0;
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
