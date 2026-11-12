import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp } from '../src/app.js';
import {
  classifyEvidenceConfidence,
  normalizeCanonicalEmail,
} from '../src/utils/anti-fraud.js';
import { isTrustedCloudinaryUrl } from '../src/utils/media-url.js';

function createMockPrisma() {
  const users = [];
  const complaints = [];
  const evidence = [];
  let nextId = 1;

  const matchesFilter = (value, filter) => {
    if (filter === undefined) return true;
    if (filter && typeof filter === 'object' && !Array.isArray(filter) && !(filter instanceof Date)) {
      if ('in' in filter) return filter.in.includes(value);
      if ('not' in filter) return value !== filter.not;
      if ('gte' in filter) return value >= filter.gte;
      if ('gt' in filter) return value > filter.gt;
    }
    return value === filter;
  };

  const attachRelations = (complaint, include = {}) => {
    const result = { ...complaint };
    if (include.evidence) {
      result.evidence = evidence.filter((e) => e.complaintId === complaint.id);
    }
    if (include.user) {
      const u = users.find((user) => user.id === complaint.userId) ?? null;
      result.user = u;
    }
    return result;
  };

  const matchComplaint = (c, where = {}) => {
    if (!where) return true;
    for (const [key, cond] of Object.entries(where)) {
      if (key === 'userId_clientRequestId') {
        if (c.userId !== cond.userId || c.clientRequestId !== cond.clientRequestId) return false;
      } else if (!matchesFilter(c[key], cond)) {
        return false;
      }
    }
    return true;
  };

  const db = {
    $queryRawUnsafe: async () => 1,
    user: {
      create: async ({ data }) => {
        const user = {
          id: `user-${nextId++}`,
          trustScore: 50,
          riskScore: 0,
          riskFlags: [],
          createdAt: new Date(),
          updatedAt: new Date(),
          ...data,
        };
        users.push(user);
        return user;
      },
      findUnique: async ({ where }) => {
        if (where.firebaseUid) return users.find((u) => u.firebaseUid === where.firebaseUid) ?? null;
        if (where.email) return users.find((u) => u.email === where.email) ?? null;
        if (where.id) return users.find((u) => u.id === where.id) ?? null;
        return null;
      },
      update: async ({ where, data }) => {
        const idx = users.findIndex((u) => u.id === where.id);
        if (idx === -1) return null;
        users[idx] = { ...users[idx], ...data, updatedAt: new Date() };
        return users[idx];
      },
      count: async ({ where = {} } = {}) => {
        return users.filter((u) => {
          if (where.canonicalEmail && u.canonicalEmail !== where.canonicalEmail) return false;
          if (where.id && !matchesFilter(u.id, where.id)) return false;
          return true;
        }).length;
      },
    },
    complaint: {
      create: async ({ data, include }) => {
        const { evidence: nestedEvidence, ...rest } = data;
        const created = {
          id: `cmp-${nextId++}`,
          status: 'PENDING',
          withdrawnAt: null,
          moderationNotes: null,
          moderatedAt: null,
          merchantResponse: null,
          merchantRespondedAt: null,
          createdAt: new Date(),
          updatedAt: new Date(),
          ...rest,
        };
        complaints.push(created);
        if (nestedEvidence?.create?.length) {
          for (const ev of nestedEvidence.create) {
            evidence.push({
              id: `ev-${nextId++}`,
              complaintId: created.id,
              role: 'OTHER',
              sha256Hash: null,
              createdAt: new Date(),
              ...ev,
            });
          }
        }
        return attachRelations(created, include);
      },
      findUnique: async ({ where, include }) => {
        const found = complaints.find((c) => {
          if (where.id) return c.id === where.id;
          if (where.userId_clientRequestId) {
            return (
              c.userId === where.userId_clientRequestId.userId &&
              c.clientRequestId === where.userId_clientRequestId.clientRequestId
            );
          }
          return false;
        });
        return found ? attachRelations(found, include) : null;
      },
      findFirst: async ({ where, include }) => {
        const found = complaints.find((c) => matchComplaint(c, where));
        return found ? attachRelations(found, include) : null;
      },
      findMany: async ({ where = {}, include, take, skip = 0, cursor } = {}) => {
        let list = complaints
          .filter((c) => matchComplaint(c, where))
          .sort((a, b) => b.createdAt - a.createdAt);
        if (cursor?.id) {
          const idx = list.findIndex((c) => c.id === cursor.id);
          if (idx !== -1) list = list.slice(idx + skip);
        }
        if (take != null) list = list.slice(0, take);
        return list.map((c) => attachRelations(c, include));
      },
      count: async ({ where = {} } = {}) => {
        return complaints.filter((c) => matchComplaint(c, where)).length;
      },
      update: async ({ where, data, include }) => {
        const idx = complaints.findIndex((c) => c.id === where.id);
        if (idx === -1) return null;
        complaints[idx] = { ...complaints[idx], ...data, updatedAt: new Date() };
        return attachRelations(complaints[idx], include);
      },
      updateMany: async ({ where = {}, data }) => {
        let count = 0;
        for (let i = 0; i < complaints.length; i += 1) {
          if (matchComplaint(complaints[i], where)) {
            complaints[i] = { ...complaints[i], ...data, updatedAt: new Date() };
            count += 1;
          }
        }
        return { count };
      },
    },
    evidence: {
      create: async ({ data }) => {
        const created = {
          id: `ev-${nextId++}`,
          role: 'OTHER',
          sha256Hash: null,
          createdAt: new Date(),
          ...data,
        };
        evidence.push(created);
        return created;
      },
      findFirst: async ({ where = {} } = {}) => {
        return (
          evidence.find((e) => {
            if (where.sha256Hash && !matchesFilter(e.sha256Hash, where.sha256Hash)) return false;
            if (where.complaintId && !matchesFilter(e.complaintId, where.complaintId)) return false;
            if (where.complaint) {
              const parent = complaints.find((c) => c.id === e.complaintId);
              if (!parent || !matchComplaint(parent, where.complaint)) return false;
            }
            return true;
          }) ?? null
        );
      },
    },
  };

  return { db, users, complaints, evidence };
}

