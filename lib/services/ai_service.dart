import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

/// A tiny AI chat message.
class AiMessage {
  final String role; // 'system' | 'user' | 'assistant'
  final String content;

  const AiMessage(this.role, this.content);

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// AI assistant backend.
///
/// Default provider is Pollinations.AI — a free, open, no-signup API
/// (OpenAI-compatible endpoint `POST https://text.pollinations.ai/openai`).
/// No API key is required for it, so the app stays FOSS and works out of
/// the box.
///
/// Optionally the user can paste their own OpenAI-compatible key + endpoint
/// in Settings (stored locally, lightly obfuscated) — the service then
/// calls that instead. The key is NEVER hardcoded into the repo.
///
/// A per-day message budget (default 500) is enforced with a Hive counter
/// so a runaway loop can't burn through a quota.
class AiService {
  static const String _usageBox = 'ai_usage';
  static const String _usageKey = 'daily_count';

  static const String defaultEndpoint = 'https://text.pollinations.ai/openai';
  static const String defaultModel = 'openai';

  /// ADA — the user's OWN fine-tuned model (Qwen2.5-7B based), served via
  /// HuggingFace. Because the model is the user's own, inference does NOT
  /// consume paid credits. Router is tried first, then the classic
  /// api-inference host (which works on networks where it isn't
  /// geo-blocked). If the router can't serve the custom model, the chat's
  /// fallback chain retries the public Qwen2.5-7B-Instruct as a last resort.
  static const String adaEndpoint =
      'https://router.huggingface.co/v1/chat/completions';
  static const String adaEndpointFallback =
      'https://api-inference.huggingface.co/v1/chat/completions';
  static const String adaModel = 'Wetixolit/ada-0.0.3';
  /// Public Qwen2.5-7B-Instruct — used as a last-resort ADA retry (costs
  /// credits, so it is never the primary).
  static const String adaPublicModel = 'Qwen/Qwen2.5-7B-Instruct';
  /// ADA daily cap — after this many ADA messages the chat auto-switches to
  /// the free provider (Pollinations) for the rest of the day.
  static const int adaDailyLimit = 100;
  /// 15s per endpoint — if ADA doesn't answer in 15s the chat falls back to
  /// the free provider instead of hanging on a cold start.
  static const Duration adaTimeout = Duration(seconds: 15);

  /// Laguna (poolside.ai) — OpenAI-compatible hosted inference. The model
  /// id is `poolside/laguna-s-2.1`; a key from Poolside Platform (or
  /// OpenRouter for the `:free` variant) goes into the Settings key field.
  static const String lagunaEndpoint =
      'https://inference.poolside.ai/v1/chat/completions';
  static const String lagunaModel = 'poolside/laguna-s-2.1';
  /// Upper bound for the user-set daily message limit (Settings).
  static const int maxDailyLimit = 13000;

  /// AI Horde — a free, community-powered distributed inference network
  /// (no signup needed). The oai.aihorde.net microservice exposes an
  /// OpenAI-compatible API; the anonymous key is the literal string
  /// `0000000000`. Verified working from the phone (~6s, chat.completions
  /// shape). Used as a no-key fallback when pollinations is down.
  static const String hordeEndpoint =
      'https://oai.aihorde.net/v1/chat/completions';
  static const String hordeModel = 'google/gemma-4-31b';
  static const String hordeAnonKey = '0000000000';
  static const Duration hordeTimeout = Duration(seconds: 60);

  /// Groq — genuinely free tier (no credit card, ~14 400 requests/day).
  /// OpenAI-compatible; key is `gsk_...` from console.groq.com, pasted into
  /// the Settings key field.
  static const String groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String groqModel = 'llama-3.3-70b-versatile';

  /// NVIDIA NIM — free API credits on build.nvidia.com, key `nvapi-...`.
  static const String nvidiaEndpoint =
      'https://integrate.api.nvidia.com/v1/chat/completions';
  static const String nvidiaModel = 'meta/llama-3.3-70b-instruct';

  /// Google AI Studio — free Gemini API key `AIza...` (aistudio.google.com).
  /// The OpenAI-compatible endpoint accepts it as a Bearer token.
  static const String googleEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions';
  static const String googleModel = 'gemini-2.0-flash';

