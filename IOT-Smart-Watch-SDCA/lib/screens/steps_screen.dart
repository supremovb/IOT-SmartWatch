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

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF060906), Color(0xFF09120C)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.directions_walk_rounded, color: Colors.green, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Activity',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.12),
                  border: Border.all(color: Colors.green.withOpacity(0.4), width: 2),
                ),
                child: const Icon(Icons.directions_walk_rounded, color: Colors.green, size: 44),
              ),
              const SizedBox(height: 18),
              Text(
                '${h.steps}',
                style: const TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                'steps',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: const AlwaysStoppedAnimation(Colors.green),
                    minHeight: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$pct%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'of ${controller.stepGoal} goal',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
