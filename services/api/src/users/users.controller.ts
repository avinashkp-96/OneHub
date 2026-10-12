import { Body, Controller, Get, Patch, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { JwtPayload } from '../auth/jwt.strategy';
import { UsersService } from './users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@UseGuards(JwtAuthGuard)
@Controller('users/me')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  me(@Req() req: { user: JwtPayload }) {
    return this.users.profile(req.user.sub);
  }

  @Patch()
  update(@Req() req: { user: JwtPayload }, @Body() body: UpdateProfileDto) {
    return this.users.updateProfile(req.user.sub, body);
  }
}
