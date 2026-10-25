# Phase 4 API, database, and authentication testing report

## Status

Phase 4 is complete to the extent permitted by the current local environment. Work remained on `backend/firebase-migration`; no branch switch occurred.

The pre-existing Flutter compatibility fix in `lib/features/scanner/presentation/screens/scanner_screen.dart` was preserved and not changed in this phase.

## Phase 3 review and backend fixes

The existing Express application, Firebase token middleware, Prisma schema, and isolated Vitest/Supertest suite were reviewed.

Two backend-only defects were fixed:

- `backend/src/middleware/authenticate.js` now returns `401 UNAUTHENTICATED` only when Firebase token verification fails. A local-user provisioning/database failure now flows to centralized error handling instead of being misreported as an invalid token.
- `backend/src/modules/complaints/routes.js` now implements `POST /api/v1/complaints/:id/evidence`. It verifies ownership and rejects withdrawn or absent complaints before creating evidence metadata.

The isolated API test mock was extended for evidence persistence and invalid-token behavior.

## Dependency installation investigation

Verified local tooling:

- Node.js: `v24.14.0`
- npm: `11.9.0`
- npm registry: `https://registry.npmjs.org/`
- npm proxy settings: unset
- Existing `backend/node_modules` and `backend/package-lock.json`: absent

The initial dependency installation had not created any packages, lockfile, or npm diagnostic log. The sandboxed registry diagnostic showed `EACCES` while fetching from `registry.npmjs.org` and while writing npm's default cache log directory. One approved outside-sandbox `npm ping` check also waited without a response and was stopped. It did not produce evidence of reachable registry access.

No repeated `npm install` attempt was made after this diagnostic because dependency installation cannot succeed until registry access is available.

## Commands actually executed

```text
git branch --show-current
git status --short --branch
node --version
npm.cmd --version
npm.cmd config get registry
npm.cmd config get proxy
npm.cmd config get https-proxy
npm.cmd config get cache
npm.cmd ping --registry=https://registry.npmjs.org/ --loglevel=verbose
npm.cmd ping --registry=https://registry.npmjs.org/ --loglevel=warn
node --check <each backend source and test JavaScript file>
where.exe psql
Get-Service -Name '*postgres*'
git diff --check
```

## Actual test and validation results

| Check | Result | Scope |
|---|---|---|
| JavaScript syntax | Passed | Every backend source and test file via `node --check` |
| Git whitespace check | Passed | `git diff --check` reported no whitespace errors |
| Vitest/Supertest API tests | Not run | `vitest`, `supertest`, and runtime dependencies are not installed |
| Prisma schema validation/client generation | Not run | `prisma` and `@prisma/client` are not installed |
| Real Firebase token verification | Not run | Requires Firebase Admin dependency and local credentials |
| Real PostgreSQL migration/database tests | Not run | PostgreSQL unavailable; no database target was selected or contacted |

The test file defines mocked Firebase/Prisma coverage for health, missing token, invalid token, and scan overcharge calculation. These tests have **not** executed and must not be treated as passing.

## Database verification

`psql` was not found on the system and no Windows service matching `*postgres*` was present. No PostgreSQL server, database, migration, synthetic record, production database, Firebase record, or remote infrastructure was contacted.

Minimum safe setup before resuming database tests:

1. Install PostgreSQL locally, outside this repository, and start its local service.
2. Create a new empty development database, for example `priceshield_dev_test`; do not reuse a production or personal database.
3. Set `backend/.env` with a `DATABASE_URL` pointing only to that local database and non-production Firebase Admin credentials.
4. Confirm the exact host, database name, and user before running `npm.cmd run prisma:migrate`.
5. Run dependency installation, Prisma generation, migration, and tests in that order.

No system software installation, Docker use, hosted service, billing, or global configuration change was performed.

## Security and operational limitations

- Firebase Authentication and Firestore remain active and unchanged.
- The backend has not been connected to a database or Firebase Admin service.
- Cloudinary uploads remain direct from Flutter; no evidence files were read, uploaded, moved, or deleted.
- The backend stores only planned evidence metadata after a future authenticated API call.
- No secrets, tokens, credentials, or production data were read or exposed.
- All introduced dependencies are free/open-source. No cost or billing change was made.

## Remaining work

1. Restore npm registry access and install the already declared dependencies.
2. Use a confirmed isolated local PostgreSQL database to generate the Prisma client and apply the migration.
3. Run the mocked suite, then add and run real local PostgreSQL integration tests with synthetic data.
4. Exercise endpoint authorization, ownership isolation, validation, complaint lifecycle, and evidence metadata against that isolated database.

Phase 5 has not begun. Explicit approval is required before any Firebase data migration preparation.
