part of 'ai_assistant_screen.dart';

/// Chat message rendering: the entrance animation, the markdown bubble
/// (with its streaming fast-path) and the thinking-dots indicator.
/// Split out of [AiFloatingAssistant]'s file to keep it readable.

/// Message bubble that eases in with a fade + slide from its side, so new
/// messages visibly appear instead of snapping into the list.
class _AnimatedMessage extends StatefulWidget {
  final AiMessageUi message;
  final ColorScheme scheme;
  /// True while this bubble is the live stream target (model typing).
  final bool streaming;
  const _AnimatedMessage({
    required this.message,
    required this.scheme,
    this.streaming = false,
  });

  @override
  State<_AnimatedMessage> createState() => _AnimatedMessageState();
}

class _AnimatedMessageState extends State<_AnimatedMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    final curved = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
    );
    _opacity = curved;
    final role = widget.message.role;
    // Reward celebration glides up from below the input; user/assistant
    // bubbles slide in from their own side.
    final begin = role == 'reward'
        ? const Offset(0, 0.7)
        : Offset(role == 'user' ? 0.35 : -0.35, 0);
    _slide = Tween<Offset>(begin: begin, end: Offset.zero).animate(curved);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: _Bubble(
          message: widget.message,
          scheme: widget.scheme,
          streaming: widget.streaming,
        ),
      ),
    );
  }
}

class _Bubble extends StatefulWidget {
  final AiMessageUi message;
  final ColorScheme scheme;
  final bool streaming;
  const _Bubble({
    required this.message,
    required this.scheme,
    this.streaming = false,
  });

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  // Memoized markdown subtree: while the model streams a reply, EVERY
  // notify rebuilds the whole message list — and MarkdownBody re-parses
  // its source on every build. Older messages never change, so we cache
  // their parsed subtree and reuse it until content/role actually changes.
  Widget? _cachedChild;
  String? _cacheKey;

  @override
  void didUpdateWidget(_Bubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = _cacheKeyFor(widget.message, widget.scheme);
    if (key != _cacheKey) {
      _cachedChild = null;
    }
  }

  static String _cacheKeyFor(AiMessageUi m, ColorScheme s) {
    // Content+role+reasoning for message identity; the scheme's primary is
    // a cheap stand-in for "the theme changed" so a cached parse is never
    // reused across a theme switch with wrong colours.
    return '${m.role}|${m.content}|${m.reasoning}|${s.primary.toARGB32()}';
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final scheme = widget.scheme;
    if (widget.streaming) {
      // Stream fast-path: MarkdownBody re-parses its source on EVERY build,
      // and a token burst rebuilds this bubble dozens of times a second —
      // that storm froze the whole app on Redmi. While typing, render a
      // plain growing Text (or thinking dots before the first token); the
      // bubble switches to the full markdown once the stream completes.
      return _buildStreamingBubble(context, message, scheme);
    }
    final key = _cacheKeyFor(message, scheme);
    if (_cacheKey != key || _cachedChild == null) {
      _cacheKey = key;
      _cachedChild = _buildBubble(context, message, scheme);
    }
    return _cachedChild!;
  }

