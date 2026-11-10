# Ataraxy Changelog

## [1.3.9] - 2026-11-10
### Fixed
- The onboarding "Начать пользоваться" button fired its action twice per tap
  (the press-dimple wrapper and the button both handled the gesture); the
  wrapper now only tracks the pressed state and lets the button handle taps.

## [1.3.8] - 2026-11-10
### Changed
- App artwork regenerated at higher resolution with supersampled
  antialiasing, so the crescent stays crisp at every icon and avatar size.
- White "paint" now flows around the crescent: a wobbly band smeared along
  the rim with clinging drops and thin drips running down.
- Splash loading spinner is now a smooth "comet" arc — a snake whose head and
  tail both fade to nothing, with a gently breathing arc length.
- Splash exit is smoother: a longer, softer fade with a subtle scale-up, so
  it melts away instead of blinking off.
- Onboarding notification card animates as one piece: the plate tints toward
  sage, the icon cross-fades with a pop, and the label colour eases in.
- Home section pill-bar is calmer: a single monotone frosted-glass capsule
  with no per-section hues, and a single monotone sliding pill.
- Unselected tab and chip labels are more translucent for a quieter bar.
- Buttons, close (×) icons, category chips, the sort icon and entry cards all
  dip in with a spring-back on press, matching the icon buttons.

## [1.3.7] - 2026-11-10
### Changed
- Splash/launch loading spinner is now a rounded, semi-transparent crimson
  arc on a richer multi-stop themed wash with a soft top bloom.
- Branding line changed from "BY WETIDOM" to "POWERED BY LARAF".
- Onboarding notification button now animates "Включить" → spinner →
  "Включено" in place instead of the screen jumping away.

### Fixed
- Onboarding "Включить" no longer requests the background/exact-alarm
  permissions, so it shows only the notification dialog and never opens a
  settings page mid-flow.

### Removed
- All tooltips across the app (and the shared tooltip theme).

## [1.3.6] - 2026-11-10
### Changed
- Screen widget tests for the home and entry editors, plus shared test
  helpers; localization strings are now checked for parity across ru/en/fr.
- Large screens (home, settings, favorites) split into focused part files.
- Localization moved to ARB files (`lib/l10n/arb/`) as the single source of
  truth, with `flutter gen-l10n` and a generated Dart map behind the existing
  `L.tr` API.

### Fixed
- Reminder dialog showed a literal `{time}` placeholder instead of the time.

## [1.3.5] - 2026-11-09
### Changed
- New app artwork: cream crescent moon on a pure black field (was peach
  gradient). Every launcher icon, splash screen and in-app avatar now sits on
  black, so the moon reads as a floating crescent on all platforms.
- Repository tidy-up: removed one-off `fix*.py` / `build*.cmd` scripts and
  root screenshots; docs moved to `docs/`, build scripts to `tools/`.
### Added
- In-app Android update check and APK installation from GitHub Releases
- Automatic signed APK releases when a matching version tag is pushed

### Improved
- Android release builds use a persistent release signing key

## [1.3.0] - 2026-08-18
### Added
- Auto-export functionality: hourly backups to Downloads/Ataraxy
- AI assistant with multiple free providers (Pollinations, AI Horde, OpenRouter, etc.)
- Support for DeepSeek V4 Flash and other modern LLMs
- New theme: MUTILATED (high-contrast dark theme)
- Pomodoro timer screen
- Daily guide prompts
- Statistics with charts (fl_chart integration)
- Voice input (speech_to_text)
- Auto-save for entries

### Fixed
- Performance optimizations for Redmi Note 12
- USB debugging authorization flow
- Android 13+ scoped storage compatibility
- Notification delivery on MIUI/Redmi devices
- Auto-export fallback to app documents when Downloads access fails

### Improved
- UI/UX consistency across themes
- Error handling in main.dart and services
- Documentation and README
- Test coverage for core functionality

## [1.2.0] - 2026-07-15
### Added
- Dream journal with lucid dream tracking
- Life journal with water/fasting/pomodoro tracking
- Tulpa journal with forcing duration tracking
- Favorites and pinned entries
- Multi-language support (Russian, English, French)
- Dynamic color theming (Material You)
- Lock screen with PIN protection
- Daily reminders and notifications

### Fixed
- Android build configuration for embedding v2
- Theme switching performance
- Notification icon display on Android

## [1.0.0] - 2026-05-01
### Added
- Initial release
- Basic journal functionality
- Light/dark theme support
- Settings screen
- About screen
