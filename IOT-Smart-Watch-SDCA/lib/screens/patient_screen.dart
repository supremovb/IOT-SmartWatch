import 'package:flutter/material.dart';
import '../models/watch_data.dart';

class PatientScreen extends StatelessWidget {
  final WatchController controller;
  const PatientScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF04070B), Color(0xFF0B1220)],
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 18),
                child: Column(
                  children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 6,
                runSpacing: 4,
                children: [
                  _chip('LIVE', const Color(0xFF28C76F)),
                  _chip('PATIENT', const Color(0xFF4DA3FF)),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Patient Details',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4DA3FF),
                ),
              ),
              const SizedBox(height: 14),
              if (!controller.patientLinked) ...[
                const SizedBox(height: 14),
                const Icon(Icons.person_off_rounded, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'No patient assigned',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Link this watch in admin',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
                const SizedBox(height: 10),
                Text(
                  controller.deviceId,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4DA3FF),
                  ),
                ),
                const SizedBox(height: 10),
              ] else ...[
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4DA3FF).withOpacity(0.14),
                    border: Border.all(color: const Color(0xFF4DA3FF), width: 2),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 10),
                Text(
                  controller.patientName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Age ${controller.patientAge}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00D4FF),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (controller.patientRisk == 'Critical'
                            ? Colors.red
                            : Colors.green)
                        .withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: controller.patientRisk == 'Critical'
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                  child: Text(
                    'Risk: ${controller.patientRisk}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: controller.patientRisk == 'Critical'
                          ? Colors.redAccent
                          : Colors.greenAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _detailCard(
                  title: 'Condition',
                  value: controller.patientCondition,
                  color: const Color(0xFF4DA3FF),
                ),
                const SizedBox(height: 8),
                _detailCard(
                  title: 'Live Vitals',
                  value:
                      'HR ${controller.health.heartRate}   SpO2 ${controller.health.bloodOxygen.toStringAsFixed(0)}%',
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                _detailCard(
                  title: 'Temp / Steps',
                  value:
                      '${controller.health.temperatureF.toStringAsFixed(1)} F   •   ${controller.health.steps} steps',
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                _detailCard(
                  title: 'Notes',
                  value: controller.patientNotes,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 10),
                Text(
                  controller.deviceId,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4DA3FF),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _detailCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151A22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
