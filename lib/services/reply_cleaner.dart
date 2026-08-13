/// Cleans model replies so the visible bubble shows a whole, direct answer —
/// never chain-of-thought. Kept public (and free of Flutter imports) so the
/// exact regexes are unit-testable.
///
/// IMPORTANT (regression): inline flag groups at pattern start — `(?im)` —
/// throw `FormatException: Invalid group` on Dart 3.12.x. Every pattern here
/// must use the `caseSensitive:` / `multiLine:` constructor flags instead.
/// This class runs on EVERY assistant reply, so a throw here silently killed
/// the whole fallback chain (the "ИИ не отвечает" bug).
library;

/// Removes a leading chain-of-thought block from a reply. Thinking models
/// (and Horde's gemma with a persona prompt) paste their reasoning as a
/// preamble — Russian ("Рассуждение: …", "Размышление: …") or English
/// ("Reasoning:", "Thinking:") — in plain text or as a markdown header
/// (`**Reasoning:**`, `### Thinking`). Everything from the marker up to the
/// start of the actual answer (an explicit "Ответ:"/"Answer:" label, a
/// bullet/numbered list, a paragraph starting with a capital Cyrillic/Latin
/// letter or punctuation) is dropped. Returns the rest, trimmed.
String stripReasoning(String text) {
  var s = text.trim();
  if (s.isEmpty) return s;
  // Match a reasoning marker that starts a line (optionally a markdown
  // header of any level) followed by `:`/`—`/`-`. NOTE: constructor
  // flags only — inline flag groups at pattern start (`(?m)`) throw
  // `FormatException: Invalid group` on this Dart SDK (3.12.x).
  final marker = RegExp(
    r'^\s*(?:(?:#{1,6}|\*{1,3})\s*)*(?:рассуждени[а-яё]*|размышлени[а-яё]*|reasoning|thinking|thought)\s*[:—-]\s*\*{0,3}\s*',
    caseSensitive: false,
    multiLine: true,
  );
  final m = marker.firstMatch(s);
  // No marker — but the model may still paste an English chain-of-thought
  // with NO label at all (AI Horde's gemma with a persona prompt starts
  // with "The user is asking in Russian: … I need to respond … Let me
  // craft …"). Detect that and cut to the actual reply.
  if (m == null) return _cutCoTWithoutMarker(s);
  // The reasoning block runs from the marker to the answer start.
  final rest = s.substring(m.end).trim();
  if (rest.isEmpty) return '';
  // Explicit answer label (Russian/English) — the block ends right before
  // it, so everything after the label IS the answer.
  final answerLabel = RegExp(
    r'^\s*(?:(?:#{1,6}|\*{1,3})\s*)*(?:ответ|answer)\s*[:—-]\s*\*{0,3}\s*',
    caseSensitive: false,
    multiLine: true,
  );
  final labelMatch = answerLabel.firstMatch(rest);
  if (labelMatch != null) {
    final after = rest.substring(labelMatch.end).trim();
    if (after.isNotEmpty) return after;
  }
  // No explicit label: the actual answer usually sits in the LAST paragraph
  // (models separate the chain-of-thought from the reply with a blank
  // line). A single-paragraph reasoning-only reply returns '' so the
  // caller's fallback chain kicks in instead of showing thoughts.
  final paras =
      rest.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  if (paras.length > 1) return paras.last;
  return '';
}

/// Detects an English chain-of-thought preamble that has NO "Reasoning:"
/// marker: models like Horde's gemma begin with self-talk ("The user is
/// asking in Russian: … I need to respond … Should I create a journal
/// entry? … Let me craft a response …") and only then produce the real
/// reply, often after a "Let's write:" / "Let me write:" line. The actual
/// answer is the last paragraph that contains Cyrillic (or, failing that,
/// the last paragraph at all).
String _cutCoTWithoutMarker(String s) {
  final paras = s
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (paras.length < 2) return s;
  // A real Russian reply contains Cyrillic; pick the LAST Cyrillic-bearing
  // paragraph (the tail usually has "Let's write: …" + the actual reply).
  final hasCyrillic = RegExp(r'[А-Яа-яЁё]');
  for (var i = paras.length - 1; i >= 0; i--) {
    if (hasCyrillic.hasMatch(paras[i])) {
      return paras[i];
    }
  }
  // No Cyrillic at all — the reply might be genuinely in another language.
  return paras.last;
}

/// Cleans up model artifacts that leak into visible replies:
/// short reasoning/tag markers in parentheses like "(лайф)", "(life)",
/// "(thinking)" — Poolside's Laguna occasionally emits those inline.
String cleanReply(String text) {
  var s = text;
  s = s.replaceAll(
    RegExp(
      r'\s*\(\s*(лайф|life|thinking|thought|reasoning?|note|inner|ooc|context)\s*\)',
      caseSensitive: false,
    ),
    '',
  );
  // Thinking models (Laguna) paste their chain-of-thought into the
  // answer as a leading "Рассуждение: …" preamble. Drop the first line
  // when it's a reasoning/thinking marker (up to the next paragraph).
  // NOTE: use Cyrillic-aware classes here — Dart's `\w` matches only
  // [a-zA-Z0-9_], so `\w*` after «рассуждени» never covered «е»/«я».
  s = s.replaceFirst(
    RegExp(
      r'^\s*(?:рассуждени[а-яё]*|размышлени[а-яё]*|reasoning|thinking|thought)\s*[:—-]\s*[^\n]*(?:\n\n|\n(?=[*#\dA-ZА-Я«"])|$)',
      caseSensitive: false,
    ),
    '',
  );
  // Models occasionally echo JSON field names as prose ("content: …",
  // "title: …"). Drop those key:value artifact lines everywhere.
  s = s.replaceAll(
    RegExp(
      r'^\s*(?:content|title|type|mood|tags|action|id)\s*[:—-].*$',
      multiLine: true,
      caseSensitive: false,
    ),
    '',
  );
  return s.trim();
}

/// Full pipeline: strips a leading reasoning block, then removes inline
/// artifacts. Returns the whole direct answer (empty only if the model
/// replied with reasoning only).
String cleanReplyFull(String text) {
  return cleanReply(stripReasoning(text));
}
