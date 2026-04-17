import 'package:flutter/material.dart';
import '../models/watch_data.dart';
import '../services/esp32_service.dart';

class SettingsScreen extends StatefulWidget {
  final WatchController controller;
  final Esp32Service? esp32;
  const SettingsScreen({super.key, required this.controller, this.esp32});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipController = TextEditingController(text: '192.168.1.100');
  bool _connecting = false;

  WatchController get controller => widget.controller;
  Esp32Service? get esp32 => widget.esp32;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _connectBLE() async {
    if (esp32 == null) return;
    setState(() => _connecting = true);
    final ok = await esp32!.connectBLE();
    setState(() => _connecting = false);
    if (ok) esp32!.startSync(controller);
  }

  Future<void> _connectWS() async {
    if (esp32 == null) return;
    setState(() => _connecting = true);
    final ok = await esp32!.connectWebSocket(_ipController.text.trim());
    setState(() => _connecting = false);
    if (ok) esp32!.startSync(controller);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final accent = controller.accentColor;

        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.4,
              colors: [accent.withOpacity(0.07), Colors.black],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              const Text(
                'SETTINGS',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),

              // ── Theme ──────────────────────────────
              _section(
                'ACCENT COLOR',
                [_ThemePicker(controller: controller)],
              ),
              const SizedBox(height: 10),

              // ── Display ────────────────────────────
              _section('DISPLAY', [
                _toggle(
                  '24‑Hour Time',
                  Icons.schedule_outlined,
                  controller.is24Hour,
                  controller.toggle24Hour,
                  accent,
                ),
              ]),
              const SizedBox(height: 10),

              // ── Device ─────────────────────────────
              _section('DEVICE', [
                _info('Model', 'SmartWatch Pro X', Icons.watch_outlined),
                _divider(),
                _info('Firmware', 'v3.2.1', Icons.memory_outlined),
                _divider(),
                _info('Battery',
                    '${controller.health.battery}%',
                    Icons.battery_5_bar_outlined),
                _divider(),
                _infoWidget(
                  'Battery Level',
                  Icons.battery_charging_full_outlined,
                  LinearProgressIndicator(
                    value: controller.health.battery / 100,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      controller.health.battery > 30
                          ? Colors.green
                          : Colors.red,
                    ),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              // ── Goals ──────────────────────────────
              _section('DAILY GOALS', [
                _goalRow('👟', 'Steps',
                    '${_fmt(controller.stepGoal)} steps',
                    controller.health.steps / controller.stepGoal,
                    accent),
                _divider(),
                _goalRow('🔥', 'Calories',
                    '${controller.calorieGoal.toInt()} kcal',
                    controller.health.calories /
                        controller.calorieGoal,
                    Colors.orange),
                _divider(),
                _goalRow('📍', 'Distance',
                    '${controller.distanceGoal} km',
                    controller.health.distance /
                        controller.distanceGoal,
                    Colors.blue),
                _divider(),
                _goalRow('💤', 'Sleep', '8 hours', 0.91,
                    Colors.deepPurple),
              ]),

              const SizedBox(height: 10),

              // ── About ──────────────────────────────
              _section('ABOUT', [
                _info('App Version', '1.0.0', Icons.info_outline),
                _divider(),
                _info('Connected Phone', 'iPhone 15 Pro',
                    Icons.smartphone_outlined),
                _divider(),
                _info('Last Synced', 'Just now',
                    Icons.sync_outlined),
              ]),

              if (esp32 != null) ...[
                const SizedBox(height: 10),
                _section('ESP32 CONNECTION', [
                  _buildEsp32Section(accent),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Section wrapper ─────────────────────────────────────────────────────

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white24,
                    fontSize: 9,
                    letterSpacing: 1.5)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(children: children),
          ),
        ],
      );

  Widget _divider() =>
      const Divider(height: 1, color: Colors.white10, indent: 14);

  Widget _toggle(String label, IconData icon, bool value,
      VoidCallback onTap, Color accent) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white38, size: 18),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13)),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: value
                    ? accent.withOpacity(0.25)
                    : Colors.white10,
                border: Border.all(
                    color: value ? accent : Colors.white24),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? accent : Colors.white38,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value, IconData icon) =>
      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: Colors.white30, size: 16),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12)),
          ],
        ),
      );

  Widget _infoWidget(
          String label, IconData icon, Widget trailing) =>
      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: Colors.white30, size: 16),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12)),
            const SizedBox(width: 10),
            Expanded(child: trailing),
          ],
        ),
      );

  Widget _goalRow(String icon, String label, String target,
      double progress, Color color) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12)),
              Text(target,
                  style: const TextStyle(
                      color: Colors.white30, fontSize: 10)),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    '${(progress.clamp(0.0, 1.0) * 100).toInt()}%',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white10,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(0)}K' : '$n';

  Widget _buildEsp32Section(Color accent) {
    final ble = esp32?.bleConnected ?? false;
    final ws = esp32?.wsConnected ?? false;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Icon(Icons.bluetooth, size: 16, color: ble ? Colors.blue : Colors.white30),
              const SizedBox(width: 6),
              Text('BLE: ${ble ? "Connected" : "Off"}',
                  style: TextStyle(color: ble ? Colors.blue : Colors.white54, fontSize: 12)),
              const SizedBox(width: 16),
              Icon(Icons.wifi, size: 16, color: ws ? Colors.green : Colors.white30),
              const SizedBox(width: 6),
              Text('WiFi: ${ws ? "Connected" : "Off"}',
                  style: TextStyle(color: ws ? Colors.green : Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),

          // BLE button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _connecting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(ble ? Icons.bluetooth_disabled : Icons.bluetooth_searching, size: 16),
              label: Text(ble ? 'Disconnect BLE' : 'Connect BLE', style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ble ? Colors.red.withOpacity(0.2) : accent.withOpacity(0.2),
                foregroundColor: ble ? Colors.red : accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: _connecting
                  ? null
                  : () {
                      if (ble) {
                        esp32!.disconnectBLE();
                        setState(() {});
                      } else {
                        _connectBLE();
                      }
                    },
            ),
          ),
          const SizedBox(height: 8),

          // WiFi IP + connect
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'ESP32 IP address',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white24)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ws ? Colors.red.withOpacity(0.2) : accent.withOpacity(0.2),
                  foregroundColor: ws ? Colors.red : accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: _connecting
                    ? null
                    : () {
                        if (ws) {
                          esp32!.disconnectWebSocket();
                          setState(() {});
                        } else {
                          _connectWS();
                        }
                      },
                child: Text(ws ? 'Disconnect' : 'Connect WiFi', style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Theme color picker ────────────────────────────────────────────────────

class _ThemePicker extends StatelessWidget {
  final WatchController controller;
  const _ThemePicker({required this.controller});

  static const _themes = WatchController.themeColors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _themes.entries.map((e) {
          final sel = controller.theme == e.key;
          return GestureDetector(
            onTap: () => controller.setTheme(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: e.value.withOpacity(0.25),
                border: Border.all(
                  color: sel ? e.value : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: e.value.withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: sel
                  ? Icon(Icons.check, color: e.value, size: 20)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
