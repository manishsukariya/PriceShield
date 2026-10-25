ALTER TABLE "users" ADD COLUMN "email_verified_at" TIMESTAMP(3);

CREATE TABLE "pending_registrations" (
  "id" TEXT NOT NULL,
  "email" TEXT NOT NULL,
  "password_hash" TEXT NOT NULL,
  "display_name" TEXT,
  "mobile" TEXT,
  "otp_hash" TEXT NOT NULL,
  "otp_expires_at" TIMESTAMP(3) NOT NULL,
  "failed_attempts" INTEGER NOT NULL DEFAULT 0,
  "send_count" INTEGER NOT NULL DEFAULT 0,
  "resend_available_at" TIMESTAMP(3) NOT NULL,
  "last_sent_at" TIMESTAMP(3),
  "last_delivery_failed_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "pending_registrations_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "pending_registrations_email_key" ON "pending_registrations"("email");
CREATE INDEX "pending_registrations_otp_expires_at_idx" ON "pending_registrations"("otp_expires_at");
