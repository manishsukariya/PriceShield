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
    } catch (_error) {
      return next(new AppError(401, 'UNAUTHENTICATED', 'The access token is invalid or expired.'));
    }

    try {
      if (!decoded?.sub || typeof decoded.sub !== 'string') {
        return next(new AppError(401, 'UNAUTHENTICATED', 'The access token is invalid or expired.'));
      }
      const user = await prismaClient.user.findUnique({ where: { id: decoded.sub } });
      if (!user) return next(new AppError(401, 'UNAUTHENTICATED', 'The account no longer exists.'));
      if (!user.emailVerifiedAt) return next(new AppError(403, 'EMAIL_NOT_VERIFIED', 'Verify your email before accessing this resource.'));
      request.user = user;
      return next();
    } catch (error) {
      return next(error);
    }
  };
}
