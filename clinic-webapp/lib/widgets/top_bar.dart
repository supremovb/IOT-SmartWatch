import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';

class TopBar extends StatefulWidget {
  final VoidCallback onProfileTap;
  final void Function(String route)? onNavigate;

  const TopBar({
    super.key,
    required this.onProfileTap,
    this.onNavigate,
  });

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNotificationsPanel(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    final allAlerts = appProvider.alerts.toList();
    final hasUnread = allAlerts.any((a) => a.status == 'new');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Notifications'),
            if (hasUnread)
              TextButton(
                onPressed: () {
                  appProvider.markAllAlertsRead();
                  Navigator.pop(context);
                },
                child: const Text('Mark all read'),
              ),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 300,
          child: allAlerts.isEmpty
              ? Center(
                  child: Text(
                    'No notifications',
                    style: TextStyle(color: AppColors.themed(context).textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: allAlerts.length,
                  itemBuilder: (context, index) {
                    final alert = allAlerts[index];
                    final isRead = alert.status != 'new';
                    return Opacity(
                      opacity: isRead ? 0.6 : 1.0,
                      child: ListTile(
                        leading: Icon(
                          (alert.severity == 'critical' || alert.severity == 'sos')
                              ? Icons.warning
                              : Icons.info,
                          color: (alert.severity == 'critical' || alert.severity == 'sos')
                              ? AppColors.danger
                              : AppColors.warning,
                        ),
                        title: Text(
                          alert.title,
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text('${alert.patient} • ${alert.timestamp}'),
                        trailing: isRead
                            ? Icon(Icons.check_circle, size: 16, color: Colors.grey.shade400)
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final appProvider = context.watch<AppProvider>();
    final isMobile = MediaQuery.of(context).size.width < 768;
    final unreadNotifications = appProvider.unreadAlerts;
    final t = AppColors.themed(context);

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: t.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            // Hamburger menu for mobile
            if (isMobile)
              IconButton(
                icon: Icon(Icons.menu, color: t.textSecondary),
                onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
              ),
            // Quick search
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: t.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: t.divider,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    appProvider.setGlobalSearch(value);
                  },
                  onSubmitted: (value) {
                    appProvider.setGlobalSearch(value);
                    if (value.isNotEmpty && widget.onNavigate != null) {
                      widget.onNavigate!('/patients');
                    }
                  },
                  decoration: InputDecoration(
                    hintText: isMobile
                        ? 'Search...'
                        : 'Search patients, alerts...',
                    hintStyle: TextStyle(
                      color: t.textHint,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: t.textSecondary,
                      size: 20,
                    ),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return IconButton(
                          icon: Icon(Icons.close, size: 16, color: t.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            appProvider.setGlobalSearch('');
                          },
                        );
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 24),

            // Notifications bell
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: t.textSecondary,
                    size: 24,
                  ),
                  onPressed: () => _showNotificationsPanel(context),
                ),
                if (unreadNotifications > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Center(
                        child: Text(
                          unreadNotifications > 99 ? '99+' : unreadNotifications.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),

            // Messages
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.mail_outlined,
                    color: t.textSecondary,
                    size: 24,
                  ),
                  onPressed: () {
                    widget.onNavigate?.call('/messages');
                  },
                ),
                if (appProvider.unreadMessages > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          appProvider.unreadMessages > 99
                              ? '99+'
                              : appProvider.unreadMessages.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 24),

            // User profile
            if (!isMobile)
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  return GestureDetector(
                    onTap: widget.onProfileTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                user?.name ?? 'User',
                                style: TextStyle(
                                  color: t.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                [
                                  if (user?.role.isNotEmpty == true) '${user!.role[0].toUpperCase()}${user.role.substring(1)}',
                                  if (user?.department.isNotEmpty == true) user!.department,
                                  if (user?.specialization.isNotEmpty == true) user!.specialization,
                                ].join(' · '),
                                style: TextStyle(
                                  color: t.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          _buildUserAvatar(user?.photoUrl, user?.name ?? 'U', 40),
                        ],
                      ),
                    ),
                  );
                },
              )
            else
              _buildUserAvatar(user?.photoUrl, user?.name ?? 'U', 40),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String? photoUrl, String name, double size) {
    final initials = name
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join()
        .toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl != null && photoUrl.isNotEmpty
          ? Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.35,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.35,
                ),
              ),
            ),
    );
  }
}
