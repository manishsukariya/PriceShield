import { randomInt } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { Router } from 'express';
import { z } from 'zod';
import { AppError } from '../../middleware/errors.js';
import { validate } from '../../middleware/validate.js';
import { hashPassword, verifyPassword } from './passwords.js';

const otpLifetimeMs = 5 * 60 * 1000;
const resendCooldownMs = 60 * 1000;
const maxAttempts = 5;
const maxSends = 5;
const email = z.string().trim().email().max(320).transform((value) => value.toLowerCase());
const password = z.string().min(8).max(128);
const register = z.object({ displayName: z.string().trim().min(1).max(120), email, password, mobile: z.string().trim().regex(/^\d{10}$/).optional() });
const verifyOtp = z.object({ email, otp: z.string().regex(/^\d{6}$/, 'Enter the 6-digit code.') });
const resendOtp = z.object({ email });

function publicUser(user) { const { passwordHash: _passwordHash, ...safeUser } = user; return safeUser; }
function session(env, user) { return { accessToken: jwt.sign({ sub: user.id }, env.JWT_SECRET, { expiresIn: env.JWT_EXPIRES_IN }), user: publicUser(user) }; }
function code() { return randomInt(0, 1000000).toString().padStart(6, '0'); }
function cooldownError() { return new AppError(429, 'OTP_COOLDOWN', 'Please wait before requesting another code.'); }

async function dispatchOtp({ prisma, emailSender, pending, otp, now }) {
  try {
    await emailSender({ to: pending.email, otp });
    await prisma.pendingRegistration.update({ where: { id: pending.id }, data: { sendCount: { increment: 1 }, lastSentAt: now, lastDeliveryFailedAt: null, resendAvailableAt: new Date(now.getTime() + resendCooldownMs) } });
  } catch (_error) {
    // A failed delivery must not lock the user out for the normal resend
    // cooldown. The next attempt can use the same pending registration.
    try {
      await prisma.pendingRegistration.update({ where: { id: pending.id }, data: { lastDeliveryFailedAt: now, resendAvailableAt: now } });
    } catch {
      // Preserve the useful delivery error if the failure bookkeeping itself
      // cannot be persisted.
    }
    throw new AppError(503, 'EMAIL_DELIVERY_FAILED', 'The verification email could not be delivered. Please try again shortly.');
  }
}

export function authRoutes({ prisma, env, emailSender }) {
  const router = Router();
  router.post('/auth/register', validate(register), async (request, response, next) => {
    try {
      const now = new Date();
      const existing = await prisma.user.findUnique({ where: { email: request.body.email } });
      if (existing) throw new AppError(409, 'EMAIL_IN_USE', 'An account with this email already exists.');
      const existingPending = await prisma.pendingRegistration.findUnique({ where: { email: request.body.email } });
      // A previous delivery failure is retryable immediately; only a
      // successfully sent code should enforce the resend cooldown.
      if (existingPending && existingPending.resendAvailableAt > now && !existingPending.lastDeliveryFailedAt) throw cooldownError();
      const otp = code();
      const { password: rawPassword, ...profile } = request.body;
      const pending = await prisma.pendingRegistration.upsert({
        where: { email: profile.email },
        create: { ...profile, passwordHash: await hashPassword(rawPassword), otpHash: await hashPassword(otp), otpExpiresAt: new Date(now.getTime() + otpLifetimeMs), resendAvailableAt: now },
        update: { ...profile, passwordHash: await hashPassword(rawPassword), otpHash: await hashPassword(otp), otpExpiresAt: new Date(now.getTime() + otpLifetimeMs), failedAttempts: 0, resendAvailableAt: now },
      });
      await dispatchOtp({ prisma, emailSender, pending, otp, now });
      response.status(202).json({ data: { email: pending.email, expiresInSeconds: otpLifetimeMs / 1000, resendAfterSeconds: resendCooldownMs / 1000, ...(env.DEV_OTP_FALLBACK ? { developmentOtp: otp } : {}) } });
    } catch (error) { next(error); }
  });

  router.post('/auth/register/resend', validate(resendOtp), async (request, response, next) => {
    try {
      const now = new Date();
      const pending = await prisma.pendingRegistration.findUnique({ where: { email: request.body.email } });
      if (!pending) throw new AppError(404, 'REGISTRATION_NOT_FOUND', 'Start registration before requesting a code.');
      if (pending.resendAvailableAt > now) throw cooldownError();
      if (pending.sendCount >= maxSends && pending.createdAt > new Date(now.getTime() - 60 * 60 * 1000)) throw new AppError(429, 'OTP_SEND_LIMIT', 'Too many verification codes were requested. Please try again later.');
      const otp = code();
      const updated = await prisma.pendingRegistration.update({ where: { id: pending.id }, data: { otpHash: await hashPassword(otp), otpExpiresAt: new Date(now.getTime() + otpLifetimeMs), failedAttempts: 0, resendAvailableAt: now } });
      await dispatchOtp({ prisma, emailSender, pending: updated, otp, now });
      response.json({ data: { email: updated.email, expiresInSeconds: otpLifetimeMs / 1000, resendAfterSeconds: resendCooldownMs / 1000, ...(env.DEV_OTP_FALLBACK ? { developmentOtp: otp } : {}) } });
    } catch (error) { next(error); }
  });

  router.post('/auth/register/verify', validate(verifyOtp), async (request, response, next) => {
    try {
      const now = new Date();
      const result = await prisma.$transaction(async (tx) => {
        const pending = await tx.pendingRegistration.findUnique({ where: { email: request.body.email } });
        if (!pending) throw new AppError(400, 'OTP_INVALID', 'The verification code is invalid.');
        if (pending.otpExpiresAt <= now) throw new AppError(400, 'OTP_EXPIRED', 'This verification code has expired. Request a new code.');
        if (pending.failedAttempts >= maxAttempts) throw new AppError(429, 'OTP_ATTEMPTS_EXCEEDED', 'Too many incorrect codes. Request a new code.');
        if (!(await verifyPassword(request.body.otp, pending.otpHash))) {
          await tx.pendingRegistration.update({ where: { id: pending.id }, data: { failedAttempts: { increment: 1 } } });
          throw new AppError(400, 'OTP_INVALID', 'The verification code is invalid.');
        }
        const user = await tx.user.create({ data: { email: pending.email, passwordHash: pending.passwordHash, displayName: pending.displayName, mobile: pending.mobile, emailVerifiedAt: now } });
        await tx.pendingRegistration.delete({ where: { id: pending.id } });
        return user;
      });
      response.status(201).json({ data: session(env, result) });
    } catch (error) {
      if (error?.code === 'P2002') return next(new AppError(409, 'EMAIL_IN_USE', 'An account with this email already exists.'));
      return next(error);
    }
  });

  router.post('/auth/login', validate(z.object({ email, password })), async (request, response, next) => {
    try {
      const user = await prisma.user.findUnique({ where: { email: request.body.email } });
      if (!user || !(await verifyPassword(request.body.password, user.passwordHash))) throw new AppError(401, 'INVALID_CREDENTIALS', 'Email or password is incorrect.');
      if (!user.emailVerifiedAt) throw new AppError(403, 'EMAIL_NOT_VERIFIED', 'Verify your email before signing in.');
      response.json({ data: session(env, user) });
    } catch (error) { next(error); }
  });
  router.post('/auth/logout', (_request, response) => response.status(204).send());
  return router;
}