  /// The live typing bubble: same assistant shell, cheap growing text.
  Widget _buildStreamingBubble(
    BuildContext context,
    AiMessageUi message,
    ColorScheme scheme,
  ) {
    final shell = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.secondaryContainer.withValues(alpha: 0.55),
          scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        ],
      ),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(16),
      ),
      border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: shell,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.content.isEmpty)
              const _ThinkingDots()
            else
              Text(
                message.content,
                style: TextStyle(
                  color: scheme.onSurface,
                  height: 1.4,
                  fontSize: 13.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context,
    AiMessageUi message,
    ColorScheme scheme,
  ) {
    // Reward messages: a centered celebration pill with a gradient rim —
    // clearly distinct from user/assistant bubbles.
    if (message.role == 'reward') {
      final lines = message.content.split('\n');
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.9),
                scheme.tertiaryContainer.withValues(alpha: 0.75),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lines.first,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (lines.length > 1) ...[
                      const SizedBox(height: 2),
                      Text(
                        lines.sublist(1).join('\n'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isUser = message.role == 'user';
    final isAda = !isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          gradient: isAda
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.secondaryContainer.withValues(alpha: 0.55),
                    scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  ],
                )
              : null,
          color: isUser ? scheme.primary : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isAda
              ? Border.all(
                  color: scheme.primary.withValues(alpha: 0.22),
                )
              : null,
        ),
        // Assistant messages render real markdown (lists, bold, code blocks
        // from the JSON commands); user messages stay plain selectable text.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAda)
              MarkdownBody(
                data: message.content,
                selectable: true,
                softLineBreak: true,
                // Clean Cut/Copy/Paste/Share toolbar (no "Ask Copilot" /
                // web lookup on Android).
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
                styleSheet: MarkdownStyleSheet.fromTheme(
                  Theme.of(context),
                ).copyWith(
                  // Keep paragraph breaks clearly larger than the line
                  // leading so a blank-line break reads as a new paragraph;
                  // derive the gap from the paragraph style.
                  blockSpacing: markdownBlockSpacing(
                    const TextStyle(height: 1.4, fontSize: 13.5),
                  ),
                  p: TextStyle(
                    color: scheme.onSurface,
                    height: 1.4,
                    fontSize: 13.5,
                  ),
                  listBullet: TextStyle(
                    color: scheme.primary,
                    fontSize: 13.5,
                  ),
                  code: TextStyle(
                    color: scheme.primary,
                    fontSize: 12.5,
                    backgroundColor: scheme.primaryContainer
                        .withValues(alpha: 0.4),
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            else
              SelectableText(
                message.content,
                style: TextStyle(
                  color: isUser ? scheme.onPrimary : scheme.onSurface,
                  height: 1.4,
                  fontSize: 13.5,
                ),
                // No selection loupe and a clean toolbar (Cut/Copy/Paste/
                // Share only — no "Ask Copilot" / web lookup on Android).
                magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
              ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool enabled;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                cursorOpacityAnimates: true,
                controller: controller,
                focusNode: focusNode,
                maxLines: 4,
                minLines: 1,
                // Hard cap (no visible counter): 13 000 characters. Hyphens
                // typed as punctuation become em dashes automatically.
                inputFormatters: [
                  LengthLimitingTextInputFormatter(13000),
                  const EmDashInputFormatter(),
                ],
                // Disable autocorrect/spellcheck: on Android it draws yellow
                // squiggly underlines under Russian words inside the chat.
                autocorrect: false,
                enableSuggestions: false,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                // No magnifying-glass selection loupe + a clean toolbar with
                // only Cut/Copy/Paste/Share (no "Ask Copilot" / lookup).
                magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
                onSubmitted: (_) => enabled ? onSend() : null,
                decoration: InputDecoration(
                  hintText: L.tr(context, 'aiInputHint'),
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Gradient send button — theme-aware (was hardcoded purple).
            // PressScale gives it the same fast dimple + eased recoil as every
            // other control; a bare IconButton only flashed a ripple.
            PressScale(
              scale: 0.92,
              haptic: true,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.tertiary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: enabled ? onSend : null,
                  icon: const Icon(Icons.send_rounded, size: 20),
                  color: scheme.onPrimary,
                  // The pressed/ripple highlight must follow the circle of
                  // the gradient shell exactly — the default square-ish
                  // highlight sticks out of the round button.
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shape: const CircleBorder(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tiny three-dot typing indicator shown inside the streaming bubble
/// before the model's first token lands. Cheap: one controller, staggered
/// sine opacity — no per-token rebuilds.
class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  opacity:
                      0.35 + 0.65 * (0.5 + 0.5 * math.sin(2 * math.pi * ((t + i / 3) % 1) - math.pi / 2)),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
