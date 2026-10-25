import { randomBytes, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(scryptCallback);
const keyLength = 64;

// Node's maintained crypto implementation uses a memory-hard password KDF.
export async function hashPassword(password) {
  const salt = randomBytes(16).toString('base64url');
  const derivedKey = await scrypt(password, salt, keyLength);
  return `scrypt$${salt}$${Buffer.from(derivedKey).toString('base64url')}`;
}

export async function verifyPassword(password, storedHash) {
  const [algorithm, salt, encodedKey] = typeof storedHash === 'string' ? storedHash.split('$') : [];
  if (algorithm !== 'scrypt' || !salt || !encodedKey) return false;
  const expected = Buffer.from(encodedKey, 'base64url');
  const derivedKey = Buffer.from(await scrypt(password, salt, expected.length));
  return expected.length === derivedKey.length && timingSafeEqual(expected, derivedKey);
}
