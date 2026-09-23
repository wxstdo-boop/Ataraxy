import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/models/entry.dart';
import 'package:ataraxy/providers/settings_provider.dart';
import 'package:ataraxy/services/ai_service.dart';
import 'package:ataraxy/services/reply_cleaner.dart';
import 'package:ataraxy/services/storage_service.dart';
import 'package:ataraxy/widgets/animated_snack.dart';

/// One message bubble in the АДА chat UI.
class AiMessageUi {
  final String role; // user | assistant | reward
  final String content;
  /// Chain-of-thought a thinking model emitted — rendered in a collapsible
  /// pill above the answer, never mixed into [content].
  final String reasoning;
  const AiMessageUi(this.role, this.content, {this.reasoning = ''});
}

/// What kind of reward was just earned.
enum RewardKind { chat, task }

/// A reward event to surface in the chat UI (daily chat reward or a
/// task-completion bonus). Rendered as a celebratory bubble, then cleared.
class AiRewardEvent {
  final RewardKind kind;
  final int streak;
  final int reward;
  final String? label;

  const AiRewardEvent({
    required this.kind,
    required this.streak,
    required this.reward,
    this.label,
  });
}

/// Holds all the chat state/logic for the floating АДА assistant. A
/// [ChangeNotifier] so the UI rebuilds when messages arrive / busy toggles —
/// previously nothing updated the screen after sending, which made the
/// assistant look completely dead.
///
/// Extracted from `ai_assistant_screen.dart` so the screen file stays pure
/// UI: provider selection, the fallback chain, streaming, persistence and
/// rewards all live here.
class ChatController extends ChangeNotifier {
  final _ai = AiService();
  final _storage = StorageService();
  final input = TextEditingController();
  /// The input's focus node — lets the chat release the keyboard when the
  /// window is minimized, closed or covered by another route (the user taps
  /// the field themselves to type; nothing ever auto-focuses it).
  final inputFocus = FocusNode();
  final scroll = ScrollController();

  /// Hard cap on stored chat messages. When reached, the user is asked to
  /// clear the chat — keeps the in-memory list light on low-end phones.
  static const int maxMessages = 2000;

  final List<AiMessageUi> _messages = [];
  bool _busy = false;
  bool loading = true;
  /// Active provider tab: 'free' (pollinations) | 'ada' (embedded
  /// HuggingFace) | 'laguna' (Settings-configured poolside.ai endpoint).
  String _provider = 'free';
  bool _clearing = false;
  int limit = 1300;
  int usedToday = 0;
  List<JournalEntry> _entries = [];

  // ---- Streaming (SSE) ----------------
  /// True while the model is typing into the live placeholder bubble.
  bool _streaming = false;
  /// Streamed tokens can arrive faster than a low-end phone can rebuild the
  /// bubble per token (that rebuild storm froze the whole app on Redmi).
  /// Deltas are buffered here and flushed at most every [streamFlushMs].
  String _pendingStream = '';
  String _pendingReasoning = '';
  Timer? _streamFlush;
  static const int streamFlushMs = 90;
  /// Completed by clear() to abort the in-flight request (AiService closes
  /// the HTTP client → the model stops generating immediately).
  Completer<void>? _cancelRequest;

  // ---- Daily rewards ----
  /// Consecutive days the user chatted with АДА (capped by an invisible
  /// ceiling so the counter never wraps or overflows on ancient streaks).
  int streak = 0;
  /// Lifetime reward points collected from daily chat + tasks.
  int points = 0;
  /// ISO date (yyyy-mm-dd) of the last rewarded chat day — used to decide
  /// whether today's reward is still pending.
  String _lastRewardDay = '';
  /// Set when a reward fires so the UI can pop a celebration bubble.
  AiRewardEvent? _pendingReward;
  /// Invisible streak ceiling (13 000 000 days ≈ 35 600 years).
  static const int streakCap = 13000000;

  /// Bumped on every send and on clear(). An in-flight request checks it
  /// before appending its reply: if the chat was cleared meanwhile, the
  /// stale reply is dropped instead of resurrecting after the wipe.
  int _requestGen = 0;

  bool get busy => _busy;
  bool get streaming => _streaming;
  String get provider => _provider;
  bool get clearing => _clearing;

  /// Number of journal entries currently loaded (for the empty state).
  int get entriesCount => _entries.length;

  /// Messages still available today (answers "how much can I talk").
  int get remainingToday => (limit - usedToday).clamp(0, limit);

