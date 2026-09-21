import { Controller, Get, Query } from '@nestjs/common';
import { ProvidersService } from './providers.service';

@Controller('providers')
export class ProvidersController {
  constructor(private readonly providers: ProvidersService) {}

  @Get()
  search(@Query('subServiceId') subServiceId: string) {
    return this.providers.findForSubService(subServiceId);
  }
}
