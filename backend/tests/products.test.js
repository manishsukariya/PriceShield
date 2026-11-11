import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';
import { createApp } from '../src/app.js';
import { extractProductMrp, formatProductName } from '../src/modules/products/open-food-facts.js';

function createMockPrisma() {
  const users = new Map();
  const products = new Map();
  const submissions = [];
  const scans = [];
  let nextId = 1;

  const db = {
    $queryRawUnsafe: async () => 1,
    user: {
      create: async ({ data }) => {
        const user = { id: `user-${nextId++}`, ...data };
        users.set(user.email, user);
        return user;
      },
      findUnique: async ({ where }) => {
        if (where.firebaseUid) return [...users.values()].find((u) => u.firebaseUid === where.firebaseUid) ?? null;
        return users.get(where.email) ?? null;
      },
    },
    product: {
      findUnique: async ({ where }) => {
        return products.get(where.barcode) ?? null;
      },
      upsert: async ({ where, create, update }) => {
        const existing = products.get(where.barcode);
        if (existing) {
          const updated = { ...existing, ...update, updatedAt: new Date() };
          products.set(where.barcode, updated);
          return updated;
        }
        const created = { id: `prod-${nextId++}`, ...create, createdAt: new Date(), updatedAt: new Date() };
        products.set(where.barcode, created);
        return created;
      },
    },
    productSubmission: {
      create: async ({ data }) => {
        const item = { id: `sub-${nextId++}`, status: 'PENDING', ...data, createdAt: new Date() };
        submissions.push(item);
        return item;
      },
    },
    scan: {
      findUnique: async () => null,
      create: async ({ data }) => {
        const item = { id: `scan-${nextId++}`, ...data, createdAt: new Date() };
        scans.push(item);
        return item;
      },
    },
  };

  return { db, users, products, submissions, scans };
}

const env = {
  NODE_ENV: 'test',
  PORT: 3000,
  DATABASE_URL: 'postgresql://test:test@localhost/test',
  JWT_SECRET: 'test-secret-that-is-long-enough-for-signing',
  JWT_EXPIRES_IN: '1h',
  CORS_ALLOWED_ORIGIN: undefined,
};

function setupTestApp({ products = [], fetchFn } = {}) {
  const memory = createMockPrisma();
  for (const p of products) {
    memory.products.set(p.barcode, p);
  }
  const verifyToken = async (value) => {
    if (value !== 'valid-token') throw new Error('invalid token');
    return { uid: 'firebase-user-1', email: 'user@example.test', email_verified: true, name: 'Test User' };
  };
  const app = createApp({ env, prismaClient: memory.db, verifyToken, fetchFn });
  return { app, memory };
}

describe('Open Food Facts formatting and extraction', () => {
  it('combines brand, product name, and quantity cleanly', () => {
    const raw = {
      brands: 'Coca-Cola',
      product_name: 'Original Taste',
      quantity: '750ml',
    };
    expect(formatProductName(raw, '12345')).toBe('Coca-Cola Original Taste (750ml)');
  });

  it('avoids duplicating brand when already part of product name', () => {
    const raw = {
      brands: 'Amul',
      product_name: 'Amul Butter 100g',
      quantity: '100g',
    };
    expect(formatProductName(raw, '12345')).toBe('Amul Butter 100g');
  });

  it('falls back to barcode when no brand or name exists', () => {
    const raw = {};
    expect(formatProductName(raw, '8901234567890')).toBe('Product 8901234567890');
  });

  it('extracts positive numeric MRP properly', () => {
    expect(extractProductMrp({ price: 25.50 })).toBe(25.5);
    expect(extractProductMrp({ mrp: '₹ 40.00' })).toBe(40.0);
    expect(extractProductMrp({ prices: [{ price: 30.0 }] })).toBe(30.0);
    expect(extractProductMrp({})).toBe(0.0);
  });

  it('infers MRP from textual name or packaging when direct price field is absent', () => {
    expect(extractProductMrp({ product_name: 'Kurkure Masala Munch Rs. 20' })).toBe(20.0);
    expect(extractProductMrp({ product_name: 'Lay\'s India\'s Magic Masala 10/-' })).toBe(10.0);
    expect(extractProductMrp({ packaging_text: 'MRP: ₹ 15.00 (INCL OF TAXES)' })).toBe(15.0);
    expect(extractProductMrp({ product_name: 'Sting Energy Drink 250ml ₹20' })).toBe(20.0);
  });
});

