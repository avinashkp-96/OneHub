-- Repairs requests whose status was pulled backwards. Until now a provider
-- accepting set the request to ACCEPTED and a bid set it to BID_RECEIVED
-- unconditionally, so on a request sent to several providers a later answer
-- could undo a newer status. Each step only moves a status forward.

-- Rated requests were completed.
UPDATE "Requirement" r
SET "status" = 'COMPLETED'
WHERE r."status" IN ('SENT', 'ACCEPTED', 'BID_RECEIVED', 'CONFIRMED')
  AND EXISTS (SELECT 1 FROM "RatingFeedback" f WHERE f."requirementId" = r."id");

-- A confirmed bid means the customer chose a provider.
UPDATE "Requirement"
SET "status" = 'CONFIRMED'
WHERE "status" IN ('SENT', 'ACCEPTED', 'BID_RECEIVED')
  AND "confirmedBidId" IS NOT NULL;

-- Any bid means bids were received.
UPDATE "Requirement" r
SET "status" = 'BID_RECEIVED'
WHERE r."status" IN ('SENT', 'ACCEPTED')
  AND EXISTS (SELECT 1 FROM "Bid" b WHERE b."requirementId" = r."id");
