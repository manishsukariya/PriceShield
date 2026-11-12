import crypto from 'node:crypto';
import { AppError } from './errors.js';

export function hasValidAdminKey(providedKey, configuredKey) {
  if (typeof providedKey !== 'string' || !providedKey.trim() || !configuredKey) return false;
  const a = crypto.createHash('sha256').update(providedKey.trim()).digest();
  const b = crypto.createHash('sha256').update(configuredKey).digest();
  return crypto.timingSafeEqual(a, b);
}

export function requireModerationKey(env) {
  return (request, _response, next) => {
    const configuredKey = env?.ADMIN_MODERATION_KEY;
    if (!configuredKey) {
      return next(
        new AppError(
          503,
          'MODERATION_NOT_CONFIGURED',
          'Moderation key is not configured on this server.',
        ),
      );
    }
    const providedKey = request.get('x-admin-key');
    if (!hasValidAdminKey(providedKey, configuredKey)) {
      return next(new AppError(403, 'FORBIDDEN', 'Invalid moderation credentials.'));
    }
    return next();
  };
}
