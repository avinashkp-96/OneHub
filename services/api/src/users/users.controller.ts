import { Body, Controller, Get, Patch, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { JwtPayload } from '../auth/jwt.strategy';
import { UsersService } from './users.service';

@UseGuards(JwtAuthGuard)
@Controller('users/me')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  me(@Req() req: { user: JwtPayload }) {
    return this.users.profile(req.user.sub);
  }

  @Patch()
  update(@Req() req: { user: JwtPayload }, @Body() body: { fullName?: string; email?: string; profilePhotoUrl?: string }) {
    return this.users.updateProfile(req.user.sub, body);
  }
}
