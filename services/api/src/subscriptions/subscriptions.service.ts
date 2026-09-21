import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

// docx 5.5
const PLAN_LIMITS: Record<'PER_SERVICE' | 'MONTHLY_99' | 'MONTHLY_299', number> = {
  PER_SERVICE: 0,
  MONTHLY_99: 5,
  MONTHLY_299: 10,
};

@Injectable()
export class SubscriptionsService {
  constructor(private readonly prisma: PrismaService) {}

  current(providerId: string) {
    return this.prisma.subscription.findUnique({ where: { providerId } });
  }

  // docx 5.5 "Plan Management Screen" — upgrade/downgrade
  setPlan(providerId: string, plan: 'PER_SERVICE' | 'MONTHLY_99' | 'MONTHLY_299') {
    const cycleLimit = PLAN_LIMITS[plan];
    return this.prisma.subscription.upsert({
      where: { providerId },
      create: { providerId, plan, cycleLimit, cycleUsed: 0 },
      update: { plan, cycleLimit, cycleUsed: 0 },
    });
  }
}
