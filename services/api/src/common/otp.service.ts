import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface OtpEntry {
  code: string;
  expiresAt: number;
}

// In-memory OTP store — replace with Redis before this leaves the MVP stage.
// See docx section 2.5 (Forgot/Reset Password) and 2.1/2.3 (mobile verification).
@Injectable()
export class OtpService {
  private readonly store = new Map<string, OtpEntry>();

  constructor(private readonly config: ConfigService) {}

  generate(mobile: string): string {
    const code = Math.floor(1000 + Math.random() * 9000).toString();
    const ttlSeconds = Number(this.config.get('OTP_TTL_SECONDS') ?? 300);
    this.store.set(mobile, { code, expiresAt: Date.now() + ttlSeconds * 1000 });
    // TODO: send via SMS provider instead of returning it to the caller.
    return code;
  }

  verify(mobile: string, code: string): boolean {
    const entry = this.store.get(mobile);
    if (!entry || entry.expiresAt < Date.now()) return false;
    const ok = entry.code === code;
    if (ok) this.store.delete(mobile);
    return ok;
  }
}
