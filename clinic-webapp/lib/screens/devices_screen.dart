import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/app_provider.dart';
import '../models/device_model.dart';
import '../widgets/top_bar.dart';

class DevicesScreen extends StatefulWidget {
  final void Function(String)? onNavigate;
  const DevicesScreen({super.key, this.onNavigate});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _showFirmwareUpdateDialog(BuildContext context, DeviceModel device) {
    final t = AppColors.themed(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            this.context.read<AppProvider>().updateFirmware(device.id);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(
                content: Text('Firmware updated successfully for ${device.id}'),
                backgroundColor: AppColors.accent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.system_update, color: AppColors.info),
            ),
            const SizedBox(width: 12),
            const Text('Updating Firmware...'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(color: AppColors.primary, minHeight: 6),
              ),
              const SizedBox(height: 16),
              Text('Please do not power off the device.', style: TextStyle(color: t.textSecondary)),
            ],
          ),
        );
      },
    );
  }

  void _showUnpairDialog(BuildContext context, DeviceModel device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.link_off, color: AppColors.danger),
          ),
          const SizedBox(width: 12),
          const Text('Unpair Device'),
        ]),
        content: Text('Are you sure you want to unpair ${device.id}? This will disconnect the device from patient ${device.patientName}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ctx.read<AppProvider>().unpairDevice(device.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Device unpaired successfully'),
                  backgroundColor: AppColors.accent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
  }

  void _showDeviceLogs(BuildContext context, DeviceModel device) {
    final t = AppColors.themed(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.receipt_long, color: AppColors.warning),
          ),
          const SizedBox(width: 12),
          Text('Logs - ${device.id}'),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: device.logs.isEmpty
              ? Center(child: Text('No logs available', style: TextStyle(color: t.textSecondary)))
              : ListView.separated(
                  itemCount: device.logs.length,
                  separatorBuilder: (_, __) => Divider(color: t.divider, height: 1),
                  itemBuilder: (_, i) => ListTile(
                    leading: Icon(Icons.history, color: t.textSecondary, size: 18),
                    title: Text(device.logs[i], style: const TextStyle(fontSize: 13)),
                    dense: true,
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showDeviceDetails(BuildContext context, DeviceModel device) {
    final t = AppColors.themed(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.watch, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(device.id, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.textPrimary)),
                  Text('Device Details', style: TextStyle(fontSize: 12, color: t.textSecondary)),
                ]),
              ]),
              IconButton(
                icon: Icon(Icons.close, color: t.textSecondary),
                onPressed: () => Navigator.pop(ctx),
              ),
            ]),
            Divider(color: t.divider, height: 28),
            _detailRow(Icons.person, 'Assigned Patient', device.patientName, t),
            const SizedBox(height: 14),
            _detailRow(Icons.sensors, 'Status', device.status, t),
            const SizedBox(height: 14),
            _detailRow(Icons.battery_full, 'Battery Level', '${device.battery}%', t),
            const SizedBox(height: 14),
            _detailRow(Icons.update, 'Firmware', device.firmware, t),
            const SizedBox(height: 14),
            _detailRow(Icons.sync, 'Last Sync', device.lastSync, t),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Themed t) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: t.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: t.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppColors.themed(context);
    final appProvider = context.watch<AppProvider>();
    final devices = appProvider.devices;

    final totalCount = devices.length;
    final onlineCount = devices.where((d) => d.status == 'Online').length;
    final offlineCount = devices.where((d) => d.status == 'Offline').length;
    final lowBatteryCount = devices.where((d) => d.battery < 20).length;

    return Column(
      children: [
        TopBar(
          onProfileTap: () => widget.onNavigate?.call('/settings'),
          onNavigate: widget.onNavigate,
        ),
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: t.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Monitor and manage connected IoT health devices', style: TextStyle(fontSize: 13, color: t.textSecondary)),
                    const SizedBox(height: 24),

                    // ── Stat Cards ──
                    Row(children: [
                      _buildStatCard('Total Devices', totalCount.toString(), Icons.devices, t.primary, t),
                      const SizedBox(width: 12),
                      _buildStatCard('Online', onlineCount.toString(), Icons.cloud_done, t.accent, t),
                      const SizedBox(width: 12),
                      _buildStatCard('Offline', offlineCount.toString(), Icons.cloud_off, t.warning, t),
                      const SizedBox(width: 12),
                      _buildStatCard('Low Battery', lowBatteryCount.toString(), Icons.battery_alert, t.danger, t),
                    ]),
                    const SizedBox(height: 28),

                    // ── Search Bar ──
                    Container(
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.divider),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by device ID or patient name...',
                          hintStyle: TextStyle(color: t.textHint),
                          prefixIcon: Icon(Icons.search, color: t.textSecondary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Devices Table ──
                    Card(
                      color: t.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth - 16),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(AppColors.primary.withOpacity(0.04)),
                                headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: t.textPrimary, fontSize: 13),
                                dataRowMinHeight: 56,
                                dataRowMaxHeight: 56,
                                columnSpacing: 20,
                                horizontalMargin: 16,
                                dividerThickness: 0.8,
                                columns: const [
                                  DataColumn(label: Text('Device ID')),
                                  DataColumn(label: Text('Patient')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Battery')),
                                  DataColumn(label: Text('Last Sync')),
                                  DataColumn(label: Text('Firmware')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: _buildDeviceRows(devices, t),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color, Themed t) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(count, key: ValueKey('ds-$title-$count'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: t.textSecondary)),
        ]),
      ),
    );
  }

  List<DataRow> _buildDeviceRows(List<DeviceModel> devices, Themed t) {
    return devices
        .where((d) =>
            _searchController.text.isEmpty ||
            d.id.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            d.patientName.toLowerCase().contains(_searchController.text.toLowerCase()))
        .map((d) {
          final battery = d.battery;
          final batteryColor = battery > 50 ? AppColors.accent : battery > 20 ? AppColors.warning : AppColors.danger;
          final isOnline = d.status == 'Online';

          return DataRow(
            cells: [
              DataCell(Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name, style: TextStyle(fontWeight: FontWeight.w700, color: t.textPrimary)),
                  Text(d.id, style: TextStyle(fontSize: 11, color: t.textSecondary)),
                ],
              )),
              DataCell(Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(d.patientName.isNotEmpty ? d.patientName[0] : '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                const SizedBox(width: 8),
                Text(d.patientName),
              ])),
              DataCell(
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey('status-${d.id}-${d.status}'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.accent.withOpacity(0.1) : t.textSecondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? AppColors.accent : t.textSecondary)),
                      const SizedBox(width: 6),
                      Text(d.status, style: TextStyle(color: isOnline ? AppColors.accent : t.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
              DataCell(
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Row(key: ValueKey('bat-${d.id}-$battery'), mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      battery > 50 ? Icons.battery_full : battery > 20 ? Icons.battery_5_bar : Icons.battery_alert,
                      color: batteryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text('$battery%', style: TextStyle(color: batteryColor, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              DataCell(Text(d.lastSync, style: TextStyle(fontSize: 12, color: t.textSecondary))),
              DataCell(Text(d.firmware, style: TextStyle(fontSize: 12, color: t.textSecondary))),
              DataCell(
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _actionButton(Icons.info_outline, 'Details', AppColors.info, () => _showDeviceDetails(context, d)),
                  _actionButton(Icons.system_update, 'Update', AppColors.primary, () => _showFirmwareUpdateDialog(context, d)),
                  _actionButton(Icons.link_off, 'Unpair', AppColors.danger, () => _showUnpairDialog(context, d)),
                  _actionButton(Icons.receipt_long, 'Logs', AppColors.warning, () => _showDeviceLogs(context, d)),
                ]),
              ),
            ],
          );
        })
        .toList();
  }

  Widget _actionButton(IconData icon, String tooltip, Color color, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
