-- Until an approval flow exists, providers waiting for verification work like
-- active ones; their ID proof stays flagged for review.
UPDATE "Provider"
SET "status" = 'ACTIVE', "idProofNeedsReview" = true
WHERE "status" = 'PENDING_VERIFICATION';
