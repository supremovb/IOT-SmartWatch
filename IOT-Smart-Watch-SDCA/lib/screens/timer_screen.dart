import 'dart:math';
import 'package:flutter/material.dart';
import '../models/watch_data.dart';

class TimerScreen extends StatefulWidget {
  final WatchController controller;
  const TimerScreen({super.key, required this.controller});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _selectedMin = 5;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Format helpers ────────────────────────────────────────────────────────

  static String mmSs(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}'
      ':${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  static String _cs(Duration d) =>
      (d.inMilliseconds % 1000 ~/ 10).toString().padLeft(2, '0');

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final accent = widget.controller.accentColor;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.4,
              colors: [accent.withOpacity(0.1), Colors.black],
            ),
          ),
          child: Column(
            children: [
              // Tab bar
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    indicator: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    labelStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        letterSpacing: 0.5),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'STOPWATCH'),
                      Tab(text: 'TIMER'),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _Stopwatch(
                        controller: widget.controller,
                        mmSs: mmSs,
                        cs: _cs),
                    _Countdown(
                        controller: widget.controller,
                        selectedMin: _selectedMin,
                        onSelectMin: (m) =>
                            setState(() => _selectedMin = m)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Stopwatch tab ─────────────────────────────────────────────────────────

class _Stopwatch extends StatelessWidget {
  final WatchController controller;
  final String Function(Duration) mmSs;
  final String Function(Duration) cs;

  const _Stopwatch(
      {required this.controller,
      required this.mmSs,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final d = controller.stopwatchDuration;
        final running = controller.stopwatchRunning;
        final laps = controller.laps;
        final accent = controller.accentColor;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            children: [
              // Clock circle
              _ClockCircle(
                running: running,
                color: accent,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      mmSs(d),
                      style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w200,
                          color: Colors.white),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '.${cs(d)}',
                        style: TextStyle(
                            fontSize: 20,
                            color: accent),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Btn(
                    icon: Icons.restart_alt,
                    color: Colors.white24,
                    onTap: controller.resetStopwatch,
                  ),
                  const SizedBox(width: 16),
                  _Btn(
                    icon: running ? Icons.pause : Icons.play_arrow,
                    color: accent,
                    size: 62,
                    onTap: running
                        ? controller.pauseStopwatch
                        : controller.startStopwatch,
                  ),
                  const SizedBox(width: 16),
                  _Btn(
                    icon: Icons.flag_outlined,
                    color: Colors.white24,
                    onTap: controller.addLap,
                  ),
                ],
              ),

              if (laps.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.builder(
                    itemCount: laps.length,
                    itemBuilder: (context, i) {
                      final idx = laps.length - 1 - i;
                      final end = laps[idx];
                      final start =
                          idx > 0 ? laps[idx - 1] : Duration.zero;
                      final lapTime = end - start;
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Text('Lap ${idx + 1}',
                                style: const TextStyle(
                                    color: Colors.white30,
                                    fontSize: 12)),
                            const Spacer(),
                            Text(
                                '${mmSs(lapTime)}.${cs(lapTime)}',
                                style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
        );
      },
    );
  }
}

// ── Countdown tab ─────────────────────────────────────────────────────────

class _Countdown extends StatelessWidget {
  final WatchController controller;
  final int selectedMin;
  final ValueChanged<int> onSelectMin;

  const _Countdown(
      {required this.controller,
      required this.selectedMin,
      required this.onSelectMin});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final remaining = controller.countdownRemaining;
        final total = controller.countdownDuration;
        final running = controller.countdownRunning;
        final finished = controller.countdownFinished;
        final accent = controller.accentColor;
        final progress = total.inSeconds > 0
            ? remaining.inSeconds / total.inSeconds
            : 0.0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            children: [
              // Countdown circle
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(160, 160),
                      painter: _CountdownPainter(
                        progress: progress,
                        color: finished
                            ? Colors.red
                            : accent,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (finished)
                          const Text('⏰',
                              style: TextStyle(fontSize: 34))
                        else
                          Text(
                            '${remaining.inMinutes.toString().padLeft(2, '0')}:'
                            '${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w200,
                              color: finished
                                  ? Colors.red
                                  : Colors.white,
                            ),
                          ),
                        if (finished)
                          const Text("TIME'S UP!",
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700))
                        else
                          const Text('remaining',
                              style: TextStyle(
                                  color: Colors.white30,
                                  fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Quick picks
              if (!running && !finished) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [1, 3, 5, 10, 20, 30].map((m) {
                    final sel = selectedMin == m;
                    return GestureDetector(
                      onTap: () {
                        onSelectMin(m);
                        controller
                            .setCountdown(Duration(minutes: m));
                      },
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? accent
                                  .withOpacity(0.25)
                              : Colors.white.withOpacity(0.05),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? accent
                                : Colors.white12,
                          ),
                        ),
                        child: Text('${m}m',
                            style: TextStyle(
                              fontSize: 12,
                              color: sel
                                  ? accent
                                  : Colors.white38,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            )),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Btn(
                    icon: Icons.restart_alt,
                    color: Colors.white24,
                    onTap: controller.resetCountdown,
                  ),
                  const SizedBox(width: 16),
                  _Btn(
                    icon: running ? Icons.pause : Icons.play_arrow,
                    color: finished
                        ? Colors.red
                        : accent,
                    size: 62,
                    onTap: running
                        ? controller.pauseCountdown
                        : controller.startCountdown,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────

class _ClockCircle extends StatelessWidget {
  final bool running;
  final Widget label;
  final Color color;
  const _ClockCircle({required this.running, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: 170,
        height: 170,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: running
                ? color.withOpacity(0.55)
                : Colors.white12,
            width: 2,
          ),
          boxShadow: running
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 22,
                    spreadRadius: 4,
                  )
                ]
              : null,
        ),
        child: Center(child: label),
      );
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _Btn(
      {required this.icon,
      required this.color,
      this.size = 48,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.18),
            border: Border.all(color: color.withOpacity(0.45)),
          ),
          child: Icon(icon,
              color: color == Colors.white24
                  ? Colors.white54
                  : Colors.white,
              size: size * 0.44),
        ),
      );
}

// ── Countdown ring painter ────────────────────────────────────────────────

class _CountdownPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _CountdownPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;

    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color.withOpacity(0.1)
          ..strokeWidth = 9
          ..style = PaintingStyle.stroke);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -pi / 2,
        progress * 2 * pi,
        false,
        Paint()
          ..color = color
          ..strokeWidth = 9
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CountdownPainter old) =>
      old.progress != progress || old.color != color;
}
