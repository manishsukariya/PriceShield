CREATE TYPE "ScanStatus" AS ENUM ('OVERCHARGED', 'WITHIN_MRP');
CREATE TYPE "ComplaintStatus" AS ENUM ('PENDING', 'RESOLVED', 'REJECTED', 'WITHDRAWN');
CREATE TYPE "EvidenceMediaType" AS ENUM ('IMAGE', 'VIDEO');

CREATE TABLE "users" (
  "id" TEXT NOT NULL,
  "firebase_uid" TEXT NOT NULL,
  "email" TEXT,
  "display_name" TEXT,
  "mobile" TEXT,
  "photo_url" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "products" (
  "id" TEXT NOT NULL,
  "barcode" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "mrp" DECIMAL(12,2) NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "products_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "scans" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "product_id" TEXT,
  "product_name" TEXT NOT NULL,
  "barcode" TEXT NOT NULL,
  "mrp" DECIMAL(12,2) NOT NULL,
  "charged_price" DECIMAL(12,2) NOT NULL,
  "overcharge" DECIMAL(12,2) NOT NULL,
  "status" "ScanStatus" NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "scans_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "complaints" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "product_id" TEXT,
  "product_name" TEXT NOT NULL,
  "barcode" TEXT NOT NULL,
  "mrp" DECIMAL(12,2) NOT NULL,
  "charged_price" DECIMAL(12,2) NOT NULL,
  "overcharge" DECIMAL(12,2) NOT NULL,
  "address" TEXT NOT NULL,
  "latitude" DECIMAL(9,6),
  "longitude" DECIMAL(9,6),
  "description" TEXT,
  "purchase_date" TIMESTAMP(3),
  "status" "ComplaintStatus" NOT NULL DEFAULT 'PENDING',
  "withdrawn_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "complaints_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "evidence" (
  "id" TEXT NOT NULL,
  "complaint_id" TEXT NOT NULL,
  "url" TEXT NOT NULL,
  "public_id" TEXT,
  "resource_type" TEXT,
  "media_type" "EvidenceMediaType" NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "evidence_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "users_firebase_uid_key" ON "users"("firebase_uid");
CREATE UNIQUE INDEX "products_barcode_key" ON "products"("barcode");
CREATE INDEX "scans_user_id_created_at_idx" ON "scans"("user_id", "created_at");
CREATE INDEX "scans_barcode_idx" ON "scans"("barcode");
CREATE INDEX "complaints_user_id_created_at_idx" ON "complaints"("user_id", "created_at");
CREATE INDEX "complaints_status_created_at_idx" ON "complaints"("status", "created_at");
CREATE INDEX "evidence_complaint_id_idx" ON "evidence"("complaint_id");

ALTER TABLE "scans" ADD CONSTRAINT "scans_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "scans" ADD CONSTRAINT "scans_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "evidence" ADD CONSTRAINT "evidence_complaint_id_fkey" FOREIGN KEY ("complaint_id") REFERENCES "complaints"("id") ON DELETE CASCADE ON UPDATE CASCADE;
