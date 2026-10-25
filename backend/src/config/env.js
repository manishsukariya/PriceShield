import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  HOST: z.string().trim().min(1).default('0.0.0.0'),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32, 'JWT_SECRET must contain at least 32 characters.'),
  JWT_EXPIRES_IN: z.string().trim().min(1).default('7d'),
  DEV_OTP_FALLBACK: z.preprocess((value) => value === true || value === 'true', z.boolean().default(false)),
  RESEND_API_KEY: z.preprocess(
    (value) => typeof value === 'string' && value.trim() === '' ? undefined : value,
    z.string().min(1).optional(),
  ),
  RESEND_FROM_EMAIL: z.preprocess(
    (value) => typeof value === 'string' && value.trim() === '' ? undefined : value,
    z.string().min(3).max(320).optional(),
  ),
  CORS_ALLOWED_ORIGIN: z.preprocess(
    (value) => typeof value === 'string' && value.trim() === '' ? undefined : value,
    z.string().url().optional(),
  ),
});

export function getEnv(values = process.env) {
  return schema.parse(values);
}
