import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';
import '../widgets/top_bar.dart';
import '../widgets/patient_vitals_dialog.dart';
import '../models/patient.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(String)? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    if (appProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Column(
      children: [
        TopBar(
          onProfileTap: () {
            if (onNavigate != null) onNavigate!('/settings');
          },
          onNavigate: onNavigate,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width < 768 ? 12 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 32),
                  _buildStatsRow(context),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Smart Watch Users'),
                  const SizedBox(height: 16),
                  _buildSmartWatchUsersList(context),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'High-Risk Patients'),
                  const SizedBox(height: 16),
                  _buildHighRiskPatients(context),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Real-Time Vitals Summary'),
                  const SizedBox(height: 16),
                  _buildVitalsGrid(context),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Air Quality & Environment'),
                  const SizedBox(height: 16),
                  _buildAirQualityGrid(context),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle(context, 'Recent Alerts'),
                      TextButton(
                        onPressed: () {
                          if (onNavigate != null) onNavigate!('/alerts');
                        },
                        child: const Text('View All', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildRecentAlerts(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _displayName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'User';
    final parts = fullName.split(' ');
    // Skip titles like "Dr.", "Nurse", "Admin" to get the actual first name
    const titles = {'dr.', 'dr', 'nurse', 'prof.', 'prof', 'mr.', 'mr', 'mrs.', 'mrs', 'ms.', 'ms'};
    for (final part in parts) {
      if (!titles.contains(part.toLowerCase())) return part;
    }
    return parts.last; // fallback to last part if all parts are titles
  }

  Widget _buildHeader(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final t = AppColors.themed(context);
    final role = (user?.role ?? '').toLowerCase();
    String prefix;
    switch (role) {
      case 'doctor':
        prefix = 'Dr.';
        break;
      case 'nurse':
        prefix = 'Nurse';
        break;
      case 'admin':
        prefix = 'Admin';
        break;
      default:
        prefix = '';
    }
    final greeting = prefix.isNotEmpty
        ? 'Welcome, $prefix ${_displayName(user?.name)}!'
        : 'Welcome, ${_displayName(user?.name)}!';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: t.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Dominican Smart Watch - Health Monitoring Dashboard',
          style: TextStyle(
            fontSize: 14,
            color: t.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatCard('Active Patients', appProvider.activePatients.toString(), AppColors.themed(context).primary),
          const SizedBox(width: 16),
          _buildStatCard('Alerts Today', appProvider.alertsToday.toString(), AppColors.themed(context).warning),
          const SizedBox(width: 16),
          _buildStatCard('Devices Online', appProvider.devicesOnline.toString(), AppColors.themed(context).accent),
          const SizedBox(width: 16),
          _buildStatCard('Critical', appProvider.criticalPatients.toString(), AppColors.themed(context).danger),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Builder(builder: (context) {
    final t = AppColors.themed(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider),
      ),
      constraints: const BoxConstraints(minWidth: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              value,
              key: ValueKey(value),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
    });
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.themed(context).textPrimary,
      ),
    );
  }

  Widget _buildHighRiskPatients(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final patients = appProvider.patients.where((p) => p.riskLevel == 'Critical' || p.riskLevel == 'High').toList();

    if (patients.isEmpty) {
      return Text('No high-risk patients.', style: TextStyle(color: AppColors.themed(context).textSecondary));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final t = AppColors.themed(context);
        final cardWidth = constraints.maxWidth < 600
            ? (constraints.maxWidth - 16) / 2
            : 280.0;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: patients.map((p) => InkWell(
            onTap: () => _showPatientVitalsSummary(context, p),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: cardWidth.clamp(200.0, 320.0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: p.riskLevel == 'Critical'
                      ? t.danger
                      : t.warning,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: t.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: p.riskLevel == 'Critical'
                              ? t.danger.withOpacity(0.1)
                              : t.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.riskLevel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: p.riskLevel == 'Critical'
                                ? t.danger
                                : t.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.condition,
                    style: TextStyle(
                      fontSize: 12,
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          '${p.heartRate} bpm',
                          key: ValueKey('${p.id}-${p.heartRate}'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        'Synced ${p.lastSync}',
                        style: TextStyle(
                          fontSize: 10,
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildAirQualityGrid(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Compute averages across online patients with device linked
    final online = appProvider.patients.where((p) => p.deviceStatus == 'Online').toList();
    final avgHumidity = online.isEmpty ? 0.0 : online.fold(0.0, (s, p) => s + p.humidity) / online.length;
    final avgEco2     = online.isEmpty ? 400  : (online.fold(0, (s, p) => s + p.eco2) / online.length).round();
    final avgTvoc     = online.isEmpty ? 0    : (online.fold(0, (s, p) => s + p.tvoc) / online.length).round();

    String aqiLabel(int eco2) {
      if (eco2 <= 600)  return 'Excellent';
      if (eco2 <= 1000) return 'Good';
      if (eco2 <= 1500) return 'Moderate';
      if (eco2 <= 2000) return 'Poor';
      return 'Unhealthy';
    }
    Color aqiColor(int eco2) {
      if (eco2 <= 600)  return Colors.green;
      if (eco2 <= 1000) return Colors.lightGreen;
      if (eco2 <= 1500) return Colors.orange;
      if (eco2 <= 2000) return Colors.deepOrange;
      return Colors.red;
    }

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      childAspectRatio: isMobile ? 1.5 : 1.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildVitalCard(context, 'Avg Humidity', '${avgHumidity.toStringAsFixed(1)}%', '30-60%', Colors.blue, Icons.water),
        _buildVitalCard(context, 'Avg eCO2', '${avgEco2}ppm', '<1000 ppm', aqiColor(avgEco2), Icons.air),
        _buildVitalCard(context, 'Avg TVOC', '${avgTvoc}ppb', '<500 ppb', Colors.purple, Icons.science),
        _buildVitalCard(context, 'Air Quality', aqiLabel(avgEco2), 'Excellent-Good', aqiColor(avgEco2), Icons.eco),
      ],
    );
  }

  Widget _buildVitalsGrid(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isMobile = MediaQuery.of(context).size.width < 768;
    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      childAspectRatio: isMobile ? 1.5 : 1.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildVitalCard(context, 'Avg Heart Rate', '${appProvider.avgHeartRate.toStringAsFixed(0)} bpm', '60-100', AppColors.themed(context).primary, Icons.favorite),
        _buildVitalCard(context, 'Avg SpO2', '${appProvider.avgSpo2.toStringAsFixed(1)}%', '95-100%', AppColors.themed(context).accent, Icons.water_drop),
        _buildVitalCard(context, 'Avg Steps', '${appProvider.avgSteps} steps', '0-10000', AppColors.themed(context).warning, Icons.directions_walk),
        _buildVitalCard(context, 'Temperature', '${appProvider.avgTemperature.toStringAsFixed(1)}°F', '97-99°F', AppColors.themed(context).info, Icons.thermostat),
      ],
    );
  }

  Widget _buildVitalCard(
    BuildContext context,
    String title,
    String value,
    String range,
    Color color,
    IconData icon,
  ) {
    final t = AppColors.themed(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: t.textSecondary,
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              value,
              key: ValueKey(value),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Text(
            'Range: $range',
            style: TextStyle(
              fontSize: 10,
              color: t.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlerts(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final alerts = appProvider.alerts.toList();
    final recentAlerts = alerts.take(5).toList();

    if (recentAlerts.isEmpty) {
      return Text('No recent alerts.', style: TextStyle(color: AppColors.themed(context).textSecondary));
    }

    final t = AppColors.themed(context);
    return Column(
      children: recentAlerts
          .map((alert) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: (alert.severity == 'critical' || alert.severity == 'sos')
                          ? AppColors.themed(context).danger
                          : AppColors.themed(context).warning,
                      width: 4,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${alert.patient} • ${alert.timestamp}',
                            style: TextStyle(
                              fontSize: 12,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      color: t.textSecondary,
                      onPressed: () {
                        if (onNavigate != null) {
                          onNavigate!('/alerts');
                        }
                      },
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildSmartWatchUsersList(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final patients = appProvider.patients;

    if (patients.isEmpty) {
      return Text('No patients.', style: TextStyle(color: AppColors.themed(context).textSecondary));
    }

    final t = AppColors.themed(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: patients.map((p) => Padding(
          padding: const EdgeInsets.only(right: 16),
          child: InkWell(
            onTap: () => _showPatientVitalsSummary(context, p),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.themed(context).primary.withOpacity(0.1),
                      child: Text(
                        p.name.substring(0, 1),
                        style: TextStyle(
                          color: AppColors.themed(context).primary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: p.riskLevel == 'Critical' 
                              ? AppColors.themed(context).danger 
                              : (p.riskLevel == 'High' 
                                  ? AppColors.themed(context).warning 
                                  : AppColors.success),
                          shape: BoxShape.circle,
                          border: Border.all(color: t.background, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  p.name.split(' ').first,
                  style: TextStyle(color: t.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  void _showPatientVitalsSummary(BuildContext context, Patient patient) {
    showDialog(
      context: context,
      builder: (context) {
        return PatientVitalsDialog(patient: patient);
      },
    );
  }
}



