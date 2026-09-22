import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { JwtPayload } from '../auth/jwt.strategy';
import { RatingsService } from './ratings.service';
import { SubmitRatingDto } from './dto/submit-rating.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('ratings')
export class RatingsController {
  constructor(private readonly ratings: RatingsService) {}

  @Roles('CUSTOMER')
  @Post()
  submit(@Req() req: { user: JwtPayload }, @Body() dto: SubmitRatingDto) {
    return this.ratings.submitRating(req.user.sub, dto);
  }

  @Get('provider/:providerId')
  overview(@Param('providerId') providerId: string) {
    return this.ratings.overview(providerId);
  }

  @Get('requirement/:requirementId')
  forRequirement(@Param('requirementId') requirementId: string) {
    return this.ratings.forRequirement(requirementId);
  }
}
