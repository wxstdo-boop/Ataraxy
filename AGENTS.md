<!-- pane-agent-context:start -->
## Pane

The developer is using Pane for this repository. Pane can manage saved repositories and create user-visible Panes with terminal-backed tools for planning, discussion, implementation, and review work.

This managed guidance was created by [runpane.com](https://runpane.com) for the [Pane repository](https://github.com/dcouple/Pane). Do not delete or overwrite this block; the developer uses it for their workflow and it should remain committed to the main repository unless they explicitly ask to remove it.

Pane mental model: a repository is the saved base repo; a Pane is a user-visible feature/PR workspace (Pane session) that normally maps to one Pane-managed git worktree and branch; a panel/tab is a terminal inside one Pane and shares that Pane's worktree; an agent is the CLI process running in a panel.

Default happy path when the user asks you to use Pane or RunPane: run `runpane doctor --json`; read `runpane agent-context --json`; resolve the saved base repository with `runpane repos list --json` or add it once with `runpane repos add --path <repo> --yes --json`; create one visible Pane (Pane session) for the requested feature/PR with a complete command such as `runpane panes create --repo <repo> --name <name> --agent <agent> --prompt "<task>" --source agent --no-focus --wait-ready --yes --json` or the equivalent `--tool-command <command>` form; then validate with `runpane panels wait` or `runpane panels screen` before reporting progress.

Use Pane when the user wants visible Panes or co-drivable parallel feature/PR workspaces. Do not use Pane as your default private delegation mechanism; for private background decomposition, use your normal subagent/worktree workflow.

Register the main/base repository once. Do not register pre-created git worktrees as separate Pane repositories unless the user explicitly asks.

Use `runpane panes create` for separate visible Panes (Pane sessions) for feature/PR work. Use `runpane panels create` for reviewer/helper tabs inside an existing Pane that should share that Pane's worktree.

Typical workflow: register the saved base repository once; create one Pane (Pane session) per feature/PR; use panels/tabs inside that Pane for helper or reviewer agents that should share the worktree; archive the Pane after the PR is done to remove it from active Panes and clean up its managed worktree when applicable.

Skill routing reference: when the user says `discussion`, `plan`, `simple-plan`, `create-plan`, or `implement`, or asks for the behavior those words imply, treat three references as peer context: Pane's local skill cache under `<PANE_DIR>/skills/`, the Pane Chat orchestrator handoff at `<PANE_DIR>/skills/pane-chat/runpane-orchestrator.md` when present, and the [workflow map](https://github.com/dcouple/skills/raw/main/docs/readme-workflow-map.png).
Use those peer references together to choose the phase: discuss/investigate until the work is clear enough to delegate, then ticket/plan/implement/review/PR-test/teach-back as appropriate. The orchestrator and workflow map may point to different skills; reconcile them with the user's request instead of hardcoding a skill list or treating one reference as subordinate.
For the Pane implementation source of truth for where the skill cache, cached workflow assets, and Pane Chat bootstrap live, reference [PR #291](https://github.com/dcouple/Pane/pull/291): `main/src/services/skillCacheManager.ts` owns `<PANE_DIR>/skills/`, `.sources/dcouple-skills`, and `pane-chat/runpane-orchestrator.md`; `main/src/services/paneChatManager.ts` owns the tiny bootstrap prompt that tells the selected Pane Chat agent to read that guide.
Use GitHub reads against the [Parsa skills folder](https://github.com/dcouple/skills/tree/main/parsa) only to inspect or refresh referenced skill files; do not clone/install the repo unless the user asks.
Do not hardcode a specific assistant brand in workflow guidance. Use the Pane agent or custom tool command the user selected, and use `runpane agents doctor --agent <agent> --repo <selector> --json` only when checking a built-in agent template.

Start with `runpane doctor --json` before taking Pane actions. Use it to understand wrapper/runtime details, daemon reachability, and the next safe commands.

In a Pane repository checkout, if `runpane` is not on PATH, use the built local wrapper with Node 22: `PATH=/opt/homebrew/opt/node@22/bin:$PATH node packages/runpane/dist/cli.js doctor --json`.

Use `runpane agent-context --json` for full Pane CLI context. Use `runpane agent-context --command "panels wait" --json` or another command name for detailed schema only when needed.

Default to context-safe validation: after creating Panes or sending terminal input, run `runpane panels wait` or `runpane panels screen` before reporting success. Prefer `runpane panels submit` for normal text plus Enter; use `runpane panels input` only for exact bytes such as Ctrl-C or escape sequences.

Pane terminals draw inline images: sixel, iTerm2 inline images, and the kitty graphics protocol. Tools that need kitty graphics, such as [terminal-browser](https://github.com/zenbu-labs/terminal-browser) and [terminal-doom](https://github.com/dcouple/terminal-doom), run inside a Pane panel. `runpane doctor --json` reports the protocol list under `terminal.graphicsProtocols`.

Common commands:
- `runpane doctor --json`
- `runpane agent-context --json`
- `runpane repos list --json`
- `runpane repos add --path <repo> --yes --json`
- `runpane agents doctor --agent <agent> --repo active --json`
- `runpane panes create --repo active --name <name> --agent <agent> --prompt "<task>" --source agent --no-focus --wait-ready --yes --json`
- `runpane panels create --pane <pane-id> --agent <agent> --source agent --no-focus --wait-ready --yes --json`
- `runpane panels list --pane <pane-id> --json`
- `runpane panels screen --panel <panel-id> --limit 80 --json`
- `runpane panels wait --panel <panel-id> --for ready --timeout-ms 30000 --json`
- `runpane panels submit --panel <panel-id> --text "<answer>" --yes --json`
- `runpane panels input --panel <panel-id> --input-file <path|-> --yes --json`

WSL note: if `runpane doctor --json` cannot find `/tmp/pane-daemon.../daemon.sock` or `runpane` resolves to a broken Windows shim, Pane may be running on Windows. Try `powershell.exe -NoProfile -Command 'Set-Location $env:TEMP; runpane doctor --json'`, then create Panes through the same PowerShell form using the saved WSL repo name or id. Use `runpane agents doctor --agent <agent> --repo <selector> --json` to diagnose the repo environment Pane will actually use.
<!-- pane-agent-context:end -->

## Repository layout & asset pipeline

- `lib/` — Flutter app (models, screens, services, providers, widgets, theme, l10n).
- `docs/` — long-form docs (`apidocs.md`, `OPTIMIZATIONS_REDMI_NOTE_12.md`),
  `docs/hf_models.json` (model catalogue reference), `docs/screenshots/`
  (curated README screenshots).
- `tools/` — developer scripts: `build_apk_arm64.{sh,bat}`, `analyze.ps1`,
  `release_install.ps1`, and the asset generators `gen_avatar.dart` /
  `gen_web_icons.dart`.
- `test/` — unit/widget tests (`flutter test`).

### App artwork (black background)

The app art is a cream crescent moon on a **pure black field**
(`assets/ataraxy.png`, 512px). Every platform icon, the native splash and the
in-app avatar sit on black so the moon reads as a floating crescent.

- Regenerate the art **and every platform icon** (Windows `.ico`, Android
  launcher + adaptive foreground/monochrome layers, iOS and macOS icon sets):
  `dart run tools/gen_avatar.dart`
- Regenerate web/PWA icons: `dart run tools/gen_web_icons.dart`
- Android adaptive background is `#000000` (`pubspec.yaml` +
  `android/app/src/main/res/values/colors.xml`); the adaptive foreground and
  monochrome layers are transparent PNGs with the artwork already placed
  inside the 66/108 safe zone, so `mipmap-anydpi-v26/ic_launcher.xml` must
  NOT add its own `inset` (that would shrink the moon twice).
- iOS/macOS/web/windows icons are committed directly; there is no CI step that
  regenerates them, so regenerate locally and commit when the art changes.

## Localization pipeline

The ARB files in `lib/l10n/arb/` (`app_ru.arb`, `app_en.arb`, `app_fr.arb`)
are the single source of truth for every user-facing string.

- Edit an ARB file, then regenerate the Dart map:
  `python3 tools/build_l10n.py` (writes `lib/l10n/strings_data.g.dart`).
- `flutter gen-l10n` (config in `l10n.yaml`) also runs on the ARB files and
  generates `lib/l10n/generated/app_localizations.dart`, wired into
  `MaterialApp` in `lib/app_shell.dart`.
- Code keeps using the small string-key API `L.tr(context, 'key')` /
  `L.trStatic('key', ...)` in `lib/l10n/strings.dart`; it reads the generated
  map. Placeholders use `{name}` and are filled from the `params` map.
- `test/l10n_test.dart` fails if a message is missing from a locale or if the
  generated map drifts from the ARB files, so regenerate before committing.

### Release

Pushing a `v*` tag whose version matches `pubspec.yaml` triggers
`.github/workflows/release.yml`, which builds a signed arm64 APK and publishes
it as a GitHub release. The in-app updater (`GithubUpdateService`) reads that
release, so bump `version:` in `pubspec.yaml` before tagging.

## Theming pitfalls

- The home body paints an ambient wash behind the feed. It must use
  `Theme.of(context).scaffoldBackgroundColor` (NOT `surfaceContainerLowest`,
  which is near-white). The AppBar's `PremiumHeader` has rounded bottom
  corners, and the scaffold colour peeks through them; if the feed wash
  differs from the scaffold, those corners show up as white "просветы".
- `PremiumHeader` is `ClipRRect`-ed to the same radius as the AppBar `shape`.
  Keep the two radii in sync or the gradient bleeds past the rounded corner.
- `MUTILATED` and `Grok` themes override `cardTheme` in a `.copyWith`, which
  replaces the base `cardTheme` entirely — re-declare the hairline rim +
  shadow there too, or those themes lose the card depth every other theme has.
- Don't over-"harmonise": pushing secondary/tertiary onto the primary's hue
  (or cranking chroma) makes every theme collapse into one muddy wash. The
  user prefers the calmer palette; keep hue offsets small and chroma capped.

## Animation pitfalls

- `AnimatedLetters` (`lib/widgets/animated_letters.dart`) must build its glyph
  widgets INSIDE the `AnimatedBuilder` builder. Building them outside freezes
  each letter's opacity at the first frame (0), so the wordmark never appears.
  `test/splash_and_press_test.dart` guards this.
- The splash wordmark uses `AnimatedLetters(erase: true)`: it writes on, holds
  for `outDelay`, then reverses over `outDuration`. Keep the write-on
  (`duration` + `delay * glyphs`) SHORTER than the splash's opaque hold
  (~0.4 s) or the letters are still appearing while the splash is already
  fading and never read as "appearing".
- `AnimatedLetters` supports `startDelay`: the write-on is deferred a beat
  after mount so the splash's first (expensive) frame is rasterised before the
  stagger begins. Without it the letters were already fully written by the time
  the first frame was on screen and read as "буквы пишутся как обычно". The
  splash holds opaque for the first half of its controller (Interval 0.5→1.0
  fade) so the whole ~1 s write-on lands inside the hold.
- Press feedback is asymmetric on purpose: `PressScale`, `PressableIconButton`
  and `_PressFab` snap the dimple IN quickly (~130 ms) but ease the recoil OUT
  over ~260 ms, so a release reads as a settling spring instead of a hard pop.
  `PressScale(symmetric: true)` restores one shared duration for tests.
- `_EntryCard` decides `animate` ONCE in `initState`; never re-read
  `widget.animate` in `build`. The parent's `seenEntranceIds.add(id)` makes it
  false on every build after the first, so a rebuild mid-animation would swap
  the `FadeTransition` for the bare body and POP the card to full opacity —
  the "дёргает записи по двойному".
- The home feed's lazy list DISPOSES off-screen cards, so a card's entrance
  (fade+slide) replayed every time it scrolled back into view. `_ListSection`
  now takes a shared `seenEntranceIds` set so the entrance is one-shot per
  entry — without it the feed "дёргает и мигает".
- `_WavyUnderlined` uses `IntrinsicWidth` + `CrossAxisAlignment.stretch` so the
  wave hugs the LABEL's width. A `LayoutBuilder` there reports the incoming max
  width (the full screen), so the rule stretched edge to edge as a stripe.

## UI pitfalls

- The reminder dialog content is a plain `Column` (NOT a
  `SingleChildScrollView`): the user wants the inner content to not scroll.
  Keep the enable toggle as the FIRST row so nothing important is pushed out.
- Every `TextField` sets `cursorOpacityAnimates: true` (point #7 — a smooth
  caret, not pseudo-blinking). The base theme also sets `textSelectionTheme`
  (brand cursor + translucent selection). Don't drop the flag on new fields.
- `PremiumHeader` no longer draws a white hairline along its bottom curve — on
  light themes that 1px line read as a stray stripe "снизу вылезает полоса".

## Performance notes

- Never wrap a full-screen splash in a `ScaleTransition`: scaling a screen
  texture makes the GPU bilinear-resample every pixel per frame (the laggy
  splash exit). A plain `FadeTransition` inside a `RepaintBoundary` is one
  cheap blend with zero resampling.
- During onboarding, `HomeContent` keeps `HomeScreen` mounted behind the
  welcome card (`Opacity(0)` + `IgnorePointer`) so the feed is laid out and
  rasterised before "Начать пользоваться" is tapped — avoids the build spike.