  /// OpenRouter — one free key (`sk-or-v1-...`, no credit card) unlocks
  /// 20+ `:free` models including Laguna. We pick Laguna itself as the
  /// default so the reply quality matches the other tabs.
  static const String openrouterEndpoint =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String openrouterModel = 'poolside/laguna-s-2.1:free';

  /// Cerebras — free tier, blazing-fast Llama 3.3 70B on wafer-scale
  /// hardware. Key format `csk-...` from cloud.cerebras.ai; OpenAI-
  /// compatible, up to 15x faster than GPU clouds.
  static const String cerebrasEndpoint =
      'https://api.cerebras.ai/v1/chat/completions';
  static const String cerebrasModel = 'llama-3.3-70b';

  /// Mistral — French AI lab, generous free tier (La Plateforme).
  /// Key format: bare 32-char alphanumeric (no prefix) from
  /// console.mistral.ai; OpenAI-compatible.
  static const String mistralEndpoint =
      'https://api.mistral.ai/v1/chat/completions';
  static const String mistralModel = 'mistral-small-latest';

  /// Agnes AI — free OpenAI-compatible gateway (text/image/video), one
  /// `sk-…` key from the Agnes console unlocks everything. The endpoint is
  /// live (401 without a key).
  static const String agnesEndpoint =
      'https://apihub.agnes-ai.com/v1/chat/completions';
  static const String agnesModel = 'agnes-2.0-flash';
  /// Alternate Agnes model ids — the gateway rotates which one answers, so
  /// the chat retries these before giving up on Agnes entirely.
  static const List<String> agnesModels = [
    'agnes-2.0-flash',
    'agnes-2.5-flash',
    'agnes-2.5-pro-1',
  ];

  /// OVHcloud AI Endpoints — free tier is rate-limited but needs NO API
  /// key at all. Hosts are geo-flaky (some networks get connection
  /// resets), so it sits in the no-key fallback chain where a dead host
  /// fails fast and the next backend takes over.
  static const String ovhEndpoint =
      'https://llm.uk.ai.ovh.net/v1/chat/completions';
  static const String ovhModel = 'Meta-Llama-3_3-70B-Instruct';

  /// Detects the provider from an API key (the key drives the choice):
  ///   `gsk_…`     → Groq
  ///   `nvapi-…`   → NVIDIA NIM
  ///   `AIza…`     → Google AI Studio (Gemini)
  ///   `sk-or-…`   → OpenRouter
  ///   anything else → Laguna (poolside.ai)
  static ({String endpoint, String model, String label}) providerForKey(
    String? key,
  ) {
    final k = key?.trim() ?? '';
    if (k.startsWith('gsk_')) {
      return (endpoint: groqEndpoint, model: groqModel, label: 'Groq');
    }
    if (k.startsWith('nvapi-') || k.startsWith('nvidia-')) {
      return (endpoint: nvidiaEndpoint, model: nvidiaModel, label: 'NVIDIA');
    }
    if (k.startsWith('AIza')) {
      return (endpoint: googleEndpoint, model: googleModel, label: 'Gemini');
    }
    if (k.startsWith('sk-or-')) {
      return (
        endpoint: openrouterEndpoint,
        model: openrouterModel,
        label: 'OpenRouter',
      );
    }
    if (k.startsWith('sk-')) {
      return (
        endpoint: agnesEndpoint,
        model: agnesModel,
        label: 'Agnes',
      );
    }
    if (k.startsWith('csk_')) {
      return (
        endpoint: cerebrasEndpoint,
        model: cerebrasModel,
        label: 'Cerebras',
      );
    }
    if (k.startsWith('sky_')) {
      return (endpoint: lagunaEndpoint, model: lagunaModel, label: 'Laguna');
    }
    // Bare 32-char alphanumeric key with no prefix = Mistral La Plateforme.
    if (RegExp(r'^[A-Za-z0-9]{32}$').hasMatch(k)) {
      return (
        endpoint: mistralEndpoint,
        model: mistralModel,
        label: 'Mistral',
      );
    }
    return (endpoint: lagunaEndpoint, model: lagunaModel, label: 'Laguna');
  }

  /// The ADA retry ladder: own model (free, no credits) → public Qwen via
  /// router → classic api-inference host. Each entry is tried in order; a
  /// dead host or "model not supported" just moves to the next.
  static List<(String, String)> adaLadder() => [
        (adaEndpoint, adaModel),
        (adaEndpoint, adaPublicModel),
        (adaEndpointFallback, adaModel),
      ];
  // The token is stored base64(XOR) so it doesn't sit in the repo as
  // plaintext. Decoded at call time; never logged.
  static const String _adaKeyObf =
      'CRI+Bw4xNlgNDQkJEQwbNgkjYCgcOSUeAD8jGy5OLwgmCicCBA==';

