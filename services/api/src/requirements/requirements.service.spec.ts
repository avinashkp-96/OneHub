import { PrismaService } from '../prisma/prisma.service';
import { RequirementsService, distanceKm } from './requirements.service';
import { NotificationsService } from '../notifications/notifications.service';

// These reads never notify anyone.
const unusedNotifications = {} as NotificationsService;

describe('RequirementsService.listForProvider', () => {
  const kochi = { latitude: 9.9667, longitude: 76.2999 };
  const providerAt = (location: { latitude: number | null; longitude: number | null } | null) => ({
    findUnique: jest.fn().mockResolvedValue(location && { user: location }),
  });

  it('filters the included bids to this provider only', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = { requirement: { findMany }, provider: providerAt(kochi) } as unknown as PrismaService;
    const service = new RequirementsService(prisma, unusedNotifications);

    await service.listForProvider('provider-1');

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        include: expect.objectContaining({
          subService: true,
          bids: { where: { providerId: 'provider-1' } },
        }),
      }),
    );
  });

  it('adds the customer name, place and distance, and drops the customer record', async () => {
    const findMany = jest.fn().mockResolvedValue([
      {
        id: 'r1',
        customer: { fullName: 'Meera Nair', city: 'Kochi', latitude: 10.0261, longitude: 76.3125 },
      },
      {
        id: 'r2',
        customer: { fullName: 'Anil Kumar', city: null, latitude: null, longitude: null },
      },
    ]);
    const prisma = { requirement: { findMany }, provider: providerAt(kochi) } as unknown as PrismaService;
    const service = new RequirementsService(prisma, unusedNotifications);

    const [withLocation, withoutLocation] = await service.listForProvider('provider-1');

    expect(withLocation).toEqual({ id: 'r1', customerName: 'Meera Nair', customerPlace: 'Kochi', distanceKm: 6.7 });
    expect(withoutLocation).toEqual({ id: 'r2', customerName: 'Anil Kumar', customerPlace: null, distanceKm: null });
  });

  it('leaves the distance out when the provider has no saved location', async () => {
    const findMany = jest.fn().mockResolvedValue([
      { id: 'r1', customer: { fullName: 'Meera Nair', city: 'Kochi', latitude: 10.0261, longitude: 76.3125 } },
    ]);
    const prisma = { requirement: { findMany }, provider: providerAt(null) } as unknown as PrismaService;
    const service = new RequirementsService(prisma, unusedNotifications);

    const [r] = await service.listForProvider('provider-1');

    expect(r.distanceKm).toBeNull();
  });

  it('scopes the query to requirements targeted at this provider', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = { requirement: { findMany }, provider: providerAt(kochi) } as unknown as PrismaService;
    const service = new RequirementsService(prisma, unusedNotifications);

    await service.listForProvider('provider-1');

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { targetedProviders: { some: { providerId: 'provider-1' } } },
      }),
    );
  });
});

describe('distanceKm', () => {
  it('is 0 for the same point', () => {
    expect(distanceKm({ latitude: 9.97, longitude: 76.3 }, { latitude: 9.97, longitude: 76.3 })).toBe(0);
  });

  it('measures Kochi to Thiruvananthapuram at about 175 km', () => {
    const km = distanceKm({ latitude: 9.9312, longitude: 76.2673 }, { latitude: 8.5241, longitude: 76.9366 });
    expect(km).toBeGreaterThan(170);
    expect(km).toBeLessThan(180);
  });

  it('is null when either point has no coordinates', () => {
    expect(distanceKm({ latitude: null, longitude: 76.3 }, { latitude: 9.97, longitude: 76.3 })).toBeNull();
    expect(distanceKm({ latitude: 9.97, longitude: 76.3 }, { latitude: 9.97, longitude: null })).toBeNull();
  });
});
