/**
 * Lightweight in-memory sliding-window rate limiter middleware.
 * Protects public and authenticated API routes against excessive traffic or abuse.
 */
export function createRateLimiter({
  windowMs = 60 * 1000,
  max = 120,
  skip = () => false,
  keyGenerator = (req) => req.ip || req.headers['x-forwarded-for']?.toString().split(',')[0]?.trim() || 'unknown',
  message = 'Too many requests. Please slow down and try again shortly.',
} = {}) {
  const buckets = new Map();

  // Periodic cleanup to avoid unbounded memory growth on long-running servers
  const cleanupInterval = setInterval(() => {
    const cutoff = Date.now() - windowMs;
    for (const [key, timestamps] of buckets.entries()) {
      const recent = timestamps.filter((t) => t > cutoff);
      if (recent.length === 0) {
        buckets.delete(key);
      } else {
        buckets.set(key, recent);
      }
    }
  }, Math.max(windowMs, 30 * 1000));
  if (typeof cleanupInterval.unref === 'function') {
    cleanupInterval.unref();
  }

  return (request, response, next) => {
    if (skip(request)) {
      return next();
    }

    const now = Date.now();
    const cutoff = now - windowMs;
    const key = keyGenerator(request);
    const existing = buckets.get(key) ?? [];
    const recent = existing.filter((timestamp) => timestamp > cutoff);

    if (recent.length >= max) {
      const oldest = recent[0];
      const retryAfterSec = Math.max(1, Math.ceil((oldest + windowMs - now) / 1000));
      response.setHeader('Retry-After', String(retryAfterSec));
      response.setHeader('X-RateLimit-Limit', String(max));
      response.setHeader('X-RateLimit-Remaining', '0');
      return response.status(429).json({
        error: {
          code: 'RATE_LIMIT_EXCEEDED',
          message,
        },
      });
    }

    recent.push(now);
    buckets.set(key, recent);
    response.setHeader('X-RateLimit-Limit', String(max));
    response.setHeader('X-RateLimit-Remaining', String(Math.max(0, max - recent.length)));
    return next();
  };
}
