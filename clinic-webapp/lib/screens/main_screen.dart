import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';
import '../widgets/sidebar.dart';
import 'dashboard_screen.dart';
import 'patients_screen.dart';
import 'alerts_screen.dart';
import 'reports_screen.dart';
import 'devices_screen.dart';
import 'settings_screen.dart';
import 'messages_screen.dart';
import 'admin_users_screen.dart';

/// Allowed routes per role. Roles not listed here get only Dashboard.
const Map<String, Set<String>> roleRoutes = {
  'doctor': {'/dashboard', '/patients', '/alerts', '/reports', '/devices', '/settings', '/messages'},
  'admin':  {'/dashboard', '/patients', '/alerts', '/reports', '/devices', '/settings', '/messages', '/users'},
  'nurse':  {'/dashboard', '/messages', '/settings'},
};

class MainScreen extends StatefulWidget {
  final String initialRoute;
  const MainScreen({super.key, this.initialRoute = '/dashboard'});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late String _currentRoute;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.initialRoute;
    // Reload data now that the user is authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshAll();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        context.read<AppProvider>().silentRefreshAll();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _navigateTo(String route) {
    // Role-based guard: redirect to dashboard if route not allowed
    final role = (context.read<AuthProvider>().user?.role ?? '').toLowerCase();
    final allowed = roleRoutes[role] ?? {'/dashboard'};
    if (!allowed.contains(route)) {
      route = '/dashboard';
    }
    if (route == _currentRoute) return;
    // Close drawer if open on mobile
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return PopScope(
      canPop: context.read<AuthProvider>().isLoggedIn,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: isMobile
            ? Drawer(
                child: Sidebar(
                  currentRoute: _currentRoute,
                  onNavigate: _navigateTo,
                ),
              )
            : null,
        body: _getScreenWithSidebar(),
      ),
    );
  }

  Widget _getScreenWithSidebar() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Row(
      children: [
        if (!isMobile)
          Sidebar(
            currentRoute: _currentRoute,
            onNavigate: _navigateTo,
          ),
        Expanded(
          child: _getCurrentScreen(),
        ),
      ],
    );
  }

  Widget _getCurrentScreen() {
    switch (_currentRoute) {
      case '/patients':
        return PatientsScreen(onNavigate: _navigateTo);
      case '/alerts':
        return AlertsScreen(onNavigate: _navigateTo);
      case '/reports':
        return ReportsScreen(onNavigate: _navigateTo);
      case '/devices':
        return DevicesScreen(onNavigate: _navigateTo);
      case '/settings':
        return SettingsScreen(onNavigate: _navigateTo);
      case '/messages':
        return MessagesScreen(onNavigate: _navigateTo);
      case '/users':
        return AdminUsersScreen(onNavigate: _navigateTo);
      case '/dashboard':
      default:
        return DashboardScreen(onNavigate: _navigateTo);
    }
  }
}
