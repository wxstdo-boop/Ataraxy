enum ChatMediaType { text, image, video, audio, file }

class ChatMessage {
  final String id;
  final String text;
  final String? mediaUrl;
  final ChatMediaType mediaType;
  final DateTime timestamp;
  final bool pinned;
  final String? customName;

  const ChatMessage({
    required this.id,
    this.text = '',
    this.mediaUrl,
    this.mediaType = ChatMediaType.text,
    required this.timestamp,
    this.pinned = false,
    this.customName,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    String? mediaUrl,
    ChatMediaType? mediaType,
    DateTime? timestamp,
    bool? pinned,
    String? customName,
    bool clearCustomName = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      timestamp: timestamp ?? this.timestamp,
      pinned: pinned ?? this.pinned,
      customName: clearCustomName ? null : (customName ?? this.customName),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType.name,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'pinned': pinned,
        'customName': customName,
      };

  /// Defensive parser: never throws. Bad / missing id or timestamp are
  /// recovered with sensible fallbacks so one malformed favorite cannot
  /// abort an entire import or silently disappear on the next load.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = (rawId is String && rawId.isNotEmpty)
        ? rawId
        : 'imported-${DateTime.now().microsecondsSinceEpoch}-${rawId.hashCode}';

    final rawTs = json['timestamp'];
    final tsMs = rawTs is int
        ? rawTs
        : (rawTs is String ? int.tryParse(rawTs) : null) ??
            DateTime.now().millisecondsSinceEpoch;

    return ChatMessage(
      id: id,
      text: json['text'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String?,
      mediaType: ChatMediaType.values.firstWhere(
        (e) => e.name == json['mediaType'],
        orElse: () => ChatMediaType.text,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(tsMs),
      pinned: (json['pinned'] as bool?) ?? false,
      customName: json['customName'] as String?,
    );
  }
}