const env = {
  NODE_ENV: 'test',
  PORT: 3000,
  DATABASE_URL: 'postgresql://test:test@localhost/test',
  ADMIN_MODERATION_KEY: 'test-admin-moderation-secret-key',
};

const VALID_CLOUD_IMG_1 = 'https://res.cloudinary.com/mpz1wxhc/image/upload/v1/packet-mrp.jpg';
const VALID_CLOUD_IMG_2 = 'https://res.cloudinary.com/mpz1wxhc/image/upload/v1/upi-proof.jpg';
const VALID_CLOUD_IMG_3 = 'https://res.cloudinary.com/mpz1wxhc/image/upload/v1/bill.jpg';
const VALID_CLOUD_VIDEO = 'https://res.cloudinary.com/mpz1wxhc/video/upload/v1/purchase.mp4';
const HASH_A = 'a'.repeat(64);
const HASH_B = 'b'.repeat(64);
const HASH_C = 'c'.repeat(64);
const HASH_D = 'd'.repeat(64);

function setup({ complaintRateLimit } = {}) {
  const memory = createMockPrisma();
  const tokens = {
    'token-alice': { uid: 'fb-alice', email: 'alice.smith@gmail.com', email_verified: true, name: 'Alice' },
    'token-alice-alias': { uid: 'fb-alice-2', email: 'alicesmith+spam@gmail.com', email_verified: true, name: 'Alice Alias' },
    'token-bob': { uid: 'fb-bob', email: 'bob.verma@yahoo.com', email_verified: true, name: 'Bob' },
  };
  const verifyToken = async (value) => {
    const decoded = tokens[value];
    if (!decoded) throw new Error('invalid token');
    return decoded;
  };
  const app = createApp({ env, prismaClient: memory.db, verifyToken, complaintRateLimit });
  return { ...memory, app };
}

