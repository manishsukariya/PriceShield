# Render deployment

The backend is a standalone Node.js service in `backend/`.

## Render settings

- Root Directory: `backend`
- Build Command: `npm ci && npm run build`
- Start Command: `npm start`
- Health Check Path: `/health`

`npm start` runs the additive Prisma migrations before starting the server. It binds to `0.0.0.0` and uses Render's `PORT` value.

## Environment variables

Configure these in the Render service dashboard. Never commit service-account JSON or database credentials.

- `NODE_ENV=production`
- `HOST=0.0.0.0`
- `DATABASE_URL`: Render PostgreSQL connection string with `sslmode=require`
- `FIREBASE_SERVICE_ACCOUNT_JSON`: compact JSON for the Firebase Admin service account
- `CORS_ALLOWED_ORIGINS`: comma-separated frontend origins, for example `http://localhost:3000,https://your-frontend.example.com`

`PORT` is supplied automatically by Render; do not hardcode it in the dashboard.
