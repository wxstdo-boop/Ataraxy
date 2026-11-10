part of 'favorites_screen.dart';

class _MediaPlayerWidget extends StatefulWidget {
  final File file;
  final String fileName;
  final double blurValue;
  final bool isAudio;

  const _MediaPlayerWidget({
    required this.file,
    required this.fileName,
    this.blurValue = 0.0,
    this.isAudio = false,
  });

  @override
  State<_MediaPlayerWidget> createState() => _MediaPlayerWidgetState();
}

class _MediaPlayerWidgetState extends State<_MediaPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    // Imported backups store absolute mediaUrl paths from the original
    // device, which can reference non-existent files after restore. Short-
    // circuit to an explicit "missing" placeholder so the player doesn't
    // spin forever trying to open a ghost file.
    if (!widget.file.existsSync()) {
      _missing = true;
      return;
    }
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
        // For audio, start playing automatically when the dialog opens so the
        // user doesn't have to tap play just to listen to music.
        if (widget.isAudio) {
          _controller.play();
        } else {
          // Loop video so it repeats until the user pauses or leaves the dialog.
          _controller.setLooping(true);
        }
      }).catchError((_) {
        if (mounted) setState(() => _error = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_missing) {
      // Media file referenced by an import was not found on this device.
      // Show a clear placeholder so the user understands why playback
      // can't start instead of staring at a spinner.
      return Container(
        width: 280,
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black26,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image_rounded,
                  size: 56, color: AppAccents.amber),
              const SizedBox(height: 12),
              Text(
                L.tr(context, 'fileNotFound'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.fileName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    if (_error) {
      return Container(
        width: 240,
        height: 320,
        decoration: BoxDecoration(
          color: Colors.black26,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: AppAccents.danger),
              const SizedBox(height: 12),
              Text(
                widget.fileName,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    if (!_initialized) {
      return Container(
        width: 240,
        height: 320,
        decoration: BoxDecoration(
          color: Colors.black26,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: widget.isAudio ? 16 / 9 : _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Always keep the platform VideoPlayer in the tree so the
                  // controller's texture stays attached for both video and audio.
                  Opacity(
                    opacity: widget.isAudio ? 0.0 : 1.0,
                    child: VideoPlayer(_controller),
                  ),
                  if (widget.isAudio)
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2C1B4A), Color(0xFF0D0D1A)],
                        ),
                      ),
                    ),
                  if (widget.blurValue > 0 && !widget.isAudio)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: widget.blurValue,
                          sigmaY: widget.blurValue,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  if (widget.isAudio)
                    Positioned.fill(
                      child: _AudioVisualizer(controller: _controller),
                    ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                    child: AnimatedOpacity(
                      opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _VideoSeekBar(controller: _controller),
      ],
    );
  }
}

/// Beautiful smooth custom video seek bar with animated thumb and gradient track.
class _VideoSeekBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoSeekBar({required this.controller});
  @override
  State<_VideoSeekBar> createState() => _VideoSeekBarState();
}

class _VideoSeekBarState extends State<_VideoSeekBar>
    with SingleTickerProviderStateMixin {
  double _dragValue = 0.0;
  bool _dragging = false;
  late final AnimationController _heartbeat;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartGlow;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);

    // Slow, smooth musical pulse (~70 BPM): gentle swell and decay. It
    // only runs while the media is actually playing so it doesn't distract
    // when paused.
    _heartbeat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_heartbeat);

    // Glow follows the same envelope — a wide, soft halo that never
    // reaches the outer edges.
    _heartGlow = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.55)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.55, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_heartbeat);

    // Start the pulse if the video is already playing when the bar builds.
    _syncPulseWithPlayback();
  }

  @override
  void dispose() {
    _heartbeat.dispose();
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!_dragging && mounted) setState(() {});
    _syncPulseWithPlayback();
  }

  void _syncPulseWithPlayback() {
    final isPlaying = widget.controller.value.isPlaying;
    if (isPlaying) {
      if (!_heartbeat.isAnimating) {
        _heartbeat.repeat();
      }
    } else if (_heartbeat.isAnimating &&
        _heartbeat.value > 0.0 &&
        _heartbeat.status != AnimationStatus.reverse) {
      // Smoothly return to the resting state so the labels don't jump.
      _heartbeat.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  double get _progress {
    final d = widget.controller.value.duration;
    if (d == Duration.zero) return 0.0;
    return (widget.controller.value.position.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '${d.inMinutes}:$s';
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.controller.value.duration;
    final position = widget.controller.value.position;
    final buffered = widget.controller.value.buffered.isNotEmpty
        ? widget.controller.value.buffered.last.end.inMilliseconds / duration.inMilliseconds
        : 0.0;
    final displayProgress = _dragging ? _dragValue : _progress;

    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Track
          GestureDetector(
            onHorizontalDragStart: (_) => setState(() => _dragging = true),
            onHorizontalDragUpdate: (d) {
              final box = context.findRenderObject() as RenderBox;
              final localX = d.localPosition.dx.clamp(0.0, box.size.width);
              setState(() => _dragValue = localX / box.size.width);
            },
            onHorizontalDragEnd: (d) {
              setState(() => _dragging = false);
              if (duration != Duration.zero) {
                widget.controller.seekTo(Duration(
                  milliseconds: (duration.inMilliseconds * _dragValue).round(),
                ));
              }
            },
            onTapDown: (d) {
              final box = context.findRenderObject() as RenderBox;
              final ratio = (d.localPosition.dx / box.size.width).clamp(0.0, 1.0);
              if (duration != Duration.zero) {
                widget.controller.seekTo(Duration(
                  milliseconds: (duration.inMilliseconds * ratio).round(),
                ));
              }
            },
            child: Container(
              height: 40,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Background track — voluminous, rounded, with depth.
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  // Buffered
                  FractionallySizedBox(
                    widthFactor: buffered.clamp(0.0, 1.0),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  // Played — rich gradient with inner glow.
                  FractionallySizedBox(
                    widthFactor: displayProgress.clamp(0.0, 1.0),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        // Muted rose ramp instead of the neon
                        // #FF6B9D → #FF9FB6 → #FFC3D9 gradient.
                        gradient: const LinearGradient(
                          colors: [
                            AppAccents.rose,
                            AppAccents.roseLight,
                            AppAccents.rosePale,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: AppAccents.rose.withValues(alpha: 0.35),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Thumb — larger, with a soft outer halo and 3D-ish border.
                  Positioned(
                    left: () {
                      final thumbW = _dragging ? 22.0 : 18.0;
                      return (displayProgress * (280 - thumbW))
                          .clamp(0.0, 280 - thumbW);
                    }(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: _dragging ? 22 : 18,
                      height: _dragging ? 22 : 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: AppAccents.rose,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppAccents.rose.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Time labels — wrapped in a heartbeat pulse (scale + glow) so the
          // row visibly "curves" like a heartbeat, in continuous rhythm.
          // Padding keeps the glow from touching the screen edges.
          AnimatedBuilder(
            animation: _heartbeat,
            builder: (context, child) {
              final glow = _heartGlow.value;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: glow > 0
                        ? [
                            BoxShadow(
                              color: AppAccents.rose
                                  .withValues(alpha: glow * 0.35),
                              blurRadius: 18 + glow * 12,
                              spreadRadius: glow * 1.5,
                            ),
                          ]
                        : const [],
                  ),
                  child: Transform.scale(
                    scale: _heartScale.value,
                    child: child,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated audio visualizer made of rounded, glowing bars.
class _AudioVisualizer extends StatefulWidget {
  final VideoPlayerController controller;

  const _AudioVisualizer({required this.controller});

  @override
  State<_AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<_AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) => CustomPaint(
          painter: _AudioVisualizerPainter(
            controller: widget.controller,
            animationValue: _anim.value,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _AudioVisualizerPainter extends CustomPainter {
  final VideoPlayerController controller;
  final double animationValue;

  const _AudioVisualizerPainter({
    required this.controller,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isPlaying = controller.value.isPlaying;
    final t = animationValue * 2 * pi + controller.value.position.inMilliseconds * 0.005;

    const barCount = 7;
    final availableW = size.width * 0.75;
    final barW = availableW / (barCount * 1.5);
    final spacing = barW * 0.5;
    final totalW = barCount * barW + (barCount - 1) * spacing;
    final startX = (size.width - totalW) / 2;
    final maxH = size.height * 0.45;
    final minH = size.height * 0.05;

    final baseGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      // Rose → mauve instead of the neon pink/violet waveform.
      colors: const [
        AppAccents.rose,
        AppAccents.roseLight,
        AppAccents.mauve,
      ],
    );

    for (int i = 0; i < barCount; i++) {
      double value;
      if (isPlaying) {
        value = 0.45 +
            0.35 * sin(t + i * 0.85) +
            0.20 * sin(t * 1.7 + i * 1.4);
      } else {
        value = 0.18 + 0.10 * sin(t * 0.5 + i * 0.9);
      }
      value = value.clamp(0.0, 1.0);
      final barH = minH + value * (maxH - minH);
      final x = startX + i * (barW + spacing);
      final y = (size.height - barH) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barW, barH),
        Radius.circular(barW / 2),
      );
      final paint = Paint()
        ..shader = baseGradient.createShader(
          Rect.fromLTWH(x, y, barW, barH),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AudioVisualizerPainter old) => true;
}

/// Fullscreen crop overlay — user drags to select a rectangular region.
class _CropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final double aspectRatio;
  const _CropScreen({required this.imageBytes, required this.aspectRatio});
  @override
  State<_CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<_CropScreen> {
  Offset _start = Offset.zero;
  Offset _end = Offset.zero;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(L.tr(context, 'crop'), style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: L.tr(context, 'apply'),
            onPressed: _applyCrop,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;
          final imgW = maxW * 0.92;
          final imgH = imgW / widget.aspectRatio;
          final offsetX = (maxW - imgW) / 2;
          final offsetY = (maxH - imgH) / 2;
          if (!_initialized && imgW > 0) {
            _start = Offset(imgW * 0.1, imgH * 0.1);
            _end = Offset(imgW * 0.9, imgH * 0.9);
            _initialized = true;
          }
          return Stack(
            children: [
              // The actual image underneath
              Positioned(
                left: offsetX,
                top: offsetY,
                width: imgW,
                height: imgH,
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.contain,
                  width: imgW,
                  height: imgH,
                ),
              ),
              // Semi-transparent overlay with crop cutout
              Positioned(
                left: offsetX,
                top: offsetY,
                width: imgW,
                height: imgH,
                child: GestureDetector(
                  onPanStart: (d) {
                    setState(() {
                      _start = d.localPosition;
                      _end = d.localPosition;
                    });
                  },
                  onPanUpdate: (d) {
                    setState(() => _end = d.localPosition);
                  },
                  onPanEnd: (_) {},
                  child: Stack(
                    children: [
                      // Dim overlay with hole
                      CustomPaint(
                        painter: _CropOverlayPainter(
                          start: _start,
                          end: _end,
                          imgW: imgW,
                          imgH: imgH,
                        ),
                        size: Size(imgW, imgH),
                      ),
                      // Corner handles
                      ..._buildHandles(imgW, imgH),
                    ],
                  ),
                ),
              ),
              // Hint text
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    L.tr(context, 'cropHint'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildHandles(double imgW, double imgH) {
    final left = _cropLeft.clamp(0.0, imgW);
    final top = _cropTop.clamp(0.0, imgH);
    final right = _cropRight.clamp(0.0, imgW);
    final bottom = _cropBottom.clamp(0.0, imgH);
    return [
      Positioned(left: left - 8, top: top - 8, child: _handle(Colors.white)),
      Positioned(left: right - 8, top: top - 8, child: _handle(Colors.white)),
      Positioned(left: left - 8, top: bottom - 8, child: _handle(Colors.white)),
      Positioned(left: right - 8, top: bottom - 8, child: _handle(Colors.white)),
    ];
  }

  Widget _handle(Color c) => Container(
    width: 16, height: 16,
    decoration: BoxDecoration(
      color: c, shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
    ),
  );

  double get _cropLeft => _start.dx < _end.dx ? _start.dx : _end.dx;
  double get _cropTop => _start.dy < _end.dy ? _start.dy : _end.dy;
  double get _cropRight => _start.dx > _end.dx ? _start.dx : _end.dx;
  double get _cropBottom => _start.dy > _end.dy ? _start.dy : _end.dy;

  void _applyCrop() {
    final left = _cropLeft;
    final top = _cropTop;
    final w = _cropRight - left;
    final h = _cropBottom - top;
    if (w < 10 || h < 10) {
      AnimatedSnack.show(
        context,
        L.tr(context, 'cropTooSmall'),
        type: SnackType.warning,
      );
      return;
    }
    final imgW = MediaQuery.of(context).size.width * 0.92;
    final imgH = imgW / widget.aspectRatio;
    final ratioLeft = left / imgW;
    final ratioTop = top / imgH;
    final ratioW = w / imgW;
    final ratioH = h / imgH;
    Navigator.of(context).pop(Rect.fromLTWH(
      ratioLeft.clamp(0.0, 1.0),
      ratioTop.clamp(0.0, 1.0),
      ratioW.clamp(0.01, 1.0),
      ratioH.clamp(0.01, 1.0),
    ));
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Offset start, end;
  final double imgW, imgH;
  _CropOverlayPainter({required this.start, required this.end, required this.imgW, required this.imgH});

  @override
  void paint(Canvas canvas, Size size) {
    final left = (start.dx < end.dx ? start.dx : end.dx).clamp(0.0, size.width);
    final top = (start.dy < end.dy ? start.dy : end.dy).clamp(0.0, size.height);
    final right = (start.dx > end.dx ? start.dx : end.dx).clamp(0.0, size.width);
    final bottom = (start.dy > end.dy ? start.dy : end.dy).clamp(0.0, size.height);
    final cropRect = Rect.fromLTRB(left, top, right, bottom);
    final fullRect = Offset.zero & size;
    // Semi-transparent overlay
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.saveLayer(fullRect, Paint());
    canvas.drawRect(fullRect, overlay);
    // Clear the crop area
    canvas.drawRect(cropRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
    // Crop border
    canvas.drawRect(
      cropRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Rule of thirds lines
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 0.8;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(left + (right - left) * i / 3, top),
        Offset(left + (right - left) * i / 3, bottom),
        paint,
      );
      canvas.drawLine(
        Offset(left, top + (bottom - top) * i / 3),
        Offset(right, top + (bottom - top) * i / 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) =>
      old.start != start || old.end != end;
}
