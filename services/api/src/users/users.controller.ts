import { Body, Controller, Get, Patch, Put, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { JwtPayload } from '../auth/jwt.strategy';
import { UsersService } from './users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UpdateSettingsDto } from './dto/update-settings.dto';
import { UpdateLocationDto } from './dto/update-location.dto';

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

  @Put('location')
  updateLocation(@Req() req: { user: JwtPayload }, @Body() body: UpdateLocationDto) {
    return this.users.updateLocation(req.user.sub, body);
  }

  @Get('settings')
  settings(@Req() req: { user: JwtPayload }) {
    return this.users.settings(req.user.sub);
  }

  @Patch('settings')
  updateSettings(@Req() req: { user: JwtPayload }, @Body() body: UpdateSettingsDto) {
    return this.users.updateSettings(req.user.sub, body);
  }
}
