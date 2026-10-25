-- Additive Firebase identity mapping. Existing user rows and relationships are preserved.
ALTER TABLE "users" ADD COLUMN "firebase_uid" TEXT;
ALTER TABLE "users" ALTER COLUMN "password_hash" DROP NOT NULL;
CREATE UNIQUE INDEX "users_firebase_uid_key" ON "users"("firebase_uid");
