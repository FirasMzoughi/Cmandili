import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../notifications/data/models/notification.dart';
import '../../notifications/providers/notification_provider.dart';
import 'package:cmandili_partner/l10n/app_localizations.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final notifications = ref.watch(notificationProvider);

    // Group notifications by date
    final groupedNotifications = _groupNotificationsByDate(notifications);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.notifications,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: screenWidth * 0.05,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () {
                ref.read(notificationProvider.notifier).markAllAsRead();
              },
              child: Text(
                AppLocalizations.of(context)!.markAllRead,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _EmptyNotifications(screenWidth: screenWidth, screenHeight: screenHeight)
          : ListView.builder(
              padding: EdgeInsets.all(screenWidth * 0.05),
              itemCount: groupedNotifications.length,
              itemBuilder: (context, index) {
                final entry = groupedNotifications.entries.elementAt(index);
                final dateLabel = entry.key;
                final notificationList = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.015,
                        horizontal: screenWidth * 0.02,
                      ),
                      child: Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    ...notificationList.map((notification) {
                      return _NotificationCard(
                        notification: notification,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        onTap: () {
                          if (!notification.isRead) {
                            ref
                                .read(notificationProvider.notifier)
                                .markAsRead(notification.id);
                          }
                        },
                        onDismissed: () {
                          ref
                              .read(notificationProvider.notifier)
                              .deleteNotification(notification.id);
                        },
                      );
                    }).toList(),
                  ],
                );
              },
            ),
    );
  }

  Map<String, List<AppNotification>> _groupNotificationsByDate(
      List<AppNotification> notifications) {
    final Map<String, List<AppNotification>> grouped = {};
    final now = DateTime.now();

    for (final notification in notifications) {
      String dateLabel;
      final difference = now.difference(notification.timestamp);

      if (difference.inDays == 0) {
        dateLabel = 'Today';
      } else if (difference.inDays == 1) {
        dateLabel = 'Yesterday';
      } else if (difference.inDays < 7) {
        dateLabel = DateFormat('EEEE').format(notification.timestamp);
      } else {
        dateLabel = DateFormat('MMM dd, yyyy').format(notification.timestamp);
      }

      if (!grouped.containsKey(dateLabel)) {
        grouped[dateLabel] = [];
      }
      grouped[dateLabel]!.add(notification);
    }

    return grouped;
  }
}

class _EmptyNotifications extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const _EmptyNotifications({
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.08),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_outlined,
              size: screenWidth * 0.2,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          SizedBox(height: screenHeight * 0.03),
          Text(
            AppLocalizations.of(context)!.noNotifications,
            style: TextStyle(
              fontSize: screenWidth * 0.06,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            AppLocalizations.of(context)!.notificationsWillAppearHere,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: screenWidth * 0.04,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final double screenWidth;
  final double screenHeight;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color iconColor;

    switch (notification.type) {
      case NotificationType.orderUpdate:
        icon = Icons.shopping_bag_outlined;
        iconColor = AppColors.primary;
        break;
      case NotificationType.promotion:
        icon = Icons.local_offer_outlined;
        iconColor = AppColors.success;
        break;
      case NotificationType.system:
        icon = Icons.info_outline;
        iconColor = AppColors.warning;
        break;
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: screenWidth * 0.05),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
        ),
        child: Icon(
          Icons.delete_outline,
          color: AppColors.error,
          size: screenWidth * 0.08,
        ),
      ),
      onDismissed: (direction) => onDismissed(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.only(bottom: screenHeight * 0.015),
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Theme.of(context).cardColor
                : AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(screenWidth * 0.05),
            border: Border.all(
              color: notification.isRead
                  ? Colors.transparent
                  : AppColors.primary.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: screenWidth * 0.025,
                offset: Offset(0, screenHeight * 0.006),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.03),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: screenWidth * 0.06,
                ),
              ),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: screenWidth * 0.025,
                            height: screenWidth * 0.025,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: screenWidth * 0.036,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Text(
                      _formatTime(notification.timestamp),
                      style: TextStyle(
                        fontSize: screenWidth * 0.032,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('HH:mm').format(timestamp);
    }
  }
}