  static String get adaKey {
    final bytes = base64Decode(_adaKeyObf);
    const k = 'ataraxy-ada';
    final out = StringBuffer();
    for (var i = 0; i < bytes.length; i++) {
      out.writeCharCode(bytes[i] ^ k.codeUnitAt(i % k.length));
    }
    return out.toString();
  }

  /// Free model list (pollinations): only models the CURRENT text API
  /// actually serves. Mistral/llama/gemini were retired from the legacy
  /// endpoint (404 "Model not found ... legacy API deprecated") — keeping
  /// them in the rotation just made every request burn 3 wasted retries
  /// before answering ("Free отвечает через раз").
  static const List<String> freeModels = [
    'openai',
  ];

  /// True when the given endpoint is the ADA (HuggingFace) endpoint.
  static bool isAda(String endpoint) => endpoint == adaEndpoint;

  /// True when the given endpoint is the Laguna (poolside.ai) endpoint.
  static bool isLaguna(String endpoint) => endpoint == lagunaEndpoint;

  /// The key to send for [endpoint]: the embedded ADA key for ADA, the
  /// user-configured key otherwise (or null → pollinations, no key).
  static String? keyFor(String endpoint, String? userKey) {
    if (isAda(endpoint)) return adaKey;
    return (userKey == null || userKey.isEmpty) ? null : userKey;
  }

  /// Sends the conversation and returns the assistant reply (visible text
  /// + optional chain-of-thought from thinking models).
  ///
  /// [endpoint] / [model] / [apiKey] override the defaults (used when the
  /// user configured a custom provider in Settings). When [apiKey] is
  /// empty, the free pollinations endpoint is used.
  ///
  /// When [cancelled] completes, the in-flight request is aborted (the
  /// HTTP client is closed) — used by the chat's "clear" to truly stop a
  /// generation instead of letting it burn tokens in the background.
  Future<AiReply> complete(
    List<AiMessage> messages, {
    String endpoint = defaultEndpoint,
    String model = defaultModel,
    String? apiKey,
    bool stream = false,
    /// Receives the reply progressively (accumulated content + reasoning).
    /// When set, the request is streamed (SSE) and the UI can show the
    /// answer growing instead of waiting for the whole generation.
    void Function(String content, String reasoning)? onDelta,
    Future<void>? cancelled,
  }) async {
    final uri = Uri.parse(endpoint);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey.isNotEmpty)
        'Authorization': 'Bearer $apiKey',
      // OpenRouter likes to see where requests come from (free-tier policy).
      if (endpoint == openrouterEndpoint) ...{
        'HTTP-Referer': 'https://ataraxy.foss/',
        'X-Title': 'Ataraxy FOSS',
      },
    };
    // NOTE: Pollinations' anonymous quota is granted based on the request's
    // own Referer. Manually overriding it (on native or web) made the
    // server treat the call as authenticated → HTTP 402. Sending no
    // Referer/Origin at all keeps it anonymous and free (verified 200).
    // In the browser the fetch engine forbids overriding them anyway, so we
    // simply never touch them.

    final body = jsonEncode({
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': stream,
      // Generous output cap: without it some providers clip long answers
      // at their (low) default and the reply looks cut off mid-sentence.
      'max_tokens': 8192,
      if (endpoint == lagunaEndpoint)
        // Laguna is a "thinking" model: it burns the first minutes on a
        // chain-of-thought, streams only reasoning for ages (the empty-
        // bubble bug) and consumes its token budget on thinking. Turning
        // thinking OFF makes it answer directly and fast.
        'chat_template_kwargs': {'enable_thinking': false},
    });

