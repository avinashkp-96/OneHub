import { Body, Controller, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { JwtPayload } from '../auth/jwt.strategy';
import { PrismaService } from '../prisma/prisma.service';
import { RequirementsService } from './requirements.service';
import { PostRequirementDto } from './dto/post-requirement.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('requirements')
export class RequirementsController {
  constructor(
    private readonly requirements: RequirementsService,
    private readonly prisma: PrismaService,
  ) {}

  @Roles('CUSTOMER')
  @Post()
  post(@Req() req: { user: JwtPayload }, @Body() dto: PostRequirementDto) {
    return this.requirements.postRequirement(req.user.sub, dto);
  }

  @Roles('CUSTOMER')
  @Get('mine')
  mine(@Req() req: { user: JwtPayload }) {
    return this.requirements.listForCustomer(req.user.sub);
  }

  @Roles('PROVIDER')
  @Get('incoming')
  async incoming(@Req() req: { user: JwtPayload }) {
    const providerId = await this.providerIdFor(req.user.sub);
    return this.requirements.listForProvider(providerId);
  }

  @Roles('PROVIDER')
  @Patch(':id/accept')
  async accept(@Req() req: { user: JwtPayload }, @Param('id') id: string) {
    const providerId = await this.providerIdFor(req.user.sub);
    return this.requirements.respond(id, providerId, true);
  }

  @Roles('PROVIDER')
  @Patch(':id/reject')
  async reject(@Req() req: { user: JwtPayload }, @Param('id') id: string) {
    const providerId = await this.providerIdFor(req.user.sub);
    return this.requirements.respond(id, providerId, false);
  }

  @Roles('PROVIDER')
  @Patch(':id/complete')
  complete(@Param('id') id: string) {
    return this.requirements.markCompleted(id);
  }

  private async providerIdFor(userId: string): Promise<string> {
    const provider = await this.prisma.provider.findUniqueOrThrow({ where: { userId } });
    return provider.id;
  }
}
