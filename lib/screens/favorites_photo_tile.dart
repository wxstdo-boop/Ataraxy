part of 'favorites_screen.dart';

class _PhotoTile extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onEdit;
  final VoidCallback? onOpen;
  final VoidCallback? onLongPress;

  const _PhotoTile({
    required this.message,
    this.onEdit,
    this.onOpen,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = message.mediaUrl;
    final file = path != null ? File(path) : null;
    // Imported favorites may reference media that's no longer on disk
    // (cross-device backup). Surface a clear "missing" chip instead of
    // silently leaving the tile open-tap-into-the-void.
    final missing = path != null &&
        message.mediaType != ChatMediaType.text &&
        file != null &&
        !file.existsSync();
    final exists = file != null && file.existsSync();

    final isImage = message.mediaType == ChatMediaType.image;
    final isText = message.mediaType == ChatMediaType.text;
    final label = path?.split(Platform.pathSeparator).last ?? '';
    final icon = message.mediaType == ChatMediaType.video
        ? Icons.video_file_rounded
        : message.mediaType == ChatMediaType.audio
            ? Icons.audiotrack_rounded
            : message.mediaType == ChatMediaType.image
                ? Icons.image_rounded
                : Icons.insert_drive_file_rounded;

    if (isText) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: message.pinned
                ? scheme.primaryContainer.withValues(alpha: 0.6)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: message.pinned
                ? Border.all(color: scheme.primary.withValues(alpha: 0.3), width: 1.5)
                : null,
          ),
          child: InkWell(
            onTap: onEdit,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                if (message.pinned) ...[
                  Icon(Icons.push_pin_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          // surfaceContainerHighest, not Lowest: Lowest is pure white, so an
          // unpinned bubble read as a white stripe over the tinted scaffold.
          color: message.pinned
              ? scheme.primaryContainer.withValues(alpha: 0.4)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: message.pinned
              ? Border.all(color: scheme.primary.withValues(alpha: 0.3), width: 1.5)
              : null,
        ),          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: exists ? onOpen : null,
              onLongPress: onLongPress,
              child: Padding(
              padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (isImage && exists)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      file,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: scheme.primary, size: 30),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.customName ?? label,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _formatDate(message.timestamp),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          if (missing) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer
                                    .withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.broken_image_rounded,
                                    size: 10,
                                    color: scheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    L.tr(context, 'fileNotFound'),
                                    style: TextStyle(
                                      color: scheme.onErrorContainer,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}

class _EditDialog extends StatefulWidget {
  final ChatMessage message;
  const _EditDialog({required this.message});

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.message.customName ?? '');
    _textController = TextEditingController(text: widget.message.text);
    // Aggressively suppress keyboard auto-pop — the user must tap to type.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.unfocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _nameController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasMedia = widget.message.mediaUrl != null;
    return AlertDialog(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        hasMedia ? L.tr(context, 'editFile') : L.tr(context, 'editTextTitle'),
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasMedia) ...[
              TextField(
        cursorOpacityAnimates: true,
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
                controller: _nameController,
                maxLength: 25,
                buildCounter: animatedFieldCounter,
                autofocus: false,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: L.tr(context, 'nameLabel'),
                  prefixIcon: const Icon(Icons.label_rounded),
                ),
              ),
            ] else ...[
              TextField(
        cursorOpacityAnimates: true,
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
                controller: _textController,
                maxLines: 6,
                maxLength: 6000,
                buildCounter: animatedFieldCounter,
                autofocus: false,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: L.tr(context, 'editTextTitle'),
                  hintText: L.tr(context, 'editTextHint'),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            L.tr(context, 'cancel'),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        FilledButton(
          onPressed: () {
            final updated = widget.message.copyWith(
              customName: hasMedia
                  ? (_nameController.text.trim().isEmpty
                      ? null
                      : _nameController.text.trim())
                  : null,
              text: hasMedia ? widget.message.text : _textController.text,
            );
            Navigator.pop(context, updated);
          },
          child: Text(L.tr(context, 'save')),
        ),
      ],
    );
  }
}

/// Plays a local video or audio file with controls.
