# Firebase Authentication Migration Report

## Completed in code

- Restored the existing Android Firebase client configuration from the repository's earlier PriceShield commit. No new Firebase project was created.
- Added Firebase Core and Firebase Auth initialization to Flutter.
- Replaced custom password/OTP calls with Firebase Email/Password signup and sign-in.
- Added Firebase verification-link resend with a 60-second client cooldown.
- Added Firebase password-reset email flow.
- Added verified-email checks before entering the app and before backend access.
- Changed the API client to refresh Firebase ID tokens before authenticated requests.
- Added Firebase Admin token verification middleware in Express.
- Added additive `firebase_uid` mapping. Existing users are linked by matching email on their first verified Firebase request; existing relationships are preserved.
- Removed the active custom OTP and Resend route implementation. The legacy pending-registration table remains untouched so no data is dropped.

## Checks completed

- `flutter pub get`: completed successfully.
- `flutter analyze --no-pub`: completed with existing lint/deprecation infos only; no errors.
- Prisma schema validation: passed.
- Firebase middleware tests: 4 passed.
- No production migration, deployment, database reset, or destructive SQL was run.

## Manual steps still required

1. Enable **Email/Password** sign-in in the existing Firebase project.
2. Confirm the Firebase email verification template and authorized domains.
3. Create/download a Firebase Admin service account key locally. Do not commit it.
4. Add these values to the local backend `.env`: `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and `FIREBASE_PRIVATE_KEY` with escaped newlines.
5. Apply the additive local Prisma migration after reviewing it:

   ```powershell
   cd backend
   npx prisma migrate deploy
   ```

6. Restart the backend and rebuild the Flutter app.

The current repository contains Android Firebase configuration only. iOS, web, and desktop Firebase option files were not present in the repository and were not invented.
