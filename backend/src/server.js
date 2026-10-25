import { getEnv } from './config/env.js';
import { prisma } from './config/prisma.js';
import { createApp } from './app.js';

const env = getEnv();
const app = createApp({ env });
const server = app.listen(env.PORT, env.HOST, () => {
  console.log(`PriceShield API listening on http://${env.HOST}:${env.PORT}`);
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
