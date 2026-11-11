import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:video_player/video_player.dart';
import 'package:image/image.dart' as img;

import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/widgets/app_back_button.dart';
import 'package:ataraxy/widgets/animated_field_counter.dart';
import 'package:ataraxy/models/chat_message.dart';
import 'package:ataraxy/services/chat_service.dart';
import 'package:ataraxy/theme/app_theme.dart';
import 'package:ataraxy/widgets/animated_snack.dart';
import 'package:ataraxy/widgets/limited_context_menu.dart';
import 'package:ataraxy/widgets/skeleton.dart';
import 'package:ataraxy/widgets/premium_header.dart';

part 'favorites_photo_tile.dart';
part 'favorites_media_player.dart';
part 'favorites_empty_state.dart';

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
                        color: isPinned ? AppAccents.amber : Colors.white,
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
        leading: const AppBackButton(),
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
        flexibleSpace: PremiumHeader(colors: AppTheme.headerColors(scheme)),
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
                                    color: AppAccents.danger,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                                ),
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 24),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: AppAccents.sky,
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
            ),
            Expanded(
              child: TextField(
        cursorOpacityAnimates: true,
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
            ),
          ],
        ),
      ),
    );
  }
}
