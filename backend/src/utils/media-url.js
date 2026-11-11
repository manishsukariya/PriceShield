import { z } from 'zod';

const PRIVATE_OR_LOCAL_HOST = /^(localhost|127\.\d+\.\d+\.\d+|0\.0\.0\.0|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|169\.254\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+|\[?::1\]?|\[?fe80:.*\]?)$/i;
const TRUSTED_MEDIA_HOSTS = new Set(['res.cloudinary.com']);

export function isSafeHttpsUrl(value) {
  if (typeof value !== 'string' || value.length > 2048) return false;
  try {
    const parsed = new URL(value);
    if (parsed.protocol !== 'https:') return false;
    if (!parsed.hostname || PRIVATE_OR_LOCAL_HOST.test(parsed.hostname)) return false;
    return true;
  } catch {
    return false;
  }
}

export function isTrustedCloudinaryUrl(value) {
  if (!isSafeHttpsUrl(value)) return false;
  try {
    const parsed = new URL(value);
    const host = parsed.hostname.toLowerCase();
    return TRUSTED_MEDIA_HOSTS.has(host) || host.endsWith('.cloudinary.com');
  } catch {
    return false;
  }
}

export const trustedMediaUrl = z
  .string()
  .trim()
  .url()
  .max(2048)
  .refine(isTrustedCloudinaryUrl, {
    message: 'Media URL must be a valid HTTPS Cloudinary upload URL.',
  });
