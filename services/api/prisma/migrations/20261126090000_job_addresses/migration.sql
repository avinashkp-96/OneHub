-- Saved addresses get separate parts, and a request keeps a copy of the
-- address it is for.
ALTER TABLE "Address" RENAME COLUMN "line" TO "house";
ALTER TABLE "Address" ADD COLUMN "street" TEXT NOT NULL DEFAULT '',
ADD COLUMN "landmark" TEXT,
ADD COLUMN "pincode" TEXT NOT NULL DEFAULT '',
ADD COLUMN "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "Requirement" ADD COLUMN "address" JSONB;
