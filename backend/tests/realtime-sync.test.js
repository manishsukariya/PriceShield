import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp } from '../src/app.js';

function createMockPrisma() {
  const users = [
    {
      id: 'usr-1',
      email: 'alice@example.test',
      firebaseUid: 'fb-alice',
      trustScore: 70,
      riskScore: 10,
      riskFlags: [],
      updatedAt: new Date(),
    },
    {
      id: 'usr-2',
      email: 'bob@example.test',
      firebaseUid: 'fb-bob',
      trustScore: 50,
      riskScore: 0,
      riskFlags: [],
      updatedAt: new Date(),
    },
  ];

  const complaints = [
    {
      id: 'cmp-101',
      userId: 'usr-1',
      barcode: '8901030960018',
      productName: 'Boost Health Drink 500g',
      venueType: 'RETAIL',
      quantity: 1,
      mrp: 260.0,
      chargedPrice: 285.0,
      totalPaid: 285.0,
      overcharge: 25.0,
      paymentMethod: 'UPI',
      utrNumber: '499988881001',
      merchantName: 'Sharma General Store',
      merchantVpa: 'sharma@okaxis',
      storeFingerprint: 'fp-sharma-1',
      address: 'Shop 4, Market Road, Pune',
      status: 'PENDING',
      confidenceLevel: 'STRONG',
      isPublicEligible: true,
      riskScore: 12,
      riskFlags: [],
      createdAt: new Date(),
      updatedAt: new Date(),
      evidence: [],
    },
  ];

  const products = [];

  return {
    $queryRawUnsafe: async () => 1,
    user: {
      findUnique: async ({ where }) => {
        if (where.id) return users.find((u) => u.id === where.id) ?? null;
        if (where.firebaseUid) return users.find((u) => u.firebaseUid === where.firebaseUid) ?? null;
        if (where.email) return users.find((u) => u.email === where.email) ?? null;
        return null;
      },
      update: async ({ where, data }) => {
        const u = users.find((item) => item.id === where.id);
        if (!u) return null;
        Object.assign(u, data, { updatedAt: new Date() });
        return u;
      },
      count: async () => users.length,
    },
    complaint: {
      findUnique: async ({ where }) => complaints.find((c) => c.id === where.id) ?? null,
      findFirst: async ({ where }) => {
        return complaints.find((c) => {
          if (where.id && c.id !== where.id) return false;
          if (where.userId && c.userId !== where.userId) return false;
          return true;
        }) ?? null;
      },
      findMany: async () => complaints,
      count: async () => complaints.length,
      update: async ({ where, data }) => {
        const c = complaints.find((item) => item.id === where.id);
        if (!c) return null;
        Object.assign(c, data, { updatedAt: new Date() });
        return c;
      },
    },
    scan: {
      count: async () => 42,
    },
    product: {
      findUnique: async ({ where }) => products.find((p) => p.barcode === where.barcode) ?? null,
      findMany: async () => products,
      upsert: async ({ where, update, create }) => {
        let p = products.find((item) => item.barcode === where.barcode);
        if (p) {
          Object.assign(p, update, { updatedAt: new Date() });
        } else {
          p = { id: `prod-${Date.now()}`, ...create, createdAt: new Date(), updatedAt: new Date() };
          products.push(p);
        }
        return p;
      },
      update: async ({ where, data }) => {
        const p = products.find((item) => item.id === where.id);
        if (!p) return null;
        Object.assign(p, data, { updatedAt: new Date() });
        return p;
      },
    },
  };
}

const env = {
  NODE_ENV: 'test',
  PORT: 3000,
  DATABASE_URL: 'postgresql://test:test@localhost/test',
  ADMIN_MODERATION_KEY: 'test-admin-moderation-secret-key',
  JWT_SECRET: 'test-secret-that-is-long-enough-for-signing',
};

function setupTestApp() {
  const prisma = createMockPrisma();
  const verifyToken = async (token) => {
    if (token === 'token-alice') {
      return { uid: 'fb-alice', email: 'alice@example.test', email_verified: true };
    }
    if (token === 'token-bob') {
      return { uid: 'fb-bob', email: 'bob@example.test', email_verified: true };
    }
    throw new Error('Invalid test token');
  };

  const app = createApp({
    env,
    prismaClient: prisma,
    verifyToken,
  });

  return { app, prisma };
}

