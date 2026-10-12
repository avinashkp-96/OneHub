import { ConfigService } from '@nestjs/config';
import { OtpService } from './otp.service';

describe('OtpService', () => {
  function build(ttl?: string) {
    const config = { get: jest.fn().mockReturnValue(ttl) } as unknown as ConfigService;
    return new OtpService(config);
  }

  afterEach(() => jest.useRealTimers());

  it('generates a 4-digit code', () => {
    const code = build().generate('9876543210');
    expect(code).toMatch(/^[0-9]{4}$/);
  });

  it('verifies the code it generated, once', () => {
    const service = build();
    const code = service.generate('9876543210');

    expect(service.verify('9876543210', code)).toBe(true);
    expect(service.verify('9876543210', code)).toBe(false);
  });

  it('rejects a wrong code and keeps the right one valid', () => {
    const service = build();
    const code = service.generate('9876543210');
    const wrong = code === '1111' ? '2222' : '1111';

    expect(service.verify('9876543210', wrong)).toBe(false);
    expect(service.verify('9876543210', code)).toBe(true);
  });

  it('rejects a mobile number that never asked for a code', () => {
    expect(build().verify('9000000000', '1234')).toBe(false);
  });

  it('expires after the configured TTL', () => {
    jest.useFakeTimers();
    const service = build('60');
    const code = service.generate('9876543210');

    jest.advanceTimersByTime(61_000);

    expect(service.verify('9876543210', code)).toBe(false);
  });

  it('defaults to a 5 minute TTL when none is configured', () => {
    jest.useFakeTimers();
    const service = build(undefined);
    const code = service.generate('9876543210');

    jest.advanceTimersByTime(299_000);

    expect(service.verify('9876543210', code)).toBe(true);
  });

  it('keeps codes separate per mobile number', () => {
    const service = build();
    const a = service.generate('9111111111');
    const b = service.generate('9222222222');

    expect(service.verify('9111111111', a)).toBe(true);
    expect(service.verify('9222222222', b)).toBe(true);
  });
});
