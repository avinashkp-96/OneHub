import { BadRequestException, ConflictException } from '@nestjs/common';
import { UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';

describe('UsersService.updateProfile', () => {
  function setup(taken: { id: string } | null = null) {
    const update = jest.fn().mockResolvedValue({});
    const findFirst = jest.fn().mockResolvedValue(taken);
    const service = new UsersService({ user: { update, findFirst } } as unknown as PrismaService);
    return { service, update, findFirst };
  }

  it('passes only fullName, email and profilePhotoUrl to the database', async () => {
    const { service, update } = setup();

    // A hostile body that skipped the validation pipe.
    const hostile = {
      fullName: 'Eve',
      role: 'ADMIN',
      passwordHash: 'x',
      mobile: '9000000000',
    } as never;
    await service.updateProfile('u1', hostile);

    const data = update.mock.calls[0][0].data;
    expect(Object.keys(data).sort()).toEqual(['email', 'fullName', 'profilePhotoUrl']);
    expect(data).not.toHaveProperty('role');
    expect(data).not.toHaveProperty('passwordHash');
    expect(data).not.toHaveProperty('mobile');
  });

  it('trims the name and email', async () => {
    const { service, update } = setup();

    await service.updateProfile('u1', { fullName: '  Meera Nair ', email: ' meera@example.com ' });

    expect(update.mock.calls[0][0].data).toMatchObject({
      fullName: 'Meera Nair',
      email: 'meera@example.com',
    });
  });

  it('refuses a blank name', async () => {
    const { service, update } = setup();

    await expect(service.updateProfile('u1', { fullName: '   ' })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(update).not.toHaveBeenCalled();
  });

  it('clears the email when sent null, and keeps it when left out', async () => {
    const { service, update, findFirst } = setup();

    await service.updateProfile('u1', { email: null });
    await service.updateProfile('u1', { fullName: 'Meera' });

    expect(update.mock.calls[0][0].data.email).toBeNull();
    expect(update.mock.calls[1][0].data.email).toBeUndefined();
    expect(findFirst).not.toHaveBeenCalled();
  });

  it('refuses an email another account already uses', async () => {
    const { service, update, findFirst } = setup({ id: 'u2' });

    await expect(
      service.updateProfile('u1', { email: 'taken@example.com' }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(findFirst.mock.calls[0][0].where).toEqual({
      email: 'taken@example.com',
      NOT: { id: 'u1' },
    });
    expect(update).not.toHaveBeenCalled();
  });
});
