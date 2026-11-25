import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { SignupCustomerDto } from './dto/signup-customer.dto';
import { SignupProviderDto } from './dto/signup-provider.dto';
import { LoginDto, RefreshTokenDto, RequestOtpDto, ResetPasswordDto } from './dto/login.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('otp/request')
  requestOtp(@Body() dto: RequestOtpDto) {
    return this.auth.requestOtp(dto.mobile);
  }

  @Post('customer/signup')
  signupCustomer(@Body() dto: SignupCustomerDto) {
    return this.auth.signupCustomer(dto);
  }

  @Post('customer/login')
  loginCustomer(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  @Post('provider/signup')
  signupProvider(@Body() dto: SignupProviderDto) {
    return this.auth.signupProvider(dto);
  }

  @Post('provider/login')
  loginProvider(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  // Swaps a refresh token for a new access and refresh token pair. Public:
  // the caller's access token has usually just expired.
  @Post('refresh')
  refresh(@Body() dto: RefreshTokenDto) {
    return this.auth.refresh(dto.refreshToken);
  }

  @Post('logout')
  logout(@Body() dto: RefreshTokenDto) {
    return this.auth.logout(dto.refreshToken);
  }

  @Post('password/reset')
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto);
  }
}
