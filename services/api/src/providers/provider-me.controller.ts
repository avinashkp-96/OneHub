import { Body, Controller, Get, Patch, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { JwtPayload } from '../auth/jwt.strategy';
import { ProvidersService } from './providers.service';
import { UpdateBusinessDto } from './dto/update-business.dto';

// docx 5.2: the signed-in provider's own business details. There is no id in
// the path; the provider is always the one on the token.
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('PROVIDER')
@Controller('providers/me')
export class ProviderMeController {
  constructor(private readonly providers: ProvidersService) {}

  @Get()
  mine(@Req() req: { user: JwtPayload }) {
    return this.providers.getMine(req.user.sub);
  }

  @Patch()
  update(@Req() req: { user: JwtPayload }, @Body() body: UpdateBusinessDto) {
    return this.providers.updateMine(req.user.sub, body);
  }
}
