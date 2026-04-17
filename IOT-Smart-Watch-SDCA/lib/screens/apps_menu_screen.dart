import 'package:flutter/material.dart';

class AppsMenuScreen extends StatefulWidget {
  final Function(int) onAppSelected;

  const AppsMenuScreen({
    super.key,
    required this.onAppSelected,
  });

  @override
  State<AppsMenuScreen> createState() => _AppsMenuScreenState();
}

class _AppsMenuScreenState extends State<AppsMenuScreen> {
  final List<Map<String, dynamic>> apps = [
    {
      'icon': Icons.favorite,
      'label': 'Heart Rate',
      'color': const Color.fromARGB(255, 239, 68, 68),
      'page': 2,
    },
    {
      'icon': Icons.directions_walk,
      'label': 'Steps',
      'color': const Color.fromARGB(255, 34, 197, 94),
      'page': 3,
    },
    {
      'icon': Icons.schedule,
      'label': 'Timer',
      'color': const Color(0xFF00D4FF),
      'page': 4,
    },
    {
      'icon': Icons.notifications_active,
      'label': 'Alerts',
      'color': const Color.fromARGB(255, 251, 146, 60),
      'page': 5,
    },
    {
      'icon': Icons.settings,
      'label': 'Settings',
      'color': const Color.fromARGB(255, 168, 85, 247),
      'page': 6,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            const Color(0xFF1a1a2e),
            const Color(0xFF0f0f1e),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Title
          Positioned(
            top: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Apps',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          // Apps Grid
          Center(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 30),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 40,
                crossAxisSpacing: 40,
                childAspectRatio: 1,
              ),
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                return _buildAppButton(
                  icon: app['icon'],
                  label: app['label'],
                  color: app['color'],
                  onTap: () {
                    widget.onAppSelected(app['page']);
                  },
                );
              },
            ),
          ),

          // Hint
          Positioned(
            bottom: 15,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Tap app or swipe to open',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ScaleTransition(
        scale: AlwaysStoppedAnimation(1.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Icon(
                    icon,
                    color: color,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
