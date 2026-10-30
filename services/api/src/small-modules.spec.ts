import { CategoriesController } from './categories/categories.controller';
import { CategoriesService } from './categories/categories.service';
import { NotificationsController } from './notifications/notifications.controller';
import { NotificationsService } from './notifications/notifications.service';
import { ProvidersController } from './providers/providers.controller';
import { maskPayout, ProvidersService } from './providers/providers.service';
import { ProviderMeController } from './providers/provider-me.controller';
import { SubscriptionsController } from './subscriptions/subscriptions.controller';
import { SubscriptionsService } from './subscriptions/subscriptions.service';
import { BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common';
import { UsersController } from './users/users.controller';
import { UsersService } from './users/users.service';
import { PrismaService } from './prisma/prisma.service';
import { AuthController } from './auth/auth.controller';
import { AuthService } from './auth/auth.service';

const asPrisma = (p: object) => p as unknown as PrismaService;

describe('CategoriesService', () => {
  function build() {
    const prisma = {
      category: {
        findMany: jest.fn().mockResolvedValue([]),
        create: jest.fn().mockResolvedValue({ id: 'c1' }),
        update: jest.fn().mockResolvedValue({ id: 'c1' }),
      },
      subService: {
        findMany: jest.fn().mockResolvedValue([]),
        create: jest.fn().mockResolvedValue({ id: 's1' }),
      },
    };
    return { service: new CategoriesService(asPrisma(prisma)), prisma };
  }

  it('lists only active categories', async () => {
    const { service, prisma } = build();
    await service.listActive();
    expect(prisma.category.findMany).toHaveBeenCalledWith({ where: { active: true } });
  });

  it('lists the sub-services of a category', async () => {
    const { service, prisma } = build();
    await service.listSubServices('c1');
    expect(prisma.subService.findMany).toHaveBeenCalledWith({ where: { categoryId: 'c1' } });
  });

  it('creates a category as active by default', async () => {
    const { service, prisma } = build();
    await service.upsertCategory({ name: 'Electrician' });
    expect(prisma.category.create).toHaveBeenCalledWith({
      data: { name: 'Electrician', active: true },
    });
  });

  it('keeps an explicit inactive flag on create', async () => {
    const { service, prisma } = build();
    await service.upsertCategory({ name: 'Hidden', active: false });
    expect(prisma.category.create.mock.calls[0][0].data.active).toBe(false);
  });

  it('updates an existing category when an id is given', async () => {
    const { service, prisma } = build();
    await service.upsertCategory({ name: 'Plumber' }, 'c1');
    expect(prisma.category.update).toHaveBeenCalledWith({ where: { id: 'c1' }, data: { name: 'Plumber' } });
    expect(prisma.category.create).not.toHaveBeenCalled();
  });

  it('creates a sub-service under a category', async () => {
    const { service, prisma } = build();
    await service.upsertSubService({ name: 'Fan repair', categoryId: 'c1', suggestedMinPrice: 200 });
    expect(prisma.subService.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ name: 'Fan repair', categoryId: 'c1', suggestedMinPrice: 200 }),
    });
  });
});

describe('CategoriesController', () => {
  it('delegates reads and admin writes', async () => {
    const service = {
      listActive: jest.fn().mockResolvedValue('active'),
      listSubServices: jest.fn().mockResolvedValue('subs'),
      upsertCategory: jest.fn().mockResolvedValue('upserted'),
      upsertSubService: jest.fn().mockResolvedValue('added'),
    };
    const controller = new CategoriesController(service as unknown as CategoriesService);

    expect(await controller.list()).toBe('active');
    expect(await controller.subServices('c1')).toBe('subs');
    expect(await controller.create({ name: 'A' })).toBe('upserted');
    expect(await controller.update('c1', { name: 'B' })).toBe('upserted');
    expect(await controller.addSubService('c1', { name: 'S' })).toBe('added');
    expect(service.upsertCategory).toHaveBeenLastCalledWith({ name: 'B' }, 'c1');
    expect(service.upsertSubService).toHaveBeenCalledWith({ name: 'S', categoryId: 'c1' });
  });
});

