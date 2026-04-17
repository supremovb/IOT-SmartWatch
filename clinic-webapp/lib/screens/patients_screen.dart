import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/app_provider.dart';
import '../models/patient.dart';
import '../widgets/top_bar.dart';
import '../widgets/patient_vitals_dialog.dart';

class PatientsScreen extends StatefulWidget {
  final void Function(String)? onNavigate;
  const PatientsScreen({super.key, this.onNavigate});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _filterValue = 'all';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final query = context.read<AppProvider>().globalSearch;
      if (query.isNotEmpty) _searchController.text = query;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────

  void _showAddPatientDialog(BuildContext context) {
    final ap = context.read<AppProvider>();
    final detectedDevices = _availableDeviceIds(context);
    String? selectedDevice = detectedDevices.isNotEmpty ? detectedDevices.first : null;

    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final conditionCtrl = TextEditingController();
    final deviceCtrl = TextEditingController(text: selectedDevice ?? '');
    final notesCtrl = TextEditingController();
    String riskLevel = 'Low';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final t = AppColors.themed(ctx);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: _dialogTitle(Icons.person_add, 'Add New Patient', AppColors.primary, t),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _field(nameCtrl, 'Full Name', Icons.person),
                const SizedBox(height: 12),
                _field(ageCtrl, 'Age', Icons.cake, keyboard: TextInputType.number),
                const SizedBox(height: 12),
                _field(conditionCtrl, 'Condition', Icons.medical_services),
                const SizedBox(height: 12),
                if (detectedDevices.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: selectedDevice,
                    decoration: InputDecoration(
                      labelText: 'Detected Watch Device',
                      prefixIcon: const Icon(Icons.bluetooth_searching, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: detectedDevices
                        .map((id) => DropdownMenuItem(value: id, child: Text(_deviceLabel(ap, id))))
                        .toList(),
                    onChanged: (v) {
                      setS(() {
                        selectedDevice = v;
                        deviceCtrl.text = v ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _field(deviceCtrl, 'Device ID (e.g. WATCH-001)', Icons.watch),
                const SizedBox(height: 12),
                _field(notesCtrl, 'Notes (optional)', Icons.notes, lines: 2),
                const SizedBox(height: 12),
                _riskDropdown(riskLevel, (v) => setS(() => riskLevel = v)),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: t.textSecondary))),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Patient'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final ap = context.read<AppProvider>();
                  ap.addPatient(ap.buildNewPatient(name: nameCtrl.text.trim(), age: int.tryParse(ageCtrl.text) ?? 0, condition: conditionCtrl.text.trim(), riskLevel: riskLevel, deviceId: deviceCtrl.text.trim(), notes: notesCtrl.text.trim()));
                  Navigator.pop(ctx);
                  _snack('Patient added successfully', AppColors.accent);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditPatientDialog(BuildContext context, Patient patient) {
    final ap = context.read<AppProvider>();
    final detectedDevices = _availableDeviceIds(context, currentDeviceId: patient.deviceId);
    String? selectedDevice = patient.deviceId.isNotEmpty
        ? patient.deviceId
        : (detectedDevices.isNotEmpty ? detectedDevices.first : null);

    final nameCtrl = TextEditingController(text: patient.name);
    final ageCtrl = TextEditingController(text: patient.age.toString());
    final conditionCtrl = TextEditingController(text: patient.condition);
    final deviceCtrl = TextEditingController(text: selectedDevice ?? '');
    final notesCtrl = TextEditingController(text: patient.notes);
    String riskLevel = patient.riskLevel;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final t = AppColors.themed(ctx);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: _dialogTitle(Icons.edit, 'Edit Patient', AppColors.info, t),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _field(nameCtrl, 'Full Name', Icons.person),
                const SizedBox(height: 12),
                _field(ageCtrl, 'Age', Icons.cake, keyboard: TextInputType.number),
                const SizedBox(height: 12),
                _field(conditionCtrl, 'Condition', Icons.medical_services),
                const SizedBox(height: 12),
                if (detectedDevices.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: selectedDevice,
                    decoration: InputDecoration(
                      labelText: 'Detected Watch Device',
                      prefixIcon: const Icon(Icons.bluetooth_searching, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: detectedDevices
                        .map((id) => DropdownMenuItem(value: id, child: Text(_deviceLabel(ap, id))))
                        .toList(),
                    onChanged: (v) {
                      setS(() {
                        selectedDevice = v;
                        deviceCtrl.text = v ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _field(deviceCtrl, 'Device ID (e.g. WATCH-001)', Icons.watch),
                const SizedBox(height: 12),
                _field(notesCtrl, 'Notes', Icons.notes, lines: 2),
                const SizedBox(height: 12),
                _riskDropdown(riskLevel, (v) => setS(() => riskLevel = v)),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: t.textSecondary))),
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.info, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  context.read<AppProvider>().updatePatient(patient.id, patient.copyWith(name: nameCtrl.text.trim(), age: int.tryParse(ageCtrl.text) ?? patient.age, condition: conditionCtrl.text.trim(), riskLevel: riskLevel, deviceId: deviceCtrl.text.trim(), notes: notesCtrl.text.trim()));
                  Navigator.pop(ctx);
                  _snack('Patient updated', AppColors.info);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRemovePatientDialog(BuildContext context, Patient patient) {
    showDialog(
      context: context,
      builder: (ctx) {
        final t = AppColors.themed(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: _dialogTitle(Icons.delete_forever, 'Remove Patient', AppColors.danger, t),
          content: Text('Are you sure you want to remove ${patient.name}? This action cannot be undone.', style: TextStyle(color: t.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: t.textSecondary))),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Remove'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                context.read<AppProvider>().removePatient(patient.id);
                Navigator.pop(ctx);
                _snack('Patient removed', AppColors.danger);
              },
            ),
          ],
        );
      },
    );
  }

  // ─── Dialog helpers ───────────────────────────────────────────────────────

  Widget _dialogTitle(IconData icon, String text, Color color, Themed t) => Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: t.textPrimary, fontSize: 18)),
      ]);

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType keyboard = TextInputType.text, int lines = 1}) =>
      TextField(controller: c, keyboardType: keyboard, maxLines: lines, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)));

  Widget _riskDropdown(String value, ValueChanged<String> onChanged) => DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: 'Risk Level', prefixIcon: const Icon(Icons.warning_amber, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
        items: ['Critical', 'High', 'Medium', 'Low'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      );

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));

  List<String> _availableDeviceIds(BuildContext context, {String currentDeviceId = ''}) {
    final ap = context.read<AppProvider>();
    final usedDeviceIds = ap.patients
        .map((p) => p.deviceId.trim())
        .where((id) => id.isNotEmpty && id != currentDeviceId.trim())
        .toSet();

    final available = ap.devices
        .where((d) => d.status == 'Online')
        .map((d) => d.id.trim())
        .where((id) => id.isNotEmpty && !usedDeviceIds.contains(id))
        .toSet()
        .toList()
      ..sort();

    if (currentDeviceId.trim().isNotEmpty && !available.contains(currentDeviceId.trim())) {
      available.insert(0, currentDeviceId.trim());
    }

    if (available.isEmpty && currentDeviceId.trim().isEmpty && !usedDeviceIds.contains('WATCH-001')) {
      available.add('WATCH-001');
    }
    return available;
  }

  String _deviceLabel(AppProvider ap, String id) {
    final match = ap.devices.cast<dynamic?>().firstWhere(
      (d) => d?.id == id,
      orElse: () => null,
    );
    final name = match?.name?.toString().trim();
    final label = (name != null && name.isNotEmpty) ? name : 'ESP32 SmartWatch';
    return '$label ($id)';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppColors.themed(context);
    return Column(
      children: [
        TopBar(onProfileTap: () => widget.onNavigate?.call('/settings'), onNavigate: widget.onNavigate),
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
                    // Header
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        if (isMobile) {
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Patient Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: t.textPrimary)),
                            const SizedBox(height: 4),
                            Consumer<AppProvider>(
                              builder: (_, ap, __) => Text('${ap.patients.length} total patients • ${ap.patients.where((p) => p.deviceStatus == "Online").length} online', style: TextStyle(fontSize: 13, color: t.textSecondary)),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Patient'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), elevation: 2),
                                onPressed: () => _showAddPatientDialog(context),
                              ),
                            ),
                          ]);
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Patient Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: t.textPrimary)),
                              const SizedBox(height: 4),
                              Consumer<AppProvider>(
                                builder: (_, ap, __) => Text('${ap.patients.length} total patients • ${ap.patients.where((p) => p.deviceStatus == "Online").length} online', style: TextStyle(fontSize: 13, color: t.textSecondary)),
                              ),
                            ]),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Patient'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), elevation: 2),
                              onPressed: () => _showAddPatientDialog(context),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Stats
                    Consumer<AppProvider>(
                      builder: (_, ap, __) {
                        final chips = [
                          _statChip('Critical', ap.patients.where((p) => p.riskLevel == 'Critical').length, AppColors.themed(context).danger),
                          _statChip('High', ap.patients.where((p) => p.riskLevel == 'High').length, AppColors.themed(context).warning),
                          _statChip('Medium', ap.patients.where((p) => p.riskLevel == 'Medium').length, AppColors.themed(context).info),
                          _statChip('Low', ap.patients.where((p) => p.riskLevel == 'Low').length, AppColors.themed(context).accent),
                        ];
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 600) {
                              return Column(children: [
                                Row(children: [chips[0], const SizedBox(width: 10), chips[1]]),
                                const SizedBox(height: 10),
                                Row(children: [chips[2], const SizedBox(width: 10), chips[3]]),
                              ]);
                            }
                            return Row(children: [
                              chips[0], const SizedBox(width: 10),
                              chips[1], const SizedBox(width: 10),
                              chips[2], const SizedBox(width: 10),
                              chips[3],
                            ]);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Search + Filter
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(hintText: 'Search patients...', prefixIcon: const Icon(Icons.search, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(vertical: 12), filled: true, fillColor: t.surface),
                          onChanged: (v) => context.read<AppProvider>().setGlobalSearch(v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      PopupMenuButton<String>(
                        onSelected: (v) => setState(() => _filterValue = v),
                        itemBuilder: (_) => [
                          _filterItem('all', 'All Patients', Icons.people),
                          _filterItem('high-risk', 'High-Risk', Icons.warning),
                          _filterItem('active', 'Active (Online)', Icons.wifi),
                          _filterItem('inactive', 'Inactive (Offline)', Icons.wifi_off),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.divider), borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            const Icon(Icons.filter_list, size: 18),
                            const SizedBox(width: 8),
                            Text(_filterLabel, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 18),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    // Table
                    Card(
                      color: t.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Consumer<AppProvider>(
                              builder: (context, ap, _) => ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth - 8),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(AppColors.themed(context).primary.withOpacity(0.04)),
                                  headingTextStyle: TextStyle(fontWeight: FontWeight.w600, color: t.textPrimary, fontSize: 13),
                                  dataRowMinHeight: 56,
                                  dataRowMaxHeight: 56,
                                  columnSpacing: 20,
                                  horizontalMargin: 16,
                                  dividerThickness: 0.8,
                                  columns: const [
                                    DataColumn(label: Text('Patient')),
                                    DataColumn(label: Text('Age')),
                                    DataColumn(label: Text('Condition')),
                                    DataColumn(label: Text('Risk Level')),
                                    DataColumn(label: Text('Vitals')),
                                    DataColumn(label: Text('Device')),
                                    DataColumn(label: Text('Last Sync')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: _buildRows(ap),
                                ),
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

  // ─── Widgets ──────────────────────────────────────────────────────────────

  String get _filterLabel => _filterValue == 'high-risk' ? 'High-Risk' : _filterValue == 'active' ? 'Active' : _filterValue == 'inactive' ? 'Inactive' : 'All Patients';

  Widget _statChip(String label, int count, Color color) => Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
          child: Column(children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(count.toString(), key: ValueKey('$label-$count'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ]),
        ),
      );

  PopupMenuItem<String> _filterItem(String value, String label, IconData icon) => PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon, size: 18, color: _filterValue == value ? AppColors.primary : null),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: _filterValue == value ? FontWeight.bold : FontWeight.normal)),
        ]),
      );

  Color _riskColor(String risk) {
    final t = AppColors.themed(context);
    switch (risk) {
      case 'Critical': return t.danger;
      case 'High': return t.warning;
      case 'Medium': return t.info;
      default: return t.accent;
    }
  }

  List<DataRow> _buildRows(AppProvider ap) {
    final query = ap.globalSearch.toLowerCase();
    final filtered = ap.patients.where((p) {
      if (query.isNotEmpty && !p.name.toLowerCase().contains(query) && !p.condition.toLowerCase().contains(query)) return false;
      if (_filterValue == 'high-risk' && p.riskLevel != 'Critical' && p.riskLevel != 'High') return false;
      if (_filterValue == 'active' && p.deviceStatus != 'Online') return false;
      if (_filterValue == 'inactive' && p.deviceStatus != 'Offline') return false;
      return true;
    }).toList();

    return filtered.map((p) {
      final rc = _riskColor(p.riskLevel);
      return DataRow(cells: [
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 16, backgroundColor: rc.withOpacity(0.1), child: Text(p.name.isNotEmpty ? p.name[0] : '?', style: TextStyle(color: rc, fontWeight: FontWeight.bold, fontSize: 14))),
          const SizedBox(width: 10),
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
        ])),
        DataCell(Text(p.age.toString())),
        DataCell(Text(p.condition)),
        DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: rc.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(p.riskLevel, style: TextStyle(color: rc, fontWeight: FontWeight.w600, fontSize: 12)))),
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.favorite, color: AppColors.primary, size: 14),
          const SizedBox(width: 3),
          AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: Text('${p.heartRate}', key: ValueKey('hr-${p.id}-${p.heartRate}'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          const SizedBox(width: 8),
          const Icon(Icons.water_drop, color: AppColors.info, size: 14),
          const SizedBox(width: 3),
          AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: Text('${p.spo2}%', key: ValueKey('spo2-${p.id}-${p.spo2}'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        ])),
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: p.deviceStatus == 'Online' ? AppColors.accent : AppColors.offline)),
          const SizedBox(width: 6),
          Text(p.deviceStatus, style: TextStyle(color: p.deviceStatus == 'Online' ? AppColors.accent : AppColors.offline, fontWeight: FontWeight.w500, fontSize: 12)),
        ])),
        DataCell(Text(p.lastSync, style: const TextStyle(fontSize: 12))),
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.visibility, size: 18), color: AppColors.info, tooltip: 'View Vitals', onPressed: () => showDialog(context: context, builder: (_) => PatientVitalsDialog(patient: p))),
          IconButton(icon: const Icon(Icons.edit, size: 18), color: AppColors.warning, tooltip: 'Edit', onPressed: () => _showEditPatientDialog(context, p)),
          IconButton(icon: const Icon(Icons.delete_outline, size: 18), color: AppColors.danger, tooltip: 'Remove', onPressed: () => _showRemovePatientDialog(context, p)),
        ])),
      ]);
    }).toList();
  }
}
