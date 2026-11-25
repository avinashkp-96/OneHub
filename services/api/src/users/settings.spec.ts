import { BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { EVENT_SETTING, settingsFor, wants } from './settings';

describe('settingsFor', () => {
  it('gives each role its own switches with the defaults', () => {
    expect(settingsFor('CUSTOMER', {})).toEqual({ requestUpdates: true, reminders: true, offers: false });
    expect(settingsFor('PROVIDER', null)).toEqual({ newRequests: true, jobUpdates: true, offers: false });
  });

  it('lays stored values over the defaults and drops keys of another role', () => {
    expect(settingsFor('CUSTOMER', { reminders: false, newRequests: false, offers: 'yes' })).toEqual({
      requestUpdates: true,
      reminders: false,
      offers: false,
    });
  });
});

describe('wants', () => {
  it('follows the switch an event belongs to', () => {
    expect(wants('PROVIDER', { newRequests: false }, 'NEW_REQUEST')).toBe(false);
    expect(wants('PROVIDER', { newRequests: false }, 'SELECTED')).toBe(true);
    expect(wants('CUSTOMER', { requestUpdates: false }, 'BID_RECEIVED')).toBe(false);
    expect(wants('CUSTOMER', { reminders: false }, 'JOB_COMPLETED')).toBe(false);
  });

  it('always sends events with no switch, or whose switch is not the role’s', () => {
    expect(wants('CUSTOMER', { requestUpdates: false }, 'REQUEST_ACCEPTED')).toBe(true);
    expect(wants('ADMIN', {}, 'NEW_REQUEST')).toBe(true);
  });

  it('maps every switchable event to a real switch', () => {
    const keys = new Set([...Object.keys(settingsFor('CUSTOMER', {})), ...Object.keys(settingsFor('PROVIDER', {}))]);
    for (const key of Object.values(EVENT_SETTING)) expect(keys.has(key)).toBe(true);
  });
});

describe('UsersService settings', () => {
  function build(role: string, settings: object = {}) {
    const prisma = {
      user: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({ role, settings }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    return { service: new UsersService(prisma as unknown as PrismaService), prisma };
  }

  it('reads the caller’s switches', async () => {
    const { service, prisma } = build('PROVIDER', { offers: true });

    expect(await service.settings('u1')).toEqual({ newRequests: true, jobUpdates: true, offers: true });
    expect(prisma.user.findUniqueOrThrow.mock.calls[0][0].where).toEqual({ id: 'u1' });
  });

  it('changes only the switches sent and stores the full set', async () => {
    const { service, prisma } = build('CUSTOMER', { offers: true });

    const result = await service.updateSettings('u1', { reminders: false });

    expect(result).toEqual({ requestUpdates: true, reminders: false, offers: true });
    expect(prisma.user.update).toHaveBeenCalledWith({ where: { id: 'u1' }, data: { settings: result } });
  });

  it('refuses a switch that belongs to the other role', async () => {
    const { service, prisma } = build('CUSTOMER');

    await expect(service.updateSettings('u1', { newRequests: false })).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('the controller acts on the signed-in user', async () => {
    const users = {
      settings: jest.fn().mockResolvedValue({ offers: false }),
      updateSettings: jest.fn().mockResolvedValue({ offers: true }),
    };
    const controller = new UsersController(users as unknown as UsersService);
    const req = { user: { sub: 'u9', role: 'CUSTOMER' as const } };

    expect(await controller.settings(req)).toEqual({ offers: false });
    expect(await controller.updateSettings(req, { offers: true })).toEqual({ offers: true });
    expect(users.updateSettings).toHaveBeenCalledWith('u9', { offers: true });
  });
});
