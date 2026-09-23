import 'package:flutter/material.dart';

enum AppThemeMode {
  system,
  lightMaterialYou,
  lightLavender,
  lightGrok,
  darkPeach,
  mutilated,
}

extension AppThemeModeExtension on AppThemeMode {
  String get label {
    return switch (this) {
      AppThemeMode.system => 'Системная (Material You)',
      AppThemeMode.lightMaterialYou => 'Светлая персиковая',
      AppThemeMode.lightLavender => 'Лавандовая',
      AppThemeMode.lightGrok => 'Светлая Grok',
      AppThemeMode.darkPeach => 'Тёмная персиковая',
      // Без переводов — название темы одно во всех языках.
      AppThemeMode.mutilated => 'MUTILATED',
    };
  }

  String get translationKey {
    return switch (this) {
      AppThemeMode.system => 'themeSystem',
      AppThemeMode.lightMaterialYou => 'themeLightPeach',
      AppThemeMode.lightLavender => 'themeLightLavender',
      AppThemeMode.lightGrok => 'themeLightGrok',
      AppThemeMode.darkPeach => 'themeDarkPeach',
      AppThemeMode.mutilated => 'themeMutilated',
    };
  }
}

class AppTheme {
  // Seeds keep the theme's identity but lose their glare: the old peach
  // (#FF8A65) and violet (#9C8BD0) seeds generated containers at FULL
  // saturation — #FFDBD0 and #FFF1ED measure saturation 1.00 — which is what
  // made the whole app feel garish ("вырвиглазно") on a phone panel. A dusty
  // clay peach and a slightly deeper, greyer violet read as the same theme
  // while every derived role comes out calmer (see [_harmonise], which also
  // caps chroma for the dynamic Material You schemes).
  static const Color _peachAccentSeed = Color(0xFFD98A6C);
  static const Color _lavenderSeed = Color(0xFF9A8EC6);

  // Brand display font: Cormorant, a high-contrast serif with Cyrillic
  // support and a REAL slanted italic cut (no faux-italic skewing). It is
  // used only for display/title sizes — body text stays in the system sans
  // so long-form reading keeps its legibility.
  static const String displayFont = 'Cormorant';

  // Global caches so switching themes (and the 600ms cross-fade that
  // rebuilds the whole tree every frame) never re-runs the expensive
  // ColorScheme.fromSeed + ThemeData construction. Built once per mode,
  // reused forever.
  static final Map<AppThemeMode, ThemeData> _lightCache = {};
  static final Map<AppThemeMode, ThemeData> _darkCache = {};

  // ---------------------------------------------------------------------
  // Palette harmoniser
  //
  // Every palette in the app (dynamic Material You included) passes through
  // [_harmonise] exactly once, right inside [_base]. It does two things and
  // nothing else — hue and tone stay where Material put them, so contrast
  // ratios and the theme's identity survive:
  //
  //  1. CHROMA CEILING. The generated seeds loved saturation: the light peach
  //     theme's primaryContainer came out #FFDBD0 (s 1.00), its surface
  //     #FFF1ED (s 1.00), the lavender primaryContainer #E8DDFF (s 1.00).
  //     Full-chroma pastel washes are what the eye reads as "вырвиглазно" —
  //     the caps below keep the hue, keep the lightness (so text contrast is
  //     untouched) and simply pull the colour out of the neon range.
  //
  //  2. HUE FAMILY. `ColorScheme.fromSeed` walks secondary/tertiary around
  //     the colour wheel, so every `[primary, secondary, tertiary]` gradient
  //     (AppBar backdrops, banners, badges) ramped across unrelated hues —
  //     the peach pair went rust → brown → OLIVE (#6B5E2F), the lavender one
  //     violet → grey → mauve, Grok charcoal → charcoal → purple. Setting
  //     absolute, small hue offsets from the primary turns every one of those
  //     gradients into an analogous, calm sweep.
  //
  // Both steps are idempotent (caps are monotone, hues are *set*, not
  // nudged), so re-harmonising a scheme can never drift a palette.
  // ---------------------------------------------------------------------

