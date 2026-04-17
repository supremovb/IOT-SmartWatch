import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';

class Sidebar extends StatefulWidget {
  final Function(String route)? onNavigate;
  final String currentRoute;

  const Sidebar({
    super.key,
    this.onNavigate,
    this.currentRoute = '/dashboard',
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _isCollapsed = html.window.localStorage['sidebar_collapsed'] == 'true';
  }

  void _toggleCollapse() {
    setState(() => _isCollapsed = !_isCollapsed);
    html.window.localStorage['sidebar_collapsed'] = _isCollapsed.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    // Inside a Drawer, use full width and never collapse
    final isDrawer = isMobile;
    final collapsed = isDrawer ? false : _isCollapsed;

    return Container(
      width: isDrawer ? null : (collapsed ? 80 : 260),
      color: AppColors.primary,
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(collapsed ? 8 : 16),
            child: Row(
              children: [
                if (!collapsed)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.health_and_safety,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                if (!collapsed) const SizedBox(width: 12),
                if (!collapsed)
                  const Expanded(
                    child: Text(
                      'Dominican Smart Watch',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (!isDrawer)
                  IconButton(
                    icon: Icon(
                      collapsed ? Icons.menu_open : Icons.menu,
                      color: Colors.white,
                    ),
                    onPressed: _toggleCollapse,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Divider(
              color: Colors.white24,
              thickness: 1,
            ),
          ),
          const SizedBox(height: 8),

          // Navigation items
          Expanded(
            child: Builder(
              builder: (context) {
                final role = context.watch<AuthProvider>().user?.role?.toLowerCase() ?? '';
                final items = _navItemsForRole(role, collapsed, context);
                return ListView(
                  padding: EdgeInsets.zero,
                  children: items,
                );
              },
            ),
          ),

          // Logout button
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildLogoutButton(collapsed: collapsed),
          ),
        ],
      ),
    );
  }

  List<Widget> _navItemsForRole(String role, bool collapsed, BuildContext context) {
    final allowed = <String>{};
    switch (role) {
      case 'doctor':
        allowed.addAll({'/dashboard', '/patients', '/alerts', '/reports', '/devices', '/settings', '/messages'});
        break;
      case 'admin':
        allowed.addAll({'/dashboard', '/patients', '/alerts', '/reports', '/devices', '/settings', '/messages', '/users'});
        break;
      case 'nurse':
        allowed.addAll({'/dashboard', '/messages', '/settings'});
        break;
      default:
        allowed.add('/dashboard');
    }

    final allItems = <Map<String, dynamic>>[
      {'icon': Icons.dashboard, 'label': 'Dashboard', 'route': '/dashboard', 'badge': null},
      {'icon': Icons.people, 'label': 'Patients', 'route': '/patients', 'badge': null},
      {'icon': Icons.notifications_active, 'label': 'Alerts', 'route': '/alerts', 'badge': context.watch<AppProvider>().unreadAlerts},
      {'icon': Icons.assessment, 'label': 'Reports', 'route': '/reports', 'badge': null},
      {'icon': Icons.watch, 'label': 'Devices', 'route': '/devices', 'badge': null},
      {'icon': Icons.settings, 'label': 'Settings', 'route': '/settings', 'badge': null},
      {'icon': Icons.mail_outlined, 'label': 'Messages', 'route': '/messages', 'badge': context.watch<AppProvider>().unreadMessages},
      {'icon': Icons.admin_panel_settings, 'label': 'User Management', 'route': '/users', 'badge': null},
    ];

    return allItems
        .where((item) => allowed.contains(item['route']))
        .map((item) => _buildNavItem(
              icon: item['icon'] as IconData,
              label: item['label'] as String,
              route: item['route'] as String,
              badgeCount: item['badge'] as int?,
              collapsed: collapsed,
            ))
        .toList();
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String route,
    int? badgeCount,
    bool collapsed = false,
  }) {
    final isActive = widget.currentRoute == route;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onNavigate?.call(route);
        },
        hoverColor: Colors.white12,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: collapsed ? 4 : 8,
            vertical: 4,
          ),
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12, vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive 
                ? LinearGradient(colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.0)], begin: Alignment.centerLeft, end: Alignment.centerRight)
                : null,
            borderRadius: BorderRadius.circular(8),
            border: isActive ? const Border(left: BorderSide(color: Colors.white, width: 3)) : null,
          ),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeCount != null && badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton({bool collapsed = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.read<AuthProvider>().logout();
          Navigator.of(context).pushReplacementNamed('/login');
        },
        hoverColor: Colors.white12,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: collapsed ? 4 : 8,
            vertical: 4,
          ),
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              const Icon(
                Icons.logout,
                color: Colors.white,
                size: 20,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