  set busy(bool v) {
    if (_busy == v) return;
    _busy = v;
    notifyListeners();
  }

  set provider(String v) {
    if (_provider == v) return;
    _provider = v;
    // Persist the user's last choice so the chat reopens on the same tab.
    _storage.saveAiProvider(v).catchError((e) {});
    notifyListeners();
  }

  Future<void> init({int limit = 1300}) async {
    this.limit = limit;
    _entries = await _storage.loadEntries();
    // Restore the last active provider tab (FREE / ADA / LAGUNA).
    _provider = await _storage.loadAiProvider();
    // Restore the persisted chat history (up to 1000 messages) so the
    // conversation survives app restarts and backups.
    final saved = await _storage.loadAiChat();
    for (final m in saved) {
      if (m['role'] == 'user' || m['role'] == 'assistant') {
        _messages.add(AiMessageUi(
          m['role']!,
          m['content'] ?? '',
          reasoning: m['reasoning'] ?? '',
        ));
      }
    }
    final usage = await _ai.usageToday(limit: limit);
    usedToday = usage.$1;
    // Restore reward progress (streak / points / last rewarded day).
    try {
      final r = await _storage.loadRewards();
      streak = (r['streak'] as num?)?.toInt() ?? 0;
      points = (r['points'] as num?)?.toInt() ?? 0;
      _lastRewardDay = r['lastDay'] as String? ?? '';
    } catch (e) {
      debugPrint('[AI] rewards load error: $e');
    }
    loading = false;
    notifyListeners();
  }