describe('UsersService and controller', () => {
  it('loads the profile with provider and addresses', async () => {
    const prisma = { user: { findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'u1' }), update: jest.fn() } };
    const service = new UsersService(asPrisma(prisma));

    await service.profile('u1');

    const args = prisma.user.findUniqueOrThrow.mock.calls[0][0];
    expect(args.where).toEqual({ id: 'u1' });
    expect(args.select.provider.select.subServices).toBe(true);
    expect(args.select.addresses).toBe(true);
  });

  it('updates only the given profile fields', async () => {
    const prisma = { user: { findUniqueOrThrow: jest.fn(), update: jest.fn().mockResolvedValue({}) } };
    const service = new UsersService(asPrisma(prisma));

    await service.updateProfile('u1', { fullName: 'New Name' });

    const args = prisma.user.update.mock.calls[0][0];
    expect(args.where).toEqual({ id: 'u1' });
    expect(args.data).toEqual({ fullName: 'New Name' });
  });

  it.each(['profile', 'updateProfile'] as const)(
    '%s never returns the password hash, ID proof or bank details',
    async (method) => {
      const prisma = {
        user: { findUniqueOrThrow: jest.fn().mockResolvedValue({}), update: jest.fn().mockResolvedValue({}) },
      };
      const service = new UsersService(asPrisma(prisma));

      await (method === 'profile' ? service.profile('u1') : service.updateProfile('u1', { fullName: 'A' }));

      const call = method === 'profile' ? prisma.user.findUniqueOrThrow : prisma.user.update;
      const { select, include } = call.mock.calls[0][0];
      expect(include).toBeUndefined();
      expect(select).toBeDefined();
      expect(select).not.toHaveProperty('passwordHash');
      expect(select.provider.select).not.toHaveProperty('idProofUrl');
      expect(select.provider.select).not.toHaveProperty('bankOrUpiDetails');
    },
  );

  it('controller uses the signed-in user id', async () => {
    const users = {
      profile: jest.fn().mockResolvedValue('me'),
      updateProfile: jest.fn().mockResolvedValue('updated'),
    };
    const controller = new UsersController(users as unknown as UsersService);
    const req = { user: { sub: 'u1', role: 'CUSTOMER' as const } };

    expect(await controller.me(req)).toBe('me');
    expect(await controller.update(req, { email: 'a@b.co' })).toBe('updated');
    expect(users.updateProfile).toHaveBeenCalledWith('u1', { email: 'a@b.co' });
  });
});

describe('ProvidersService and controller', () => {
  it('finds active providers for a sub-service, best rated first', async () => {
    const prisma = { provider: { findMany: jest.fn().mockResolvedValue([]) } };
    const service = new ProvidersService(asPrisma(prisma));

    await service.findForSubService('s1');

expect(prisma.provider.findMany).toHaveBeenCalledWith(      expect.objectContaining({        where: { status: 'ACTIVE', subServices: { some: { subServiceId: 's1' } } },        orderBy: { averageRating: 'desc' },      }),    );
  });

  it('controller passes the sub-service id through', async () => {
    const providers = { findForSubService: jest.fn().mockResolvedValue('found') };
    const controller = new ProvidersController(providers as unknown as ProvidersService);

    expect(await controller.search('s1')).toBe('found');
    expect(providers.findForSubService).toHaveBeenCalledWith('s1');
  });
});

