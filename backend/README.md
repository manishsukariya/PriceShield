# PriceShield backend

Local Node.js, Express, PostgreSQL, Prisma, JWT, and Resend verification backend.

## Local setup

1. Install PostgreSQL locally and create a development database.
2. Copy `.env.example` to `.env`, set `DATABASE_URL`, a 32+-character `JWT_SECRET`, and the Resend API key and verified sender address. Never commit those values.
3. Run `npm.cmd install`, `npm.cmd run prisma:generate`, `npm.cmd run prisma:migrate`, and `npm.cmd test`.
4. Start the API with `npm.cmd run dev`.

## Flutter development connection

The Flutter client is opt-in: it only contacts the migration API when the
`PRICESHIELD_API_BASE_URL` Dart define is supplied. Use
`http://10.0.2.2:3000` for an Android emulator. For a USB-connected physical
phone, use the development computer's LAN IPv4 address, for example:

```powershell
flutter run -d DEVICE_ID --dart-define=PRICESHIELD_API_BASE_URL=http://192.168.1.10:3000
```

The Android HTTP allowance exists only in the debug manifest. Use HTTPS before
shipping a release build.

The API issues JWTs only after a user verifies a time-limited email OTP. Firebase is not used.
