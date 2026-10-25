import { AppError } from './errors.js';

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
      let user = await prismaClient.user.findUnique({ where: { firebaseUid: decoded.uid } });
      if (!user) {
        const byEmail = await prismaClient.user.findUnique({ where: { email: decoded.email.toLowerCase() } });
        if (byEmail?.firebaseUid && byEmail.firebaseUid !== decoded.uid) {
          return next(new AppError(409, 'ACCOUNT_LINK_CONFLICT', 'This email is already linked to another account.'));
        }
        user = byEmail
          ? await prismaClient.user.update({ where: { id: byEmail.id }, data: { firebaseUid: decoded.uid, emailVerifiedAt: new Date() } })
          : await prismaClient.user.create({ data: { firebaseUid: decoded.uid, email: decoded.email.toLowerCase(), emailVerifiedAt: new Date(), displayName: decoded.name ?? null, passwordHash: null } });
      }
      request.user = user;
      return next();
    } catch (error) {
      return next(error);
    }
  };
}
