part of 'settings_screen.dart';

/// AI-assistant settings: provider info sheets, API-key editing/picking,
/// the daily-limit dialog and the key-masking helper. Split out of
/// [SettingsScreen] to keep that file focused on the general settings list.
extension _SettingsAi on _SettingsScreenState {
  /// Rounded info sheet shown on the provider tile: lists the providers
  /// whose API keys are recognized — pasting any of them into the key field
  /// makes it work instead of the default Laguna.
  Future<void> _showProviderInfo(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Icon(
              Icons.dns_rounded,
              color: Theme.of(ctx).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Text(L.tr(ctx, 'aiProvider')),
          ],
        ),
        content: const Text(
          'Поддерживаются почти все из FreeLLM — вставь их API-ключ в поле '
          'ниже, и провайдер заработает вместо Laguna. OVHcloud AI '
          'Endpoints и AI Horde работают вообще без ключа (подключены как '
          'бесплатные фолбэки). Пилля FreeLLM откроет каталог freellm.net — '
          '400+ бесплатных моделей и ссылки на свежие ключи.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L.tr(ctx, 'ok')),
          ),
        ],
      ),
    );
  }

  /// Rounded info sheet for the «Участвуй в развитии ADA» tile — describes
  /// how to try the author's other FOSS apps while ADA is early-stage.
  Future<void> _showAdaJoinInfo(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Icon(Icons.handshake_rounded, color: scheme.primary),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Участвуй в развитии ADA',
                style: TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Text(
          'АДА в начальном развитии, если хотите участвовать — пробуйте '
          'приложение Misasoc (или IDE на PC) от того же автора, '
          'полностью FOSS.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L.tr(ctx, 'ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _editAiKey(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) async {
    final controller = TextEditingController(text: settings.aiKey ?? '');
    // The key is hidden by default; the eye reveals it. The flag lives
    // OUTSIDE the dialog builder closure so StatefulBuilder can toggle it
    // across rebuilds.
    var obscure = true;
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(L.tr(ctx, 'aiKey')),
          // The WHOLE field cross-fades between the masked and revealed
          // states (the key text itself changes smoothly, not just the eye
          // icon). Both children share the same controller; the incoming
          // one re-focuses and restores the caret after the swap.
          content: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: 0.97, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: TextField(
              cursorOpacityAnimates: true,
              key: ValueKey('key-field-$obscure'),
              controller: controller,
              obscureText: obscure,
              // No auto keyboard popup — the user taps the field to type.
              autofocus: false,
              maxLength: 350,
              maxLines: 3,
              buildCounter: animatedFieldCounter,
              // No magnifying-glass selection loupe + clean toolbar (Cut/
              // Copy/Paste/Share only — no "Ask Copilot" / web lookup).
              magnifierConfiguration: TextMagnifierConfiguration.disabled,
              contextMenuBuilder: buildLimitedContextMenu,
              decoration: InputDecoration(
                hintText: 'gsk_… / nvapi-… / AIza… / sk-or-… / sky_…',
                border: const OutlineInputBorder(),
                // Smooth eye toggle: fades/scales between the two states and
                // keeps the caret exactly where it was.
                suffixIcon: PressableIconButton(
                  size: 32,
                  onPressed: () {
                    final sel = controller.selection;
                    setDlgState(() => obscure = !obscure);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (controller.selection != sel) {
                        controller.selection = sel;
                      }
                    });
                  },
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      key: ValueKey(obscure),
                      size: 20,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(L.tr(ctx, 'cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(L.tr(ctx, 'save')),
            ),
          ],
        ),
      ),
    );
    if (value != null && context.mounted) {
      provider.onChanged(settings.copyWith(aiKey: value));
      // Every pasted key is remembered (most recent first, max 10) so it
      // can be re-picked from the «Мои ключи» dropdown without retyping.
      if (value.trim().isNotEmpty) {
        unawaited(() async {
          try {
            await StorageService().saveAiKeyToSaved(value.trim());
          } catch (e) {
            debugPrint('saveAiKeyToSaved: $e');
          }
        }());
      }
    }
  }

  /// Bottom sheet with all saved API keys: tap to select, hold 10 s to
  /// delete (a progress ring counts the hold).
  Future<void> _showSavedKeys(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) async {
    final storage = StorageService();
    var keys = await storage.loadSavedAiKeys();
    if (!context.mounted) return;
    if (keys.isEmpty) {
      AnimatedSnack.show(
        context,
        'Пока нет сохранённых ключей — вставь ключ в поле выше.',
        type: SnackType.info,
      );
      return;
    }
    final scheme = Theme.of(context).colorScheme;
    final picked = await showModalBottomSheet<String>(
      context: context,
      // Tinted container, not Low: Low is near-white on the light themes and
      // the sheet read as a white slab over the tinted scaffold.
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.key_rounded, size: 19, color: scheme.primary),
                    const SizedBox(width: 9),
                    Text(
                      'Мои API-ключи',
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Тап — выбрать · зажми 10 сек — удалить',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: keys.length,
                    itemBuilder: (ctx, i) {
                      final k = keys[i];
                      return _SavedKeyRow(
                        keyValue: k,
                        active: k == settings.aiKey,
                        onSelect: () => Navigator.pop(ctx, k),
                        onDelete: () {
                          storage.deleteSavedAiKey(k).then((updated) {
                            if (ctx.mounted) {
                              setSheetState(() => keys = updated);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null && context.mounted) {
      provider.onChanged(settings.copyWith(aiKey: picked));
      AnimatedSnack.show(
        context,
        'Ключ выбран: ${_maskKey(picked)}',
        type: SnackType.success,
      );
    }
  }

  /// `abcdef…Wxyz` — shows enough to recognise the key, hides the middle.
  String _maskKey(String key) {
    if (key.length <= 10) return key;
    return '${key.substring(0, 6)}…${key.substring(key.length - 4)}';
  }

  /// Opens freellm.net — a directory of 400+ free LLM APIs (NVIDIA NIM,
  /// Google Gemini, Groq, OpenRouter, Cerebras…) with links to fresh free
  /// keys and live rate limits. The app already supports every provider it
  /// lists; this is the way to discover new free backends.
  Future<void> _openFreeLlm(BuildContext context) async {
    final uri = Uri.parse('https://freellm.net/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens the Poolside Platform in the browser — free Laguna API keys.
  Future<void> _openPoolside(BuildContext context) async {
    final uri = Uri.parse('https://platform.poolside.ai');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens the author's Misasoc repo — VPN-for-websites helper for sites
  /// that block RU.
  Future<void> _openVpnSites(BuildContext context) async {
    final uri = Uri.parse('https://github.com/wxstdo-boop/Misasoc');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _editAiLimit(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) async {
    final controller = TextEditingController(
      text: settings.aiDailyLimit.toString(),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.tr(ctx, 'aiDailyLimit')),
        content: TextField(
          cursorOpacityAnimates: true,
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 5,
          buildCounter: animatedFieldCounter,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          // No magnifying-glass selection loupe + clean toolbar (Cut/
          // Copy/Paste/Share only).
          magnifierConfiguration: TextMagnifierConfiguration.disabled,
          contextMenuBuilder: buildLimitedContextMenu,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L.tr(ctx, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(L.tr(ctx, 'save')),
          ),
        ],
      ),
    );
    if (value != null && context.mounted) {
      final limit = (int.tryParse(value) ?? AiService.maxDailyLimit)
          .clamp(1, AiService.maxDailyLimit);
      provider.onChanged(settings.copyWith(aiDailyLimit: limit));
    }
  }
}
