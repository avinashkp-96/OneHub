import { Body, Controller, Delete, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { JwtPayload } from '../auth/jwt.strategy';
import { AddressesService } from './addresses.service';
import { AddressDto } from './dto/address.dto';

@UseGuards(JwtAuthGuard)
@Controller('users/me/addresses')
export class AddressesController {
  constructor(private readonly addresses: AddressesService) {}

  @Get()
  list(@Req() req: { user: JwtPayload }) {
    return this.addresses.list(req.user.sub);
  }

  @Post()
  create(@Req() req: { user: JwtPayload }, @Body() body: AddressDto) {
    return this.addresses.create(req.user.sub, body);
  }

  @Delete(':id')
  remove(@Req() req: { user: JwtPayload }, @Param('id') id: string) {
    return this.addresses.remove(req.user.sub, id);
  }
}
