import { Body, Controller, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { JwtPayload } from '../auth/jwt.strategy';
import { PrismaService } from '../prisma/prisma.service';
import { BidsService } from './bids.service';
import { PriceRangeDto } from './dto/submit-bid.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller()
export class BidsController {
  constructor(
    private readonly bids: BidsService,
    private readonly prisma: PrismaService,
  ) {}

  @Roles('PROVIDER')
  @Post('requirements/:requirementId/bids')
  async submit(
    @Req() req: { user: JwtPayload },
    @Param('requirementId') requirementId: string,
    @Body() range: PriceRangeDto,
  ) {
    const providerId = await this.providerIdFor(req.user.sub);
    return this.bids.submitInitialBid(requirementId, providerId, range);
  }

  private async providerIdFor(userId: string): Promise<string> {
    const provider = await this.prisma.provider.findUniqueOrThrow({ where: { userId } });
    return provider.id;
  }

  @Roles('CUSTOMER', 'PROVIDER')
  @Get('requirements/:requirementId/bids')
  list(@Param('requirementId') requirementId: string) {
    return this.bids.listForRequirement(requirementId);
  }

  @Roles('PROVIDER')
  @Post('bids/:id/unlock-contact')
  unlock(@Param('id') id: string) {
    return this.bids.unlockContact(id);
  }

  @Roles('PROVIDER')
  @Patch('bids/:id/refine')
  refine(@Param('id') id: string, @Body() range: PriceRangeDto) {
    return this.bids.updateRefinedBid(id, range);
  }

  @Roles('CUSTOMER')
  @Patch('bids/:id/confirm')
  confirm(@Param('id') id: string) {
    return this.bids.confirmBid(id);
  }
}
