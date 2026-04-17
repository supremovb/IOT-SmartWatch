import 'package:flutter/material.dart';
import '../models/watch_data.dart';

class NotificationsScreen extends StatelessWidget {
  final WatchController controller;
  final VoidCallback onSwipeRight;
  const NotificationsScreen({super.key, required this.controller, required this.onSwipeRight});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final accent = controller.accentColor;
        final notifs = controller.notifications;
        final unread = controller.unreadCount;

        return GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 500) {
              onSwipeRight();
            }
          },
          child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.4,
              colors: [accent.withOpacity(0.07), Colors.black],
            ),
          ),
          child: Column(
            children: [
              // ── Header ──────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NOTIFICATIONS',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (unread > 0)
                          Text(
                            '$unread unread',
                            style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (unread > 0)
                      GestureDetector(
                        onTap: controller.markAllRead,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color: accent.withOpacity(0.3)),
                          ),
                          child: Text('Mark all read',
                              style: TextStyle(
                                  color: accent, fontSize: 10)),
                        ),
                      ),
                  ],
                ),
              ),

              // ── List ────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: notifs.length,
                  itemBuilder: (context, i) =>
                      _NotifCard(notif: notifs[i], accent: accent),
                ),
              ),
            ],
          ),          ),        );
      },
    );
  }
}

// ── Notification card ─────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final NotificationItem notif;
  final Color accent;
  const _NotifCard({required this.notif, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: notif.isRead
            ? Colors.white.withOpacity(0.04)
            : accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notif.isRead ? Colors.white10 : accent.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Icon bubble
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(notif.icon,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 10),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      notif.app.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _ago(notif.timestamp),
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 10),
                    ),
                    if (!notif.isRead) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: accent),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  notif.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  notif.message,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
