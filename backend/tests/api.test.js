import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp } from '../src/app.js';
import { hashPassword } from '../src/modules/auth/passwords.js';

function createPrisma() {
  const users = new Map(); const pending = new Map();
  const apply = (record, data) => Object.fromEntries(Object.entries(data).map(([key, value]) => [key, value?.increment != null ? (record[key] ?? 0) + value.increment : value]));
  const db = {
    $queryRawUnsafe: async () => 1,
    $transaction: async (work) => work(db),
    user: {
      create: async ({ data }) => { if (users.has(data.email)) { const error = new Error('duplicate'); error.code = 'P2002'; throw error; } const user = { id: `user-${users.size + 1}`, ...data }; users.set(user.email, user); return user; },
      findUnique: async ({ where }) => where.email ? users.get(where.email) ?? null : [...users.values()].find((user) => user.id === where.id) ?? null,
      update: async ({ where, data }) => ({ ...[...users.values()].find((user) => user.id === where.id), ...data }),
    },
    pendingRegistration: {
      findUnique: async ({ where }) => pending.get(where.email) ?? null,
      upsert: async ({ where, create, update }) => { const old = pending.get(where.email); const result = old ? { ...old, ...apply(old, update), updatedAt: new Date() } : { id: `pending-${pending.size + 1}`, sendCount: 0, failedAttempts: 0, createdAt: new Date(), ...create }; pending.set(result.email, result); return result; },
      update: async ({ where, data }) => { const old = [...pending.values()].find((item) => item.id === where.id); const result = { ...old, ...apply(old, data), updatedAt: new Date() }; pending.set(result.email, result); return result; },
      delete: async ({ where }) => { const item = [...pending.values()].find((value) => value.id === where.id); pending.delete(item.email); return item; },
    },
    product: { findUnique: async () => null },
    scan: { create: async ({ data }) => ({ id: 'scan-1', ...data }), findMany: async () => [], findUnique: async () => null },
    complaint: { create: async ({ data }) => ({ id: 'complaint-1', ...data, evidence: [] }), findMany: async () => [], findFirst: async () => null, updateMany: async () => ({ count: 0 }), findUnique: async () => null },
    evidence: { create: async ({ data }) => ({ id: 'evidence-1', ...data }) }, productSubmission: { create: async ({ data }) => ({ id: 'submission-1', status: 'PENDING', ...data }), findMany: async () => [] },
  };
  return { db, users, pending };
}
const env = { NODE_ENV: 'test', PORT: 3000, DATABASE_URL: 'postgresql://test:test@localhost/test', JWT_SECRET: 'test-secret-that-is-long-enough-for-signing', JWT_EXPIRES_IN: '1h', CORS_ALLOWED_ORIGIN: undefined };
function setup({ failDelivery = false } = {}) { const memory = createPrisma(); const deliveries = []; const emailSender = async ({ to, otp }) => { if (failDelivery) throw new Error('provider unavailable'); deliveries.push({ to, otp }); }; const verifyToken = async (token) => { if (token !== 'valid-token') throw new Error('invalid'); return { sub: 'user-1' }; }; return { ...memory, deliveries, app: createApp({ env, prismaClient: memory.db, verifyToken, emailSender }) }; }
const registration = { displayName: 'Test User', email: 'user@example.test', password: 'password-123', mobile: '9876543210' };

describe('registration OTP flow', () => {
  it('returns a public root health response before the not-found handler', async () => {
    const { app } = setup();
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: 'ok' });
  });
  it('sends a code but does not create a session until it is verified', async () => { const { app, deliveries } = setup(); const response = await request(app).post('/api/v1/auth/register').send(registration); expect(response.status).toBe(202); expect(response.body.data.accessToken).toBeUndefined(); expect(deliveries).toHaveLength(1); expect(deliveries[0].otp).toMatch(/^\d{6}$/); });
  it('creates a verified account and JWT only for the correct unused OTP', async () => { const { app, deliveries } = setup(); await request(app).post('/api/v1/auth/register').send(registration); const response = await request(app).post('/api/v1/auth/register/verify').send({ email: registration.email, otp: deliveries[0].otp }); expect(response.status).toBe(201); expect(response.body.data.accessToken).toBeTypeOf('string'); const reused = await request(app).post('/api/v1/auth/register/verify').send({ email: registration.email, otp: deliveries[0].otp }); expect(reused.status).toBe(400); });
  it('rejects registration for an email that is already verified', async () => { const { app, deliveries } = setup(); await request(app).post('/api/v1/auth/register').send(registration); await request(app).post('/api/v1/auth/register/verify').send({ email: registration.email, otp: deliveries[0].otp }); const duplicate = await request(app).post('/api/v1/auth/register').send(registration); expect(duplicate.status).toBe(409); expect(duplicate.body.error.code).toBe('EMAIL_IN_USE'); });
  it('rejects wrong and expired OTPs', async () => { const { app, deliveries, pending } = setup(); await request(app).post('/api/v1/auth/register').send(registration); const wrong = await request(app).post('/api/v1/auth/register/verify').send({ email: registration.email, otp: '000000' }); expect(wrong.status).toBe(400); const item = pending.get(registration.email); item.otpExpiresAt = new Date(Date.now() - 1); const expired = await request(app).post('/api/v1/auth/register/verify').send({ email: registration.email, otp: deliveries[0].otp }); expect(expired.status).toBe(400); expect(expired.body.error.code).toBe('OTP_EXPIRED'); });
  it('does not claim delivery succeeded when delivery fails', async () => { const { app, deliveries } = setup({ failDelivery: true }); const response = await request(app).post('/api/v1/auth/register').send(registration); expect(response.status).toBe(503); expect(response.body.error.code).toBe('EMAIL_DELIVERY_FAILED'); expect(deliveries).toHaveLength(0); });
  it('enforces resend cooldown and prevents unverified login', async () => { const { app, users } = setup(); await request(app).post('/api/v1/auth/register').send(registration); const resend = await request(app).post('/api/v1/auth/register/resend').send({ email: registration.email }); expect(resend.status).toBe(429); users.set('unverified@example.test', { id: 'unverified', email: 'unverified@example.test', passwordHash: await hashPassword('password-123'), emailVerifiedAt: null }); const login = await request(app).post('/api/v1/auth/login').send({ email: 'unverified@example.test', password: 'password-123' }); expect(login.status).toBe(403); });
  it('locks OTP verification after repeated incorrect attempts', async () => { const { app } = setup(); await request(app).post('/api/v1/auth/register').send(registration); for (let attempt = 0; attempt < 5; attempt += 1) await request(app).post('/api/v1/auth/register/verify').send({ email: registration.email, otp: '000000' }); const locked = await request(app).post('/api/v1/auth/register/verify').send({ email: registration.email, otp: '000000' }); expect(locked.status).toBe(429); expect(locked.body.error.code).toBe('OTP_ATTEMPTS_EXCEEDED'); });
  it('rejects unauthenticated protected requests', async () => { const { app } = setup(); const response = await request(app).get('/api/v1/me'); expect(response.status).toBe(401); });
});
