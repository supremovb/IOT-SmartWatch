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
        final patientLabel = controller.patientLinked
            ? controller.patientName
            : 'No patient linked';

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF020406), Color(0xFF0B0D12)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _topBadge('LIVE', const Color(0xFF28C76F), Icons.sync),
                  _batteryBadge(h.battery, accent),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.formatTime(now),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.formatSeconds(now),
                          style: TextStyle(
                            fontSize: 14,
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!controller.is24Hour)
                          Text(
                            controller.amPm,
                            style: TextStyle(
                              fontSize: 12,
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
                  fontSize: 11,
                  color: Colors.grey[500],
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                patientLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: controller.patientLinked ? accent : Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              _infoCard(
                icon: Icons.favorite_rounded,
                iconColor: const Color(0xFFFF5252),
                title: 'Heart',
                value: '${h.heartRate} bpm',
              ),
              const SizedBox(height: 6),
              _infoCard(
                icon: Icons.opacity_rounded,
                iconColor: const Color(0xFF4DA3FF),
                title: 'SpO2',
                value: '${h.bloodOxygen.toStringAsFixed(0)}%',
              ),
              const SizedBox(height: 6),
              _infoCard(
                icon: Icons.device_thermostat_rounded,
                iconColor: const Color(0xFFFFA24D),
                title: 'Temp',
                value: '${h.temperatureF.toStringAsFixed(1)} F',
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Text(
                      controller.patientCondition,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.deviceId,
                      style: TextStyle(
                        fontSize: 11,
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _topBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _batteryBadge(int battery, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF141923),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.battery_6_bar_rounded, color: accent, size: 14),
          const SizedBox(width: 4),
          Text(
            '$battery%',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.85), width: 1),
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
                title,
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
