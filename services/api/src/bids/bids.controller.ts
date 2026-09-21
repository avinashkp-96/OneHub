import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { BidsService } from './bids.service';
import { PriceRangeDto } from './dto/submit-bid.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller()
export class BidsController {
  constructor(private readonly bids: BidsService) {}

  @Roles('PROVIDER')
  @Post('requirements/:requirementId/bids')
  submit(@Param('requirementId') requirementId: string, @Body() body: { providerId: string } & PriceRangeDto) {
    return this.bids.submitInitialBid(requirementId, body.providerId, body);
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
