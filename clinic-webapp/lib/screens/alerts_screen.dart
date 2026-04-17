import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/app_provider.dart';
import '../models/alert_model.dart';
import '../widgets/top_bar.dart';

class AlertsScreen extends StatefulWidget {
  final void Function(String)? onNavigate;
  const AlertsScreen({super.key, this.onNavigate});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  String _filterStatus = 'all';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppProvider>().silentRefreshAll();
      }
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        context.read<AppProvider>().silentRefreshAll();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppColors.themed(context);
    final appProvider = context.watch<AppProvider>();
    final newAlerts = appProvider.alerts.where((a) => a.status == 'new').length;
    final inProgressAlerts = appProvider.alerts.where((a) => a.status == 'in-progress').length;
    final escalatedAlerts = appProvider.alerts.where((a) => a.status == 'escalated').length;
    final resolvedAlerts = appProvider.alerts.where((a) => a.status == 'resolved').length;

    return Column(
      children: [
        TopBar(onProfileTap: () => widget.onNavigate?.call('/settings'), onNavigate: widget.onNavigate),
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        if (isMobile) {
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Alerts & Notifications', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: t.textPrimary)),
                            const SizedBox(height: 4),
                            Text('${appProvider.alerts.length} total alerts • $newAlerts new', style: TextStyle(fontSize: 13, color: t.textSecondary)),
                            const SizedBox(height: 12),
                            Row(children: [
                              if (newAlerts > 0) ...[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.done_all, size: 18),
                                    label: const Text('Mark All Read'),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                    onPressed: () {
                                      appProvider.markAllAlertsRead();
                                      _snack('All alerts marked as read', AppColors.accent);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              _buildFilterChip(t),
                            ]),
                          ]);
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Alerts & Notifications', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: t.textPrimary)),
                              const SizedBox(height: 4),
                              Text('${appProvider.alerts.length} total alerts • $newAlerts new', style: TextStyle(fontSize: 13, color: t.textSecondary)),
                            ]),
                            Row(children: [
                              if (newAlerts > 0)
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.done_all, size: 18),
                                  label: const Text('Mark All Read'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  onPressed: () {
                                    appProvider.markAllAlertsRead();
                                    _snack('All alerts marked as read', AppColors.accent);
                                  },
                                ),
                              const SizedBox(width: 12),
                              _buildFilterChip(t),
                            ]),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Stats Row
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cards = [
                          _statCard('New', newAlerts, AppColors.themed(context).primary, Icons.fiber_new),
                          _statCard('In Progress', inProgressAlerts, AppColors.themed(context).warning, Icons.pending_actions),
                          _statCard('Escalated', escalatedAlerts, AppColors.themed(context).danger, Icons.arrow_upward),
                          _statCard('Resolved', resolvedAlerts, AppColors.themed(context).accent, Icons.check_circle),
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
                    // Alerts List
                    Text('Recent Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.textPrimary)),
                    const SizedBox(height: 16),
                    ..._buildAlertsList(appProvider, t),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(Themed t) {
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => _filterStatus = v),
      itemBuilder: (_) => [
        _menuItem('all', 'All Alerts', Icons.list),
        _menuItem('new', 'New', Icons.fiber_new),
        _menuItem('in-progress', 'In Progress', Icons.pending_actions),
        _menuItem('escalated', 'Escalated', Icons.arrow_upward),
        _menuItem('resolved', 'Resolved', Icons.check_circle),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.divider), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.filter_list, size: 18),
          const SizedBox(width: 8),
          Text('Filter: ${_filterLabel()}', style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 18),
        ]),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label, IconData icon) => PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon, size: 18, color: _filterStatus == value ? AppColors.primary : null),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: _filterStatus == value ? FontWeight.bold : FontWeight.normal)),
        ]),
      );

  String _filterLabel() {
    switch (_filterStatus) {
      case 'new': return 'New';
      case 'in-progress': return 'In Progress';
      case 'escalated': return 'Escalated';
      case 'resolved': return 'Resolved';
      default: return 'All';
    }
  }

  Widget _statCard(String title, int count, Color color, IconData icon) {
    final t = AppColors.themed(context);
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(icon, color: color, size: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(count.toString(), key: ValueKey('$title-$count'), style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: t.textSecondary, fontSize: 12)),
        ]),
      ),
    );
  }

  List<Widget> _buildAlertsList(AppProvider appProvider, Themed t) {
    final threshold = appProvider.alertThreshold;
    final alerts = appProvider.alerts.where((alert) {
      if (_filterStatus != 'all' && alert.status != _filterStatus) return false;
      if (threshold == 'low' && alert.severity != 'critical' && alert.severity != 'sos') return false;
      if (threshold == 'medium' && alert.severity != 'critical' && alert.severity != 'sos' && alert.severity != 'warning') return false;
      return true;
    }).toList();

    if (alerts.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Column(children: [
              Icon(Icons.notifications_none, size: 56, color: t.textHint),
              const SizedBox(height: 12),
              Text(_filterStatus == 'all' ? 'No alerts to display' : 'No ${_filterLabel().toLowerCase()} alerts',
                  style: TextStyle(color: t.textSecondary, fontSize: 15)),
            ]),
          ),
        ),
      ];
    }

    return alerts.asMap().entries.map((entry) {
      final index = entry.key;
      final alert = entry.value;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 300 + (index * 80).clamp(0, 600)),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
        ),
        child: _buildAlertCard(alert, appProvider, t),
      );
    }).toList();
  }

  Widget _buildAlertCard(AlertModel alert, AppProvider appProvider, Themed t) {
    final isCritical = alert.severity == 'critical' || alert.severity == 'sos';
    final t2 = AppColors.themed(context);
    final severityColor = isCritical ? t2.danger : t2.warning;

    Color statusColor;
    IconData statusIcon;
    switch (alert.status) {
      case 'in-progress':
        statusColor = t2.warning;
        statusIcon = Icons.pending_actions;
        break;
      case 'escalated':
        statusColor = t2.danger;
        statusIcon = Icons.arrow_upward;
        break;
      case 'resolved':
        statusColor = t2.accent;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = t2.primary;
        statusIcon = Icons.fiber_new;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 500;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.divider),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: IntrinsicHeight(
            child: Row(children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(alert.id, style: TextStyle(fontSize: 11, color: t.textSecondary, fontWeight: FontWeight.w500)),
                        _badge(alert.severity.toUpperCase(), severityColor),
                        _badgeIcon(alert.status.toUpperCase(), statusColor, statusIcon),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(alert.title, style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold, color: t.textPrimary)),
                    const SizedBox(height: 4),
                    Text('${alert.patient} • ${alert.value}', style: TextStyle(fontSize: 13, color: t.textSecondary)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.access_time, size: 12, color: t.textHint),
                      const SizedBox(width: 4),
                      Flexible(child: Text(alert.timestamp, style: TextStyle(fontSize: 11, color: t.textHint), overflow: TextOverflow.ellipsis)),
                    ]),
                    if ((alert.status == 'new' || alert.status == 'in-progress') && isMobile) ...[
                      const SizedBox(height: 12),
                      _buildActionButtonsRow(alert, appProvider),
                    ],
                  ]),
                ),
              ),
              if ((alert.status == 'new' || alert.status == 'in-progress') && !isMobile)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildActionButtons(alert, appProvider),
                ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildActionButtonsRow(AlertModel alert, AppProvider appProvider) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      if (alert.status == 'new')
        _actionBtn(Icons.check, 'Acknowledge', AppColors.accent, () {
          appProvider.acknowledgeAlert(alert.id);
          _snack('Alert ${alert.id} acknowledged', AppColors.accent);
        }),
      _actionBtn(Icons.arrow_upward, 'Escalate', AppColors.primary, () {
        appProvider.escalateAlert(alert.id);
        _snack('Alert ${alert.id} escalated', AppColors.primary);
      }),
      if (alert.status == 'in-progress')
        _actionBtn(Icons.done_all, 'Resolve', AppColors.accent, () {
          appProvider.resolveAlert(alert.id);
          _snack('Alert ${alert.id} resolved', AppColors.accent);
        }),
    ]);
  }

  Widget _buildActionButtons(AlertModel alert, AppProvider appProvider) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (alert.status == 'new')
        _actionBtn(Icons.check, 'Acknowledge', AppColors.accent, () {
          appProvider.acknowledgeAlert(alert.id);
          _snack('Alert ${alert.id} acknowledged', AppColors.accent);
        }),
      if (alert.status == 'new') const SizedBox(height: 8),
      _actionBtn(Icons.arrow_upward, 'Escalate', AppColors.primary, () {
        appProvider.escalateAlert(alert.id);
        _snack('Alert ${alert.id} escalated', AppColors.primary);
      }),
      if (alert.status == 'in-progress') const SizedBox(height: 8),
      if (alert.status == 'in-progress')
        _actionBtn(Icons.done_all, 'Resolve', AppColors.accent, () {
          appProvider.resolveAlert(alert.id);
          _snack('Alert ${alert.id} resolved', AppColors.accent);
        }),
    ]);
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      );

  Widget _badgeIcon(String label, Color color, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ]),
      );

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), duration: const Duration(seconds: 2)),
      );
}
