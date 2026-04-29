import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../models/patient.dart';
import '../constants/app_colors.dart';
import '../providers/app_provider.dart';
import 'package:intl/intl.dart';

class PatientVitalsDialog extends StatefulWidget {
  final Patient patient;
  const PatientVitalsDialog({super.key, required this.patient});

  @override
  State<PatientVitalsDialog> createState() => _PatientVitalsDialogState();
}

class _PatientVitalsDialogState extends State<PatientVitalsDialog> {
  late Timer _timer;
  late int currentHeartRate;
  late int currentSpo2;
  late double currentTemp;
  late int currentSteps;
  late double currentHumidity;
  late int currentEco2;
  late int currentTvoc;
  DateTime _capturedAt = DateTime.now();
  final List<FlSpot> _hrData = [];
  int xValue = 0;

  @override
  void initState() {
    super.initState();
    currentHeartRate = widget.patient.heartRate;
    currentSpo2 = widget.patient.spo2;
    currentTemp = widget.patient.temperature;
    currentSteps = widget.patient.steps;
    currentHumidity = widget.patient.humidity;
    currentEco2 = widget.patient.eco2;
    currentTvoc = widget.patient.tvoc;

    for (int i = 0; i < 15; i++) {
      _hrData.add(FlSpot(xValue.toDouble(), currentHeartRate.toDouble()));
      xValue++;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _syncFromProvider());
  }

  void _syncFromProvider() {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    final livePatient = provider.patients.firstWhere(
      (p) => p.id == widget.patient.id,
      orElse: () => widget.patient,
    );

    setState(() {
      currentHeartRate = livePatient.heartRate;
      currentSpo2 = livePatient.spo2;
      currentTemp = livePatient.temperature;
      currentSteps = livePatient.steps;
      currentHumidity = livePatient.humidity;
      currentEco2 = livePatient.eco2;
      currentTvoc = livePatient.tvoc;
      _capturedAt = DateTime.now();
      _hrData.add(FlSpot(xValue.toDouble(), currentHeartRate.toDouble()));
      if (_hrData.length > 15) {
        _hrData.removeAt(0);
      }
      xValue++;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.themed(context).surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${widget.patient.name}\'s Vitals',
                  style: TextStyle(color: AppColors.themed(context).textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: AppColors.success, size: 6),
                    SizedBox(width: 4),
                    Text('LIVE', style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM d, y, h:mm a').format(_capturedAt),
            style: TextStyle(fontSize: 11, color: AppColors.themed(context).textSecondary),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _buildDialogVitalCard('Heart Rate', '$currentHeartRate bpm', Icons.favorite, AppColors.primary, true),
                _buildDialogVitalCard('SpO2', '$currentSpo2%', Icons.water_drop, AppColors.info, false),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDialogVitalCard('Temperature', '${currentTemp.toStringAsFixed(1)}°F', Icons.thermostat, AppColors.warning, false),
                _buildDialogVitalCard('Steps', '$currentSteps', Icons.directions_walk, AppColors.accent, false),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDialogVitalCard('Humidity', '${currentHumidity.toStringAsFixed(1)}%', Icons.water, Colors.blue, false),
                _buildDialogVitalCard('eCO2', '${currentEco2}ppm', Icons.air, currentEco2 > 1000 ? AppColors.warning : Colors.green, false),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDialogVitalCard('TVOC', '${currentTvoc}ppb', Icons.science, Colors.purple, false),
                _buildDialogVitalCard('Air Quality', _aqiLabel(currentEco2), Icons.eco, _aqiColor(currentEco2), false),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }

  String _aqiLabel(int eco2) {
    if (eco2 <= 600) return 'Excellent';
    if (eco2 <= 1000) return 'Good';
    if (eco2 <= 1500) return 'Moderate';
    if (eco2 <= 2000) return 'Poor';
    return 'Unhealthy';
  }

  Color _aqiColor(int eco2) {
    if (eco2 <= 600) return Colors.green;
    if (eco2 <= 1000) return Colors.lightGreen;
    if (eco2 <= 1500) return Colors.orange;
    if (eco2 <= 2000) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _buildDialogVitalCard(String title, String value, IconData icon, Color color, bool showChart) {
    return Expanded(
      child: Container(
        height: 85,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 4),
                Flexible(child: Text(title, style: TextStyle(fontSize: 10, color: AppColors.themed(context).textSecondary), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                value,
                key: ValueKey(value),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            if (showChart) ...[
              const Spacer(),
              SizedBox(
                height: 24,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minX: _hrData.first.x,
                    maxX: _hrData.last.x,
                    minY: 50,
                    maxY: 130,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _hrData,
                        isCurved: true,
                        color: color,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else 
              const Spacer()
          ],
        ),
      ),
    );
  }
}
