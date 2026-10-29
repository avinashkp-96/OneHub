import { corsOptions, isOriginAllowed } from './cors';

describe('isOriginAllowed', () => {
  const dev = { NODE_ENV: 'development' };
  const prod = { NODE_ENV: 'production' };

  it.each([
    'http://localhost:8081',
    'http://127.0.0.1:5173',
    'http://[::1]:8082',
    'http://localhost',
    'http://192.168.1.20:8081',
    'http://10.0.0.5:8082',
    'http://172.17.0.246:8081',
    'http://172.31.255.1:3000',
  ])('allows %s outside production', (origin) => {
    expect(isOriginAllowed(origin, dev)).toBe(true);
  });

  it.each([
    'https://evil.example',
    'http://8.8.8.8:8081',
    'http://172.32.0.1:8081', // just outside 172.16.0.0/12
    'http://172.15.0.1:8081',
    'http://localhost.evil.example',
    'http://192.168.1.20.evil.example',
  ])('refuses %s outside production', (origin) => {
    expect(isOriginAllowed(origin, dev)).toBe(false);
  });

  it('refuses local and private origins in production', () => {
    expect(isOriginAllowed('http://localhost:8081', prod)).toBe(false);
    expect(isOriginAllowed('http://192.168.1.20:8081', prod)).toBe(false);
  });

  it('allows exactly the listed origins, in any environment', () => {
    const env = { ...prod, CORS_ORIGINS: ' https://admin.onehub.example , https://app.onehub.example' };

    expect(isOriginAllowed('https://admin.onehub.example', env)).toBe(true);
    expect(isOriginAllowed('https://app.onehub.example', env)).toBe(true);
    expect(isOriginAllowed('https://admin.onehub.example.evil', env)).toBe(false);
    expect(isOriginAllowed('http://admin.onehub.example', env)).toBe(false);
  });

  it('treats an empty list as no listed origins', () => {
    expect(isOriginAllowed('https://evil.example', { ...prod, CORS_ORIGINS: '' })).toBe(false);
    expect(isOriginAllowed('', { ...prod, CORS_ORIGINS: ' , ' })).toBe(false);
  });
});

describe('corsOptions', () => {
  function decide(origin: string | undefined, env: { NODE_ENV?: string; CORS_ORIGINS?: string }) {
    const options = corsOptions(env);
    const check = options.origin as (o: string | undefined, cb: (err: Error | null, allow?: boolean) => void) => void;
    let allowed: boolean | undefined;
    check(origin, (_err, allow) => (allowed = allow));
    return allowed;
  }

  it('lets requests without an Origin through (native apps, curl)', () => {
    expect(decide(undefined, { NODE_ENV: 'production' })).toBe(true);
  });

  it('applies the allow-list to browser requests', () => {
    expect(decide('http://localhost:8081', { NODE_ENV: 'development' })).toBe(true);
    expect(decide('https://evil.example', { NODE_ENV: 'development' })).toBe(false);
  });

  it('allows the auth header and the methods the apps use', () => {
    const options = corsOptions({});
    expect(options.allowedHeaders).toEqual(['Authorization', 'Content-Type']);
    expect(options.methods).toEqual(['GET', 'POST', 'PUT', 'PATCH', 'DELETE']);
  });

  it('reads process.env by default', () => {
    const saved = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    try {
      expect(corsOptions().origin).toBeInstanceOf(Function);
      const check = corsOptions().origin as (o: string, cb: (e: Error | null, a?: boolean) => void) => void;
      let allowed: boolean | undefined;
      check('http://localhost:8081', (_e, a) => (allowed = a));
      expect(allowed).toBe(false);
    } finally {
      process.env.NODE_ENV = saved;
    }
  });
});
