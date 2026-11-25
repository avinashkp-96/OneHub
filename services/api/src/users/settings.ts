// A user's notification preferences, stored as User.settings (JSON). Each
// role has its own switches; anything not stored takes the default here, so a
// new switch needs no migration. The API honours them when it sends
// notifications (see NotificationsService.send).

export const SETTING_DEFAULTS = {
  CUSTOMER: { requestUpdates: true, reminders: true, offers: false },
  PROVIDER: { newRequests: true, jobUpdates: true, offers: false },
  ADMIN: {},
} as const;

export type Role = keyof typeof SETTING_DEFAULTS;
export type Settings = Record<string, boolean>;

// Which switch turns each notification event off. Events not listed are
// always sent. "offers" has no event yet: nothing sends offers or tips.
export const EVENT_SETTING: Record<string, string> = {
  NEW_REQUEST: 'newRequests',
  CONTACT_UNLOCKED: 'jobUpdates',
  SELECTED: 'jobUpdates',
  NOT_SELECTED: 'jobUpdates',
  NEW_RATING: 'jobUpdates',
  CERTIFIED: 'jobUpdates',
  BID_RECEIVED: 'requestUpdates',
  BID_UPDATED: 'requestUpdates',
  JOB_COMPLETED: 'reminders',
};

/** The role's switches, with what is stored laid over the defaults. Stored
 * keys that do not belong to the role are dropped. */
export function settingsFor(role: Role, stored: unknown): Settings {
  const saved = stored && typeof stored === 'object' ? (stored as Record<string, unknown>) : {};
  const result: Settings = { ...SETTING_DEFAULTS[role] };
  for (const key of Object.keys(result)) {
    if (typeof saved[key] === 'boolean') result[key] = saved[key] as boolean;
  }
  return result;
}

/** Whether a user with these settings wants this event. */
export function wants(role: Role, stored: unknown, event: string): boolean {
  const key = EVENT_SETTING[event];
  if (!key) return true;
  const settings = settingsFor(role, stored);
  return key in settings ? settings[key] : true;
}
