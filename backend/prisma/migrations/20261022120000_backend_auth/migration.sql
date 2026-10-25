-- The initial local development migration has no production data. This migration
-- replaces the temporary Firebase identity column with email/password credentials.
DROP INDEX "users_firebase_uid_key";
ALTER TABLE "users" DROP COLUMN "firebase_uid";
ALTER TABLE "users" ALTER COLUMN "email" SET NOT NULL;
ALTER TABLE "users" ADD COLUMN "password_hash" TEXT NOT NULL;
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");