describe('Provider business details (providers/me)', () => {
  const row = {
    id: 'p1',
    businessName: 'Rajesh Electricals',
    yearsExperience: 8,
    coverageRadiusKm: 10,
    status: 'ACTIVE',
    idProofUrl: 'https://docs.example/id.png',
    idProofNeedsReview: false,
    bankOrUpiDetails: 'rajesh@okhdfc',
    user: { fullName: 'Rajesh K', mobile: '9000000002', email: 'rajesh@example.test', profilePhotoUrl: null },
    subServices: [
      { subService: { id: 's1', name: 'Fan Installation', category: { id: 'c1', name: 'Electrician' } } },
      { subService: { id: 's2', name: 'Light Fitting', category: { id: 'c1', name: 'Electrician' } } },
    ],
  };

  function build(subServices: { id: string; categoryId: string }[] = []) {
    const prisma = {
      provider: {
        findUniqueOrThrow: jest.fn().mockResolvedValue(row),
        update: jest.fn().mockResolvedValue(row),
      },
      subService: { findMany: jest.fn().mockResolvedValue(subServices) },
    };
    return { service: new ProvidersService(asPrisma(prisma)), prisma };
  }

  it("reads the caller's own provider row and flattens category and services", async () => {
    const { service, prisma } = build();

    const result = await service.getMine('u1');

    expect(prisma.provider.findUniqueOrThrow.mock.calls[0][0].where).toEqual({ userId: 'u1' });
    expect(result).toEqual({
      id: 'p1',
      businessName: 'Rajesh Electricals',
      mobile: '9000000002',
      email: 'rajesh@example.test',
      profilePhotoUrl: null,
      status: 'ACTIVE',
      yearsExperience: 8,
      coverageRadiusKm: 10,
      category: { id: 'c1', name: 'Electrician' },
      subServices: [
        { id: 's1', name: 'Fan Installation' },
        { id: 's2', name: 'Light Fitting' },
      ],
      idProofOnFile: true,
      idProofNeedsReview: false,
      bankOrUpiMasked: 'ra••••@okhdfc',
    });
  });

  it('falls back to the person’s name when there is no business name', async () => {
    const { service, prisma } = build();
    prisma.provider.findUniqueOrThrow.mockResolvedValue({ ...row, businessName: null });
    expect((await service.getMine('u1')).businessName).toBe('Rajesh K');
  });

  it('reports no category when the provider offers no services', async () => {
    const { service, prisma } = build();
    prisma.provider.findUniqueOrThrow.mockResolvedValue({ ...row, subServices: [] });

    expect((await service.getMine('u1')).category).toBeNull();
  });

  it('never returns the ID proof link or raw bank details, even to the owner', async () => {
    const { service } = build();

    const result = await service.getMine('u1');

    expect(result).not.toHaveProperty('idProofUrl');
    expect(result).not.toHaveProperty('bankOrUpiDetails');
    expect(JSON.stringify(result)).not.toContain('rajesh@okhdfc');
    expect(JSON.stringify(result)).not.toContain('id.png');
  });

  it('updates only the fields given, on the caller\'s own row', async () => {
    const { service, prisma } = build();

    await service.updateMine('u1', { yearsExperience: 9 });

    const args = prisma.provider.update.mock.calls[0][0];
    expect(args.where).toEqual({ userId: 'u1' });
    expect(args.data).toEqual({
      businessName: undefined,
      yearsExperience: 9,
      coverageRadiusKm: undefined,
      subServices: undefined,
    });
    expect(prisma.subService.findMany).not.toHaveBeenCalled();
  });

  it('saves a trimmed business name', async () => {
    const { service, prisma } = build();
    await service.updateMine('u1', { businessName: '  Rajesh Power Works ' });
    expect(prisma.provider.update.mock.calls[0][0].data.businessName).toBe('Rajesh Power Works');
  });

  it('a new ID proof link is saved and marked for review, without blocking the provider', async () => {
    const { service, prisma } = build();

    await service.updateMine('u1', { idProofUrl: ' https://docs.example/new-id.png ' });

    const data = prisma.provider.update.mock.calls[0][0].data;
    expect(data.idProofUrl).toBe('https://docs.example/new-id.png');
    expect(data.idProofNeedsReview).toBe(true);
    expect(data).not.toHaveProperty('status');
  });

  it('sending the same ID proof link again changes nothing', async () => {
    const { service, prisma } = build();

    await service.updateMine('u1', { idProofUrl: 'https://docs.example/id.png' });

    const data = prisma.provider.update.mock.calls[0][0].data;
    expect(data).not.toHaveProperty('idProofUrl');
    expect(data).not.toHaveProperty('idProofNeedsReview');
  });

  it('saves payout details trimmed, and an empty value clears them', async () => {
    const { service, prisma } = build();

    await service.updateMine('u1', { bankOrUpiDetails: ' meera@oksbi ' });
    expect(prisma.provider.update.mock.calls[0][0].data.bankOrUpiDetails).toBe('meera@oksbi');

    await service.updateMine('u1', { bankOrUpiDetails: '  ' });
    expect(prisma.provider.update.mock.calls[1][0].data.bankOrUpiDetails).toBeNull();
  });

  it('replaces the service list in one write, dropping duplicate ids', async () => {
    const { service, prisma } = build([
      { id: 's1', categoryId: 'c1' },
      { id: 's2', categoryId: 'c1' },
    ]);

    await service.updateMine('u1', { subServiceIds: ['s1', 's2', 's1'], coverageRadiusKm: 15 });

    expect(prisma.subService.findMany.mock.calls[0][0].where).toEqual({ id: { in: ['s1', 's2'] } });
    expect(prisma.provider.update.mock.calls[0][0].data).toEqual({
      businessName: undefined,
      yearsExperience: undefined,
      coverageRadiusKm: 15,
      subServices: { deleteMany: {}, create: [{ subServiceId: 's1' }, { subServiceId: 's2' }] },
    });
  });

  it.each([
    ['rajesh@okhdfc', 'ra••••@okhdfc'],
    ['r@ybl', 'r••••@ybl'],
    ['123456789012', '•••• 9012'],
    ['1234 5678 9012 HDFC0001234', '•••• 1234'],
    ['123', '••••'],
    ['  ', null],
    [null, null],
  ])('masks payout %p as %p', (value, masked) => {
    expect(maskPayout(value)).toBe(masked);
  });

  it('refuses an unknown sub-service', async () => {
    const { service, prisma } = build([{ id: 's1', categoryId: 'c1' }]);

    await expect(service.updateMine('u1', { subServiceIds: ['s1', 'nope'] })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.provider.update).not.toHaveBeenCalled();
  });

  it('refuses services from more than one category', async () => {
    const { service, prisma } = build([
      { id: 's1', categoryId: 'c1' },
      { id: 's5', categoryId: 'c2' },
    ]);

    await expect(service.updateMine('u1', { subServiceIds: ['s1', 's5'] })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.provider.update).not.toHaveBeenCalled();
  });

  it('controller always uses the signed-in user id', async () => {
    const providers = {
      getMine: jest.fn().mockResolvedValue('mine'),
      updateMine: jest.fn().mockResolvedValue('updated'),
    };
    const controller = new ProviderMeController(providers as unknown as ProvidersService);
    const req = { user: { sub: 'u1', role: 'PROVIDER' as const } };

    expect(await controller.mine(req)).toBe('mine');
    expect(await controller.update(req, { yearsExperience: 3 })).toBe('updated');
    expect(providers.getMine).toHaveBeenCalledWith('u1');
    expect(providers.updateMine).toHaveBeenCalledWith('u1', { yearsExperience: 3 });
  });
});

