import 'package:flutter/material.dart';
import '../models/watch_data.dart';

class StepsScreen extends StatelessWidget {
  final WatchController controller;
  const StepsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final h = controller.health;
        final pct = ((h.steps / controller.stepGoal) * 100).toInt().clamp(0, 100);

        return LayoutBuilder(
          builder: (context, constraints) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF060906), Color(0xFF09120C)],
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
                  _chip('IMU', controller.imuReady ? Colors.green : Colors.red),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Activity',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.12),
                  border: Border.all(color: Colors.green.withOpacity(0.4), width: 2),
                ),
                child: const Icon(Icons.directions_walk_rounded, color: Colors.green, size: 42),
              ),
              const SizedBox(height: 14),
              Text(
                '${h.steps}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                'steps today',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: const AlwaysStoppedAnimation(Colors.green),
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '$pct%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Goal ${controller.stepGoal}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  controller.imuReady ? 'IMU tracking live' : 'IMU offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: controller.imuReady ? controller.accentColor : Colors.redAccent,
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.65)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
