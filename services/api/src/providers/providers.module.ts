import { Module } from '@nestjs/common';
import { ProvidersController } from './providers.controller';
import { ProviderMeController } from './provider-me.controller';
import { ProvidersService } from './providers.service';

@Module({
  controllers: [ProvidersController, ProviderMeController],
  providers: [ProvidersService],
})
export class ProvidersModule {}
