import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp } from '../src/app.js';

function createPrisma() {
  const users = new Map();
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
        if (where.firebaseUid) return [...users.values()].find((user) => user.firebaseUid === where.firebaseUid) ?? null;
        return users.get(where.email) ?? null;
      },
      update: async ({ where, data }) => {
        const user = [...users.values()].find((item) => item.id === where.id);
        const updated = { ...user, ...data };
        users.set(updated.email, updated);
        return updated;
      },
    },
  };
  return { db, users };
}

const env = {
  NODE_ENV: 'test',
  PORT: 3000,
  DATABASE_URL: 'postgresql://test:test@localhost/test',
  JWT_SECRET: 'test-secret-that-is-long-enough-for-signing',
  JWT_EXPIRES_IN: '1h',
  CORS_ALLOWED_ORIGIN: undefined,
};

function setup(token = { uid: 'firebase-user-1', email: 'user@example.test', email_verified: true, name: 'Test User' }) {
  const memory = createPrisma();
  const verifyToken = async (value) => {
    if (value !== 'valid-token') throw new Error('invalid token');
    return token;
  };
  return { ...memory, app: createApp({ env, prismaClient: memory.db, verifyToken }) };
}

describe('Firebase authentication integration', () => {
  it('returns public root health before the not-found handler', async () => {
    const { app } = setup();
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: 'ok' });
  });

  it('creates a PostgreSQL user mapping from a verified Firebase token', async () => {
    const { app, users } = setup();
    const response = await request(app).get('/api/v1/me').set('Authorization', 'Bearer valid-token');
    expect(response.status).toBe(200);
    expect(response.body.data.email).toBe('user@example.test');
    expect(response.body.data.firebaseUid).toBe('firebase-user-1');
    expect(users.size).toBe(1);
  });

  it('reuses an existing email record and links its Firebase UID', async () => {
    const { app, db, users } = setup();
    const existing = await db.user.create({ data: { email: 'user@example.test', passwordHash: 'legacy-hash', emailVerifiedAt: null } });
    const response = await request(app).get('/api/v1/me').set('Authorization', 'Bearer valid-token');
    expect(response.status).toBe(200);
    expect(response.body.data.id).toBe(existing.id);
    expect(response.body.data.firebaseUid).toBe('firebase-user-1');
    expect(users.size).toBe(1);
  });

  it('rejects missing, invalid, and unverified Firebase tokens', async () => {
    const missing = await request(appFor({ uid: 'unused', email: 'unused@example.test', email_verified: true })).get('/api/v1/me');
    expect(missing.status).toBe(401);
    const invalid = await request(appFor({ uid: 'unused', email: 'unused@example.test', email_verified: true })).get('/api/v1/me').set('Authorization', 'Bearer bad-token');
    expect(invalid.status).toBe(401);
    const unverified = await request(appFor({ uid: 'unverified', email: 'unverified@example.test', email_verified: false })).get('/api/v1/me').set('Authorization', 'Bearer valid-token');
    expect(unverified.status).toBe(403);
    expect(unverified.body.error.code).toBe('EMAIL_NOT_VERIFIED');
  });
});

function appFor(token) {
  return setup(token).app;
}