  /// Hue offsets from the primary that keep secondary/tertiary visibly
  /// related: warm-leaning tertiary, cool-leaning secondary.
  static const double _secondaryHueOffset = -10;
  static const double _tertiaryHueOffset = 16;

  /// Clamps chroma in HSL space, leaving hue and lightness untouched.
  static Color _cap(Color c, double maxSaturation) {
    final h = HSLColor.fromColor(c);
    if (h.saturation <= maxSaturation) return c;
    return h.withSaturation(maxSaturation).toColor();
  }

  /// Places [c] at [hue] on the wheel, keeping its own saturation/lightness.
  static Color _atHue(Color c, double hue) =>
      HSLColor.fromColor(c).withHue(hue % 360).toColor();

  static ColorScheme _harmonise(ColorScheme s) {
    final dark = s.brightness == Brightness.dark;
    final hue = HSLColor.fromColor(s.primary).hue;
    return s.copyWith(
      // Accents: a touch less chroma than Material's default.
      primary: _cap(s.primary, dark ? 0.58 : 0.48),
      secondary: _cap(_atHue(s.secondary, hue + _secondaryHueOffset),
          dark ? 0.34 : 0.30),
      tertiary: _cap(
          _atHue(s.tertiary, hue + _tertiaryHueOffset), dark ? 0.45 : 0.34),
      // Containers are the loudest surfaces in the app (tab pills, cards,
      // chips, the home header glass) — cap them hardest.
      primaryContainer: _cap(_atHue(s.primaryContainer, hue), 0.45),
      secondaryContainer:
          _cap(_atHue(s.secondaryContainer, hue + _secondaryHueOffset), 0.38),
      tertiaryContainer:
          _cap(_atHue(s.tertiaryContainer, hue + _tertiaryHueOffset), 0.38),
      // Semantic red stays recognisable, just no longer fluorescent.
      error: _cap(s.error, dark ? 0.75 : 0.62),
      // Backgrounds keep a hint of the theme's tint and lose the wash.
      surface: _cap(s.surface, 0.30),
      surfaceContainerLowest: _cap(s.surfaceContainerLowest, 0.26),
      surfaceContainerLow: _cap(s.surfaceContainerLow, 0.28),
      surfaceContainer: _cap(s.surfaceContainer, 0.30),
      surfaceContainerHigh: _cap(s.surfaceContainerHigh, 0.32),
      surfaceContainerHighest: _cap(s.surfaceContainerHighest, 0.34),
      outline: _cap(s.outline, 0.30),
      outlineVariant: _cap(s.outlineVariant, 0.34),
    );
  }

  /// The gradient behind every screen's AppBar ([PremiumHeader]).
  ///
  /// Screens paint white titles/icons over this, so it must stay dark in BOTH
  /// brightnesses. The old call sites passed `[primary, secondary, tertiary]`
  /// straight from the scheme, which on the dark themes meant the *pastel*
  /// primary (#FFB59D, #CEBDFF) as a bar background — the loudest surface in
  /// the app, right under the status bar. Dark themes now build the bar from
  /// their containers pulled toward the surface; light themes blend the
  /// primary into the (already harmonised) secondary/tertiary so the ramp is
  /// analogous instead of a three-hue rainbow.
  static List<Color> headerColors(ColorScheme s) {
    if (s.brightness == Brightness.dark) {
      final top = Color.lerp(s.primaryContainer, s.surface, 0.30)!;
      return [
        top,
        Color.lerp(top, s.secondaryContainer, 0.45)!,
        Color.lerp(top, s.tertiaryContainer, 0.50)!,
      ];
    }
    return [
      s.primary,
      Color.lerp(s.primary, s.secondary, 0.55)!,
      Color.lerp(s.primary, s.tertiary, 0.65)!,
    ];
  }

  static ColorScheme _fixLightColors(
    ColorScheme s, {
    // Tinted per-theme instead of Material's neutral grey: warm greys for
    // peach, violet greys for lavender — surfaces stop looking "cheap".
    Color onSurface = const Color(0xFF1C1B1F),
    Color onSurfaceVariant = const Color(0xFF444746),
    Color outline = const Color(0xFF747775),
  }) {
    return s.copyWith(
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
    );
  }