function basePayload(overrides = {}) {
  return {
    venueType: 'RETAIL',
    barcode: '8901764012241',
    productName: 'Coca-Cola 750ml',
    quantity: 1,
    mrp: 40,
    chargedPrice: 50,
    totalPaid: 50,
    paymentMethod: 'UPI',
    utrNumber: '412345678901',
    merchantName: 'Sharma Cold Drinks',
    merchantVpa: 'sharma.drinks@okaxis',
    address: 'Shop 14, Main Market, Sector 18, Noida',
    latitude: 28.5706,
    longitude: 77.326,
    purchaseDate: new Date(Date.now() - 60 * 60 * 1000).toISOString(),
    evidence: [
      {
        url: VALID_CLOUD_IMG_1,
        mediaType: 'IMAGE',
        role: 'PACKET_MRP',
        sha256Hash: HASH_A,
      },
      {
        url: VALID_CLOUD_IMG_2,
        mediaType: 'IMAGE',
        role: 'PAYMENT_PROOF',
        sha256Hash: HASH_B,
      },
    ],
    ...overrides,
  };
}

describe('Anti-fraud utility checks', () => {
  it('normalizes Gmail dots and +alias suffixes into canonical emails', () => {
    expect(normalizeCanonicalEmail('Alice.Smith+test@gmail.com')).toBe('alicesmith@gmail.com');
    expect(normalizeCanonicalEmail('a.b.c+123@googlemail.com')).toBe('abc@gmail.com');
    expect(normalizeCanonicalEmail('User.Name+promo@yahoo.com')).toBe('user.name@yahoo.com');
  });

  it('pins Cloudinary media URLs to the configured cloud name', () => {
    expect(isTrustedCloudinaryUrl('https://res.cloudinary.com/mpz1wxhc/image/upload/v1/test.jpg')).toBe(true);
    expect(isTrustedCloudinaryUrl('https://res.cloudinary.com/mpz1wxhc/video/upload/v1/clip.mp4')).toBe(true);
    expect(isTrustedCloudinaryUrl('https://res.cloudinary.com/othercloud/image/upload/v1/test.jpg')).toBe(false);
    expect(isTrustedCloudinaryUrl('https://evil.cloudinary.com/mpz1wxhc/image/upload/v1/test.jpg')).toBe(false);
    expect(isTrustedCloudinaryUrl('https://res.cloudinary.com/mpz1wxhc/raw/upload/v1/payload.html')).toBe(false);
  });

  it('requires PACKET_MRP for non-UNVERIFIED confidence classification', () => {
    expect(classifyEvidenceConfidence({ evidence: [] })).toBe('UNVERIFIED');
    expect(
      classifyEvidenceConfidence({
        evidence: [{ role: 'PAYMENT_PROOF', mediaType: 'IMAGE' }],
      }),
    ).toBe('UNVERIFIED');
    expect(
      classifyEvidenceConfidence({
        evidence: [
          { role: 'PACKET_MRP', mediaType: 'IMAGE' },
          { role: 'PAYMENT_PROOF', mediaType: 'IMAGE' },
        ],
      }),
    ).toBe('BASIC');
    expect(
      classifyEvidenceConfidence({
        evidence: [
          { role: 'PACKET_MRP', mediaType: 'IMAGE' },
          { role: 'ITEMIZED_BILL', mediaType: 'IMAGE' },
        ],
      }),
    ).toBe('STRONG');
    expect(
      classifyEvidenceConfidence({
        evidence: [
          { role: 'PACKET_MRP', mediaType: 'IMAGE' },
          { role: 'VIDEO_PROOF', mediaType: 'VIDEO' },
        ],
      }),
    ).toBe('STRONG');
  });
});

