-- Notification switches per user. Empty means every default applies (see
-- src/users/settings.ts), so existing users need no backfill.
ALTER TABLE "User" ADD COLUMN "settings" JSONB NOT NULL DEFAULT '{}';
