import { Body, Controller, Get, Param, Put, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { SubscriptionsService } from './subscriptions.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('PROVIDER')
@Controller('providers/:providerId/subscription')
export class SubscriptionsController {
  constructor(private readonly subscriptions: SubscriptionsService) {}

  @Get()
  current(@Param('providerId') providerId: string) {
    return this.subscriptions.current(providerId);
  }

  @Put()
  setPlan(@Param('providerId') providerId: string, @Body('plan') plan: 'PER_SERVICE' | 'MONTHLY_99' | 'MONTHLY_299') {
    return this.subscriptions.setPlan(providerId, plan);
  }
}