describe('NotificationsService and controller', () => {
  function build() {
    const prisma = {
      notification: {
        create: jest.fn().mockResolvedValue({ id: 'n1' }),
        findMany: jest.fn().mockResolvedValue([]),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };
    return { service: new NotificationsService(asPrisma(prisma)), prisma };
  }

  it('persists a notification', async () => {
    const { service, prisma } = build();
    await service.notify('u1', 'NEW_REQUEST_MATCH', 'New job', 'PUSH');
    expect(prisma.notification.create).toHaveBeenCalledWith({
      data: { userId: 'u1', event: 'NEW_REQUEST_MATCH', message: 'New job', channel: 'PUSH' },
    });
  });

  it("lists a user's notifications newest first", async () => {
    const { service, prisma } = build();
    await service.listForUser('u1');
    expect(prisma.notification.findMany).toHaveBeenCalledWith({
      where: { userId: 'u1' },
      orderBy: { createdAt: 'desc' },
    });
  });

  it('marks one read with a timestamp', async () => {
    const { service, prisma } = build();
    await service.markRead('n1', 'u1');
    const args = prisma.notification.updateMany.mock.calls[0][0];
    expect(args.where).toEqual({ id: 'n1', userId: 'u1' });
    expect(args.data.readAt).toBeInstanceOf(Date);
  });

  it('controller delegates', async () => {
    const notifications = {
      listForUser: jest.fn().mockResolvedValue('list'),
      markRead: jest.fn().mockResolvedValue('read'),
    };
    const controller = new NotificationsController(notifications as unknown as NotificationsService);

    expect(await controller.mine({ user: { sub: 'u1', role: 'CUSTOMER' } })).toBe('list');
    expect(await controller.markRead({ user: { sub: 'u1', role: 'CUSTOMER' } }, 'n1')).toBe('read');
    expect(notifications.markRead).toHaveBeenCalledWith('n1', 'u1');
    expect(notifications.listForUser).toHaveBeenCalledWith('u1');
  });
});

describe('SubscriptionsService and controller', () => {
  function build() {
    const prisma = {
      subscription: {
        findUnique: jest.fn().mockResolvedValue(null),
        upsert: jest.fn().mockResolvedValue({}),
      },
    };
    return { service: new SubscriptionsService(asPrisma(prisma)), prisma };
  }

  it('looks up the current plan', async () => {
    const { service, prisma } = build();
    await service.current('p1');
    expect(prisma.subscription.findUnique).toHaveBeenCalledWith({ where: { providerId: 'p1' } });
  });

  it.each([
    ['PER_SERVICE', 0],
    ['MONTHLY_99', 5],
    ['MONTHLY_299', 10],
  ] as const)('setPlan %s sets the cycle limit to %i and resets usage', async (plan, limit) => {
    const { service, prisma } = build();

    await service.setPlan('p1', plan);

    expect(prisma.subscription.upsert).toHaveBeenCalledWith({
      where: { providerId: 'p1' },
      create: { providerId: 'p1', plan, cycleLimit: limit, cycleUsed: 0 },
      update: { plan, cycleLimit: limit, cycleUsed: 0 },
    });
  });

  it('controller delegates', async () => {
    const subscriptions = {
      current: jest.fn().mockResolvedValue('current'),
      setPlan: jest.fn().mockResolvedValue('set'),
    };
    const prisma = { provider: { findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'p1' }) } };
    const controller = new SubscriptionsController(
      subscriptions as unknown as SubscriptionsService,
      asPrisma(prisma),
    );
    const req = { user: { sub: 'u1', role: 'PROVIDER' as const } };

    expect(await controller.current(req, 'p1')).toBe('current');
    expect(await controller.setPlan(req, 'p1', 'MONTHLY_99')).toBe('set');
    expect(subscriptions.setPlan).toHaveBeenCalledWith('p1', 'MONTHLY_99');
  });

  it("refuses to read or change another provider's subscription", async () => {
    const subscriptions = { current: jest.fn(), setPlan: jest.fn() };
    const prisma = { provider: { findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'mine' }) } };
    const controller = new SubscriptionsController(
      subscriptions as unknown as SubscriptionsService,
      asPrisma(prisma),
    );
    const req = { user: { sub: 'u1', role: 'PROVIDER' as const } };

    await expect(controller.current(req, 'theirs')).rejects.toBeInstanceOf(ForbiddenException);
    await expect(controller.setPlan(req, 'theirs', 'MONTHLY_299')).rejects.toBeInstanceOf(ForbiddenException);
    expect(subscriptions.current).not.toHaveBeenCalled();
    expect(subscriptions.setPlan).not.toHaveBeenCalled();
  });
});

