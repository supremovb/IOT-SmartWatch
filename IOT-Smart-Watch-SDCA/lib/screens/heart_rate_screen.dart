import 'package:flutter/material.dart';
import '../models/watch_data.dart';

class HeartRateScreen extends StatelessWidget {
  final WatchController controller;
  const HeartRateScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final h = controller.health;
        final zone = _getZone(h.heartRate);
        final zoneColor = _getZoneColor(h.heartRate);

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF090909), Color(0xFF12090B)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.favorite_rounded, color: Colors.red, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Heart Rate',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.12),
                  border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.red, size: 46),
              ),
              const SizedBox(height: 16),
              Text(
                '${h.heartRate}',
                style: const TextStyle(
                  fontSize: 62,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                'BPM',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: zoneColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: zoneColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monitor_heart_rounded, color: zoneColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      zone,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: zoneColor,
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

  String _getZone(int bpm) {
    if (bpm < 60) return 'Resting';
    if (bpm < 100) return 'Normal';
    if (bpm < 140) return 'Elevated';
    return 'High';
  }

  Color _getZoneColor(int bpm) {
    if (bpm < 60) return Colors.blue;
    if (bpm < 100) return Colors.green;
    if (bpm < 140) return Colors.orange;
    return Colors.red;
  }
}
