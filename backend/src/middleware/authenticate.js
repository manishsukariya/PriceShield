import { AppError } from './errors.js';
import { normalizeCanonicalEmail } from '../utils/anti-fraud.js';

export function authenticate(verifyToken, prismaClient) {
  return async (request, _response, next) => {
    const [scheme, token] = request.get('authorization')?.split(' ') ?? [];
    if (scheme !== 'Bearer' || !token) {
      return next(new AppError(401, 'UNAUTHENTICATED', 'A bearer token is required.'));
    }

    let decoded;
    try {
      decoded = await verifyToken(token);
    } catch (error) {
      if (error?.message === 'Firebase Admin credentials are not configured.') {
        return next(new AppError(503, 'FIREBASE_AUTH_NOT_CONFIGURED', 'Firebase authentication is not configured on the server.'));
      }
      return next(new AppError(401, 'UNAUTHENTICATED', 'The access token is invalid or expired.'));
    }

    try {
      if (!decoded?.uid || typeof decoded.uid !== 'string') {
        return next(new AppError(401, 'UNAUTHENTICATED', 'The access token is invalid or expired.'));
      }
      if (decoded.email_verified !== true) {
        return next(new AppError(403, 'EMAIL_NOT_VERIFIED', 'Verify your email before accessing this resource.'));
      }
      if (typeof decoded.email !== 'string' || !decoded.email) {
        return next(new AppError(401, 'UNAUTHENTICATED', 'The Firebase account has no email address.'));
      }
      const canonicalEmail = normalizeCanonicalEmail(decoded.email);
      let user = await prismaClient.user.findUnique({ where: { firebaseUid: decoded.uid } });
      if (!user) {
        const byEmail = await prismaClient.user.findUnique({ where: { email: decoded.email.toLowerCase() } });
        if (byEmail?.firebaseUid && byEmail.firebaseUid !== decoded.uid) {
          return next(new AppError(409, 'ACCOUNT_LINK_CONFLICT', 'This email is already linked to another account.'));
        }
        user = byEmail
          ? await prismaClient.user.update({ where: { id: byEmail.id }, data: { firebaseUid: decoded.uid, canonicalEmail, emailVerifiedAt: new Date() } })
          : await prismaClient.user.create({ data: { firebaseUid: decoded.uid, email: decoded.email.toLowerCase(), canonicalEmail, emailVerifiedAt: new Date(), displayName: decoded.name ?? null, passwordHash: null } });
      } else if (!user.canonicalEmail && canonicalEmail) {
        user = typeof prismaClient.user?.update === 'function'
          ? await prismaClient.user.update({ where: { id: user.id }, data: { canonicalEmail } })
          : { ...user, canonicalEmail };
      }
      request.user = user;
      return next();
    } catch (error) {
      return next(error);
    }
  };
}

export function authenticateOptional(verifyToken, prismaClient) {
  return async (request, _response, next) => {
    const [scheme, token] = request.get('authorization')?.split(' ') ?? [];
    if (scheme !== 'Bearer' || !token) {
      request.user = null;
      return next();
    }

    try {
      const decoded = await verifyToken(token);
      if (decoded?.uid && decoded.email && decoded.email_verified === true) {
        const canonicalEmail = normalizeCanonicalEmail(decoded.email);
        let user = await prismaClient.user.findUnique({ where: { firebaseUid: decoded.uid } });
        if (!user) {
          const byEmail = await prismaClient.user.findUnique({ where: { email: decoded.email.toLowerCase() } });
          if (!byEmail?.firebaseUid || byEmail.firebaseUid === decoded.uid) {
            user = byEmail
              ? await prismaClient.user.update({ where: { id: byEmail.id }, data: { firebaseUid: decoded.uid, canonicalEmail, emailVerifiedAt: new Date() } })
              : await prismaClient.user.create({ data: { firebaseUid: decoded.uid, email: decoded.email.toLowerCase(), canonicalEmail, emailVerifiedAt: new Date(), displayName: decoded.name ?? null, passwordHash: null } });
          }
        } else if (!user.canonicalEmail && canonicalEmail) {
          user = typeof prismaClient.user?.update === 'function'
            ? await prismaClient.user.update({ where: { id: user.id }, data: { canonicalEmail } })
            : { ...user, canonicalEmail };
        }
        request.user = user ?? null;
      }
    } catch {
      request.user = null;
    }
    return next();
  };
}