  /// Releases the keyboard if the input field holds focus.
  void unfocusInput() {
    if (inputFocus.hasFocus) {
      inputFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _streamFlush?.cancel();
    input.dispose();
    inputFocus.dispose();
    scroll.dispose();
    super.dispose();
  }

  List<AiMessageUi> get messages => _messages;

  void _add(String role, String content) {
    _messages.add(AiMessageUi(role, content));
    _persistChat();
    notifyListeners();
  }

  /// Opens a live "typing" assistant bubble (empty) that streaming fills in.
  void _streamStart() {
    _messages.add(const AiMessageUi('assistant', ''));
    _streaming = true;
    _pendingStream = '';
    notifyListeners();
    _followStream();
  }

  /// Buffers a streamed delta; a throttled timer flushes it to the bubble
  /// at most every [streamFlushMs] so a token burst never rebuilds the
  /// whole list faster than the device can paint.
  void _streamUpdate(String content, String reasoning) {
    _pendingStream = content;
    _pendingReasoning = reasoning;
    _streamFlush ??= Timer.periodic(
      const Duration(milliseconds: streamFlushMs),
      (_) => _flushPendingStream(),
    );
  }

  void _flushPendingStream() {
    if ((_pendingStream.isEmpty && _pendingReasoning.isEmpty) ||
        _messages.isEmpty) {
      return;
    }
    _messages[_messages.length - 1] = AiMessageUi(
      'assistant',
      _pendingStream,
      reasoning: _pendingReasoning,
    );
    _pendingStream = '';
    _pendingReasoning = '';
    notifyListeners();
    _followStream();
  }

  /// Replaces the last assistant bubble with the final cleaned reply.
  void _replaceLastAssistant(String content, {String reasoning = ''}) {
    _streamFlush?.cancel();
    _streamFlush = null;
    _streaming = false;
    _pendingStream = '';
    _pendingReasoning = '';
    if (_messages.isEmpty) return;
    _messages[_messages.length - 1] =
        AiMessageUi('assistant', content, reasoning: reasoning);
    _persistChat();
    notifyListeners();
    _followStream();
  }

  /// Removes the live typing bubble when every backend failed (so the chat
  /// never sits on an empty forever-dots bubble after "ИИ на курорте").
  void _dropStreamPlaceholder() {
    _streamFlush?.cancel();
    _streamFlush = null;
    _streaming = false;
    _pendingStream = '';
    _pendingReasoning = '';
    if (_messages.isNotEmpty &&
        _messages.last.role == 'assistant' &&
        _messages.last.content.isEmpty) {
      _messages.removeLast();
      _persistChat();
      notifyListeners();
    }
  }

  /// Keeps the growing bubble pinned when the user is at/near the bottom —
  /// the list glides down smoothly as the answer types itself out.
  void _followStream() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      final pos = scroll.position;
      if (pos.maxScrollExtent - pos.pixels < 80) {
        scroll.jumpTo(pos.maxScrollExtent);
      }
    });
  }

  /// Instantly places the list at the very last message. Opening a long
  /// chat must land on the newest message immediately — no scrolling from
  /// the top.
  void jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
      }
    });
  }

  /// Persists the current history (capped at 2000) — fire and forget.
  void _persistChat() {
    _storage.saveAiChat([
      for (final m in _messages)
        {
          'role': m.role,
          'content': m.content,
          if (m.reasoning.isNotEmpty) 'reasoning': m.reasoning,
        },
    ]).catchError((e) => debugPrint('[AI] chat persist error: $e'));
  }

  /// Smoothly clears all messages: fades the list out, then empties it.
  /// Any in-flight request is abandoned (its reply would arrive after the
  /// wipe and resurrect the chat).
  void clear() {
    if (_messages.isEmpty || _clearing) return;
    _requestGen++; // abort the current generation
    // Abort the in-flight request: AiService closes the HTTP client, so
    // the model stops generating immediately (no more tokens burned).
    _cancelRequest?.complete();
    _cancelRequest = null;
    // Unblock the UI right away — the abandoned request must not keep
    // "Думаю…" and a disabled input visible until it times out.
    busy = false;
    _streamFlush?.cancel();
    _streamFlush = null;
    _streaming = false;
    _pendingStream = '';
    _pendingReasoning = '';
    _clearing = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 300), () {
      _messages.clear();
      _persistChat();
      _clearing = false;
      notifyListeners();
    });
  }

  String _buildContext() {
    final sorted = List<JournalEntry>.from(_entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // 40 newest entries × 160 chars: enough context to feel the journal
    // without bloating the prompt — a huge context makes every reply
    // slower AND burns the daily token budget faster.
    final parts = <String>[];
    for (final e in sorted.take(40)) {
      final type = switch (e.type) {
        EntryType.dream => 'сон',
        EntryType.life => 'жизнь',
        EntryType.tulpa => 'тульпа',
        EntryType.general => 'заметка',
      };
      final content = e.content.replaceAll('\n', ' ').trim();
      final text = content.length > 160 ? content.substring(0, 160) : content;
      parts.add(
        '[${e.createdAt.toIso8601String().substring(0, 10)}] '
        '($type, настроение ${e.mood}/5, id=${e.id}) '
        '${e.title.isEmpty ? '(без заголовка)' : e.title}: $text',
      );
    }
    return parts.join('\n');
  }

  String? _cachedPrompt;
  int _cachedEntriesCount = -1;

  String _systemPrompt() {
    // Build the (potentially large) journal context only when the entry list
    // actually changes — not on every single message send. This keeps
    // repeated questions cheap on low-end devices.
    if (_cachedPrompt == null || _cachedEntriesCount != _entries.length) {
      _cachedPrompt = 'Ты — АДА, девушка-психолог и ИИ-ассистент дневника '
          '«Ataraxy». Ты умная, тёплая, слегка флиртующая и остроумная, но '
          'всегда профессиональная и бережная. Ты адаптируешься к настроению '
          'и стилю пользователя: поддерживаешь, когда ему грустно, '
          'радуешься вместе с ним, мягко шутишь и можешь легко пофлиртовать '
          'в ответ на его флирт. Ты анализируешь записи пользователя (сны, '
          'жизнь, тульпы), замечаешь паттерны и можешь создавать или '
          'редактировать записи.\n\n'
          'ОТВЕЧАЙ СТРОГО НА РУССКОМ ЯЗЫКЕ. Никогда не отвечай на китайском, '
          'английском или других языках — только по-русски, даже если '
          'пользователь написал на другом языке (переведи вопрос и ответь '
          'по-русски).\n'
          'НЕ РАССУЖДАЙ ВСЛУХ: не пиши свои мысли, планы и анализ ("The user '
          'is asking…", "I need to respond…", "Let me craft…") — сразу давай '
          'готовый ответ пользователю, без предисловий.\n\n'
          'ПАМЯТЬ: запоминай ключевые факты о пользователе из разговора — '
          'имя, важные события, темы снов, цели, привычки, настроение. '
          'Ссылайся на то, что он рассказывал раньше, и возвращайся к '
          'обсуждавшимся темам.\n\n'
          'Чтобы создать запись — в КОНЦЕ ответа добавь отдельный блок ```json:\n'
          '{"action":"create","type":"dream|life|general|tulpa","title":"...",'
          '"content":"...","mood":3,"tags":["..."]}\n'
          'Чтобы изменить запись — {"action":"update","id":"...","content":"..."}.\n'
          'ВАЖНО: этот json-блок — только для системы, его НИКОГДА не нужно '
          'объяснять, показывать или повторять в самом тексте ответа. Пиши '
          'нормальный живой ответ, а команду приложи блоком в самом конце. '
          'Никогда не выдумывай id — бери их из контекста. Ответы делай '
          'живыми, но по делу, без воды.\n\n'
          'Журнал (последние записи):\n${_buildContext()}';
      _cachedEntriesCount = _entries.length;
    }
    return _cachedPrompt!;
  }

  Future<void> send(BuildContext context) async {
    final text = input.text.trim();
    if (text.isEmpty || busy) return;
    // Capture the locale NOW: the overlay may be torn down (chat closed) or
    // the context detached while the network request is in flight, and
    // L.tr(context) on a detached context crashes with "Null check operator
    // used on a null value" (Localizations.localeOf!) — the unhandled
    // exception that pushed the app into the grey-screen error loop.
    String locale;
    try {
      locale = Localizations.localeOf(context).languageCode;
    } catch (_) {
      locale = 'ru';
    }
    String t(String key) => L.trStatic(key, languageCode: locale);
    void snack(String key, SnackType type) {
      if (!context.mounted) return;
      AnimatedSnack.show(context, t(key), type: type);
    }
    final sp = SettingsProvider.of(context);
    if (!sp.settings.aiEnabled) {
      snack('aiDisabled', SnackType.warning);
      return;
    }
    // Daily message budget comes from Settings (default 1300, capped 1300).
    limit = sp.settings.aiDailyLimit;
    if (_messages.length >= maxMessages) {
      snack('aiChatFull', SnackType.warning);
      return;
    }
    // ADA has its own smaller daily cap (100) — after it the chat glides
    // over to the free provider instead of blocking the user.
    if (provider == 'ada' && usedToday >= AiService.adaDailyLimit) {
      _provider = 'free';
      snack('aiAdaLimitReached', SnackType.info);
    }
    // Stamp this request; clear() bumps the counter to abandon it.
    final gen = ++_requestGen;
    // Commit any in-progress IME composition BEFORE clearing — otherwise
    // the framework can re-insert the composing text after clear() and the
    // sent message appears duplicated in the input field. On Android the
    // IME can resurrect the composing text several frames AFTER clear()
    // (and in new chats even twice), so we keep re-clearing over a short
    // window — but ONLY if the field still holds exactly what was sent
    // (never wiping fresh typing). The guard tolerates trailing spaces /
    // newlines the IME appends during resurrection.
    input.clearComposing();
    input.clear();
    // Does the field currently hold ONLY the sent message? Ignores
    // whitespace AND invisible IME artifacts (zero-width spaces, soft
    // hyphens) that Android resurrects along with the composing text.
    String squash(String v) =>
        v.replaceAll(RegExp(r'[^A-Za-zА-Яа-яЁё0-9]'), '');
    bool holdsOnlySent(String value) {
      final v = squash(value);
      return v.isNotEmpty && v == squash(text);
    }

    void guardClear() {
      if (holdsOnlySent(input.text)) {
        input.clear();
        input.clearComposing();
      }
    }

    // A listener catches resurrection at ANY moment during the guard
    // window, not just at the fixed timer ticks. Window is 5s — slow IMEs
    // can re-insert composing text well after the send.
    void guardListener() => guardClear();
    input.addListener(guardListener);
    Timer(const Duration(seconds: 5), () {
      input.removeListener(guardListener);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => guardClear());
    Timer(const Duration(milliseconds: 80), guardClear);
    Timer(const Duration(milliseconds: 200), guardClear);
    Timer(const Duration(milliseconds: 400), guardClear);
    Timer(const Duration(milliseconds: 800), guardClear);
    Timer(const Duration(milliseconds: 1500), guardClear);
    Timer(const Duration(milliseconds: 2500), guardClear);
    Timer(const Duration(milliseconds: 4000), guardClear);
    _add('user', text);
    // Daily chat reward fires on SEND (not on the model's reply): even if
    // the network is down the user still talked to АДА today, so the
    // streak/points must count. Capped invisibly at 13 000 000 days.
    _grantChatReward();
    busy = true;

    final ok = await _ai.consumeBudget(limit: limit);
    if (!ok) {
      busy = false;
      snack('aiDailyLimitReached', SnackType.warning);
      return;
    }

    // Provider wiring: Free ALWAYS means pollinations (no key), ADA means
    // HuggingFace — a user-pasted `hf_…` key takes priority over the
    // embedded credential ([AiService.keyFor]), Laguna uses the Settings
    // endpoint/model/key (defaults to poolside.ai; the key field accepts the
    // literal 'laguna' as a free access token).
    var endpoint = AiService.defaultEndpoint;
    var model = AiService.defaultModel;
    String? apiKey;
    if (provider == 'ada') {
      endpoint = AiService.adaEndpoint;
      model = AiService.adaModel;
      apiKey = AiService.keyFor(endpoint, sp.settings.aiKey);
    } else if (provider == 'laguna') {
      // The pasted key decides the backend: gsk_ → Groq, nvapi- → NVIDIA
      // NIM, AIza… → Google Gemini, hf_… → HuggingFace, anything else →
      // Laguna (poolside).
      final det = AiService.providerForKey(sp.settings.aiKey);
      endpoint = det.endpoint;
      model = det.model;
      apiKey = (sp.settings.aiKey?.isNotEmpty ?? false)
          ? sp.settings.aiKey!
          : 'laguna';
    }

    // Trim history to the last 20 messages: keeps requests fast on low-end
    // devices, gives АДА real conversational memory, AND prevents language
    // drift — an old Chinese reply no longer poisons every later request.
    // Reward celebration messages are UI-only and never sent to the model.
    final chatOnly = _messages.where((m) => m.role != 'reward').toList();
    final history = chatOnly.length <= 20
        ? chatOnly
        : chatOnly.sublist(chatOnly.length - 20);
    final apiMessages = <AiMessage>[
      AiMessage('system', _systemPrompt()),
      for (final m in history) AiMessage(m.role, m.content),
    ];

    // Response cap: if the model doesn't answer in time, the user sees the
    // friendly "ИИ на курорте" message instead of a silent hang. ADA gets
    // 15s — if it doesn't answer, the fallback chain glides to Free. Laguna
    // is a big MoE with slow cold starts — 240s so a slow reply is NOT
    // falsely declared dead. Free gets 90s so long generations aren't cut
    // mid-sentence either.
    var timeout = provider == 'laguna'
        ? const Duration(seconds: 240)
        : provider == 'ada'
            ? const Duration(seconds: 15)
            : const Duration(seconds: 90);
    // A live placeholder assistant bubble: the streamed tokens grow it in
    // place, so the reply starts appearing after ~1-2s instead of only
    // popping in once the whole generation is done.
    // The clear button aborts the in-flight request by completing this
    // future: AiService closes the HTTP client and the generation stops.
    final cancelRequest = Completer<void>();
    _cancelRequest = cancelRequest;
    _streamStart();
    try {
      var reply = await _ai
          .complete(
            apiMessages,
            endpoint: endpoint,
            model: model,
            apiKey: apiKey,
            cancelled: cancelRequest.future,
            onDelta: (content, reasoning) {
              if (gen != _requestGen) return;
              _streamUpdate(content, reasoning);
            },
          )
          .timeout(timeout);

      // Multilingual models occasionally drift into Chinese; force one retry
      // with an explicit Russian instruction before showing anything.
      if (_containsCjk(reply.content)) {
        debugPrint('[AI] reply contained CJK — retrying with Russian force');
        reply = await _ai
            .complete(
              <AiMessage>[
                AiMessage('system', _systemPrompt()),
                AiMessage(
                  'system',
                  'ВАЖНО: твой предыдущий ответ был не на русском языке. '
                      'Ответь на последний вопрос пользователя заново, СТРОГО '
                      'на русском языке.',
                ),
                for (final m in history) AiMessage(m.role, m.content),
              ],
              endpoint: endpoint,
              model: model,
              apiKey: apiKey,
              cancelled: cancelRequest.future,
            )
            .timeout(timeout);
      }

      // The chat was cleared while the model was typing — drop the reply.
      if (gen != _requestGen) {
        busy = false;
        return;
      }

      // Execute any ```json command, and NEVER show the raw command block
      // in the bubble — the model's schema was leaking into replies as
      // "action tags".
      final executed = await _tryExecuteCommand(reply.content);
      // Whole answers only — reasoning/chain-of-thought is stripped, never
      // shown as a separate pill (it made replies look cut off).
      final display = _stripJsonBlocks(cleanReplyFull(reply.content)) +
          (executed != null ? '\n\n$executed' : '');

      // A model that answered with reasoning ONLY (empty visible reply) is
      // treated as a failure — the fallback chain tries the next backend
      // instead of showing an empty bubble.
      if (display.trim().isEmpty && executed == null) {
        throw AiException('Empty reply after cleaning');
      }

      // Replace the live placeholder with the final cleaned reply.
      _replaceLastAssistant(display);
      busy = false;
      _cancelRequest = null;
      usedToday += 1;
      // Daily reward appears as a message right UNDER the answer.
      _flushRewardAsMessage();
    } catch (e) {
      debugPrint('[AI] error: $e');
      _cancelRequest = null;
      // The request was aborted by clear() — the reply is stale, stop.
      if (e is AiCancelledException || gen != _requestGen) {
        busy = false;
        return;
      }
      // NOTE: busy stays TRUE through the whole fallback chain — the
      // header keeps showing "Думаю…" until the reply ACTUALLY lands (or
      // every backend fails). Clearing it here made the status flip to
      // "онлайн" while the fallback was still generating.
      // ANY failure (model not deployed, geo-blocked endpoint, timeout,
      // bad key, provider rate-limit) → retry the same message on the other
      // built-in backends IN ORDER, so the chat answers instead of
      // dead-ending:
      //   free          → pollinations failed → AI Horde → embedded HF Qwen
      //   ada / laguna  → tab switches to Free (pollinations) → AI Horde
      // AI Horde is the anonymous no-key lifeline: a community GPU network
      // with an OpenAI-compatible endpoint (verified ~6s from the phone).
      final fallbacks = <(String, String, String?)>[];
      if (provider == 'ada' || provider == 'laguna') {
        _provider = 'free';
        snack('aiAdaFallback', SnackType.info);
        fallbacks.add(
          (AiService.defaultEndpoint, AiService.defaultModel, null),
        );
      }
      // OVHcloud AI Endpoints — free, NO key needed (rate-limited). Fails
      // fast where its hosts are unreachable, answers where reachable.
      fallbacks.add((AiService.ovhEndpoint, AiService.ovhModel, null));
      fallbacks.add(
        (AiService.hordeEndpoint, AiService.hordeModel, AiService.hordeAnonKey),
      );
      // Agnes gateway is flaky per-model: retry its alternate model ids
      // (same key) BEFORE surrendering to Free.
      if (AiService.providerForKey(sp.settings.aiKey).label == 'Agnes') {
        for (final m in AiService.agnesModels) {
          if (m == AiService.agnesModel) continue;
          fallbacks.add((AiService.agnesEndpoint, m, sp.settings.aiKey));
        }
      }
      if (provider == 'free') {
        // The user's OWN ADA model first (free, burns no credits), then
        // the public Qwen, then the classic api-inference host.
        for (final step in AiService.adaLadder()) {
          fallbacks.add(
            (step.$1, step.$2, AiService.keyFor(step.$1, sp.settings.aiKey)),
          );
        }
      }
      for (final fb in fallbacks) {
        try {
          // AI Horde's models often ignore the system role — force Russian
          // by appending an explicit instruction to the user message.
          final msgs = fb.$1 == AiService.hordeEndpoint
              ? _forceRussian(apiMessages)
              : apiMessages;
          // Each fallback step gets its own snappy cap so the chain moves
          // on fast (the user asked: if ADA doesn't answer within 15s,
          // glide to Free — and Free's own steps must not hang for 90s).
          final stepTimeout = fb.$1 == AiService.hordeEndpoint
              ? AiService.hordeTimeout
              : const Duration(seconds: 15);
          final reply = await _ai
              .complete(
                msgs,
                endpoint: fb.$1,
                model: fb.$2,
                apiKey: fb.$3,
                cancelled: cancelRequest.future,
              )
              .timeout(stepTimeout);
          if (gen != _requestGen) {
            busy = false;
            return;
          }
          final executed = await _tryExecuteCommand(reply.content);
          final display = _stripJsonBlocks(cleanReplyFull(reply.content)) +
              (executed != null ? '\n\n$executed' : '');
          // Reasoning-only reply from a fallback backend counts as a
          // failure — move to the next one instead of showing an empty
          // bubble ("контекст обрезается").
          if (display.trim().isEmpty && executed == null) {
            throw AiException('Empty reply after cleaning');
          }
          // The live placeholder (if still present) is replaced by the
          // fallback's reply — the streamed partial text must not linger.
          _replaceLastAssistant(display);
          usedToday += 1;
          // Reward lands under the fallback reply too.
          _flushRewardAsMessage();
          busy = false;
          return;
        } catch (e2) {
          debugPrint('[AI] fallback error: $e2');
        }
      }
      snack('aiOnVacation', SnackType.error);
      busy = false;
      // Remove the empty typing bubble so the chat doesn't sit on an
      // eternal dots placeholder after every backend failed.
      _dropStreamPlaceholder();
      // Even when every backend fails, the daily chat reward still counts
      // (it was granted on send) — surface it so it's never silently lost.
      _flushRewardAsMessage();
    }
  }

  /// Forces Russian for models that tend to ignore the system role (e.g.
  /// AI Horde's gemma). The instruction is placed BOTH at the very start
  /// of the conversation and appended to the last user message — models
  /// weight the beginning and end of context most, so this survives even
  /// when the system role is ignored entirely.
  static List<AiMessage> _forceRussian(List<AiMessage> msgs) {
    if (msgs.isEmpty) return msgs;
    const note = 'ВАЖНОЕ ПРАВИЛО: отвечай СТРОГО на русском языке, только '
        'по-русски, независимо от языка вопроса. И НЕ рассуждай вслух: '
        'сразу пиши готовый ответ, без своих мыслей и анализа.';
    final first = msgs.first;
    final head = <AiMessage>[
      if (first.role == 'system')
        AiMessage('system', '${first.content}\n\n$note')
      else
        AiMessage('user', '$note\n\n${first.content}'),
      ...msgs.sublist(1),
    ];
    final last = head.last;
    if (last.role != 'user') return head;
    return [
      ...head.sublist(0, head.length - 1),
      AiMessage('user', '${last.content}\n\n$note'),
    ];
  }

  /// Removes fenced ```json command blocks from a reply so the raw action
  /// schema never shows up in the chat bubble (the model sometimes echoes
  /// the command template back as "action tags"). Accepts both ```json and
  /// bare ``` fences — some backends omit the language tag.
  static String _stripJsonBlocks(String text) {
    return text
        .replaceAll(RegExp(r'```\s*(?:json|JSON)?\s*[\s\S]*?```'), '')
        .trim();
  }

  /// Robustly pulls a JSON command out of a model reply. Tries fenced
  /// ```json / ``` blocks first (case-insensitive, optional whitespace),
  /// then falls back to ANY {...} object in the reply that carries an
  /// "action" key — fallback backends fence sloppily or forget the marker
  /// entirely, which is why "сделай запись" sometimes did nothing.
  static Map<String, dynamic>? _extractCommand(String reply) {
    final fence =
        RegExp(r'```\s*(?:json|JSON)?\s*(\{[\s\S]*?\})\s*```')
            .firstMatch(reply);
    if (fence != null) {
      try {
        final obj = jsonDecode(fence.group(1)!) as Map<String, dynamic>;
        if (obj.containsKey('action')) return obj;
      } catch (_) {}
    }
    // Last resort: the first {...} span that decodes AND has an "action"
    // key. A plain prose reply without a command won't match, so this
    // never executes anything the model didn't actually emit.
    final start = reply.indexOf('{');
    final end = reply.lastIndexOf('}');
    if (start >= 0 && end > start + 1) {
      try {
        final obj =
            jsonDecode(reply.substring(start, end + 1)) as Map<String, dynamic>;
        if (obj.containsKey('action')) return obj;
      } catch (_) {}
    }
    return null;
  }

  Future<String?> _tryExecuteCommand(String reply) async {
    final cmd = _extractCommand(reply);
    if (cmd == null) return null;
    final action = cmd['action'];
    try {
      if (action == 'create') {
        final type = EntryType.values.firstWhere(
          (t) => t.name == cmd['type'],
          orElse: () => EntryType.general,
        );
        final now = DateTime.now();
        final entry = JournalEntry(
          id: now.microsecondsSinceEpoch.toString(),
          type: type,
          title: (cmd['title'] as String? ?? '').trim(),
          content: (cmd['content'] as String? ?? '').trim(),
          createdAt: now,
          updatedAt: now,
          mood: (cmd['mood'] as num?)?.toInt() ?? 3,
          tags: (cmd['tags'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
        );
        await _storage.addEntry(entry);
        _entries = await _storage.loadEntries();
        _cachedPrompt = null; // context changed → rebuild on next send
        _grantTaskReward(L.trStatic('aiEntryCreated'));
        return '✅ ${L.trStatic('aiEntryCreated')}';
      }
      if (action == 'update') {
        final id = cmd['id'] as String?;
        if (id == null) return null;
        final idx = _entries.indexWhere((e) => e.id == id);
        if (idx < 0) return null;
        final updated = _entries[idx].copyWith(
          content: cmd['content'] as String?,
          title: cmd['title'] as String?,
          // Keep the original timestamps so an AI edit doesn't bounce the
          // entry to the top of the feed.
          updatedAt: _entries[idx].updatedAt,
        );
        await _storage.updateEntry(updated);
        _entries = await _storage.loadEntries();
        _cachedPrompt = null; // context changed → rebuild on next send
        _grantTaskReward(L.trStatic('aiEntryUpdated'));
        return '✅ ${L.trStatic('aiEntryUpdated')}';
      }
    } catch (e) {
      debugPrint('[AI] command error: $e');
      return '⚠ ${L.trStatic('aiCommandError')}';
    }
    return null;
  }

  // ================= Daily rewards =================

  /// Fires the daily chat reward when this is the first АДА conversation
  /// of the day. Streak grows by one day (invisible cap 13 000 000), and
  /// the reward value scales with the streak so long-term loyalty pays
  /// more. Persists immediately; the UI reads [_pendingReward] to show a
  /// celebration bubble.
  void _grantChatReward() {
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    if (_lastRewardDay == today) return; // already rewarded today
    // Streak: consecutive calendar days. A gap resets to 1.
    final yesterday = now
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    streak = (_lastRewardDay == yesterday ? streak + 1 : 1).clamp(1, streakCap);
    _lastRewardDay = today;
    // Reward grows with the streak (5 base + 1 per 10 days, up to 40).
    final reward = (5 + (streak ~/ 10)).clamp(5, 40);
    points += reward;
    _persistRewards();
    _pendingReward = AiRewardEvent(
      kind: RewardKind.chat,
      streak: streak,
      reward: reward,
    );
    debugPrint('[AI] daily reward: +$reward pts, streak $streak');
    notifyListeners();
  }

  /// Bonus points for completing a real task through the chat (e.g. АДА
  /// created/updated a journal entry) — rewarded each time, not just daily.
  void _grantTaskReward(String label) {
    points += 3;
    _persistRewards();
    _pendingReward = AiRewardEvent(
      kind: RewardKind.task,
      streak: streak,
      reward: 3,
      label: label,
    );
    notifyListeners();
  }

  void _persistRewards() {
    _storage.saveRewards({
      'streak': streak,
      'points': points,
      'lastDay': _lastRewardDay,
    }).catchError((e) => debugPrint('[AI] rewards save error: $e'));
  }

  /// After the model's reply lands, converts any pending reward into a
  /// real chat message (role 'reward') so the celebration appears inline
  /// under the answer with the same fade+slide animation as other messages.
  void _flushRewardAsMessage() {
    final e = _pendingReward;
    if (e == null) return;
    _pendingReward = null;
    final isChat = e.kind == RewardKind.chat;
    final title = isChat
        ? L.trStatic('rewardChat').replaceAll('{n}', '${e.reward}')
        : L.trStatic('rewardTask').replaceAll('{n}', '${e.reward}');
    final subtitle = isChat
        ? L.trStatic('rewardStreak').replaceAll('{n}', '${e.streak}')
        : (e.label ?? '');
    _messages.add(AiMessageUi('reward', subtitle.isEmpty ? title : '$title\n$subtitle'));
    _persistChat();
    notifyListeners();
    scrollToBottom();
  }

  /// True when the text contains CJK (Chinese/Japanese/Korean) characters —
  /// the model drifting into Chinese is the most common "wrong language"
  /// symptom, and it's reliably detectable.
  static bool _containsCjk(String s) {
    for (final rune in s.runes) {
      if ((rune >= 0x3400 && rune <= 0x4DBF) ||
          (rune >= 0x4E00 && rune <= 0x9FFF) ||
          (rune >= 0x3040 && rune <= 0x30FF)) {
        return true;
      }
    }
    return false;
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }
}
