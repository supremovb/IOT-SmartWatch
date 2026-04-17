import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../providers/app_provider.dart';
import '../widgets/top_bar.dart';

class ReportsScreen extends StatefulWidget {
  final void Function(String)? onNavigate;
  const ReportsScreen({super.key, this.onNavigate});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _exporting = false;
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
    _animController.dispose();
    super.dispose();
  }

  // ─── PDF Export ──────────────────────────────────────────────────────────

  Future<void> _exportPDF(AppProvider ap) async {
    setState(() => _exporting = true);
    try {
      final pdf = pw.Document();
      final dateRange = '${DateFormat.yMMMd().format(_startDate)} - ${DateFormat.yMMMd().format(_endDate)}';
      final now = DateFormat('MMMM d, y h:mm a').format(DateTime.now());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => pw.Column(children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Dominican Smart Watch', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#DC2626'))),
                pw.SizedBox(height: 4),
                pw.Text('Health Monitoring Report', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Report Period', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                pw.Text(dateRange, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Generated: $now', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
              ]),
            ]),
            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColor.fromHex('#DC2626'), thickness: 2),
            pw.SizedBox(height: 16),
          ]),
          build: (context) => [
            // ── Summary Stats ──
            pw.Text('Summary Statistics', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Row(children: [
              _pdfStatBox('Total Patients', ap.activePatients.toString()),
              pw.SizedBox(width: 12),
              _pdfStatBox('Active Alerts', ap.alertsToday.toString()),
              pw.SizedBox(width: 12),
              _pdfStatBox('Devices Online', ap.devicesOnline.toString()),
              pw.SizedBox(width: 12),
              _pdfStatBox('Critical Patients', ap.criticalPatients.toString()),
            ]),
            pw.SizedBox(height: 24),

            // ── Avg Vitals ──
            pw.Text('Population Vitals (Averages)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFDC2626)),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center},
              cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center},
              headers: ['Metric', 'Value'],
              data: [
                ['Average Heart Rate', '${ap.avgHeartRate.toStringAsFixed(0)} bpm'],
                ['Average SpO2', '${ap.avgSpo2.toStringAsFixed(1)}%'],
                ['Average Temperature', '${ap.avgTemperature.toStringAsFixed(1)}°F'],
                ['Average Daily Steps', '${ap.avgSteps}'],
              ],
            ),
            pw.SizedBox(height: 24),

            // ── Patient Details ──
            pw.Text('Patient Details', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFDC2626)),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              headers: ['Name', 'Age', 'Condition', 'Risk', 'HR', 'SpO2', 'Temp', 'Device'],
              data: ap.patients.map((p) => [
                p.name,
                p.age.toString(),
                p.condition,
                p.riskLevel,
                '${p.heartRate} bpm',
                '${p.spo2}%',
                '${p.temperature.toStringAsFixed(1)}°F',
                p.deviceStatus,
              ]).toList(),
            ),
            pw.SizedBox(height: 24),

            // ── Active Alerts ──
            pw.Text('Active Alerts', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFDC2626)),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              headers: ['ID', 'Title', 'Patient', 'Severity', 'Status', 'Value'],
              data: ap.alerts.map((a) => [
                a.id,
                a.title,
                a.patient,
                a.severity.toUpperCase(),
                a.status.toUpperCase(),
                a.value,
              ]).toList(),
            ),
            pw.SizedBox(height: 24),

            // ── Devices ──
            pw.Text('Device Status', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFDC2626)),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              headers: ['Device ID', 'Patient', 'Status', 'Battery', 'Last Sync', 'Firmware'],
              data: ap.devices.map((d) => [
                d.id,
                d.patientName,
                d.status,
                '${d.battery}%',
                d.lastSync,
                d.firmware,
              ]).toList(),
            ),
          ],
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
          ),
        ),
      );

      final bytes = await pdf.save();
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'DSW_Report_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) _snack('PDF Report downloaded successfully', AppColors.accent);
    } catch (e) {
      if (mounted) _snack('Error generating PDF: $e', AppColors.danger);
    }
    if (mounted) setState(() => _exporting = false);
  }

  pw.Expanded _pdfStatBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#DC2626'))),
        ]),
      ),
    );
  }

  // ─── CSV Export ──────────────────────────────────────────────────────────

  Future<void> _exportCSV(AppProvider ap) async {
    setState(() => _exporting = true);
    try {
      // Patients sheet
      final patientRows = [
        ['--- PATIENTS ---', '', '', '', '', '', '', '', ''],
        ['Name', 'Age', 'Condition', 'Risk Level', 'Heart Rate (bpm)', 'SpO2 (%)', 'Temperature (°F)', 'Steps', 'Device Status'],
        ...ap.patients.map((p) => [
              p.name,
              p.age.toString(),
              p.condition,
              p.riskLevel,
              p.heartRate.toString(),
              p.spo2.toString(),
              p.temperature.toStringAsFixed(1),
              p.steps.toString(),
              p.deviceStatus,
            ]),
        [''],
        ['--- ALERTS ---', '', '', '', '', ''],
        ['ID', 'Title', 'Patient', 'Severity', 'Status', 'Value'],
        ...ap.alerts.map((a) => [
              a.id,
              a.title,
              a.patient,
              a.severity,
              a.status,
              a.value,
            ]),
        [''],
        ['--- DEVICES ---', '', '', '', '', ''],
        ['Device ID', 'Patient', 'Status', 'Battery (%)', 'Last Sync', 'Firmware'],
        ...ap.devices.map((d) => [
              d.id,
              d.patientName,
              d.status,
              d.battery.toString(),
              d.lastSync,
              d.firmware,
            ]),
        [''],
        ['--- SUMMARY ---', '', ''],
        ['Metric', 'Value', ''],
        ['Total Patients', ap.activePatients.toString(), ''],
        ['Active Alerts', ap.alertsToday.toString(), ''],
        ['Devices Online', ap.devicesOnline.toString(), ''],
        ['Critical Patients', ap.criticalPatients.toString(), ''],
        ['Avg Heart Rate', '${ap.avgHeartRate.toStringAsFixed(0)} bpm', ''],
        ['Avg SpO2', '${ap.avgSpo2.toStringAsFixed(1)}%', ''],
        ['Avg Temperature', '${ap.avgTemperature.toStringAsFixed(1)}°F', ''],
        ['Avg Daily Steps', ap.avgSteps.toString(), ''],
        [''],
        ['Report Period', '${DateFormat.yMMMd().format(_startDate)} - ${DateFormat.yMMMd().format(_endDate)}', ''],
        ['Generated', DateFormat('MMMM d, y h:mm a').format(DateTime.now()), ''],
      ];

      final csvString = const ListToCsvConverter().convert(patientRows);
      final bytes = utf8.encode(csvString);
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'DSW_Report_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.csv')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) _snack('CSV Report downloaded successfully', AppColors.accent);
    } catch (e) {
      if (mounted) _snack('Error generating CSV: $e', AppColors.danger);
    }
    if (mounted) setState(() => _exporting = false);
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppColors.themed(context);
    final appProvider = context.watch<AppProvider>();

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
                    Text('Reports & Analytics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: t.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Generate and export comprehensive health monitoring reports', style: TextStyle(fontSize: 13, color: t.textSecondary)),
                    const SizedBox(height: 24),

                    // Report Period + Export buttons
                    Card(
                      color: t.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 500;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.date_range, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('Report Period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.textPrimary)),
                                ]),
                                const SizedBox(height: 16),
                                if (isMobile) ...[
                                  _datePicker('From', _startDate, (d) => setState(() => _startDate = d), t),
                                  const SizedBox(height: 12),
                                  _datePicker('To', _endDate, (d) => setState(() => _endDate = d), t),
                                ] else
                                  Row(children: [
                                    Expanded(child: _datePicker('From', _startDate, (d) => setState(() => _startDate = d), t)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _datePicker('To', _endDate, (d) => setState(() => _endDate = d), t)),
                                  ]),
                                const SizedBox(height: 20),
                                if (isMobile) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: _exporting
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.picture_as_pdf, size: 18),
                                      label: const Text('Export PDF'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                      ),
                                      onPressed: _exporting ? null : () => _exportPDF(appProvider),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      icon: _exporting
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.table_chart, size: 18),
                                      label: const Text('Export CSV'),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                        side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                                      ),
                                      onPressed: _exporting ? null : () => _exportCSV(appProvider),
                                    ),
                                  ),
                                ] else
                                  Row(children: [
                                    ElevatedButton.icon(
                                      icon: _exporting
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.picture_as_pdf, size: 18),
                                      label: const Text('Export PDF'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                      ),
                                      onPressed: _exporting ? null : () => _exportPDF(appProvider),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      icon: _exporting
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.table_chart, size: 18),
                                      label: const Text('Export CSV'),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                        side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                                      ),
                                      onPressed: _exporting ? null : () => _exportCSV(appProvider),
                                    ),
                                  ]),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Quick Stats ──
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cards = [
                          _quickStat('Patients', appProvider.activePatients.toString(), Icons.people, AppColors.primary, t),
                          _quickStat('Active Alerts', appProvider.alertsToday.toString(), Icons.notifications_active, AppColors.warning, t),
                          _quickStat('Online Devices', appProvider.devicesOnline.toString(), Icons.watch, AppColors.accent, t),
                          _quickStat('Critical', appProvider.criticalPatients.toString(), Icons.warning, AppColors.danger, t),
                        ];
                        if (constraints.maxWidth < 600) {
                          return Column(children: [
                            Row(children: [cards[0], const SizedBox(width: 12), cards[1]]),
                            const SizedBox(height: 12),
                            Row(children: [cards[2], const SizedBox(width: 12), cards[3]]),
                          ]);
                        }
                        return Row(children: [
                          cards[0], const SizedBox(width: 12),
                          cards[1], const SizedBox(width: 12),
                          cards[2], const SizedBox(width: 12),
                          cards[3],
                        ]);
                      },
                    ),
                    const SizedBox(height: 28),

                    // ── Population Trends ──
                    Text('Population Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.textPrimary)),
                    const SizedBox(height: 16),
                    _trendRow('Heart Rate', '${appProvider.avgHeartRate.toStringAsFixed(0)} bpm', appProvider.avgHeartRate.toInt(), 120, Icons.favorite, AppColors.primary, t),
                    const SizedBox(height: 12),
                    _trendRow('SpO2 Level', '${appProvider.avgSpo2.toStringAsFixed(1)}%', appProvider.avgSpo2.toInt(), 100, Icons.water_drop, AppColors.info, t),
                    const SizedBox(height: 12),
                    _trendRow('Temperature', '${appProvider.avgTemperature.toStringAsFixed(1)}°F', ((appProvider.avgTemperature - 95) * 20).toInt().clamp(0, 100), 100, Icons.thermostat, AppColors.warning, t),
                    const SizedBox(height: 12),
                    _trendRow('Steps (Daily Avg)', '${appProvider.avgSteps}', appProvider.avgSteps, 10000, Icons.directions_walk, AppColors.accent, t),
                    const SizedBox(height: 28),

                    // ── Alert Summary ──
                    Text('Alert Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.textPrimary)),
                    const SizedBox(height: 16),
                    _alertSummary(appProvider, t),
                    const SizedBox(height: 28),

                    // ── Patient Adherence ──
                    Text('Patient Adherence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.textPrimary)),
                    const SizedBox(height: 16),
                    _adherenceRow('Device Sync', _calcDeviceSyncPercent(appProvider), t),
                    const SizedBox(height: 12),
                    _adherenceRow('Medication Adherence', 87, t),
                    const SizedBox(height: 12),
                    _adherenceRow('Appointment Attendance', 91, t),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _calcDeviceSyncPercent(AppProvider ap) {
    if (ap.devices.isEmpty) return 0;
    return ((ap.devices.where((d) => d.status == 'Online').length / ap.devices.length) * 100).round();
  }

  Widget _datePicker(String label, DateTime date, ValueChanged<DateTime> onPick, Themed t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, color: t.textSecondary, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      InkWell(
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime.now());
          if (d != null) onPick(d);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(border: Border.all(color: t.divider), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(DateFormat.yMMMd().format(date), style: TextStyle(color: t.textPrimary)),
            Icon(Icons.calendar_today, size: 16, color: t.textSecondary),
          ]),
        ),
      ),
    ]);
  }

  Widget _quickStat(String label, String value, IconData icon, Color color, Themed t) {
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
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(value, key: ValueKey('qs-$label-$value'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: t.textSecondary)),
        ]),
      ),
    );
  }

  Widget _trendRow(String label, String value, int current, int max, IconData icon, Color color, Themed t) {
    final pct = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.divider), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: t.textPrimary)),
          ]),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(value, key: ValueKey(value), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          ),
        ]),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: pct),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (_, val, __) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: val, minHeight: 8, backgroundColor: t.divider, valueColor: AlwaysStoppedAnimation<Color>(color)),
          ),
        ),
        const SizedBox(height: 6),
        Text('${(pct * 100).toInt()}% of target', style: TextStyle(fontSize: 11, color: t.textSecondary)),
      ]),
    );
  }

  Widget _alertSummary(AppProvider ap, Themed t) {
    final criticalCount = ap.alerts.where((a) => a.severity == 'critical' || a.severity == 'sos').length;
    final warningCount = ap.alerts.where((a) => a.severity == 'warning').length;
    final newCount = ap.alerts.where((a) => a.status == 'new').length;
    final resolvedCount = ap.alerts.where((a) => a.status == 'resolved').length;

    return Card(
      color: t.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _alertSummaryRow('Critical Alerts', criticalCount.toString(), AppColors.danger, t),
          const Divider(height: 20),
          _alertSummaryRow('Warning Alerts', warningCount.toString(), AppColors.warning, t),
          const Divider(height: 20),
          _alertSummaryRow('New (Unread)', newCount.toString(), AppColors.primary, t),
          const Divider(height: 20),
          _alertSummaryRow('Resolved', resolvedCount.toString(), AppColors.accent, t),
        ]),
      ),
    );
  }

  Widget _alertSummaryRow(String label, String count, Color color, Themed t) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 14, color: t.textPrimary)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: Text(count, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ),
    ]);
  }

  Widget _adherenceRow(String label, int percentage, Themed t) {
    final color = percentage >= 90 ? AppColors.accent : percentage >= 75 ? AppColors.warning : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.divider), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: t.textPrimary)),
          Text('$percentage%', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ]),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: percentage / 100),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (_, val, __) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: val, minHeight: 8, backgroundColor: t.divider, valueColor: AlwaysStoppedAnimation<Color>(color)),
          ),
        ),
      ]),
    );
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      );
}
