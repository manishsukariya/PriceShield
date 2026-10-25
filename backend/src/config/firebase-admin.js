import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

let firebaseAuth;

export function createFirebaseTokenVerifier(env) {
  return async (token) => {
    const serviceAccount = env.FIREBASE_SERVICE_ACCOUNT_JSON
      ? JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON)
      : env.FIREBASE_PROJECT_ID && env.FIREBASE_CLIENT_EMAIL && env.FIREBASE_PRIVATE_KEY
        ? {
            projectId: env.FIREBASE_PROJECT_ID,
            clientEmail: env.FIREBASE_CLIENT_EMAIL,
            privateKey: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
          }
        : null;
    if (!serviceAccount) {
      throw new Error('Firebase Admin credentials are not configured.');
    }
    const app = getApps()[0] ?? initializeApp({
      credential: cert(serviceAccount),
    });
    firebaseAuth ??= getAuth(app);
    return firebaseAuth.verifyIdToken(token);
  };
}
