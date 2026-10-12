import { UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';

describe('UsersService.updateProfile', () => {
  it('passes only fullName, email and profilePhotoUrl to the database', async () => {
    const update = jest.fn().mockResolvedValue({});
    const service = new UsersService({ user: { update } } as unknown as PrismaService);

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
});
