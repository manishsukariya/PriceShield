import { Router } from 'express';
import { z } from 'zod';
import { validate } from '../../middleware/validate.js';
import { trustedMediaUrl } from '../../utils/media-url.js';

const updateProfile = z.object({
  displayName: z.string().trim().min(1).max(120).optional(),
  mobile: z.string().trim().regex(/^\d{10}$/).optional(),
  photoUrl: trustedMediaUrl.optional(),
}).refine((value) => Object.keys(value).length > 0, 'Provide at least one profile field.');

export function userRoutes({ authenticate, prisma }) {
  const router = Router();
  router.use('/me', authenticate);
  router.get('/me', (request, response) => {
    const { passwordHash: _passwordHash, ...user } = request.user;
    response.json({ data: user });
  });
  router.patch('/me', validate(updateProfile), async (request, response, next) => {
    try {
      const user = await prisma.user.update({ where: { id: request.user.id }, data: request.body });
      const { passwordHash: _passwordHash, ...safeUser } = user;
      response.json({ data: safeUser });
    } catch (error) {
      next(error);
    }
  });
  router.delete('/me', async (request, response, next) => {
    try {
      await prisma.user.delete({ where: { id: request.user.id } });
      response.status(204).send();
    } catch (error) {
      next(error);
    }
  });
  return router;
}
