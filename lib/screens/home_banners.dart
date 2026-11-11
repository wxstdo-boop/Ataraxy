part of 'home_screen.dart';

class _DailyGuideBanner extends StatelessWidget {
  final DailyGuideTopic topic;
  final VoidCallback onTap;

  const _DailyGuideBanner({required this.topic, required this.onTap});

  // Dream prompts imported from data/daily_prompts.dart (~220 entries,
  // enough for 5+ years of unique daily content).

  // Tulpa prompts imported from data/daily_prompts.dart (~200 entries).

  static int _dayIndex(int length) => dp.dailyIndex(length);

  static List<_DailyGuidePrompt> get _dreamPrompts => dp.dreamPrompts;
  static List<_DailyGuidePrompt> get _tulpaPrompts => dp.tulpaPrompts;

  @override
  Widget build(BuildContext context) {
    final isDream = topic == DailyGuideTopic.lucidDreams;
    final prompts = isDream ? _dreamPrompts : _tulpaPrompts;
    final idx = _DailyGuideBanner._dayIndex(prompts.length);
    final prompt = dp.promptForLocale(
      index: idx,
      languageCode: Localizations.localeOf(context).languageCode,
      isDream: isDream,
    );

    // Theme-driven gradient with a daily hue rotation: the banner always
    // belongs to the ACTIVE theme (primary → tertiary) yet every day shifts
    // the hue slightly, so consecutive days stay visually distinct without
    // ever clashing with the app palette.
    // The swing is deliberately capped at ±24°: the old `(idx * 17) % 360`
    // walked the whole color wheel, so a lavender app could get a green
    // banner — a palette clash rather than a daily variation.
    final scheme = Theme.of(context).colorScheme;
    final shift = (((idx % 5) - 2) * 12).toDouble();
    Color shiftHue(Color c, double delta) => HSLColor.fromColor(c)
        .withHue((HSLColor.fromColor(c).hue + delta) % 360)
        .toColor();
    final gradient = [
      shiftHue(scheme.primary, shift.toDouble()),
      shiftHue(scheme.tertiary, shift.toDouble()),
    ];

    return Padding(
      // Inside the list header the list already applies 16px horizontal
      // padding — only keep vertical rhythm here.
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: PressScale(
        scale: 0.97,
        haptic: true,
        child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        elevation: 6,
        shadowColor: gradient.first.withValues(alpha: 0.3),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: [
                // Subtle decorative circles in the background for depth
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -15,
                  left: 30,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon tile with frosted glass + glow
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: gradient.first.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(prompt.icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prompt.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontSize: 15,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              prompt.subtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    height: 1.3,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      // Day counter badge — shows which prompt
                      // of the cycle we're on.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

typedef _DailyGuidePrompt = dp.DailyGuidePrompt;

class _FavoritesBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _FavoritesBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Inside the list header the list already applies 16px horizontal
      // padding — only keep vertical rhythm here.
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: PressScale(
        scale: 0.97,
        haptic: true,
        child: Material(
        borderRadius: BorderRadius.circular(16),
        // Clip.antiAlias: without it a Material with a solid colour draws its
        // own background rounded but leaves the child's square corners (and
        // the ink splash) un-clipped — the "острые углы фона" on the plate.
        clipBehavior: Clip.antiAlias,
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L.tr(context, 'favoritesBannerTitle'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        L.tr(context, 'favoritesBannerSubtitle'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// "Любимое дело" banner — sits ABOVE the Favorites banner in the Life tab,
/// opens the new FavoriteActivityScreen with a beautiful reading mode.
class _FavoriteActivitiesBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _FavoriteActivitiesBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Inside the list header the list already applies 16px horizontal
      // padding — only keep vertical rhythm here.
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: PressScale(
        scale: 0.97,
        haptic: true,
        child: Material(
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.secondary, scheme.tertiary],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.spa_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L.tr(context, 'favoriteActivityBannerTitle'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          L.tr(context, 'favoriteActivityBannerSubtitle'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _MadeWithLove extends StatelessWidget {
  const _MadeWithLove({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 16,
            color: scheme.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Text(
            L.tr(context, 'madeWithLove'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

/// Beautiful gradient banner for the "ВСЕ" tab — shows only note-type entries
/// (EntryType.general) count. Clickable — opens a screen with all notes.
class _AllBanner extends StatelessWidget {
  final List<JournalEntry> entries;
  final VoidCallback onTap;
  const _AllBanner({required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final notes = entries.where((e) => e.type == EntryType.general).toList();
    if (notes.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Inside the list header the list already applies 16px horizontal
      // padding — only keep vertical rhythm here.
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: PressScale(
        scale: 0.97,
        haptic: true,
        child: Material(
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.secondary, scheme.tertiary],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L.tr(context, 'tabNotes'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${L.tr(context, 'totalEntries')}: ${notes.length}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${notes.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
