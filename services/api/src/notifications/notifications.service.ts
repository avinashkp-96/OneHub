import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

// docx section 6, Notification Matrix. Each row there maps directly to a call
// to `notify` below, e.g.:
//   notify(providerId, 'NEW_REQUEST_MATCH', 'New job request near you: ...', 'PUSH')
// Actual push/SMS delivery is a follow-up integration; this only persists the
// in-app record for now.
@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  notify(userId: string, event: string, message: string, channel: 'PUSH' | 'IN_APP' | 'SMS') {
    return this.prisma.notification.create({ data: { userId, event, message, channel } });
  }

  listForUser(userId: string) {
    return this.prisma.notification.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } });
  }

  markRead(id: string) {
    return this.prisma.notification.update({ where: { id }, data: { readAt: new Date() } });
  }
}
