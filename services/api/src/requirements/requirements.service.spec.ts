import { PrismaService } from '../prisma/prisma.service';
import { RequirementsService } from './requirements.service';
import { NotificationsService } from '../notifications/notifications.service';

// These reads never notify anyone.
const unusedNotifications = {} as NotificationsService;

describe('RequirementsService.listForProvider', () => {
  it('filters the included bids to this provider only', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = { requirement: { findMany } } as unknown as PrismaService;
    const service = new RequirementsService(prisma, unusedNotifications);

    await service.listForProvider('provider-1');

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        include: { subService: true, bids: { where: { providerId: 'provider-1' } } },
      }),
    );
  });

  it('scopes the query to requirements targeted at this provider', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = { requirement: { findMany } } as unknown as PrismaService;
    const service = new RequirementsService(prisma, unusedNotifications);

    await service.listForProvider('provider-1');

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { targetedProviders: { some: { providerId: 'provider-1' } } },
      }),
    );
  });
});
