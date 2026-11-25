import { Prisma, RequestStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

// A request stays open for prices for REQUEST_OPEN_DAYS after it is posted,
// or until the day after the customer's preferred date if that is later.
// After that it expires: no new prices, unlocks or confirmations. There is no
// scheduler, so requests are expired when they are next read or acted on
// (the customer's and provider's lists, sending a price, unlocking,
// confirming).
export const REQUEST_OPEN_DAYS = 3;
const DAY_MS = 24 * 60 * 60 * 1000;

// Statuses that still take prices. CONFIRMED, COMPLETED, CANCELLED and
// EXPIRED are final for bidding.
export const OPEN_STATUSES: RequestStatus[] = ['SENT', 'ACCEPTED', 'BID_RECEIVED'];

export const EXPIRED_MESSAGE = 'this request has expired';

interface Timing {
  createdAt: Date;
  preferredAt?: Date | null;
}

export function closesAt(r: Timing): Date {
  const byAge = r.createdAt.getTime() + REQUEST_OPEN_DAYS * DAY_MS;
  const byPreferredDate = r.preferredAt ? r.preferredAt.getTime() + DAY_MS : 0;
  return new Date(Math.max(byAge, byPreferredDate));
}

// True for a request already marked EXPIRED, or one still open past its
// closing time.
export function hasExpired(r: Timing & { status: string }, now = new Date()): boolean {
  if (r.status === 'EXPIRED') return true;
  return (OPEN_STATUSES as string[]).includes(r.status) && closesAt(r) <= now;
}

// The database version of hasExpired for still-open requests.
export function staleWhere(now = new Date()): Prisma.RequirementWhereInput {
  return {
    status: { in: OPEN_STATUSES },
    createdAt: { lte: new Date(now.getTime() - REQUEST_OPEN_DAYS * DAY_MS) },
    OR: [{ preferredAt: null }, { preferredAt: { lte: new Date(now.getTime() - DAY_MS) } }],
  };
}

// Marks open requests past their closing time as EXPIRED, limited to [scope].
export function expireStale(
  prisma: Pick<PrismaService, 'requirement'>,
  scope: Prisma.RequirementWhereInput,
  now = new Date(),
) {
  return prisma.requirement.updateMany({
    where: { AND: [staleWhere(now), scope] },
    data: { status: 'EXPIRED' },
  });
}