describe('Realtime Event Stream & Admin Moderation API', () => {
  it('allows admin to moderate status and add notes on complaints', async () => {
    const { app } = setupTestApp();

    const patchRes = await request(app)
      .patch('/api/v1/admin/complaints/cmp-101')
      .set('x-admin-key', env.ADMIN_MODERATION_KEY)
      .send({
        status: 'RESOLVED',
        moderationNotes: 'Store owner verified printed MRP was Rs 260 and refunded Rs 25 to complainant via UPI.',
      });

    expect(patchRes.status).toBe(200);
    expect(patchRes.body.data.complaint.status).toBe('RESOLVED');
    expect(patchRes.body.data.complaint.moderationNotes).toContain('refunded Rs 25');
  });

  it('returns corporate operational metrics via GET /api/v1/admin/metrics', async () => {
    const { app } = setupTestApp();

    const metricsRes = await request(app)
      .get('/api/v1/admin/metrics')
      .set('x-admin-key', env.ADMIN_MODERATION_KEY);

    expect(metricsRes.status).toBe(200);
    expect(metricsRes.body.data.activeCasesCount).toBeDefined();
    expect(metricsRes.body.data.totalScansToday).toBeGreaterThan(0);
    expect(metricsRes.body.data.totalOverchargedRupees).toBeDefined();
  });

  it('persists intermediate stage INVESTIGATING and retrieves it via GET endpoints', async () => {
    const { app } = setupTestApp();

    const patchRes = await request(app)
      .patch('/api/v1/admin/complaints/cmp-101')
      .set('x-admin-key', env.ADMIN_MODERATION_KEY)
      .send({
        status: 'INVESTIGATING',
        moderationNotes: 'Operations officer contacted store manager for explanation.',
      });

    expect(patchRes.status).toBe(200);
    expect(patchRes.body.data.complaint.status).toBe('INVESTIGATING');

    // Fetch as consumer
    const getRes = await request(app)
      .get('/api/v1/complaints/cmp-101')
      .set('Authorization', 'Bearer token-alice');

    expect(getRes.status).toBe(200);
    expect(getRes.body.data.status).toBe('INVESTIGATING');

    // Admin filter query
    const adminFilterRes = await request(app)
      .get('/api/v1/admin/complaints?status=INVESTIGATING')
      .set('x-admin-key', env.ADMIN_MODERATION_KEY);

    expect(adminFilterRes.status).toBe(200);
    expect(adminFilterRes.body.data.length).toBe(1);
    expect(adminFilterRes.body.data[0].status).toBe('INVESTIGATING');
  });

  it('clears previous STAGE_ flags when complaint is marked RESOLVED', async () => {
    const { app } = setupTestApp();

    // First set to INVESTIGATING
    await request(app)
      .patch('/api/v1/admin/complaints/cmp-101')
      .set('x-admin-key', env.ADMIN_MODERATION_KEY)
      .send({ status: 'INVESTIGATING' });

    // Then transition to RESOLVED
    const resolveRes = await request(app)
      .patch('/api/v1/admin/complaints/cmp-101')
      .set('x-admin-key', env.ADMIN_MODERATION_KEY)
      .send({ status: 'RESOLVED', moderationNotes: 'Refund completed' });

    expect(resolveRes.status).toBe(200);
    expect(resolveRes.body.data.complaint.status).toBe('RESOLVED');
    expect(resolveRes.body.data.complaint.riskFlags.some((f) => f.startsWith('STAGE_'))).toBe(false);

    const getRes = await request(app)
      .get('/api/v1/complaints/cmp-101')
      .set('Authorization', 'Bearer token-alice');

    expect(getRes.status).toBe(200);
    expect(getRes.body.data.status).toBe('RESOLVED');
  });

  it('supports admin product catalog CRUD operations', async () => {
    const { app } = setupTestApp();

    // Create / upsert product
    const createRes = await request(app)
      .post('/api/v1/admin/products')
      .set('x-admin-key', env.ADMIN_MODERATION_KEY)
      .send({
        barcode: '8901234567890',
        name: 'Organic Wheat Flour 5kg',
        mrp: 320.0,
      });

    expect(createRes.status).toBe(201);
    expect(createRes.body.data.barcode).toBe('8901234567890');
    expect(Number(createRes.body.data.mrp)).toBe(320.0);

    // List products
    const listRes = await request(app)
      .get('/api/v1/admin/products')
      .set('x-admin-key', env.ADMIN_MODERATION_KEY);

    expect(listRes.status).toBe(200);
    expect(listRes.body.data.length).toBeGreaterThanOrEqual(1);

    // Patch product
    const patchRes = await request(app)
      .patch(`/api/v1/admin/products/${createRes.body.data.id}`)
      .set('x-admin-key', env.ADMIN_MODERATION_KEY)
      .send({ mrp: 340.0 });

    expect(patchRes.status).toBe(200);
    expect(Number(patchRes.body.data.mrp)).toBe(340.0);
  });
});
