import { Injectable, NotFoundException } from '@nestjs/common';
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

  // Scoped to the owner: someone else's notification id behaves as not found.
  async markRead(id: string, userId: string) {
    const result = await this.prisma.notification.updateMany({
      where: { id, userId },
      data: { readAt: new Date() },
    });
    if (result.count === 0) throw new NotFoundException('notification not found');
    return { id, read: true };
  }
}
