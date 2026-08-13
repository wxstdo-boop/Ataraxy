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
  static const Color _peachAccentSeed = Color(0xFFFF8A65);
  static const Color _lavenderSeed = Color(0xFFB39DDB);

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

  static ColorScheme _fixLightColors(ColorScheme s) {
    return s.copyWith(
      onSurface: const Color(0xFF1C1B1F),
      onSurfaceVariant: const Color(0xFF444746),
      outline: const Color(0xFF747775),
    );
  }

  static ThemeData _base(
    ColorScheme scheme, {
    Color? scaffoldBg,
    required Color headerBg,
    required Color headerFg,
    bool boostLightText = false,
    // Цвет снекбара и текста на нём — берётся из темы чтобы отличаться
    Color? snackBg,
    Color? snackFg,
  }) {
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
        backgroundColor: headerBg,
        foregroundColor: headerFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Slightly bigger AppBar titles («Настройки», «Сон», «Редактировать»)
        // — and explicitly the system sans, so headers never inherit the
        // display font's italic cut.
        titleTextStyle: TextStyle(
          color: headerFg,
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
      _fixLightColors(s),
      scaffoldBg: s.surfaceContainerLow,
      headerBg: s.primary,
      headerFg: s.onPrimary,
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
      surface: const Color(0xFFFCF8F5),
    );
    return _base(
      _fixLightColors(s),
      scaffoldBg: s.surfaceContainerLow,
      headerBg: s.primary,
      headerFg: s.onPrimary,
      boostLightText: true,
      // Светлая тема → светлый лавандовый снекбар
      snackBg: const Color(0xFFF2ECFD),
      snackFg: const Color(0xFF2A1F45),
    );
  }

  /// Grok theme: black & white minimalist with strong contrast.
  /// Uses Brightness.light so that system bars stay dark-on-light, but colours
  /// are tuned for maximum readability — onSurface is near-black so labels on
  /// cards and chips are always legible.
  static ThemeData darkGrok({ColorScheme? scheme}) {
    const Color almostBlack = Color(0xFF0A0A0A);
    const Color onWhite = Color(0xFF111111);
    const Color textSecondary = Color(0xFF4B5563); // darker for readability

    final gs = ColorScheme.fromSeed(
      seedColor: almostBlack,
      brightness: Brightness.light,
      surface: const Color(0xFFFFFFFF),
    ).copyWith(
      primary: almostBlack,
      onPrimary: Colors.white,
      secondary: almostBlack,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE5E7EB),
      onSecondaryContainer: almostBlack,
      surface: Colors.white,
      onSurface: onWhite,
      onSurfaceVariant: textSecondary,
      outline: const Color(0xFF9CA3AF),
    );

    final themed = _base(
      gs,
      scaffoldBg: Colors.white,
      headerBg: almostBlack,
      headerFg: Colors.white,
      boostLightText: true,
      // Grok (светлая) → белый снекбар с чёрным текстом
      snackBg: const Color(0xFFF9FAFB),
      snackFg: const Color(0xFF111111),
    );

    return themed.copyWith(
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(Colors.black),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Color(0xFF333333);
          return Color(0xFFD1D5DB);
        }),
        trackOutlineColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: Color(0xFF0A0A0A), width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Color(0xFF0A0A0A);
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll<Color>(Colors.white),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: Color(0xFF444444)),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  /// MUTILATED — a light, airy palette where deep blood red seeps through
  /// the section backgrounds. Scaffold + card surfaces are slightly
  /// translucent so the animated blood-flow layer behind the app shows
  /// through softly; accents are rich crimson with dark-maroon depth.
  static ThemeData lightMutilated() {
    const Color blood = Color(0xFF9C1C1C);
    const Color deepBlood = Color(0xFF5A0E0E);
    const Color paleBlood = Color(0xFFF6E0DB);
    const Color cream = Color(0xFFFDF7F2);

    final s = ColorScheme.fromSeed(
      seedColor: blood,
      brightness: Brightness.light,
      surface: cream,
    ).copyWith(
      primary: blood,
      onPrimary: Colors.white,
      primaryContainer: paleBlood,
      onPrimaryContainer: const Color(0xFF3B0606),
      secondary: const Color(0xFF7C2D1E),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFF8E3DC),
      onSecondaryContainer: const Color(0xFF3B0606),
      tertiary: const Color(0xFF5A0E0E),
      onTertiary: Colors.white,
      error: const Color(0xFFB3261E),
      surface: cream,
      onSurface: const Color(0xFF211417),
      onSurfaceVariant: const Color(0xFF5C4A44),
      outline: const Color(0xFF9C7F77),
      outlineVariant: const Color(0xFFE4CCC4),
      // Fully OPAQUE warm surfaces. The blood layer is painted ON TOP of
      // the app (not behind it), so translucency buys nothing visually —
      // and translucent containers force the GPU to blend against the
      // white window background every frame, which read as a whitish
      // flicker on low-end phones. Opaque = same look, zero shimmer.
      surfaceContainerLowest: const Color(0xFFFFF9F4),
      surfaceContainerLow: const Color(0xFFFBF1EA),
      surfaceContainer: const Color(0xFFF6E7DF),
      surfaceContainerHigh: const Color(0xFFF2DFD6),
      surfaceContainerHighest: const Color(0xFFEDD3C9),
    );

    return _base(
      s,
      scaffoldBg: const Color(0xFFFFF9F4),
      headerBg: deepBlood,
      headerFg: Colors.white,
      boostLightText: true,
      // Кровавый снекбар: тёмно-красный с бледным текстом.
      snackBg: const Color(0xFF5A0E0E),
      snackFg: const Color(0xFFFFE9E2),
    ).copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: s.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shadowColor: s.shadow.withValues(alpha: 0.10),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: s.surfaceContainer.withValues(alpha: 0.92),
        indicatorColor: paleBlood,
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
      surfaceContainerLowest: const Color(0xFF0F0A08),
      surfaceContainerLow: const Color(0xFF1A1210),
      surfaceContainer: const Color(0xFF221814),
      surfaceContainerHigh: const Color(0xFF2A1E18),
      surfaceContainerHighest: const Color(0xFF32241C),
    );
    return _base(
      s,
      scaffoldBg: const Color(0xFF0F0A08),
      headerBg: s.primary,
      headerFg: s.onPrimary,
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
        headerBg: dynamicScheme.primary,
        headerFg: dynamicScheme.onPrimary,
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
        headerBg: dynamicScheme.primary,
        headerFg: dynamicScheme.onPrimary,
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
    );
    return _base(
      s,
      scaffoldBg: s.surfaceContainerLow,
      headerBg: s.primary,
      headerFg: s.onPrimary,
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
    );
    return _base(
      s,
      scaffoldBg: s.surfaceContainerLow,
      headerBg: s.primary,
      headerFg: s.onPrimary,
      // Тёмная тема → тёмный лавандовый снекбар
      snackBg: const Color(0xFF2A1F45),
      snackFg: const Color(0xFFEAE0FF),
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