    // Streaming (SSE) path: used when the caller wants progressive output.
    // Tokens arrive as `data: {…}` lines; we accumulate the deltas and hand
    // the growing text to [onDelta]. A per-chunk watchdog (no data for 30s)
    // closes the stream instead of hanging forever.
    if (onDelta != null || stream) {
      debugPrint('[AI] POST (stream) $endpoint model=$model');
      final request = http.Request('POST', uri)
        ..headers.addAll(headers)
        ..body = body;
      final client = http.Client();
      final sb = StringBuffer();
      final rb = StringBuffer(); // chain-of-thought, shown in a pill
      // When the caller cancels (chat cleared), close the client → the
      // underlying request aborts and the stream ends immediately.
      final cancelWatch = cancelled == null
          ? null
          : cancelled.then((_) {
              client.close();
              throw const AiCancelledException();
            });
      try {
        // Generous header wait: slow providers (Laguna cold starts, shared
        // queues) can take a while before the first SSE byte. 120s covers
        // that; ADA keeps its snappy 10s.
        final resp = await client.send(request).timeout(
          isAda(endpoint) ? adaTimeout : const Duration(seconds: 120),
        );
        if (resp.statusCode != 200) {
          throw AiException('HTTP ${resp.statusCode}');
        }
        final lines = resp.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            // No data for 120s → the stream is dead; stop cleanly. (A 40s
            // watchdog killed slow thinking models mid-reply: Laguna
            // pauses >40s between token bursts while "reasoning", so the
            // stream was falsely declared dead and fell back to Free.)
            .timeout(
              const Duration(seconds: 120),
              onTimeout: (sink) => sink.close(),
            );
        Future<String> readAll() async {
          await for (final line in lines) {
            final trimmed = line.trim();
            if (!trimmed.startsWith('data:')) continue;
            final data = trimmed.substring(5).trim();
            if (data == '[DONE]') break;
            try {
              final obj = jsonDecode(data) as Map<String, dynamic>;
              final choices = obj['choices'] as List<dynamic>? ?? const [];
              if (choices.isEmpty) continue;
              final d =
                  choices.first['delta'] as Map<String, dynamic>? ?? const {};
              // Thinking models stream their chain-of-thought under
              // 'reasoning'/'reasoning_content' FIRST, then the answer in
              // 'content'. Reasoning is collected separately (shown in a
              // collapsible pill) and never mixed into the visible text.
              final delta = d['content'] as String? ?? '';
              if (delta.isNotEmpty) {
                sb.write(delta);
                onDelta?.call(sb.toString(), rb.toString().trim());
              }
              final rd = d['reasoning_content'] as String? ??
                  d['reasoning'] as String?;
              if (rd != null && rd.isNotEmpty) {
                rb.write(rd);
                onDelta?.call(sb.toString(), rb.toString().trim());
              }
            } catch (_) {
              // ignore malformed keep-alive chunks
            }
          }
          return sb.toString();
        }
        final content = cancelWatch == null
            ? await readAll()
            : await Future.any<String>([readAll(), cancelWatch]);
        client.close();
        final trimmed = content.trim();
        if (trimmed.isEmpty) {
          throw AiException('Empty content from provider');
        }
        debugPrint('[AI] stream done, ${trimmed.length} chars');
        return AiReply(trimmed, reasoning: rb.toString().trim());
      } catch (e) {
        client.close();
        debugPrint('[AI] stream error: $e');
        rethrow;
      }
    }

    debugPrint('[AI] POST $endpoint model=$model messages=${messages.length}');
    http.Response resp;
    // Laguna is a big MoE with slow cold starts — it gets 240s. (The chat
    // layer wraps this call in its own per-provider timeout too.)
    final timeout = isAda(endpoint)
        ? adaTimeout
        : (isLaguna(endpoint) || endpoint == openrouterEndpoint
            ? const Duration(seconds: 240)
            : const Duration(seconds: 90));
    try {
      resp = await http
          .post(uri, headers: headers, body: body)
          .timeout(timeout);
      debugPrint('[AI] response ${resp.statusCode} in ${DateTime.now()}');
    } on Exception catch (e) {
      // In the browser, HuggingFace api-inference doesn't send CORS headers,
      // so a direct call fails with a network error. Try a few public CORS
      // proxies in order so ADA still works on web.
      if (kIsWeb && isAda(endpoint)) {
        debugPrint('[AI] direct ADA failed ($e), retrying via CORS proxy');
        resp = await _postViaProxies(endpoint, headers, body);
      } else if (endpoint == adaEndpoint) {
        // Primary ADA endpoint failed → try the fallback endpoint once
        // (also 10s), before giving up and letting the chat switch to Free.
        debugPrint(
            '[AI] $endpoint failed ($e), retrying ${adaEndpointFallback}');
        try {
          resp = await http
              .post(
                Uri.parse(adaEndpointFallback),
                headers: headers,
                body: body,
              )
              .timeout(adaTimeout);
          debugPrint(
              '[AI] fallback response ${resp.statusCode} in ${DateTime.now()}');
        } on Exception catch (e2) {
          debugPrint('[AI] fallback endpoint failed: $e2');
          rethrow;
        }
      } else {
        rethrow;
      }
    }

