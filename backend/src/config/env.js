import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  HOST: z.string().trim().min(1).default('0.0.0.0'),
  DATABASE_URL: z.string().url(),
  FIREBASE_PROJECT_ID: z.string().trim().min(1).optional(),
  FIREBASE_CLIENT_EMAIL: z.string().trim().email().optional(),
  FIREBASE_PRIVATE_KEY: z.string().min(1).optional(),
  FIREBASE_SERVICE_ACCOUNT_JSON: z.string().trim().min(1).optional(),
  CORS_ALLOWED_ORIGIN: z.preprocess(
    (value) => typeof value === 'string' && value.trim() === '' ? undefined : value,
    z.string().url().optional(),
  ),
  CORS_ALLOWED_ORIGINS: z.string().trim().min(1).optional(),
}).superRefine((values, context) => {
  if (values.NODE_ENV === 'production') {
    const hasFirebaseJson = Boolean(values.FIREBASE_SERVICE_ACCOUNT_JSON);
    const hasFirebaseParts = Boolean(
      values.FIREBASE_PROJECT_ID && values.FIREBASE_CLIENT_EMAIL && values.FIREBASE_PRIVATE_KEY,
    );
    if (!hasFirebaseJson && !hasFirebaseParts) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: ['FIREBASE_SERVICE_ACCOUNT_JSON'], message: 'Firebase Admin credentials are required in production.' });
    }
    if (!/[?&]sslmode=require(?:&|$)/i.test(values.DATABASE_URL)) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: ['DATABASE_URL'], message: 'Production DATABASE_URL must include sslmode=require.' });
    }
  }
});

export function getEnv(values = process.env) {
  return schema.parse(values);
}
