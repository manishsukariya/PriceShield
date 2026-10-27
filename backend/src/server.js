import { getEnv } from './config/env.js';
import { prisma } from './config/prisma.js';
import { createApp } from './app.js';

const env = getEnv();
const app = createApp({ env });
// Render and other managed hosts require binding to every container interface.
// Keep the configurable host for local development, but never bind production
// to a laptop/LAN address that does not exist inside the hosted container.
const isManagedHost = env.NODE_ENV === 'production' || process.env.RENDER === 'true';
const host = isManagedHost ? '0.0.0.0' : env.HOST;
const server = app.listen(env.PORT, host, () => {
  console.log(`PriceShield API listening on http://${host}:${env.PORT}`);
});

async function shutdown(signal) {
  console.log(`${signal} received; shutting down.`);
  server.close(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
