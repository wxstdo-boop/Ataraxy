import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/theme/app_theme.dart';
import 'package:ataraxy/widgets/animated_snack.dart';
import 'package:ataraxy/widgets/app_avatar.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _patchNotesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(L.tr(context, 'about'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Hero(
              tag: 'app-avatar',
              child: Material(
                color: Colors.transparent,
                elevation: 0,
                shape: const CircleBorder(),
                child: const AppAvatar(radius: 72),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // New-Year hat: Material snowflake in the active theme
                // colour, matching the one in the home header.
                Icon(
                  Icons.ac_unit_rounded,
                  size: 28,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ataraxy',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'FOSS 1.3',
              style: TextStyle(
                fontSize: 16,
                color: scheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                L.tr(context, 'aboutDesc'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.code_rounded,
                    size: 18, color: scheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Text(
                  '${L.tr(context, 'version')} 1.3.4',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SupportButton(),
            const SizedBox(height: 16),
            _PatchNotesCard(
              expanded: _patchNotesExpanded,
              onTap: () => setState(
                () => _patchNotesExpanded = !_patchNotesExpanded,
              ),
            ),
            const SizedBox(height: 16),
            const _SteqtoqBanner(),
          ],
        ),
      ),
    );
  }
}

/// Кнопка «Поддержать» — красивый gradient-баннер с сердечком.
/// Открывает CloudTips по ссылке.
class _SupportButton extends StatelessWidget {
  const _SupportButton();

  static const _url = 'https://pay.cloudtips.ru/p/da0c7421';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () async {
          final uri = Uri.parse(_url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (context.mounted) {
              AnimatedSnack.show(
                context,
                L.tr(context, 'supportThanks'),
                type: SnackType.success,
              );
            }
          }
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            // Muted support banner: the neon #FF6C87 → #FF9FB6 → #FFB347 ramp
            // now runs rose → blush → sand, so the white label stays readable
            // without the card shouting across the screen.
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppAccents.rose,
                AppAccents.roseLight,
                AppAccents.amber,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppAccents.rose.withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                // Иконка сердца с анимацией пульса
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  builder: (context, v, child) => Transform.scale(
                    scale: v,
                    child: child,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L.tr(context, 'supportButton'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 18,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        L.tr(context, 'supportHint'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Expandable gradient card listing what's new in the current version
/// (and what is left to refine). Tapping toggles an AnimatedSize that
/// reveals the full bullet list — the rotation icon spins half a turn
/// to give a tactile "open / close" cue.
class _PatchNotesCard extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _PatchNotesCard({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppTheme.headerColors(scheme),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        L.tr(context, 'patchNotes'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 18,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !expanded
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _VersionHeader(
                                title: '1.3.4',
                                badge: '2026-09-22',
                                color: Colors.white,
                              ),
                              const SizedBox(height: 10),
                              _PatchBullet(
                                text: L.tr(context, 'pn133Repeat'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pn133Spots'),
                                color: Colors.white,
                              ),
                              const SizedBox(height: 18),
                              _VersionHeader(
                                title: '1.3.2',
                                badge: '2026-09-22',
                                color: Colors.white,
                              ),
                              const SizedBox(height: 10),
                              _PatchBullet(
                                text: L.tr(context, 'pn132Words'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pn132Order'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pn132Editor'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pn132Spots'),
                                color: Colors.white,
                              ),
                              const SizedBox(height: 18),
                              _VersionHeader(
                                title: '1.3.1',
                                badge: '2026-09-22',
                                color: Colors.white,
                              ),
                              const SizedBox(height: 10),
                              _PatchBullet(
                                text: L.tr(context, 'pn131Save'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pn131Meta'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pn131Export'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pn131Smooth'),
                                color: Colors.white,
                              ),
                              const SizedBox(height: 18),
                              _VersionHeader(
                                title: '1.3',
                                badge: '2026-08-09',
                                color: Colors.white,
                              ),
                              const SizedBox(height: 10),
                              _PatchBullet(
                                text: L.tr(context, 'pn13Web'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pn13Anim'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pn13Smooth'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pn13Limits'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pn13Card'),
                                color: Colors.white,
                              ),
                              const SizedBox(height: 18),
                              _VersionHeader(
                                title: '0.3',
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              const SizedBox(height: 10),
                              _PatchBullet(
                                text: L.tr(context, 'pnLocales'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pnPinnedFix'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pnBlurVideo'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pnNotesTab'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pnExport'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pnFavorites'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pnHeartbeatPlayer'),
                                color: Colors.white,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'pnPatchNotesSection'),
                                color: Colors.white,
                              ),
                              const SizedBox(height: 18),
                              _VersionHeader(
                                title: L.tr(context, 'whatsLeft'),
                                icon: Icons.pending_actions_rounded,
                                // Pale sand instead of neon amber.shade100 —
                                // still reads as a "todo" tint on the dark card.
                                color: AppAccents.amberPale,
                              ),
                              const SizedBox(height: 10),
                              _PatchBullet(
                                text: L.tr(context, 'remindersTodo'),
                                color: AppAccents.amberPale,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'autosaveTodo'),
                                color: AppAccents.amberPale,
                              ),
                              _PatchBullet(
                                text: L.tr(context, 'favoritesTodo'),
                                color: AppAccents.amberPale,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VersionHeader extends StatelessWidget {
  final String title;
  final String? badge;
  final IconData? icon;
  final Color color;
  const _VersionHeader({
    required this.title,
    this.badge,
    this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PatchBullet extends StatelessWidget {
  final String text;
  final Color color;
  const _PatchBullet({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.95),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Coming soon" tease for Steqtoq — a planned local video editor
/// (the dream Pipette alternative described in the user's roadmap). The
/// gradient skews purple→pink to differentiate it from the app palette
/// and visually position it as a separate, future-facing module.
class _SteqtoqBanner extends StatelessWidget {
  const _SteqtoqBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          AnimatedSnack.show(
            context,
            'Steqtoq — ${L.tr(context, 'comingSoon')}',
            type: SnackType.info,
            duration: const Duration(seconds: 2),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            // Steqtoq teaser: the violet/magenta/amber "synthwave" ramp is
            // gone — a dusty lilac → rose → amber sweep keeps the playful
            // mood without the neon glare.
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppAccents.lilac, AppAccents.rose, AppAccents.amber],
            ),
            boxShadow: [
              BoxShadow(
                color: AppAccents.lilac.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.movie_filter_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Steqtoq',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontSize: 18,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              L.tr(context, 'comingSoon'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        L.tr(context, 'steqtoqTag'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lock_clock_rounded,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
