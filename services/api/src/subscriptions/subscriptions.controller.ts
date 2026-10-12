import { Body, Controller, ForbiddenException, Get, Param, Put, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { JwtPayload } from '../auth/jwt.strategy';
import { PrismaService } from '../prisma/prisma.service';
import { SubscriptionsService } from './subscriptions.service';

type Plan = 'PER_SERVICE' | 'MONTHLY_99' | 'MONTHLY_299';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('PROVIDER')
@Controller('providers/:providerId/subscription')
export class SubscriptionsController {
  constructor(
    private readonly subscriptions: SubscriptionsService,
    private readonly prisma: PrismaService,
  ) {}

  @Get()
  async current(@Req() req: { user: JwtPayload }, @Param('providerId') providerId: string) {
    await this.assertOwn(req.user.sub, providerId);
    return this.subscriptions.current(providerId);
  }

  @Put()
  async setPlan(
    @Req() req: { user: JwtPayload },
    @Param('providerId') providerId: string,
    @Body('plan') plan: Plan,
  ) {
    await this.assertOwn(req.user.sub, providerId);
    return this.subscriptions.setPlan(providerId, plan);
  }

  // A provider may only read and change their own subscription.
  private async assertOwn(userId: string, providerId: string) {
    const provider = await this.prisma.provider.findUniqueOrThrow({ where: { userId } });
    if (provider.id !== providerId) throw new ForbiddenException('this is not your subscription');
  }
}