describe('Notifications ownership', () => {
  it("treats someone else's notification as not found", async () => {
    const prisma = { notification: { updateMany: jest.fn().mockResolvedValue({ count: 0 }) } };
    const service = new NotificationsService(asPrisma(prisma));

    await expect(service.markRead('n1', 'intruder')).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.notification.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 'n1', userId: 'intruder' } }),
    );
  });
});

describe('Public provider search', () => {
  it('never selects the ID proof or bank details', async () => {
    const prisma = { provider: { findMany: jest.fn().mockResolvedValue([]) } };
    const service = new ProvidersService(asPrisma(prisma));

    await service.findForSubService('s1');

    const { select } = prisma.provider.findMany.mock.calls[0][0];
    expect(select).toBeDefined();
    expect(select).not.toHaveProperty('idProofUrl');
    expect(select).not.toHaveProperty('bankOrUpiDetails');
    expect(select).not.toHaveProperty('userId');
  });
});

describe('AuthController', () => {
  it('delegates every route to AuthService', async () => {
    const auth = {
      requestOtp: jest.fn().mockReturnValue('otp'),
      signupCustomer: jest.fn().mockResolvedValue('cust'),
      signupProvider: jest.fn().mockResolvedValue('prov'),
      login: jest.fn().mockResolvedValue('token'),
      resetPassword: jest.fn().mockResolvedValue('reset'),
    };
    const controller = new AuthController(auth as unknown as AuthService);

    expect(controller.requestOtp({ mobile: '9876543210' })).toBe('otp');
    expect(auth.requestOtp).toHaveBeenCalledWith('9876543210');
    expect(await controller.signupCustomer({} as never)).toBe('cust');
    expect(await controller.signupProvider({} as never)).toBe('prov');
    expect(await controller.loginCustomer({ mobileOrEmail: 'a', password: 'b' })).toBe('token');
    expect(await controller.loginProvider({ mobileOrEmail: 'a', password: 'b' })).toBe('token');
    expect(await controller.resetPassword({} as never)).toBe('reset');
  });
});

describe('PrismaService', () => {
  it('connects on module init and disconnects on destroy', async () => {
    const service = new PrismaService();
    const connect = jest.spyOn(service, '$connect').mockResolvedValue();
    const disconnect = jest.spyOn(service, '$disconnect').mockResolvedValue();

    await service.onModuleInit();
    await service.onModuleDestroy();

    expect(connect).toHaveBeenCalledTimes(1);
    expect(disconnect).toHaveBeenCalledTimes(1);
  });
});
