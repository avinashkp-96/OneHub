import { ExecutionContext } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { RolesGuard } from './roles.guard';
import { JwtStrategy } from './jwt.strategy';
import { ROLES_KEY } from './roles.decorator';

class Controller {
  open() {
    return 'open';
  }
  providersOnly() {
    return 'providers';
  }
}
Reflect.defineMetadata(ROLES_KEY, ['PROVIDER'], Controller.prototype.providersOnly);

function contextFor(handler: () => string, user?: { role: string }): ExecutionContext {
  return {
    getHandler: () => handler,
    getClass: () => Controller,
    switchToHttp: () => ({ getRequest: () => ({ user }) }),
  } as unknown as ExecutionContext;
}

describe('RolesGuard', () => {
  const guard = new RolesGuard(new Reflector());
  const c = new Controller();

  it('lets anyone through a route with no roles', () => {
    expect(guard.canActivate(contextFor(c.open, { role: 'CUSTOMER' }))).toBe(true);
  });

  it('allows a user with a required role', () => {
    expect(guard.canActivate(contextFor(c.providersOnly, { role: 'PROVIDER' }))).toBe(true);
  });

  it('blocks a user without the required role', () => {
    expect(guard.canActivate(contextFor(c.providersOnly, { role: 'CUSTOMER' }))).toBe(false);
  });

  it('blocks a request with no user', () => {
    expect(guard.canActivate(contextFor(c.providersOnly, undefined))).toBe(false);
  });
});

describe('JwtStrategy', () => {
  it('returns the token payload as the request user', async () => {
    const config = { get: jest.fn().mockReturnValue('secret') } as unknown as ConfigService;
    const strategy = new JwtStrategy(config);

    expect(await strategy.validate({ sub: 'u1', role: 'ADMIN' })).toEqual({ sub: 'u1', role: 'ADMIN' });
  });

  it('refuses to start without JWT_SECRET', () => {
    const config = { get: jest.fn().mockReturnValue(undefined) } as unknown as ConfigService;
    expect(() => new JwtStrategy(config)).toThrow('JWT_SECRET is not set');
  });
});

describe('JwtStrategy placeholder secret', () => {
  const withEnv = (nodeEnv: string | undefined) =>
    ({
      get: jest.fn((key: string) => (key === 'JWT_SECRET' ? 'change-me' : nodeEnv)),
    }) as unknown as ConfigService;

  it('is refused in production', () => {
    expect(() => new JwtStrategy(withEnv('production'))).toThrow('placeholder');
  });

  it('is still allowed in development', () => {
    expect(() => new JwtStrategy(withEnv('development'))).not.toThrow();
  });
});
