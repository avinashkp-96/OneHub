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

  @Roles('CUSTOMER', 'PROVIDER')
  @Get('requirements/:requirementId/bids')
  async list(@Req() req: { user: JwtPayload }, @Param('requirementId') requirementId: string) {
    const providerId = req.user.role === 'PROVIDER' ? await this.providerIdFor(req.user.sub) : undefined;
    return this.bids.listForRequirement(requirementId, {
      userId: req.user.sub,
      role: req.user.role,
      providerId,
    });
  }

  @Roles('PROVIDER')
  @Post('bids/:id/unlock-contact')
  async unlock(@Req() req: { user: JwtPayload }, @Param('id') id: string) {
    const providerId = await this.providerIdFor(req.user.sub);
    return this.bids.unlockContact(id, providerId);
  }

  @Roles('PROVIDER')
  @Patch('bids/:id/refine')
  async refine(@Req() req: { user: JwtPayload }, @Param('id') id: string, @Body() range: PriceRangeDto) {
    const providerId = await this.providerIdFor(req.user.sub);
    return this.bids.updateRefinedBid(id, providerId, range);
  }

  @Roles('CUSTOMER')
  @Patch('bids/:id/confirm')
  confirm(@Req() req: { user: JwtPayload }, @Param('id') id: string) {
    return this.bids.confirmBid(id, req.user.sub);
  }

  private async providerIdFor(userId: string): Promise<string> {
    const provider = await this.prisma.provider.findUniqueOrThrow({ where: { userId } });
    return provider.id;
  }
}
