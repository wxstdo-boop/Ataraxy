/// A short text describing a favorite activity the user loves doing.
/// Limited to 150 characters by the input field.
class FavoriteActivity {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool pinned;

  const FavoriteActivity({
    required this.id,
    required this.text,
    required this.createdAt,
    this.pinned = false,
  });

  FavoriteActivity copyWith({
    String? text,
    DateTime? createdAt,
    bool? pinned,
  }) {
    return FavoriteActivity(
      id: id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      pinned: pinned ?? this.pinned,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'pinned': pinned,
      };

  /// Defensive parser: never throws. Missing or invalid id / createdAt
  /// are recovered with fallbacks so a single bad entry can't abort an
  /// import or vanish on the next load.
  factory FavoriteActivity.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = (rawId is String && rawId.isNotEmpty)
        ? rawId
        : 'imported-${DateTime.now().microsecondsSinceEpoch}-${rawId.hashCode}';

    final rawCreatedAt = json['createdAt'];
    final createdAtMs = rawCreatedAt is int
        ? rawCreatedAt
        : (rawCreatedAt is String ? int.tryParse(rawCreatedAt) : null) ??
            DateTime.now().millisecondsSinceEpoch;

    return FavoriteActivity(
      id: id,
      text: json['text'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      pinned: (json['pinned'] as bool?) ?? false,
    );
  }
}