describe('Product route with Open Food Facts fallback', () => {
  it('returns locally stored product immediately without calling external API', async () => {
    const fetchMock = vi.fn();
    const localProduct = {
      id: 'local-1',
      barcode: '8901719101037',
      name: 'Parle-G Original Gluco Biscuits 800g',
      mrp: 80.00,
    };
    const { app } = setupTestApp({
      products: [localProduct],
      fetchFn: fetchMock,
    });

    const response = await request(app)
      .get('/api/v1/products/8901719101037')
      .set('Authorization', 'Bearer valid-token');

    expect(response.status).toBe(200);
    expect(response.body.data.barcode).toBe('8901719101037');
    expect(response.body.data.name).toBe('Parle-G Original Gluco Biscuits 800g');
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('fetches from Open Food Facts when not found locally and caches in database', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        status: 1,
        product: {
          product_name: 'Maggi 2-Minute Noodles',
          brands: 'Nestle',
          quantity: '70g',
          price: 14.00,
        },
      }),
    });

    const { app, memory } = setupTestApp({
      products: [],
      fetchFn: fetchMock,
    });

    const response = await request(app)
      .get('/api/v1/products/8901058852493')
      .set('Authorization', 'Bearer valid-token');

    expect(response.status).toBe(200);
    expect(response.body.data.barcode).toBe('8901058852493');
    expect(response.body.data.name).toContain('Nestle Maggi 2-Minute Noodles (70g)');
    expect(response.body.data.mrp).toBe(14);
    expect(fetchMock).toHaveBeenCalledTimes(1);

    // Verify it was saved to the database for instant 0ms subsequent lookups
    const cached = memory.products.get('8901058852493');
    expect(cached).toBeDefined();
    expect(cached.name).toContain('Nestle Maggi 2-Minute Noodles');
  });

  it('returns 404 when product is not found in database and not found in OFF', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        status: 0,
        status_verbose: 'product not found',
      }),
    });

    const { app } = setupTestApp({
      products: [],
      fetchFn: fetchMock,
    });

    const response = await request(app)
      .get('/api/v1/products/9999999999999')
      .set('Authorization', 'Bearer valid-token');

    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe('PRODUCT_NOT_FOUND');
  });

  it('returns 404 when Open Food Facts request fails or times out', async () => {
    const fetchMock = vi.fn().mockRejectedValue(new Error('AbortError: The operation was aborted'));

    const { app } = setupTestApp({
      products: [],
      fetchFn: fetchMock,
    });

    const response = await request(app)
      .get('/api/v1/products/8888888888888')
      .set('Authorization', 'Bearer valid-token');

    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe('PRODUCT_NOT_FOUND');
  });

  it('returns 400 validation error for blank barcode', async () => {
    const { app } = setupTestApp();

    const response = await request(app)
      .get('/api/v1/products/%20')
      .set('Authorization', 'Bearer valid-token');

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('allows unauthenticated guest access to public product lookup', async () => {
    const localProduct = {
      id: 'local-1',
      barcode: '8901262150057',
      name: 'Amul Taaza Homogenised Toned Milk 500ml',
      mrp: 27.00,
    };
    const { app } = setupTestApp({
      products: [localProduct],
    });

    const response = await request(app)
      .get('/api/v1/products/8901262150057');

    expect(response.status).toBe(200);
    expect(response.body.data.barcode).toBe('8901262150057');
    expect(response.body.data.name).toBe('Amul Taaza Homogenised Toned Milk 500ml');
  });

  it('returns enriched product metadata (brand, imageUrl, category, quantity) from Open Food Facts', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        status: 1,
        product: {
          product_name: 'Original Taste Cold Drink',
          brands: 'Coca-Cola',
          quantity: '750ml',
          categories: 'Beverages, Carbonated drinks',
          image_url: 'https://images.openfoodfacts.org/images/products/8901764012241/front.jpg',
          price: 40.00,
        },
      }),
    });

    const { app } = setupTestApp({
      products: [],
      fetchFn: fetchMock,
    });

    const response = await request(app)
      .get('/api/v1/products/8901764012241');

    expect(response.status).toBe(200);
    expect(response.body.data.barcode).toBe('8901764012241');
    expect(response.body.data.brand).toBe('Coca-Cola');
    expect(response.body.data.imageUrl).toBe('https://images.openfoodfacts.org/images/products/8901764012241/front.jpg');
    expect(response.body.data.category).toBe('Beverages');
    expect(response.body.data.quantity).toBe('750ml');
    expect(response.body.data.mrp).toBe(40.00);
  });

  it('falls back to Open Beauty Facts when product is absent from Open Food Facts', async () => {
    const fetchMock = vi.fn().mockImplementation(async (url) => {
      if (url.includes('openfoodfacts.org')) {
        return {
          ok: true,
          json: async () => ({ status: 0, status_verbose: 'product not found' }),
        };
      }
      if (url.includes('openbeautyfacts.org')) {
        return {
          ok: true,
          json: async () => ({
            status: 1,
            product: {
              product_name: 'Total Protection Bar Soap 125g',
              brands: 'Dettol',
              price: 55.00,
            },
          }),
        };
      }
      return { ok: true, json: async () => ({ status: 0 }) };
    });

    const { app, memory } = setupTestApp({
      products: [],
      fetchFn: fetchMock,
    });

    const response = await request(app)
      .get('/api/v1/products/8901030383794');

    expect(response.status).toBe(200);
    expect(response.body.data.barcode).toBe('8901030383794');
    expect(response.body.data.name).toContain('Dettol Total Protection Bar Soap');
    expect(response.body.data.mrp).toBe(55.00);
    expect(response.body.data.source).toBe('open_beauty_facts');
    expect(response.body.data.isReferenceEstimate).toBe(true);

    // Verify it was cached in the database for subsequent fast lookups
    expect(memory.products.get('8901030383794')).toBeDefined();
  });

  it('keeps unmoderated product submissions PENDING without overwriting catalog products', async () => {
    const existingProduct = {
      id: 'local-1',
      barcode: '8901262150057',
      name: 'Amul Taaza Homogenised Toned Milk 500ml',
      mrp: 27.00,
    };
    const { app, memory } = setupTestApp({ products: [existingProduct] });

    const response = await request(app)
      .post('/api/v1/product-submissions')
      .set('Authorization', 'Bearer valid-token')
      .send({
        barcode: '8901262150057',
        productName: 'Tampered Name',
        printedMrp: 5.00,
        frontImageUrl: 'https://res.cloudinary.com/mpz1wxhc/image/upload/v1/front.jpg',
      });

    expect(response.status).toBe(201);
    expect(response.body.data.status).toBe('PENDING');
    // Existing authoritative product must remain untouched
    expect(memory.products.get('8901262150057').mrp).toBe(27.00);
    expect(memory.products.get('8901262150057').name).toBe('Amul Taaza Homogenised Toned Milk 500ml');
  });

  it('rejects untrusted non-Cloudinary image URLs in product submissions', async () => {
    const { app } = setupTestApp();
    const response = await request(app)
      .post('/api/v1/product-submissions')
      .set('Authorization', 'Bearer valid-token')
      .send({
        barcode: '8901234567899',
        productName: 'Test Item',
        frontImageUrl: 'https://evil.example.com/payload.png',
      });
    expect(response.status).toBe(400);
  });

  it('records user scans without auto-creating authoritative catalog products', async () => {
    const { app, memory } = setupTestApp({ products: [] });
    const response = await request(app)
      .post('/api/v1/scans')
      .set('Authorization', 'Bearer valid-token')
      .send({
        barcode: '8909998887776',
        productName: 'Unverified Local Snack',
        mrp: 20,
        chargedPrice: 25,
      });

    expect(response.status).toBe(201);
    expect(memory.products.get('8909998887776')).toBeUndefined();
  });
});
