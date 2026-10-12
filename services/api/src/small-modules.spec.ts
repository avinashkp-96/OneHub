import { CategoriesController } from './categories/categories.controller';
import { CategoriesService } from './categories/categories.service';
import { NotificationsController } from './notifications/notifications.controller';
import { NotificationsService } from './notifications/notifications.service';
import { ProvidersController } from './providers/providers.controller';
import { ProvidersService } from './providers/providers.service';
import { SubscriptionsController } from './subscriptions/subscriptions.controller';
import { SubscriptionsService } from './subscriptions/subscriptions.service';
import { NotFoundException, ForbiddenException } from '@nestjs/common';
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

    expect(prisma.user.findUniqueOrThrow).toHaveBeenCalledWith({
      where: { id: 'u1' },
      include: { provider: { include: { subServices: true } }, addresses: true },
    });
  });

  it('updates only the given profile fields', async () => {
    const prisma = { user: { findUniqueOrThrow: jest.fn(), update: jest.fn().mockResolvedValue({}) } };
    const service = new UsersService(asPrisma(prisma));

    await service.updateProfile('u1', { fullName: 'New Name' });

    expect(prisma.user.update).toHaveBeenCalledWith({ where: { id: 'u1' }, data: { fullName: 'New Name' } });
  });

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
