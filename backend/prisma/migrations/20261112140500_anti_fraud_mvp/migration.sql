-- Additive anti-fraud verification, structured evidence confidence, moderation, and user reputation scoring.
CREATE TYPE "VenueType" AS ENUM ('RETAIL', 'RESTAURANT');
CREATE TYPE "PaymentMethod" AS ENUM ('UPI', 'CASH', 'CARD');
CREATE TYPE "EvidenceConfidence" AS ENUM ('UNVERIFIED', 'BASIC', 'STRONG', 'CORROBORATED');
CREATE TYPE "EvidenceRole" AS ENUM ('PACKET_MRP', 'PAYMENT_PROOF', 'ITEMIZED_BILL', 'VIDEO_PROOF', 'OTHER');

ALTER TABLE "users"
  ADD COLUMN "canonical_email" TEXT,
  ADD COLUMN "trust_score" INTEGER NOT NULL DEFAULT 50,
  ADD COLUMN "risk_score" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "risk_flags" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

CREATE INDEX "users_canonical_email_idx" ON "users"("canonical_email");

ALTER TABLE "complaints"
  ADD COLUMN "venue_type" "VenueType" NOT NULL DEFAULT 'RETAIL',
  ADD COLUMN "quantity" INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN "total_paid" DECIMAL(12,2),
  ADD COLUMN "payment_method" "PaymentMethod" NOT NULL DEFAULT 'CASH',
  ADD COLUMN "utr_number" TEXT,
  ADD COLUMN "merchant_name" TEXT,
  ADD COLUMN "merchant_vpa" TEXT,
  ADD COLUMN "store_fingerprint" TEXT,
  ADD COLUMN "confidence_level" "EvidenceConfidence" NOT NULL DEFAULT 'UNVERIFIED',
  ADD COLUMN "is_public_eligible" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "risk_score" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "risk_flags" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "moderation_notes" TEXT,
  ADD COLUMN "moderated_at" TIMESTAMP(3),
  ADD COLUMN "merchant_response" TEXT,
  ADD COLUMN "merchant_responded_at" TIMESTAMP(3);

CREATE INDEX "complaints_utr_number_idx" ON "complaints"("utr_number");
CREATE INDEX "complaints_store_fingerprint_status_idx" ON "complaints"("store_fingerprint", "status");
CREATE INDEX "complaints_confidence_level_status_idx" ON "complaints"("confidence_level", "status");

ALTER TABLE "evidence"
  ADD COLUMN "role" "EvidenceRole" NOT NULL DEFAULT 'OTHER',
  ADD COLUMN "sha256_hash" TEXT;

CREATE INDEX "evidence_sha256_hash_idx" ON "evidence"("sha256_hash");
