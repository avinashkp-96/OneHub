-- Requests now have a short title as well as the description. Existing
-- requests take their sub-service name (e.g. "Switchboard Repair") as the title.
ALTER TABLE "Requirement" ADD COLUMN "title" TEXT;

UPDATE "Requirement" r
SET "title" = s."name"
FROM "SubService" s
WHERE s."id" = r."subServiceId";

ALTER TABLE "Requirement" ALTER COLUMN "title" SET NOT NULL;
