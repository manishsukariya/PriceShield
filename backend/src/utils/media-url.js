import { z } from 'zod';

const PRIVATE_OR_LOCAL_HOST = /^(localhost|127\.\d+\.\d+\.\d+|0\.0\.0\.0|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|169\.254\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+|\[?::1\]?|\[?fe80:.*\]?)$/i;
const TRUSTED_MEDIA_HOSTS = new Set(['res.cloudinary.com']);
const ALLOWED_RESOURCE_TYPES = new Set(['image', 'video']);
const DEFAULT_CLOUDINARY_CLOUD_NAME = 'mpz1wxhc';

export function getTrustedCloudinaryCloudName(env = process.env) {
  const configured = env?.CLOUDINARY_CLOUD_NAME?.trim().toLowerCase();
  return configured || DEFAULT_CLOUDINARY_CLOUD_NAME;
}

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

export function isTrustedCloudinaryUrl(value, cloudName = getTrustedCloudinaryCloudName()) {
  if (!isSafeHttpsUrl(value)) return false;
  try {
    const parsed = new URL(value);
    const host = parsed.hostname.toLowerCase();
    if (!TRUSTED_MEDIA_HOSTS.has(host)) return false;

    const segments = parsed.pathname.split('/').filter(Boolean);
    if (segments.length < 4) return false;
    const [urlCloudName, resourceType, deliveryType] = segments;
    return (
      urlCloudName.toLowerCase() === cloudName.toLowerCase() &&
      ALLOWED_RESOURCE_TYPES.has(resourceType.toLowerCase()) &&
      deliveryType.toLowerCase() === 'upload'
    );
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
