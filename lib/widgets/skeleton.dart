import 'package:flutter/material.dart';

/// Wraps a subtree of [SkeletonBox]es with one shared sliding shimmer.
///
/// A single [AnimationController] powers every box inside, so all skeletons
/// pulse in sync and the app pays for exactly one repaint stream instead of
/// one controller per placeholder (that was the old per-card animation cost
/// that caused scroll jank on low-end devices).
class Skeleton extends StatefulWidget {
  final Widget child;

  const Skeleton({super.key, required this.child});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final v = _ctrl.value;
        // A soft light band that slides diagonally across the skeleton.
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.5 + 3 * v, -0.5),
            end: Alignment(0.5 + 3 * v, 1.5),
            colors: [
              base,
              Colors.white.withValues(alpha: 0.30),
              base,
            ],
            stops: const [0.30, 0.50, 0.70],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A single rounded placeholder block. The shimmer gradient is applied by the
/// enclosing [Skeleton].
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final Color? color;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color:
            color ??
            Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.85,
            ),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A full loading list shaped like the home screen's entry cards, used while
/// entries are being read from storage.
class SkeletonList extends StatelessWidget {
  final int count;

  const SkeletonList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: count,
        itemBuilder: (_, _) => const SkeletonCard(),
      ),
    );
  }
}

/// One placeholder card mirroring the layout of a real entry card (badge row,
/// title, preview lines, tag chips) so the skeleton is recognisable as the
/// content that is about to appear.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 86, height: 22, radius: 11),
              Spacer(),
              SkeletonBox(width: 48, height: 14, radius: 7),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBox(width: 220, height: 18, radius: 9),
          SizedBox(height: 8),
          SkeletonBox(width: double.infinity, height: 13, radius: 6),
          SizedBox(height: 6),
          SkeletonBox(width: 180, height: 13, radius: 6),
          SizedBox(height: 14),
          Row(
            children: [
              SkeletonBox(width: 60, height: 20, radius: 10),
              SizedBox(width: 8),
              SkeletonBox(width: 44, height: 20, radius: 10),
            ],
          ),
        ],
      ),
    );
  }
}