  static ThemeData _base(
    ColorScheme rawScheme, {
    Color? scaffoldBg,
    // Header tone. Null → derived from the HARMONISED scheme: light themes
    // take the (already calmed) primary, dark themes take primaryContainer so
    // the bar is a deep tone with light text instead of the pastel primary
    // that used to glow at the top of a dark screen.
    Color? headerBg,
    Color? headerFg,
    bool boostLightText = false,
    // Цвет снекбара и текста на нём — берётся из темы чтобы отличаться
    Color? snackBg,
    Color? snackFg,
  }) {
    final scheme = _harmonise(rawScheme);
    final dark = scheme.brightness == Brightness.dark;
    final effectiveHeaderBg =
        headerBg ?? (dark ? scheme.primaryContainer : scheme.primary);
    final effectiveHeaderFg =
        headerFg ?? (dark ? scheme.onPrimaryContainer : scheme.onPrimary);
    final effectiveSnackBg = snackBg ?? scheme.inverseSurface;
    final effectiveSnackFg = snackFg ?? scheme.onInverseSurface;

    // Premium typography: display sizes use the brand serif Cormorant in
    // italic (a true slanted cut) with tight tracking, while body sizes keep
    // the system sans and relaxed spacing for readability.
    final baseTextTheme = TextTheme(
      headlineLarge: const TextStyle(
        fontFamily: displayFont,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.bold,
        fontSize: 28,
        letterSpacing: -0.6,
      ),
      headlineMedium: const TextStyle(
        fontFamily: displayFont,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        letterSpacing: -0.4,
      ),
      headlineSmall: const TextStyle(
        fontFamily: displayFont,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        letterSpacing: -0.3,
      ),
      titleLarge: const TextStyle(
        fontFamily: displayFont,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        fontSize: 20,
        letterSpacing: -0.3,
      ),
      titleMedium: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      bodyLarge: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 1.5,
        letterSpacing: boostLightText ? 0.1 : null,
      ),
      bodyMedium: TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.5,
        letterSpacing: boostLightText ? 0.1 : null,
      ),
      bodySmall: TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 1.4,
      ),
      labelLarge: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      labelMedium: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg ?? scheme.surfaceContainerLowest,
      textTheme: baseTextTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: effectiveHeaderBg,
        foregroundColor: effectiveHeaderFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Slightly bigger AppBar titles («Настройки», «Сон», «Редактировать»)
        // — and explicitly the system sans, so headers never inherit the
        // display font's italic cut.
        titleTextStyle: TextStyle(
          color: effectiveHeaderFg,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shadowColor: scheme.shadow.withValues(alpha: 0.10),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        elevation: 4,
        highlightElevation: 6,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        // Softer placeholder + icon colors keep the fields from looking
        // harsh on any theme.
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.secondaryContainer,
        labelStyle: TextStyle(
          fontSize: 13,
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 13,
          color: scheme.onSecondaryContainer,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 10,
        shadowColor: scheme.shadow.withValues(alpha: 0.18),
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primaryContainer;
          }
          return scheme.surfaceContainerHighest;
        }),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: effectiveSnackBg,
        contentTextStyle: TextStyle(
          color: effectiveSnackFg,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        actionTextColor: scheme.primary == effectiveSnackBg
            ? effectiveSnackFg
            : scheme.primaryContainer,
        elevation: 8,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 8,
        shadowColor: scheme.shadow.withValues(alpha: 0.12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        // A hairline top border + faint shadow give the bar a subtle lift
        // against the scroll content on every theme (pure chrome, no
        // palette change).
        elevation: 2,
        shadowColor: scheme.shadow.withValues(alpha: 0.08),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      tooltipTheme: TooltipThemeData(
        // Consistent Material-style tooltips BELOW their button by default
        // (preferBelow: true). Clean rounded pill — no pointer arrow: a
        // floating bubble reads calmer than a speech bubble with a tail.
        preferBelow: true,
        decoration: ShapeDecoration(
          color: scheme.brightness == Brightness.light
              ? Colors.white
              : scheme.inverseSurface,
          shadows: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        textStyle: TextStyle(
          color: scheme.brightness == Brightness.light
              ? scheme.onSurface
              : scheme.onInverseSurface,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        excludeFromSemantics: false,
        waitDuration: const Duration(milliseconds: 400),
        showDuration: const Duration(seconds: 3),
      ),
    );
  }

  static ThemeData lightMaterialYou({ColorScheme? scheme}) {
    // Distinct from "Системная (Material You)" — the user reported the two
    // looked identical when their wallpaper happened to be peach-toned. We
    // pin a deeper, more saturated peach seed (`_peachAccentSeed`) so this
    // theme always lands on a clearly different palette from the dynamic
    // colorScheme Material You derives from the device wallpaper.
    final s =
        scheme ??
        ColorScheme.fromSeed(
          seedColor: _peachAccentSeed,
          brightness: Brightness.light,
          surface: const Color(0xFFFCF8F5),
        );
    return _base(
      _fixLightColors(
        s,
        // Warm-tinted ink instead of neutral grey — the whole palette
        // reads cozier and more deliberate on the peach background.
        onSurface: const Color(0xFF2B211A),
        onSurfaceVariant: const Color(0xFF5F5248),
        outline: const Color(0xFF9A8E85),
      ),
      scaffoldBg: s.surfaceContainerLow,
      // No explicit header: [_base] derives it (light → harmonised primary).
      boostLightText: true,
      // Светлая тема → светлый снекбар (тёплый персиковый)
      snackBg: const Color(0xFFFFF3EA),
      snackFg: const Color(0xFF5B2A10),
    );
  }

  static ThemeData lightLavender() {
    final s = ColorScheme.fromSeed(
      seedColor: _lavenderSeed,
      brightness: Brightness.light,
      surface: const Color(0xFFFBF9FE),
    );
    return _base(
      _fixLightColors(
        s,
        // Violet-tinted ink: keeps the lavender mood in the text as well,
        // instead of dropping to Material's neutral grey.
        onSurface: const Color(0xFF241F33),
        onSurfaceVariant: const Color(0xFF5B5670),
        outline: const Color(0xFF928DA6),
      ),
      scaffoldBg: s.surfaceContainerLow,
      boostLightText: true,
      // Светлая тема → светлый лавандовый снекбар
      snackBg: const Color(0xFFF2ECFD),
      snackFg: const Color(0xFF2A1F45),
    );
  }

  /// Grok theme: black & white minimalist, with the extremes pulled in.
  /// Uses Brightness.light so that system bars stay dark-on-light. The old
  /// palette was pure #FFFFFF paper under #111 ink — the harshest pairing the
  /// eye gets, and on the Redmi's AMOLED panel it read as a sheet of light at
  /// night. Warm off-white paper + lifted charcoal keep the same stark Grok
  /// identity without the glare, and `onSurface` stays dark enough that labels
  /// on cards and chips remain fully legible.
  static ThemeData darkGrok({ColorScheme? scheme}) {
    const Color charcoal = Color(0xFF1C1F26);
    const Color paper = Color(0xFFFAF9F7);
    const Color ink = Color(0xFF1F2328);
    const Color textSecondary = Color(0xFF555B66);
    const Color neutralGrey = Color(0xFFE7E4DF);

    final gs = ColorScheme.fromSeed(
      seedColor: charcoal,
      brightness: Brightness.light,
      surface: paper,
    ).copyWith(
      primary: charcoal,
      onPrimary: Colors.white,
      secondary: charcoal,
      onSecondary: Colors.white,
      secondaryContainer: neutralGrey,
      onSecondaryContainer: charcoal,
      primaryContainer: neutralGrey,
      onPrimaryContainer: charcoal,
      surface: paper,
      surfaceContainerHighest: neutralGrey,
      onSurface: ink,
      onSurfaceVariant: textSecondary,
      outline: const Color(0xFF98938C),
    );

    final themed = _base(
      gs,
      scaffoldBg: paper,
      // Header derives from the scheme — Grok's primary IS the charcoal, so
      // the bar stays black-on-white's calm counterpart.
      boostLightText: true,
      // Grok (светлая) → бумажный снекбар с графитовым текстом
      snackBg: const Color(0xFFF4F2EF),
      snackFg: ink,
    );

    return themed.copyWith(
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(charcoal),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF3A404A);
          }
          return const Color(0xFFDAD6D0);
        }),
        trackOutlineColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: charcoal, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return charcoal;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll<Color>(Colors.white),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: const Color(0xFF4B5057),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  /// MUTILATED — a light, airy palette where *dusty* blood red seeps through
  /// the section backgrounds. Scaffold + card surfaces are warm and opaque so
  /// the animated blood-flow layer behind the app shows through softly;
  /// accents are a desaturated brick rose with maroon depth (the old vivid
  /// crimson #A62B2B / #C1121F was the single loudest colour in the app).
  static ThemeData lightMutilated() {
    const Color blood = Color(0xFF9E524C);
    const Color deepBlood = Color(0xFF412729);
    const Color paleBlood = Color(0xFFEDDCD8);
    const Color cream = Color(0xFFFCF7F4);

    final s = ColorScheme.fromSeed(
      seedColor: blood,
      brightness: Brightness.light,
      surface: cream,
    ).copyWith(
      primary: blood,
      onPrimary: Colors.white,
      primaryContainer: paleBlood,
      onPrimaryContainer: const Color(0xFF35201F),
      secondary: const Color(0xFF7A4A46),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFEFDDDA),
      onSecondaryContainer: const Color(0xFF35201F),
      tertiary: const Color(0xFF5E4243),
      onTertiary: Colors.white,
      error: const Color(0xFFA65C56),
      surface: cream,
      onSurface: const Color(0xFF231A19),
      onSurfaceVariant: const Color(0xFF5C4A47),
      outline: const Color(0xFF9A847F),
      outlineVariant: const Color(0xFFE2CFCA),
      // Fully OPAQUE warm surfaces. The blood layer is painted ON TOP of
      // the app (not behind it), so translucency buys nothing visually —
      // and translucent containers force the GPU to blend against the
      // white window background every frame, which read as a whitish
      // flicker on low-end phones. Opaque = same look, zero shimmer.
      surfaceContainerLowest: const Color(0xFFFFFAF7),
      surfaceContainerLow: const Color(0xFFFBF2EE),
      surfaceContainer: const Color(0xFFF6E9E4),
      surfaceContainerHigh: const Color(0xFFF2E2DD),
      surfaceContainerHighest: const Color(0xFFEBD8D3),
    );

    // Harmonised once here so the card/nav-bar overrides below use the same
    // calmed tones [_base] ends up with (the pass is idempotent, so `_base`
    // harmonising again changes nothing).
    final hs = _harmonise(s);

    return _base(
      s,
      scaffoldBg: const Color(0xFFFFFAF7),
      // Deep maroon bar (vivid blood #4F1010 → dusty #412729) with warm
      // off-white type instead of stark white.
      headerBg: deepBlood,
      headerFg: const Color(0xFFF7E9E5),
      boostLightText: true,
      // Кровавый снекбар: тёмно-розовый с бледным текстом.
      snackBg: const Color(0xFF4A2F30),
      snackFg: const Color(0xFFF6E7E3),
    ).copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: hs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shadowColor: s.shadow.withValues(alpha: 0.10),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: hs.surfaceContainer.withValues(alpha: 0.92),
        indicatorColor: hs.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: s.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 2,
        shadowColor: s.shadow.withValues(alpha: 0.08),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData darkPeach() {
    // Force a distinctly darker palette so "Тёмная персиковая" is never
    // confused with the light peach themes. The seed is a deep burnt orange
    // and we pin surface/background colors to true dark values instead of
    // relying on Material You's fromSeed which tends to brighten light seeds.
    const deepSeed = Color(0xFF8B3A1E);
    final s = ColorScheme.fromSeed(
      seedColor: deepSeed,
      brightness: Brightness.dark,
      surface: const Color(0xFF1A1210),
    ).copyWith(
      // Warm amber tertiary: [_harmonise] pulls it into the peach's own hue
      // family and caps its chroma, so two-stop gradient banners (daily guide,
      // entry cards) get a muted ember glow instead of a muddy second orange.
      tertiary: const Color(0xFFE0A458),
      onTertiary: const Color(0xFF2B1A08),
      // Softer night ink: warm cream instead of icy near-white — the harsh
      // blue-white text was what made the dark theme sting the eyes.
      onSurface: const Color(0xFFE9DFD3),
      onSurfaceVariant: const Color(0xFFB5A795),
      outline: const Color(0xFF7E7260),
      // Very dark, but not crushed to pure black: #0D0908 read as a hard void
      // right under the (previously pastel) bar on an OLED panel.
      surfaceContainerLowest: const Color(0xFF151110),
      surfaceContainerLow: const Color(0xFF1A1210),
      surfaceContainer: const Color(0xFF221814),
      surfaceContainerHigh: const Color(0xFF2A1E18),
      surfaceContainerHighest: const Color(0xFF372920),
    );
    return _base(
      s,
      scaffoldBg: const Color(0xFF151110),
      // No explicit header: a dark theme derives a DEEP primaryContainer bar
      // (#723521) with light onPrimaryContainer type — the old bright primary
      // (#FFB59D) header was the single most glaring surface at night.
      // Тёмная тема → тёмный снекбар с тёплым светлым текстом
      snackBg: const Color(0xFF32241C),
      snackFg: const Color(0xFFFFE4D4),
    );
  }

  static ThemeData systemLight(ColorScheme? dynamicScheme) {
    if (dynamicScheme != null) {
      return _base(
        _fixLightColors(dynamicScheme),
        scaffoldBg: dynamicScheme.surfaceContainerLow,
        // Header derives from the harmonised scheme (see [_base]).
        boostLightText: true,
        // Светлая тема → светлый снекбар из поверхности
        snackBg: dynamicScheme.surfaceContainerHigh,
        snackFg: dynamicScheme.onSurface,
      );
    }
    return lightMaterialYou();
  }

  static ThemeData systemDark(ColorScheme? dynamicScheme) {
    if (dynamicScheme != null) {
      return _base(
        dynamicScheme,
        scaffoldBg: dynamicScheme.surfaceContainerLow,
        // Dark → deep primaryContainer bar with light type.
        // Тёмная тема → тёмный снекбар из поверхности
        snackBg: dynamicScheme.surfaceContainerHigh,
        snackFg: dynamicScheme.onSurface,
      );
    }
    // Distinct dark fallback so "Системная" never looks identical to
    // "Тёмная персиковая" when the device has no dynamic colour scheme.
    final s = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.dark,
    ).copyWith(
      // Softer violet-grey ink for the fallback dark theme.
      onSurface: const Color(0xFFE4E1E9),
      onSurfaceVariant: const Color(0xFFB8B4C1),
      outline: const Color(0xFF837D8C),
    );
    return _base(
      s,
      scaffoldBg: s.surfaceContainerLow,
      snackBg: s.surfaceContainerHigh,
      snackFg: s.onSurface,
    );
  }

  static ThemeData of(
    AppThemeMode mode, {
    ColorScheme? dynamicLight,
    ColorScheme? dynamicDark,
  }) {
    // Only themes that depend on the live dynamic scheme are rebuilt on
    // every call; everything else is cached once per mode. Dynamic schemes
    // are intentionally NOT cached (they change with the wallpaper), but
    // that path is only taken on Android 12+ "system" mode.
    final cached = _lightCache[mode];
    if (cached != null) return cached;
    final built = switch (mode) {
      AppThemeMode.system => systemLight(dynamicLight),
      AppThemeMode.lightMaterialYou => lightMaterialYou(scheme: dynamicLight),
      AppThemeMode.lightLavender => lightLavender(),
      AppThemeMode.lightGrok => darkGrok(scheme: dynamicLight),
      AppThemeMode.darkPeach => darkPeach(),
      AppThemeMode.mutilated => lightMutilated(),
    };
    if (mode != AppThemeMode.system && mode != AppThemeMode.lightMaterialYou) {
      _lightCache[mode] = built;
    }
    return built;
  }

  static ThemeData darkLavender() {
        final s = ColorScheme.fromSeed(
      seedColor: _lavenderSeed,
      brightness: Brightness.dark,
    ).copyWith(
      // Softer lavender-grey ink — the "dark mode" text no longer glares.
      onSurface: const Color(0xFFEAE5F0),
      onSurfaceVariant: const Color(0xFFB9B3CA),
      outline: const Color(0xFF7F788F),
    );
    return _base(
      s,
      scaffoldBg: s.surfaceContainerLow,
      // Dark theme → deep violet primaryContainer bar (see [_base]) instead
      // of the pastel #CEBDFF primary that used to glow at the top.
      // Тёмная тема → тёмный лавандовый снекбар
      snackBg: const Color(0xFF2A2640),
      snackFg: const Color(0xFFEAE5F0),
    );
  }

  static ThemeData darkOf(AppThemeMode mode, {ColorScheme? dynamicDark}) {
    final cached = _darkCache[mode];
    if (cached != null) return cached;
    final built = switch (mode) {
      AppThemeMode.system => systemDark(dynamicDark),
      AppThemeMode.lightLavender => darkLavender(),
      AppThemeMode.lightGrok => darkGrok(scheme: dynamicDark),
      AppThemeMode.lightMaterialYou => darkPeach(),
      AppThemeMode.darkPeach => darkPeach(),
      // MUTILATED всегда светлая (свой отдельный вид).
      AppThemeMode.mutilated => lightMutilated(),
    };
    if (mode != AppThemeMode.system) {
      _darkCache[mode] = built;
    }
        return built;
  }
}

