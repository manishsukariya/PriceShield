import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import pinoHttp from 'pino-http';
import jwt from 'jsonwebtoken';
import { getEnv } from './config/env.js';
import { prisma } from './config/prisma.js';
import { authenticate as createAuthenticate } from './middleware/authenticate.js';
import { errorHandler, notFound } from './middleware/errors.js';
import { apiRoutes } from './routes/index.js';
import { createDevelopmentOtpSender, createResendEmailSender } from './modules/auth/resend.js';

export function createApp({ env = getEnv(), prismaClient = prisma, verifyToken, emailSender } = {}) {
  const app = express();
  const tokenVerifier = verifyToken ?? ((token) => jwt.verify(token, env.JWT_SECRET));
  const authenticate = createAuthenticate(tokenVerifier, prismaClient);

  app.disable('x-powered-by');
  app.use(pinoHttp({ redact: ['req.headers.authorization'] }));
  app.use(helmet());
  app.use(cors(env.CORS_ALLOWED_ORIGIN ? { origin: env.CORS_ALLOWED_ORIGIN } : { origin: false }));
  app.use(express.json({ limit: '1mb' }));
  // Public process health check. It intentionally avoids database access so
  // orchestration and local network checks can distinguish an alive API from
  // a ready database-backed API at /api/v1/health.
  app.get('/health', (_request, response) => response.status(200).json({ status: 'ok' }));
  const configuredEmailSender = env.DEV_OTP_FALLBACK ? createDevelopmentOtpSender() : createResendEmailSender({ apiKey: env.RESEND_API_KEY, fromEmail: env.RESEND_FROM_EMAIL });
  app.use('/api/v1', apiRoutes({ prisma: prismaClient, authenticate, env, emailSender: emailSender ?? configuredEmailSender }));
  app.use(notFound);
  app.use(errorHandler);
  return app;
}
