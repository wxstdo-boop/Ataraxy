import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ataraxy/l10n/strings.dart';

class PomodoroScreen extends StatelessWidget {
  const PomodoroScreen({super.key});

  @override
  Widget build(BuildContext context) => const _PomodoroBody();
}

class _PomodoroBody extends StatefulWidget {
  const _PomodoroBody();

  @override
  State<_PomodoroBody> createState() => _PomodoroBodyState();
}

class _PomodoroBodyState extends State<_PomodoroBody> {
  static const Duration _total = Duration(minutes: 10);
  late Duration _remaining = _total;
  late final Stopwatch _sw;
  Timer? _timer;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _sw = Stopwatch();
    _start();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _start() {
    _sw.start();
    _running = true;
    _startTimer();
  }

  void _tick() {
    if (!mounted) return;
    final rem = _total - _sw.elapsed;
    if (rem <= Duration.zero) {
      _finish();
      return;
    }
    setState(() => _remaining = rem);
  }

  void _pause() {
    _sw.stop();
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _resume() {
    _sw.start();
    _running = true;
    _startTimer();
    setState(() {});
  }

  void _finish() {
    _timer?.cancel();
    _sw.stop();
    setState(() => _remaining = Duration.zero);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sw.stop();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final done = _remaining <= Duration.zero;
    final progress = done
        ? 1.0
        : 1 - _remaining.inSeconds / _total.inSeconds;
    return Scaffold(
      appBar: AppBar(title: Text(L.tr(context, 'pomodoroRunning'))),
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 260,
              height: 260,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 14,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.15),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _fmt(_remaining),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  done
                      ? L.tr(context, 'pomodoroDone')
                      : L.tr(context, 'pomodoroRunning'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: done
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded),
              label: Text(L.tr(context, 'pomodoroDone')),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'pause',
                  onPressed: _running ? _pause : _resume,
                  child: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: 'stop',
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded),
                ),
              ],
            ),
    );
  }
}
