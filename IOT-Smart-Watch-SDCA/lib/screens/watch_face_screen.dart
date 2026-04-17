import 'package:flutter/material.dart';
import '../models/watch_data.dart';

class WatchFaceScreen extends StatelessWidget {
  final WatchController controller;
  const WatchFaceScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final accent = controller.accentColor;
        final now = controller.now;
        final h = controller.health;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF020406), Color(0xFF0B0D12)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.formatTime(now),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.4,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.formatSeconds(now),
                          style: TextStyle(
                            fontSize: 16,
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!controller.is24Hour)
                          Text(
                            controller.amPm,
                            style: TextStyle(
                              fontSize: 13,
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                controller.formatDate(now),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF122118),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF28C76F).withOpacity(0.7)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync, size: 12, color: Color(0xFF28C76F)),
                    SizedBox(width: 5),
                    Text(
                      'LIVE SYNC',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF28C76F),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                height: 2,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              _infoCard(
                icon: Icons.favorite_rounded,
                iconColor: const Color(0xFFFF5252),
                borderColor: const Color(0xFFFF5252),
                value: '${h.heartRate}',
                label: 'bpm',
              ),
              const SizedBox(height: 6),
              _infoCard(
                icon: Icons.directions_walk_rounded,
                iconColor: const Color(0xFF28C76F),
                borderColor: const Color(0xFF28C76F),
                value: '${h.steps}',
                label: 'steps',
              ),
              const SizedBox(height: 6),
              _batteryCard(h.battery, accent),
              const SizedBox(height: 6),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wb_cloudy_rounded, color: accent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${controller.weatherTemp}°C ${controller.weatherCondition}',
                      style: TextStyle(fontSize: 13, color: accent),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    _StatusPill(icon: Icons.wifi_rounded, label: 'WiFi', active: false),
                    _StatusPill(icon: Icons.sensors, label: 'IMU', active: false),
                    _StatusPill(icon: Icons.usb, label: 'USB', active: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required String value,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withOpacity(0.9), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.18),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _batteryCard(int battery, Color accent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.16),
            ),
            child: Icon(Icons.battery_6_bar_rounded, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$battery%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: battery / 100,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation(Colors.green),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _StatusPill({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green : Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color),
        ),
      ],
    );
  }
}
