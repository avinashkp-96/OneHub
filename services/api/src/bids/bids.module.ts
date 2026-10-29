import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { BidsController } from './bids.controller';
import { BidsService } from './bids.service';

@Module({
  imports: [NotificationsModule],
  controllers: [BidsController],
  providers: [BidsService],
})
export class BidsModule {}
