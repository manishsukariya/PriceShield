CREATE TYPE "ProductSubmissionStatus" AS ENUM ('PENDING', 'REVIEWED', 'REJECTED');

ALTER TABLE "scans" ADD COLUMN "client_request_id" TEXT;
ALTER TABLE "complaints" ADD COLUMN "client_request_id" TEXT;
CREATE UNIQUE INDEX "scans_user_id_client_request_id_key" ON "scans"("user_id", "client_request_id");
CREATE UNIQUE INDEX "complaints_user_id_client_request_id_key" ON "complaints"("user_id", "client_request_id");

CREATE TABLE "product_submissions" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "barcode" TEXT NOT NULL,
  "product_name" TEXT,
  "printed_mrp" DECIMAL(12,2),
  "ocr_text" TEXT,
  "front_image_url" TEXT,
  "back_image_url" TEXT,
  "status" "ProductSubmissionStatus" NOT NULL DEFAULT 'PENDING',
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "product_submissions_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "product_submissions_user_id_created_at_idx" ON "product_submissions"("user_id", "created_at");
CREATE INDEX "product_submissions_barcode_status_idx" ON "product_submissions"("barcode", "status");
ALTER TABLE "product_submissions" ADD CONSTRAINT "product_submissions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
