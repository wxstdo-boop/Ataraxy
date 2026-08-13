import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:video_player/video_player.dart';
import 'package:image/image.dart' as img;

import 'package:dream_journal/l10n/strings.dart';
import 'package:dream_journal/models/chat_message.dart';
import 'package:dream_journal/services/chat_service.dart';
import 'package:dream_journal/widgets/animated_snack.dart';
import 'package:dream_journal/widgets/limited_context_menu.dart';
import 'package:dream_journal/widgets/skeleton.dart';
import 'package:dream_journal/widgets/premium_header.dart';

/// Personal saved messages: text, photos, videos and arbitrary files.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _chatService = ChatService();
  final _scrollCtrl = ScrollController();
  final _textController = TextEditingController();
  final _textFocus = FocusNode();
  List<ChatMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Aggressively suppress keyboard auto-pop when screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocus.unfocus();
    });
  }

  @override
  void dispose() {
    _textFocus.dispose();
    _scrollCtrl.dispose();
    _textController.dispose();
    super.dispose();
  }


  Future<void> _load() async {
    final raw = await _chatService.loadMessages();
    if (!mounted) return;
    setState(() {
      _messages = raw;
      _loading = false;
    });
  }

  Future<void> _pickMedia() async {
    final file = await openFile();
    if (file == null) return;
    final path = await _copyAttachment(file.path);
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: '',
      mediaUrl: path,
      mediaType: _mediaTypeFor(path),
      timestamp: DateTime.now(),
    );
    await _chatService.addMessage(msg);
    if (!mounted) return;
    setState(() => _messages.add(msg));
  }

  Future<String> _copyAttachment(String sourcePath) async {
    final source = File(sourcePath);
    final directory = await getApplicationDocumentsDirectory();
    final attachments = Directory(
      '${directory.path}${Platform.pathSeparator}favorites',
    );
    await attachments.create(recursive: true);
    final name = sourcePath.split(Platform.pathSeparator).last;
    final target = File(
      '${attachments.path}${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}_$name',
    );
    await source.copy(target.path);
    return target.path;
  }

  ChatMediaType _mediaTypeFor(String path) {
    final extension = path.split('.').last.toLowerCase();
    if (const [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
    ].contains(extension)) {
      return ChatMediaType.image;
    }
    if (const ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
      return ChatMediaType.video;
    }
    if (const ['mp3', 'flac', 'wav', 'ogg', 'aac', 'm4a', 'opus'].contains(extension)) {
      return ChatMediaType.audio;
    }
    return ChatMediaType.file;
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final message = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
    );
    _textController.clear();
    await _chatService.addMessage(message);
    if (!mounted) return;
    setState(() => _messages.add(message));
  }

  Future<void> _deleteMessage(String id) async {
    await _chatService.deleteMessage(id);
    setState(() => _messages.removeWhere((m) => m.id == id));
  }

  Future<bool> _togglePin(String id) async {
    await _chatService.togglePin(id);
    bool nowPinned = false;
    if (!mounted) return nowPinned;
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == id);
      if (idx >= 0) {
        _messages[idx] = _messages[idx].copyWith(pinned: !_messages[idx].pinned);
        nowPinned = _messages[idx].pinned;
        // Sort: pinned first (newest among pinned at top), then unpinned
        // (newest first). Previously sorted oldest-first which made the
        // newest pinned item appear *below* older pinned ones, so it
        // looked like the pin "slipped off" the top.
        _messages.sort((a, b) {
          if (b.pinned && !a.pinned) return 1;
          if (!b.pinned && a.pinned) return -1;
          return b.timestamp.compareTo(a.timestamp);
        });
      }
    });
    if (_messages.any((m) => m.id == id)) {
      AnimatedSnack.show(
        context,
        nowPinned ? L.tr(context, 'pinned') : L.tr(context, 'unpinned'),
        type: SnackType.info,
        duration: const Duration(seconds: 1),
      );
    }
    return nowPinned;
  }

  Future<void> _cropImage(ChatMessage msg) async {
    if (msg.mediaUrl == null) return;
    final srcFile = File(msg.mediaUrl!);
    if (!srcFile.existsSync()) return;
    final nav = Navigator.of(context);
    final bytes = await srcFile.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) return;
    final result = await nav.push<Rect>(
      MaterialPageRoute(
        builder: (_) => _CropScreen(imageBytes: bytes, aspectRatio: original.width / original.height),
      ),
    );
    if (result == null || !mounted) return;
    // Convert Rect (ratio) to actual pixel coords
    final x = (result.left * original.width).round().clamp(0, original.width - 1);
    final y = (result.top * original.height).round().clamp(0, original.height - 1);
    final w = (result.width * original.width).round().clamp(1, original.width - x);
    final h = (result.height * original.height).round().clamp(1, original.height - y);
    final cropped = img.copyCrop(original, x: x, y: y, width: w, height: h);

    // Save the cropped image as a new file and update the message so the
    // gallery immediately shows the new version (overwriting the same path
    // can leave stale frames cached by Image.file).
    final directory = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory(
      '${directory.path}${Platform.pathSeparator}favorites',
    );
    await attachmentsDir.create(recursive: true);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final oldName = srcFile.path.split(Platform.pathSeparator).last;
    final ext = oldName.split('.').last.toLowerCase();
    final isPng = ext == 'png';
    final newName = '${timestamp}_cropped.${isPng ? 'png' : 'jpg'}';
    final target = File(
      '${attachmentsDir.path}${Platform.pathSeparator}$newName',
    );
    final outBytes = Uint8List.fromList(
      isPng ? img.encodePng(cropped) : img.encodeJpg(cropped, quality: 90),
    );
    await target.writeAsBytes(outBytes);

    final updated = msg.copyWith(mediaUrl: target.path);
    await _chatService.updateMessage(updated);

    // Remove the now-orphaned original file so storage doesn't accumulate.
    try {
      if (srcFile.existsSync()) await srcFile.delete();
    } catch (_) {
      // Best-effort cleanup; if the file is locked, the new file is still valid.
    }

    if (mounted) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == msg.id);
        if (idx >= 0) _messages[idx] = updated;
      });
      AnimatedSnack.show(
        context,
        L.tr(context, 'imageCropped'),
        type: SnackType.success,
        duration: const Duration(seconds: 1),
      );
    }
  }

  Future<void> _editMessage(ChatMessage msg) async {
    final updated = await showDialog<ChatMessage>(
      context: context,
      builder: (_) => _EditDialog(message: msg),
    );
    if (updated == null) return;
    await _chatService.updateMessage(updated);
    if (!mounted) return;
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == msg.id);
      if (idx >= 0) _messages[idx] = updated;
    });
  }

  double _blurTarget = 0.0;

  void _onMediaLongPress(ChatMessage msg) {
    if (msg.mediaType == ChatMediaType.image) {
      _cropImage(msg);
    } else {
      _togglePin(msg.id);
    }
  }

  void _onMediaTap(ChatMessage msg) {
    if (msg.mediaUrl == null) return;
    final file = File(msg.mediaUrl!);
    if (!file.existsSync()) {
      AnimatedSnack.show(
        context,
        L.tr(context, 'fileNotFound'),
        type: SnackType.error,
      );
      return;
    }
    _blurTarget = 0.0;
    bool isPinned = msg.pinned;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: _blurTarget),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              builder: (context, blurValue, child) {
                final videoFileName = msg.customName ??
                    file.path.split(Platform.pathSeparator).last;
                final mediaWidget = _MediaPlayerWidget(
                  file: file,
                  fileName: videoFileName,
                  blurValue: blurValue,
                  isAudio: msg.mediaType == ChatMediaType.audio,
                );
                return Stack(
              children: [
                Center(
                  child: msg.mediaType == ChatMediaType.image
                      ? Container(
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
                            child: blurValue > 0
                                ? ImageFiltered(
                                    imageFilter: ui.ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
                                    child: AspectRatio(
                                      aspectRatio: 3 / 4,
                                      child: Image.file(file, fit: BoxFit.cover),
                                    ),
                                  )
                                : AspectRatio(
                                    aspectRatio: 3 / 4,
                                    child: Image.file(file, fit: BoxFit.cover),
                                  ),
                          ),
                        )
                      : msg.mediaType == ChatMediaType.video ||
                          msg.mediaType == ChatMediaType.audio
                      ? mediaWidget
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 200,
                              height: 280,
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
                                    Icon(Icons.insert_drive_file_rounded, size: 64, color: Colors.white70),
                                    const SizedBox(height: 12),
                                    Text(
                                      msg.customName ?? file.path.split(Platform.pathSeparator).last,
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                Positioned(
                  top: 40,
                  right: 16,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 16,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.blur_on_rounded, color: Colors.white),
                    ),
                    onPressed: () {
                      setDialogState(() => _blurTarget = _blurTarget >= 10 ? 0 : _blurTarget + 2);
                    },
                    onLongPress: () {
                      setDialogState(() => _blurTarget = _blurTarget >= 10 ? 0 : _blurTarget + 1);
                    },
                  ),
                ),
                if (msg.mediaType == ChatMediaType.image) Positioned(
                  top: 40,
                  left: 72,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        color: isPinned ? const Color(0xFFFFD166) : Colors.white,
                      ),
                    ),
                    onPressed: () async {
                      isPinned = await _togglePin(msg.id);
                      setDialogState(() {});
                    },
                  ),
                ),
              ],
            );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // White text over the pastel seed-derived gradient is unreadable on light
    // themes. Pick a brightness-aware foreground so title + icons stay visible
    // regardless of the active theme.
    final headerFg = Colors.white;
    final headerIconBg = Colors.white.withValues(alpha: 0.2);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: headerFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        flexibleSpace: PremiumHeader(
          colors: [scheme.primary, scheme.secondary, scheme.tertiary],
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: headerIconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.bookmark_rounded, size: 18, color: headerFg),
            ),
            const SizedBox(width: 10),
            Text(
              L.tr(context, 'favoritesTitle'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: headerFg,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const SkeletonList(count: 4)
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _EmptyState(onAdd: _pickMedia)
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            return AnimatedSize(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              child: Dismissible(
                                key: ValueKey(_messages[i].id),
                                confirmDismiss: (direction) async {
                                  if (direction == DismissDirection.endToStart) {
                                    return true; // delete on right→left swipe
                                  }
                                  // left→right swipe → edit
                                  await _editMessage(_messages[i]);
                                  return false;
                                },
                                secondaryBackground: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 24),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                                ),
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 24),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.edit_rounded, color: Colors.white),
                                ),
                                onDismissed: (direction) {
                                  if (direction == DismissDirection.endToStart) {
                                    _deleteMessage(_messages[i].id);
                                  }
                                },
                                child: _PhotoTile(
                                  message: _messages[i],
                                  onEdit: () => _editMessage(_messages[i]),
                                  onOpen: () => _onMediaTap(_messages[i]),
                                  onLongPress: () => _onMediaLongPress(_messages[i]),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                _buildAttachBar(scheme),
              ],
            ),
    );
  }

  Widget _buildAttachBar(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
        top: 8,
        left: 8,
        right: 8,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.attach_file_rounded, color: scheme.primary),
              onPressed: _pickMedia,
              tooltip: L.tr(context, 'attachFile'),
            ),
            Expanded(
              child: TextField(
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
                controller: _textController,
                focusNode: _textFocus,
                minLines: 1,
                maxLines: 4,
                autofocus: false,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendText(),
                decoration: InputDecoration(
                  hintText: L.tr(context, 'writeToFavorites'),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send_rounded, color: scheme.primary),
              onPressed: _sendText,
              tooltip: L.tr(context, 'saveText'),
            ),
          ],
        ),
      ),
    );
  }
}

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
          color: message.pinned
              ? scheme.primaryContainer.withValues(alpha: 0.4)
              : scheme.surfaceContainerLowest,
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
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
                controller: _nameController,
                maxLength: 25,
                autofocus: false,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: L.tr(context, 'nameLabel'),
                  prefixIcon: const Icon(Icons.label_rounded),
                ),
              ),
            ] else ...[
              TextField(
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
                controller: _textController,
                maxLines: 6,
                maxLength: 6000,
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
                  size: 56, color: Colors.orangeAccent),
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
              const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B9D), Color(0xFFFF9FB6), Color(0xFFFFC3D9)],
                        ),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B9D).withValues(alpha: 0.45),
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
                          color: const Color(0xFFFF6B9D),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B9D).withValues(alpha: 0.5),
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
                              color: const Color(0xFFFF6B9D)
                                  .withValues(alpha: glow * 0.5),
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
      colors: const [
        Color(0xFFFF6B9D),
        Color(0xFFFF9FB6),
        Color(0xFFC084FC),
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.secondary],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.image_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              L.tr(context, 'favoritesPhotosEmpty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              L.tr(context, 'favoritesPhotosEmptyHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(L.tr(context, 'favoritesAddAnyFile')),
            ),
          ],
        ),
      ),
    );
  }
}
