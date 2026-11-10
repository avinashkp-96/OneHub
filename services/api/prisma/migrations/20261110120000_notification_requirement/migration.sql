-- Notifications about a request now record which one, so tapping a
-- notification can open that request. Older rows stay null and open nothing.
ALTER TABLE "Notification" ADD COLUMN "requirementId" TEXT;
