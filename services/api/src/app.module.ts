import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { CategoriesModule } from './categories/categories.module';
import { RequirementsModule } from './requirements/requirements.module';
import { BidsModule } from './bids/bids.module';
import { SubscriptionsModule } from './subscriptions/subscriptions.module';
import { RatingsModule } from './ratings/ratings.module';
import { NotificationsModule } from './notifications/notifications.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    UsersModule,
    CategoriesModule,
    RequirementsModule,
    BidsModule,
    SubscriptionsModule,
    RatingsModule,
    NotificationsModule,
  ],
})
export class AppModule {}
