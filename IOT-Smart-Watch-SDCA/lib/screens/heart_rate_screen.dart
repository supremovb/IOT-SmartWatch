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

        return LayoutBuilder(
          builder: (context, constraints) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF090909), Color(0xFF12090B)],
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 22),
                child: Column(
                  children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 6,
                runSpacing: 4,
                children: [
                  _chip('LIVE', const Color(0xFF28C76F)),
                  _chip('VITALS', Colors.redAccent),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Heart & Vitals',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.12),
                  border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.red, size: 42),
              ),
              const SizedBox(height: 12),
              Text(
                '${h.heartRate}',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                'BPM',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _miniCard(
                      icon: Icons.opacity_rounded,
                      color: const Color(0xFF4DA3FF),
                      value: '${h.bloodOxygen.toStringAsFixed(0)}%',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniCard(
                      icon: Icons.device_thermostat_rounded,
                      color: const Color(0xFFFFA24D),
                      value: '${h.temperatureF.toStringAsFixed(1)} F',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: zoneColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: zoneColor.withOpacity(0.5)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Icon(Icons.monitor_heart_rounded, color: zoneColor, size: 14),
                    Text(
                      zone,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: zoneColor,
                      ),
                    ),
                  ],
                ),
              ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.65)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _miniCard({
    required IconData icon,
    required Color color,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF15151A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.8)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _getZone(int bpm) {
    if (bpm < 60) return 'Resting';
    if (bpm < 100) return 'Normal zone';
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
