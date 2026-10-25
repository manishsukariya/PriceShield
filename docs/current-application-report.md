# PriceShield: current application status

## Architecture

- Flutter mobile app with a Node.js/Express API and PostgreSQL through Prisma.
- Firebase configuration and Firestore rules have been removed from the current migration branch.
- Authentication is now email/password with a time-limited email OTP and JWT session.
- Cloudinary remains the intended media host for profile and complaint evidence URLs.

## Implemented flows

- Registration, email OTP verification, sign-in, local JWT session, and logout.
- Barcode scan, product lookup, manual product/MRP entry, price comparison, and scan history.
- Missing-product submission with package photos, on-device OCR, manual correction, and an unverified review status.
- Complaint creation, evidence metadata, list/detail views, authenticated ownership checks, and withdrawal.
- Profile reading and updates.

## Local development

- VS Code launch configuration: `.vscode/launch.json`.
- Current USB-phone API origin: `http://192.168.0.107:3000`.
- Start the backend before pressing F5: `cd backend` then `npm run dev`.
- Debug Flutter builds fall back to this local API origin if launched without
  the VS Code configuration. Release builds do not use this fallback.

## Current blocker

At report time, `http://127.0.0.1:3000/api/v1/health` was unavailable. The Flutter app cannot use backend features until the backend is running and the phone can reach the same LAN address.

## Operational requirements

- `backend/.env` needs a valid local PostgreSQL `DATABASE_URL` and a 32+ character `JWT_SECRET`.
- Email verification requires `RESEND_API_KEY` and a verified `RESEND_FROM_EMAIL`.
- Local development currently uses `DEV_OTP_FALLBACK=true` because the Resend
  endpoint is unreachable from this machine. The development OTP is returned
  only in development responses and auto-filled in the verification screen;
  keep this disabled in production.
- The laptop and USB-connected phone must share Wi-Fi. Update the launch configuration if the laptop LAN IP changes.
