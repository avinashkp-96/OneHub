import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { SignupCustomerDto } from './dto/signup-customer.dto';
import { SignupProviderDto } from './dto/signup-provider.dto';
import { LoginDto, RequestOtpDto, ResetPasswordDto } from './dto/login.dto';

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

  @Post('password/reset')
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto);
  }
}
