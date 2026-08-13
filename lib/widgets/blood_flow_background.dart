import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Blood for the MUTILATED theme. This layer is painted ON TOP of the app
/// (IgnorePointer, so it never blocks touches) — soft crimson stains that
/// slowly drift over the section backgrounds, so the blood reads clearly
/// over translucent surfaces instead of hiding behind them.
///
/// Only the sweeping blotches remain (no dripping drops). Motion uses ONLY
/// continuous functions of the raw elapsed time (sine / triangle waves),
/// so the animation is genuinely infinite — there is no loop boundary at
/// all, hence no restart pop and no sharp transition to a "new" pattern.
/// On the first second the whole layer fades in gently instead of popping.
class BloodFlowBackground extends StatelessWidget {
  const BloodFlowBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _BloodPainter(),
        ),
      ),
    );
  }
}

class _BloodPainter extends CustomPainter {
  _BloodPainter() : super(repaint: _BloodTicker.instance);

  static const Color _crimson = Color(0xFFC1121F); // fresh bright blood

  /// Per-stain cached shader + the quantized alpha bucket it was built for.
  /// The gradient is created ONCE per unit circle per stain and reused for
  /// every lobe via canvas transforms (translate+scale), so a full frame
  /// costs ~30 cheap drawCircle calls instead of 30 gradient constructions
  /// — the exact visual, a fraction of the GPU work (the old per-circle
  /// shader creation was the main lag on Redmi Note 12). Each stain keeps
  /// its own cache so its alpha always matches its own fade.
  static const int _stainCount = 6;
  final List<double> _buckets = List.filled(_stainCount, -1);
  final List<Paint> _paints =
      List.generate(_stainCount, (_) => Paint());

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final t = _BloodTicker.instance.elapsed;
    // Gentle entry: the layer breathes in over the first ~2.4s instead of
    // snapping on (matches the splash cross-fade) — an extra-slow ease so
    // the stain entry reads as a soft bloom, never a pop.
    final entry = (t / 2.4).clamp(0.0, 1.0);

    // --- Sweeping stains: big irregular blotches that drift slowly across
    // the screen (like pooled blood), fading in mid-screen and out at the
    // extremes. Each stain is a cluster of soft overlapping circles → an
    // organic amoeba, not a round dot. ---
    // [xAnchor, phase, radius, speed] — speed = up-down cycles per 150s:
    // one full glide takes ~27-75s (2-3x slower than the old pacing) —
    // the stains still visibly drift, but never hurry.
    const stains = [
      [0.10, 0.12, 200.0, 3.0],
      [0.30, 0.55, 240.0, 4.5],
      [0.55, 0.22, 220.0, 2.5],
      [0.75, 0.75, 260.0, 5.5],
      [0.92, 0.05, 180.0, 3.5],
      [0.45, 0.95, 280.0, 2.0],
    ];
    for (var i = 0; i < stains.length; i++) {
      final s = stains[i];
      final x0 = s[0];
      final phase = s[1];
      final r = s[2];
      final speed = s[3];
      // Continuous triangle wave 0..1..0: acos(cos(x))/pi is periodic and
      // smooth for EVERY x — the stain glides down, fades out at the
      // bottom, reverses, glides back up, forever. No wrap, no snap.
      // speed is already in cycles/150s: /150 converts to cycles/sec.
      final p = math.acos(math.cos((t * speed / 150 + phase) * math.pi * 2)) /
          math.pi;
      // Sine envelope: invisible at the extremes (p=0 and p=1), full
      // mid-screen — the blotch never pops in/out, it breathes smoothly
      // over many seconds.
      final fade = math.sin(p * math.pi) * entry;
      if (fade < 0.02) continue; // invisible → skip, saves the draw
      final y = p * h;
      // Extremely slow horizontal sway (~55s per full swing) and slow
      // radius breathing — the whole scene is a lazy underwater drift.
      final x = x0 * w + math.sin((t * 0.018 + x0) * math.pi * 2) * w * 0.05;
      final radius = r * (0.85 + 0.15 * math.sin(t * 0.035 + i * 2.3));
      // Rebuild this stain's gradient only when its fade crossed a bucket
      // boundary (steps of 1/300 — invisible); otherwise reuse the cache.
      final bucket = (fade * 300).round();
      final paint = _paints[i];
      if (bucket != _buckets[i]) {
        _buckets[i] = bucket.toDouble();
        paint.shader = RadialGradient(
          colors: [
            _crimson.withValues(alpha: 0.11 * fade),
            _crimson.withValues(alpha: 0.045 * fade),
            _crimson.withValues(alpha: 0.0),
          ],
          // Unit-circle gradient; drawn scaled/translated below.
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
      }
      final base = Offset(x, y);
      // Amoeba cluster: one big core + a few smaller lobes around it.
      final lobes = [
        Offset.zero,
        Offset(radius * 0.52, radius * 0.38),
        Offset(-radius * 0.48, radius * 0.52),
        Offset(radius * 0.22, -radius * 0.58),
        Offset(-radius * 0.30, -radius * 0.34),
      ];
      for (var li = 0; li < lobes.length; li++) {
        final c = base + lobes[li];
        final rr = li == 0 ? radius : radius * 0.5;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(rr, rr);
        canvas.drawCircle(Offset.zero, 1, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_BloodPainter oldDelegate) => true;
}

/// A tiny global ticker that nudges all [BloodFlowBackground] painters at
/// ~12fps — the stains move at sub-pixel speed per tick (a full glide takes
/// 27-75s), so 12fps is visually identical to 20fps while cutting the
/// full-screen recomposite load by ~40% on low-end phones (Redmi Note 12).
class _BloodTicker extends ChangeNotifier {
  _BloodTicker._() {
    // Optimized for Redmi Note 12: reduced from 80ms (12.5fps) to 125ms (~8fps)
    // The blood stains move very slowly (27-75s per full glide), so 8fps is
    // visually indistinguishable from 12fps but reduces GPU load by ~35%.
    Timer.periodic(const Duration(milliseconds: 125), (_) => notifyListeners());
  }

  static final _BloodTicker instance = _BloodTicker._();

  final DateTime _start = DateTime.now();

  double get elapsed =>
      DateTime.now().difference(_start).inMilliseconds / 1000.0;
}
