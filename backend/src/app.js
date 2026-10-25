import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import pinoHttp from 'pino-http';
import { getEnv } from './config/env.js';
import { prisma } from './config/prisma.js';
import { authenticate as createAuthenticate } from './middleware/authenticate.js';
import { errorHandler, notFound } from './middleware/errors.js';
import { apiRoutes } from './routes/index.js';
import { createFirebaseTokenVerifier } from './config/firebase-admin.js';

export function createApp({ env = getEnv(), prismaClient = prisma, verifyToken } = {}) {
  const app = express();
  const tokenVerifier = verifyToken ?? createFirebaseTokenVerifier(env);
  const authenticate = createAuthenticate(tokenVerifier, prismaClient);

  app.disable('x-powered-by');
  app.use(pinoHttp({ redact: ['req.headers.authorization'] }));
  app.use(helmet());
  const allowedOrigins = [env.CORS_ALLOWED_ORIGIN, ...(env.CORS_ALLOWED_ORIGINS?.split(',') ?? [])]
    .map((origin) => origin?.trim())
    .filter(Boolean);
  app.use(cors(allowedOrigins.length ? {
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
      return callback(new Error('CORS origin is not allowed.'));
    },
  } : { origin: false }));
  app.use(express.json({ limit: '1mb' }));
  // Public process health check. It intentionally avoids database access so
  // orchestration and local network checks can distinguish an alive API from
  // a ready database-backed API at /api/v1/health.
  app.get('/health', (_request, response) => response.status(200).json({ status: 'ok' }));
  app.use('/api/v1', apiRoutes({ prisma: prismaClient, authenticate, env }));
  app.use(notFound);
  app.use(errorHandler);
  return app;
}