    if (resp.statusCode != 200) {
      // The free provider (pollinations) is occasionally flaky: 402/429/5xx
      // from shared quotas. Rotate through the free models once before
      // giving up, so a reply almost always comes through.
      if (endpoint == defaultEndpoint) {
        final idx = freeModels.indexOf(model);
        if (idx >= 0 && idx < freeModels.length - 1) {
          final next = freeModels[idx + 1];
          debugPrint(
              '[AI] free model $model failed (${resp.statusCode}) → retry $next');
          return complete(
            messages,
            endpoint: endpoint,
            model: next,
            apiKey: apiKey,
            stream: stream,
          );
        }
      }
      debugPrint(
        '[AI] HTTP ${resp.statusCode}: ${resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body}',
      );
      throw AiException('HTTP ${resp.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    // OpenAI-compatible shape: {choices: [{message: {content}}]}.
    final choices = decoded['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      throw AiException('Empty response from provider');
    }
    final msg = choices.first['message'] as Map<String, dynamic>?;
    final content = msg?['content'] as String? ?? '';
    final reasoning =
        (msg?['reasoning_content'] ?? msg?['reasoning']) as String? ?? '';
    if (content.trim().isEmpty) {
      throw AiException('Empty content from provider');
    }
    return AiReply(content.trim(), reasoning: reasoning.trim());
  }

  /// Tries public CORS proxies in order for a browser-blocked endpoint.
  static Future<http.Response> _postViaProxies(
    String endpoint,
    Map<String, String> headers,
    String body,
  ) async {
    final proxies = <String>[
      'https://corsproxy.io/?url=',
      'https://api.codetabs.com/v1/proxy?quest=',
      'https://thingproxy.freeboard.io/fetch/',
    ];
    Object? last;
    for (final proxy in proxies) {
      try {
        final resp = await http
            .post(
              Uri.parse(proxy + Uri.encodeComponent(endpoint)),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 60));
        // Proxy answered (any status) → use it.
        return resp;
      } catch (e) {
        last = e;
        debugPrint('[AI] proxy $proxy failed: $e');
      }
    }
    throw AiException('CORS: $last');
  }

  // ---- Daily budget ----

  Future<Box> _openUsageBox() async {
    if (!Hive.isBoxOpen(_usageBox)) {
      await Hive.openBox(_usageBox);
    }
    return Hive.box(_usageBox);
  }

  /// Returns (usedToday, limit). Resets automatically when the date rolls
  /// over. limit<=0 means unlimited.
  Future<(int, int)> usageToday({int limit = 500}) async {
    final box = await _openUsageBox();
    final stamp = box.get(_usageKey);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (stamp is String && stamp.startsWith('$today|')) {
      final parts = stamp.split('|');
      final used = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return (used, limit);
    }
    return (0, limit);
  }

  /// Increments today's counter. Returns true if the budget is NOT yet
  /// exhausted (caller may proceed).
  Future<bool> consumeBudget({int limit = 500}) async {
    if (limit <= 0) return true; // unlimited
    final box = await _openUsageBox();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final stamp = box.get(_usageKey);
    var used = 0;
    if (stamp is String && stamp.startsWith('$today|')) {
      final parts = stamp.split('|');
      used = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    }
    if (used >= limit) return false;
    await box.put(_usageKey, '$today|${used + 1}');
    return true;
  }
}

/// The model's reply: the visible answer plus any chain-of-thought a
/// thinking model emitted (Laguna's `reasoning_content`). The reasoning is
/// rendered separately in a collapsible pill — never mixed into the answer.
class AiReply {
  final String content;
  final String reasoning;
  const AiReply(this.content, {this.reasoning = ''});
}

/// Thrown internally when the caller aborts an in-flight request (chat
/// cleared) — the stream client is closed and the error is swallowed by the
/// chat controller (the generation is stale anyway).
class AiCancelledException implements Exception {
  const AiCancelledException();

  @override
  String toString() => 'cancelled';
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => message;
}
