import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/watch_data.dart';
import 'screens/watch_face_screen.dart';
import 'screens/heart_rate_screen.dart';
import 'screens/steps_screen.dart';
import 'screens/sos_screen.dart';
import 'services/esp32_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SmartWatchApp());
}

class SmartWatchApp extends StatelessWidget {
  const SmartWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Watch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4FF),
          surface: Color(0xFF111118),
        ),
      ),
      home: const _WatchShell(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Watch Shell – bezel + navigation
// ─────────────────────────────────────────────────────────────────────────────

class _WatchShell extends StatefulWidget {
  const _WatchShell();

  @override
  State<_WatchShell> createState() => _WatchShellState();
}

class _WatchShellState extends State<_WatchShell> {
  late final WatchController _ctrl;
  late final Esp32Service _esp32;
  final PageController _pageCtrl = PageController();
  int _page = 0;

  static const List<({IconData icon, String label})> _screens = [
    (icon: Icons.watch_outlined, label: 'Watch'),
    (icon: Icons.favorite_rounded, label: 'Heart'),
    (icon: Icons.directions_walk_rounded, label: 'Activity'),
    (icon: Icons.warning_amber_rounded, label: 'SOS'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = WatchController();
    _esp32 = Esp32Service();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _esp32.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLarge = size.width > 500 || size.height > 800;
    final watchW = isLarge ? min(size.width * 0.56, 390.0) : size.width;
    final watchH =
        isLarge ? min(size.height * 0.78, 470.0) : size.height;

    final body = _watchBody(watchW, watchH);

    if (!isLarge) {
      return Scaffold(backgroundColor: Colors.black, body: body);
    }

    // Large screen: decorative watch frame
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Crown stub (right side — visual only)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: (size.width - watchW) / 2 - 2),
                child: Container(
                  width: 10,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E2E2E),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: const Color(0xFF404040)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Watch case
            Container(
              width: watchW + 24,
              height: watchH + 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(66),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF383838), Color(0xFF181818)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.75),
                    blurRadius: 50,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.035),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(62),
                  child: body,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Top strap nub
            Container(
              width: watchW * 0.68,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 8,
                    offset: Offset(0, 4),
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

  Widget _watchBody(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.black),
        child: Column(
          children: [
            // Page indicator
            ListenableBuilder(
              listenable: _ctrl,
              builder: (context, _) => _PageDots(
                page: _page,
                total: _screens.length,
                accent: _ctrl.accentColor,
                unreadAt: -1,
                hasUnread: false,
              ),
            ),

            // Screens
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _page = i);
                  _esp32.setScreen(i);
                },
                children: [
                  WatchFaceScreen(controller: _ctrl),
                  HeartRateScreen(controller: _ctrl),
                  StepsScreen(controller: _ctrl),
                  SOSScreen(controller: _ctrl),
                ],
              ),
            ),

            // Bottom nav
            ListenableBuilder(
              listenable: _ctrl,
              builder: (context, _) => _BottomNav(
                screens: _screens,
                page: _page,
                accent: _ctrl.accentColor,
                unread: 0,
                onTap: (i) => _pageCtrl.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page dots (top indicator)
// ─────────────────────────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  final int page;
  final int total;
  final Color accent;
  final int unreadAt;
  final bool hasUnread;

  const _PageDots(
      {required this.page,
      required this.total,
      required this.accent,
      required this.unreadAt,
      required this.hasUnread});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(total, (i) {
            final active = i == page;
            final unread = i == unreadAt && hasUnread;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? accent
                    : unread
                        ? accent.withOpacity(0.5)
                        : Colors.white12,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom navigation bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final List<({IconData icon, String label})> screens;
  final int page;
  final Color accent;
  final int unread;
  final ValueChanged<int> onTap;

  const _BottomNav(
      {required this.screens,
      required this.page,
      required this.accent,
      required this.unread,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: Color(0xFF080808),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: List.generate(screens.length, (i) {
          final active = i == page;
          final isNotif = i == 4;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: active ? accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedScale(
                          duration: const Duration(milliseconds: 200),
                          scale: active ? 1.08 : 1.0,
                          child: Icon(
                            screens[i].icon,
                            size: active ? 22 : 18,
                            color: active ? accent : Colors.white30,
                          ),
                        ),
                        if (isNotif && unread > 0)
                          Positioned(
                            right: -7,
                            top: -5,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.black, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  '$unread',
                                  style: const TextStyle(
                                      fontSize: 7,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      screens[i].label,
                      style: TextStyle(
                        fontSize: 8,
                        color: active ? accent : Colors.white24,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.normal,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