describe('Complaint anti-fraud & moderation API', () => {
  it('blocks RESTAURANT dine-in complaints under SC FHRAI 2017', async () => {
    const { app } = setup();
    const res = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload({ venueType: 'RESTAURANT' }));

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('RESTAURANT_MRP_EXEMPT');
  });

  it('enforces mandatory fields, quantity/totalPaid math, UTR for UPI, barcode, and purchaseDate bounds', async () => {
    const { app } = setup();

    // Invalid barcode (repeated digits)
    const badBarcode = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload({ barcode: '00000000' }));
    expect(badBarcode.status).toBe(400);

    // totalPaid < chargedPrice * quantity
    const badTotal = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload({ quantity: 2, chargedPrice: 50, totalPaid: 60 }));
    expect(badTotal.status).toBe(400);

    // Missing UTR on UPI
    const missingUtr = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload({ paymentMethod: 'UPI', utrNumber: '' }));
    expect(missingUtr.status).toBe(400);

    // Future purchaseDate
    const futureDate = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload({ purchaseDate: new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString() }));
    expect(futureDate.status).toBe(400);

    // > 30 days old purchaseDate
    const staleDate = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload({ purchaseDate: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000).toISOString() }));
    expect(staleDate.status).toBe(400);
  });

  it('allows CASH complaint without photos as private UNVERIFIED record (never public eligible)', async () => {
    const { app } = setup();
    const res = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(
        basePayload({
          paymentMethod: 'CASH',
          utrNumber: undefined,
          merchantVpa: undefined,
          evidence: [],
        }),
      );

    expect(res.status).toBe(201);
    expect(res.body.data.confidenceLevel).toBe('UNVERIFIED');
    expect(res.body.data.isPublicEligible).toBe(false);
    expect(res.body.data.riskFlags).toContain('UNVERIFIED_CLAIM');
  });

  it('classifies BASIC vs STRONG confidence levels accurately', async () => {
    const { app } = setup();

    const basicRes = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload());
    expect(basicRes.status).toBe(201);
    expect(basicRes.body.data.confidenceLevel).toBe('BASIC');
    expect(basicRes.body.data.isPublicEligible).toBe(false);

    const strongRes = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-bob')
      .send(
        basePayload({
          utrNumber: '412345678902',
          merchantName: 'Metro Mart',
          merchantVpa: 'metromart@okicici',
          evidence: [
            { url: VALID_CLOUD_IMG_1, mediaType: 'IMAGE', role: 'PACKET_MRP', sha256Hash: HASH_C },
            { url: VALID_CLOUD_VIDEO, mediaType: 'VIDEO', role: 'VIDEO_PROOF', sha256Hash: HASH_D },
          ],
        }),
      );
    expect(strongRes.status).toBe(201);
    expect(strongRes.body.data.confidenceLevel).toBe('STRONG');
    expect(strongRes.body.data.isPublicEligible).toBe(true);
  });

  it('blocks duplicate UTR reuse (409) across active/resolved complaints and allows reuse after withdrawal', async () => {
    const { app } = setup();

    const first = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload({ utrNumber: '499988887777' }));
    expect(first.status).toBe(201);

    const dup = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-bob')
      .send(
        basePayload({
          utrNumber: '499988887777',
          evidence: [
            { url: VALID_CLOUD_IMG_3, mediaType: 'IMAGE', role: 'PACKET_MRP', sha256Hash: HASH_C },
          ],
        }),
      );
    expect(dup.status).toBe(409);
    expect(dup.body.error.code).toBe('DUPLICATE_UTR');

    // Withdraw first complaint -> UTR can now be filed cleanly
    const withdrawn = await request(app)
      .delete(`/api/v1/complaints/${first.body.data.id}`)
      .set('Authorization', 'Bearer token-alice');
    expect(withdrawn.status).toBe(204);

    const refiled = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-bob')
      .send(
        basePayload({
          utrNumber: '499988887777',
          evidence: [
            { url: VALID_CLOUD_IMG_3, mediaType: 'IMAGE', role: 'PACKET_MRP', sha256Hash: HASH_C },
          ],
        }),
      );
    expect(refiled.status).toBe(201);
  });

  it('blocks duplicate sha256Hash within same complaint (400) and across complaints (409)', async () => {
    const { app } = setup();

    const sameRequestDup = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(
        basePayload({
          evidence: [
            { url: VALID_CLOUD_IMG_1, mediaType: 'IMAGE', role: 'PACKET_MRP', sha256Hash: HASH_A },
            { url: VALID_CLOUD_IMG_2, mediaType: 'IMAGE', role: 'PAYMENT_PROOF', sha256Hash: HASH_A },
          ],
        }),
      );
    expect(sameRequestDup.status).toBe(400);
    expect(sameRequestDup.body.error.code).toBe('DUPLICATE_EVIDENCE');

    const first = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload());
    expect(first.status).toBe(201);

    const crossComplaintDup = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-bob')
      .send(
        basePayload({
          utrNumber: '512345678999',
          evidence: [
            { url: VALID_CLOUD_IMG_3, mediaType: 'IMAGE', role: 'PACKET_MRP', sha256Hash: HASH_A },
          ],
        }),
      );
    expect(crossComplaintDup.status).toBe(409);
    expect(crossComplaintDup.body.error.code).toBe('DUPLICATE_EVIDENCE_HASH');
  });

  it('locks POST /complaints/:id/evidence to PENDING and max 5 items, and upgrades confidence when bill added', async () => {
    const { app } = setup();

    const created = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload());
    expect(created.status).toBe(201);
    expect(created.body.data.confidenceLevel).toBe('BASIC');
    const id = created.body.data.id;

    // Add itemized bill -> upgrades BASIC to STRONG
    const addBill = await request(app)
      .post(`/api/v1/complaints/${id}/evidence`)
      .set('Authorization', 'Bearer token-alice')
      .send({
        url: VALID_CLOUD_IMG_3,
        mediaType: 'IMAGE',
        role: 'ITEMIZED_BILL',
        sha256Hash: HASH_C,
      });
    expect(addBill.status).toBe(201);

    const fetched = await request(app)
      .get(`/api/v1/complaints/${id}`)
      .set('Authorization', 'Bearer token-alice');
    expect(fetched.status).toBe(200);
    expect(fetched.body.data.confidenceLevel).toBe('STRONG');
    expect(fetched.body.data.evidence).toHaveLength(3);

    // Add 4th and 5th item
    for (let i = 4; i <= 5; i += 1) {
      const r = await request(app)
        .post(`/api/v1/complaints/${id}/evidence`)
        .set('Authorization', 'Bearer token-alice')
        .send({
          url: `https://res.cloudinary.com/mpz1wxhc/image/upload/v1/extra-${i}.jpg`,
          mediaType: 'IMAGE',
          role: 'OTHER',
          sha256Hash: `${i}`.repeat(64),
        });
      expect(r.status).toBe(201);
    }

    // 6th evidence item must fail
    const sixth = await request(app)
      .post(`/api/v1/complaints/${id}/evidence`)
      .set('Authorization', 'Bearer token-alice')
      .send({
        url: 'https://res.cloudinary.com/mpz1wxhc/image/upload/v1/extra-6.jpg',
        mediaType: 'IMAGE',
        role: 'OTHER',
        sha256Hash: '6'.repeat(64),
      });
    expect(sixth.status).toBe(400);
    expect(sixth.body.error.code).toBe('EVIDENCE_LIMIT_EXCEEDED');

    // Admin resolves complaint -> adding evidence must be locked (409)
    const resolved = await request(app)
      .patch(`/api/v1/admin/complaints/${id}`)
      .set('x-admin-key', env.ADMIN_MODERATION_KEY)
      .send({ status: 'RESOLVED' });
    expect(resolved.status).toBe(200);

    const locked = await request(app)
      .post(`/api/v1/complaints/${id}/evidence`)
      .set('Authorization', 'Bearer token-alice')
      .send({
        url: 'https://res.cloudinary.com/mpz1wxhc/image/upload/v1/extra-7.jpg',
        mediaType: 'IMAGE',
        role: 'OTHER',
      });
    expect(locked.status).toBe(409);
    expect(locked.body.error.code).toBe('COMPLAINT_LOCKED');
  });

  it('prevents Gmail alias self-corroboration and promotes store to CORROBORATED only for distinct independent users', async () => {
    const { app } = setup();

    // 1. Alice files BASIC complaint against store
    const aliceCmp = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload());
    expect(aliceCmp.status).toBe(201);
    expect(aliceCmp.body.data.confidenceLevel).toBe('BASIC');

    // 2. Alice's Gmail alias (alicesmith+spam@gmail.com) tries to corroborate same store
    const aliasCmp = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice-alias')
      .send(
        basePayload({
          utrNumber: '412345678902',
          evidence: [
            { url: VALID_CLOUD_IMG_3, mediaType: 'IMAGE', role: 'PACKET_MRP', sha256Hash: HASH_C },
            { url: 'https://res.cloudinary.com/mpz1wxhc/image/upload/v1/upi2.jpg', mediaType: 'IMAGE', role: 'PAYMENT_PROOF', sha256Hash: HASH_D },
          ],
        }),
      );
    expect(aliasCmp.status).toBe(201);
    expect(aliasCmp.body.data.confidenceLevel).toBe('BASIC');
    expect(aliasCmp.body.data.riskFlags).toContain('DUPLICATE_CANONICAL_EMAIL_ACCOUNT');

    // Store risk signal must NOT be corroborated yet
    const riskBefore = await request(app)
      .get('/api/v1/stores/risk?merchantVpa=sharma.drinks@okaxis');
    expect(riskBefore.status).toBe(200);
    expect(riskBefore.body.data.isCorroborated).toBe(false);

    // 3. Independent user Bob files BASIC complaint against same store
    const bobCmp = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-bob')
      .send(
        basePayload({
          utrNumber: '412345678903',
          evidence: [
            { url: 'https://res.cloudinary.com/mpz1wxhc/image/upload/v1/bob1.jpg', mediaType: 'IMAGE', role: 'PACKET_MRP', sha256Hash: 'e'.repeat(64) },
            { url: 'https://res.cloudinary.com/mpz1wxhc/image/upload/v1/bob2.jpg', mediaType: 'IMAGE', role: 'PAYMENT_PROOF', sha256Hash: 'f'.repeat(64) },
          ],
        }),
      );
    expect(bobCmp.status).toBe(201);
    expect(bobCmp.body.data.confidenceLevel).toBe('CORROBORATED');
    expect(bobCmp.body.data.isPublicEligible).toBe(true);

    // Store risk signal is now corroborated
    const riskAfter = await request(app)
      .get('/api/v1/stores/risk?merchantVpa=sharma.drinks@okaxis');
    expect(riskAfter.status).toBe(200);
    expect(riskAfter.body.data.isCorroborated).toBe(true);
    expect(riskAfter.body.data.independentReporterCount).toBe(2);

    // Admin rejects Bob's complaint -> Alice's complaint must revert from CORROBORATED to BASIC
    const rejectBob = await request(app)
      .patch(`/api/v1/admin/complaints/${bobCmp.body.data.id}`)
      .set('x-admin-key', env.ADMIN_MODERATION_KEY)
      .send({
        status: 'REJECTED',
        moderationNotes: 'Receipt mismatch during review.',
        merchantResponse: 'Merchant submitted GST invoice showing MRP compliance.',
      });
    expect(rejectBob.status).toBe(200);
    expect(rejectBob.body.data.complaint.status).toBe('REJECTED');
    expect(rejectBob.body.data.complaint.merchantResponse).toContain('GST invoice');
    expect(rejectBob.body.data.userReputation.trustScore).toBe(35);
    expect(rejectBob.body.data.userReputation.riskFlags).toContain('REJECTED_COMPLAINT');

    const aliceAfterReject = await request(app)
      .get(`/api/v1/complaints/${aliceCmp.body.data.id}`)
      .set('Authorization', 'Bearer token-alice');
    expect(aliceAfterReject.status).toBe(200);
    expect(aliceAfterReject.body.data.confidenceLevel).toBe('BASIC');
  });

  it('rate-limits complaints across Gmail canonical aliases and guards admin endpoints', async () => {
    const { app } = setup({ complaintRateLimit: { windowMs: 60000, max: 2 } });

    const r1 = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload({ utrNumber: '400000000001', evidence: [] }));
    expect(r1.status).toBe(201);

    const r2 = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice-alias')
      .send(basePayload({ utrNumber: '400000000002', evidence: [] }));
    expect(r2.status).toBe(201);

    // 3rd request from same canonical email hits per-user rate limit
    const r3 = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload({ utrNumber: '400000000003', evidence: [] }));
    expect(r3.status).toBe(429);
    expect(r3.body.error.code).toBe('RATE_LIMIT_EXCEEDED');

    // Admin list rejects bad key and works with valid key
    const badAdmin = await request(app)
      .get('/api/v1/admin/complaints')
      .set('x-admin-key', 'invalid');
    expect(badAdmin.status).toBe(403);

    const okAdmin = await request(app)
      .get('/api/v1/admin/complaints?status=PENDING')
      .set('x-admin-key', env.ADMIN_MODERATION_KEY);
    expect(okAdmin.status).toBe(200);
    expect(okAdmin.body.data).toHaveLength(2);
  });

  it('preserves clientRequestId idempotency without tripping duplicate UTR', async () => {
    const { app } = setup();
    const payload = basePayload({ clientRequestId: 'cmp-idempotent-12345' });

    const first = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(payload);
    expect(first.status).toBe(201);

    const retry = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(payload);
    expect(retry.status).toBe(200);
    expect(retry.body.data.id).toBe(first.body.data.id);
  });

  it('persists canonicalEmail for pre-existing users on auth and blocks CARD short UTR & partial storeRisk queries', async () => {
    const memory = createMockPrisma();
    // Simulate a pre-migration user with canonicalEmail = null
    const legacyAlice = await memory.db.user.create({
      data: {
        firebaseUid: 'fb-alice',
        email: 'alice.smith@gmail.com',
        canonicalEmail: null,
        emailVerifiedAt: new Date(),
      },
    });
    const tokens = {
      'token-alice': { uid: 'fb-alice', email: 'alice.smith@gmail.com', email_verified: true },
      'token-alice-alias': { uid: 'fb-alice-2', email: 'alicesmith+new@gmail.com', email_verified: true },
    };
    const app = createApp({
      env,
      prismaClient: memory.db,
      verifyToken: async (v) => tokens[v],
    });

    // Authenticating legacy Alice persists canonicalEmail to DB
    const me = await request(app)
      .get('/api/v1/me')
      .set('Authorization', 'Bearer token-alice');
    expect(me.status).toBe(200);
    expect(memory.users.find((u) => u.id === legacyAlice.id).canonicalEmail).toBe('alicesmith@gmail.com');

    // Alias account sees DUPLICATE_CANONICAL_EMAIL_ACCOUNT risk flag
    const aliasCmp = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice-alias')
      .send(basePayload({ merchantVpa: 'shop@kotak811' }));
    expect(aliasCmp.status).toBe(201);
    expect(aliasCmp.body.data.merchantVpa).toBe('shop@kotak811');
    expect(aliasCmp.body.data.riskFlags).toContain('DUPLICATE_CANONICAL_EMAIL_ACCOUNT');

    // Short 4-digit CARD reference is rejected
    const badCardRef = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(basePayload({ paymentMethod: 'CARD', utrNumber: '1234', merchantVpa: undefined }));
    expect(badCardRef.status).toBe(400);

    // Partial /stores/risk query without address fails validation
    const partialRisk = await request(app).get('/api/v1/stores/risk?merchantName=Sharma');
    expect(partialRisk.status).toBe(400);
  });

  it('clears UNVERIFIED_CLAIM when upgraded and resets CORROBORATED on rejection or withdrawal', async () => {
    const { app } = setup();

    // Alice starts with UNVERIFIED CASH complaint
    const alice = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-alice')
      .send(
        basePayload({
          paymentMethod: 'CASH',
          utrNumber: undefined,
          merchantVpa: undefined,
          evidence: [],
        }),
      );
    expect(alice.status).toBe(201);
    expect(alice.body.data.riskFlags).toContain('UNVERIFIED_CLAIM');

    // Alice attaches PACKET_MRP and ITEMIZED_BILL -> upgrades to STRONG and clears UNVERIFIED_CLAIM
    const ev1 = await request(app)
      .post(`/api/v1/complaints/${alice.body.data.id}/evidence`)
      .set('Authorization', 'Bearer token-alice')
      .send({ url: VALID_CLOUD_IMG_1, mediaType: 'IMAGE', role: 'PACKET_MRP', sha256Hash: HASH_A });
    expect(ev1.status).toBe(201);

    const ev2 = await request(app)
      .post(`/api/v1/complaints/${alice.body.data.id}/evidence`)
      .set('Authorization', 'Bearer token-alice')
      .send({ url: VALID_CLOUD_IMG_3, mediaType: 'IMAGE', role: 'ITEMIZED_BILL', sha256Hash: HASH_B });
    expect(ev2.status).toBe(201);

    const aliceUpgraded = await request(app)
      .get(`/api/v1/complaints/${alice.body.data.id}`)
      .set('Authorization', 'Bearer token-alice');
    expect(aliceUpgraded.body.data.confidenceLevel).toBe('STRONG');
    expect(aliceUpgraded.body.data.riskFlags).not.toContain('UNVERIFIED_CLAIM');

    // Bob files BASIC at same store -> both become CORROBORATED
    const bob = await request(app)
      .post('/api/v1/complaints')
      .set('Authorization', 'Bearer token-bob')
      .send(
        basePayload({
          merchantVpa: undefined,
          utrNumber: '511122223333',
          evidence: [
            { url: VALID_CLOUD_IMG_2, mediaType: 'IMAGE', role: 'PACKET_MRP', sha256Hash: HASH_C },
            { url: 'https://res.cloudinary.com/mpz1wxhc/image/upload/v1/b2.jpg', mediaType: 'IMAGE', role: 'PAYMENT_PROOF', sha256Hash: HASH_D },
          ],
        }),
      );
    expect(bob.status).toBe(201);
    expect(bob.body.data.confidenceLevel).toBe('CORROBORATED');

    // Admin attaches merchantResponse without changing status, then rejects Bob
    const merchantNoteOnly = await request(app)
      .patch(`/api/v1/admin/complaints/${bob.body.data.id}`)
      .set('x-admin-key', env.ADMIN_MODERATION_KEY)
      .send({ merchantResponse: 'Store provided POS log.' });
    expect(merchantNoteOnly.status).toBe(200);
    expect(merchantNoteOnly.body.data.complaint.status).toBe('PENDING');

    const rejected = await request(app)
      .patch(`/api/v1/admin/complaints/${bob.body.data.id}`)
      .set('x-admin-key', env.ADMIN_MODERATION_KEY)
      .send({ status: 'REJECTED', moderationNotes: 'Invalid receipt.' });
    expect(rejected.status).toBe(200);
    expect(rejected.body.data.complaint.confidenceLevel).toBe('BASIC');

    const bobFetched = await request(app)
      .get(`/api/v1/complaints/${bob.body.data.id}`)
      .set('Authorization', 'Bearer token-bob');
    expect(bobFetched.body.data.storeRisk).toBeUndefined();
  });
});
