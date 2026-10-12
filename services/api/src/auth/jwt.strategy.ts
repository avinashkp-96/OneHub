import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

export interface JwtPayload {
  sub: string;
  role: 'CUSTOMER' | 'PROVIDER' | 'ADMIN';
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService) {
    const secret = config.get<string>('JWT_SECRET');
    // Refuse to start with a guessable secret: anyone who knows the
    // placeholder could mint a valid admin token.
    if (!secret) {
      throw new Error('JWT_SECRET is not set');
    }
    if (secret === 'change-me' && config.get<string>('NODE_ENV') === 'production') {
      throw new Error('JWT_SECRET must not be the placeholder value in production');
    }
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: secret,
    });
  }

  async validate(payload: JwtPayload) {
    return payload;
  }
}