/// Hand-tuned, low-chroma accents shared by every screen.
///
/// The app used to sprinkle `Colors.purpleAccent`, `redAccent`, `blueAccent`,
/// `orangeAccent`, `Colors.red` and a few neon literals (`#FF6B9D`,
/// `#6B4EFF -> #FF4E8E -> #FFA84B`, `#C1121F`) over its own palettes. Those are
/// maximum-saturation Material swatches: they vibrate against any surface and
/// ignore the active theme entirely -- the eye-straining part of the UI.
///
/// Each colour below keeps the *meaning* of the hue it replaces (rose =
/// favourites, amber = streak/warning, sky = water/info, sage = success,
/// danger = destructive) while sitting at roughly half the chroma, so it can
/// even be read on a coloured card.
class AppAccents {
  AppAccents._();

  /// Lerp two [AppAccents] consts.
  static Color lerp(Color a, Color b, double t) =>
      Color.lerp(a, b, t) as Color;

  /// Favourites, hearts, favourite-media chrome.
  static const Color rose = Color(0xFFB4707C);
  static const Color roseLight = Color(0xFFCFA0A8);
  static const Color rosePale = Color(0xFFE2C8CB);

  /// Dusty mauve -- the cool partner of [rose] for two-stop pink ramps.
  static const Color mauve = Color(0xFF9C8AAE);

  /// Streaks, pinned markers, warnings, fasting timers.
  static const Color amber = Color(0xFFC08A4E);
  static const Color amberLight = Color(0xFFD6B375);
  static const Color amberPale = Color(0xFFE8D9BD);

  /// Water, info, the "random" category.
  static const Color sky = Color(0xFF6E8FB4);

  /// Success, granted permissions, step counters.
  static const Color sage = Color(0xFF6F9179);

  /// Dreams / night journal.
  static const Color lilac = Color(0xFF8779AE);

  /// Life journal, notes, "general" accents.
  static const Color clay = Color(0xFFBE8068);

  /// Neutral secondary accent (tulpa, placeholders).
  static const Color slate = Color(0xFF7C8798);

  /// The Life tab's teal.
  static const Color teal = Color(0xFF62958F);

  /// Destructive actions and error states -- brick red, not fire-engine.
  static const Color danger = Color(0xFFB0554F);
  static const Color dangerLight = Color(0xFFC48177);
}


