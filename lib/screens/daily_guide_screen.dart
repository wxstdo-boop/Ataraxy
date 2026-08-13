import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_journal/l10n/strings.dart';
import 'package:dream_journal/widgets/premium_header.dart';

enum DailyGuideTopic { lucidDreams, tulpa }

class DailyGuideScreen extends StatefulWidget {
  final DailyGuideTopic topic;

  const DailyGuideScreen({super.key, required this.topic});

  @override
  State<DailyGuideScreen> createState() => _DailyGuideScreenState();
}

class _DailyGuideScreenState extends State<DailyGuideScreen> {
  bool _completed = false;

  List<_Lesson> get _lessons => widget.topic == DailyGuideTopic.lucidDreams
      ? const [
          _Lesson(
            ru: 'Наблюдение',
            en: 'Observing',
            fr: 'Observer',
            textRu: 'Сегодня 3 раза спроси себя: «Я сплю?» и внимательно проверь детали вокруг.',
            textEn: "Today ask yourself 3 times: \"Am I dreaming?\" and carefully check the details around you.",
            textFr: "Aujourd'hui demande-toi 3 fois : « Suis-je en train de rêver ? » et vérifie attentivement les détails autour de toi.",
            icon: Icons.visibility_rounded,
          ),
          _Lesson(
            ru: 'Дневник снов',
            en: 'Dream journal',
            fr: 'Journal de rêves',
            textRu: 'После пробуждения запиши хотя бы три детали сна: место, чувство и персонажа.',
            textEn: 'After waking, write down at least three dream details: a place, a feeling and a character.',
            textFr: 'Au réveil, note au moins trois détails du rêve : un lieu, une émotion et un personnage.',
            icon: Icons.edit_note_rounded,
          ),
          _Lesson(
            ru: 'Намерение',
            en: 'Intention',
            fr: 'Intention',
            textRu: 'Перед сном спокойно повтори: «Я замечу, что сплю». Без давления — только интерес.',
            textEn: 'Before sleep, calmly repeat: \"I will notice that I am dreaming.\" No pressure — just curiosity.',
            textFr: 'Avant de dormir, répète calmement : « Je remarquerai que je rêve ». Sans pression — juste la curiosité.',
            icon: Icons.nights_stay_rounded,
          ),
          _Lesson(
            ru: 'Проверка реальности',
            en: 'Reality check',
            fr: 'Test de réalité',
            textRu: 'Посмотри на ладони или текст дважды. Во сне детали часто меняются.',
            textEn: 'Look at your palms or text twice. In dreams details often change.',
            textFr: 'Regarde tes paumes ou un texte deux fois. En rêve, les détails changent souvent.',
            icon: Icons.back_hand_rounded,
          ),
          _Lesson(
            ru: 'Память сна',
            en: 'Dream memory',
            fr: 'Mémoire du rêve',
            textRu: 'В течение дня вспомни последний сон и найди в нём один необычный знак.',
            textEn: 'During the day recall your last dream and find one unusual sign in it.',
            textFr: 'Dans la journée, rappelle-toi ton dernier rêve et trouve-y un signe inhabituel.',
            icon: Icons.psychology_rounded,
          ),
          _Lesson(
            ru: 'Мягкий фокус',
            en: 'Soft focus',
            fr: 'Focalisation douce',
            textRu: 'За час до сна убери яркий экран и выдели минуту на спокойное дыхание.',
            textEn: 'An hour before sleep, put away bright screens and take a minute for calm breathing.',
            textFr: 'Une heure avant de dormir, range les écrans lumineux et prends une minute pour respirer calmement.',
            icon: Icons.self_improvement_rounded,
          ),
          _Lesson(
            ru: 'Поддержка',
            en: 'Support',
            fr: 'Soutien',
            textRu: 'Даже один запомненный фрагмент — это прогресс. Стабильность важнее идеального результата.',
            textEn: 'Even one remembered fragment is progress. Consistency matters more than a perfect result.',
            textFr: 'Même un fragment mémorisé est un progrès. La régularité compte plus qu\'un résultat parfait.',
            icon: Icons.favorite_rounded,
          ),
        ]
      : const [
          _Lesson(
            ru: 'Бережный контакт',
            en: 'Gentle contact',
            fr: 'Contact doux',
            textRu: 'Общение начинается с уважения: слушай возникающие мысли без принуждения и ожиданий.',
            textEn: 'Communication starts with respect: listen to arising thoughts without force or expectations.',
            textFr: 'La communication commence par le respect : écoute les pensées qui surgissent sans contrainte ni attente.',
            icon: Icons.forum_rounded,
          ),
          _Lesson(
            ru: 'Безопасные границы',
            en: 'Safe boundaries',
            fr: 'Limites sûres',
            textRu: 'Сохраняй сон, учёбу, работу и отношения в приоритете. Практика не должна истощать.',
            textEn: 'Keep sleep, study, work and relationships a priority. The practice should not exhaust you.',
            textFr: 'Garde le sommeil, les études, le travail et les relations en priorité. La pratique ne doit pas épuiser.',
            icon: Icons.shield_outlined,
          ),
          _Lesson(
            ru: 'Диалог',
            en: 'Dialogue',
            fr: 'Dialogue',
            textRu: 'Попробуй короткий вопрос в дневнике и запиши ответ как свободную ассоциацию.',
            textEn: 'Try a short question in your journal and write the answer as a free association.',
            textFr: 'Essaie une courte question dans ton journal et note la réponse comme une association libre.',
            icon: Icons.chat_bubble_outline_rounded,
          ),
          _Lesson(
            ru: 'Терпение',
            en: 'Patience',
            fr: 'Patience',
            textRu: 'Не сравнивай свой опыт с чужим: внутренние образы и привычки формируются постепенно.',
            textEn: "Don't compare your experience with others': inner images and habits form gradually.",
            textFr: 'Ne compare pas ton expérience à celle des autres : les images intérieures et les habitudes se forment progressivement.',
            icon: Icons.hourglass_top_rounded,
          ),
          _Lesson(
            ru: 'Творчество',
            en: 'Creativity',
            fr: 'Créativité',
            textRu: 'Нарисуй или опиши спокойное место для диалога. Это развивает воображение без давления.',
            textEn: 'Draw or describe a calm place for dialogue. It develops imagination without pressure.',
            textFr: 'Dessine ou décris un lieu calme pour le dialogue. Cela développe l\'imagination sans pression.',
            icon: Icons.palette_outlined,
          ),
          _Lesson(
            ru: 'Рефлексия',
            en: 'Reflection',
            fr: 'Réflexion',
            textRu: 'Отметь, как практика влияет на настроение. Если становится тревожно — сделай паузу.',
            textEn: 'Notice how the practice affects your mood. If anxiety arises — take a pause.',
            textFr: 'Remarque comment la pratique affecte ton humeur. Si l\'anxiété monte — fais une pause.',
            icon: Icons.monitor_heart_outlined,
          ),
          _Lesson(
            ru: 'Поддержка',
            en: 'Support',
            fr: 'Soutien',
            textRu: 'Доброжелательность к себе — основа любого внутреннего диалога. Не нужно торопиться.',
            textEn: 'Kindness to yourself is the foundation of any inner dialogue. There is no rush.',
            textFr: 'La bienveillance envers soi est la base de tout dialogue intérieur. Pas besoin de se presser.',
            icon: Icons.volunteer_activism_rounded,
          ),
        ];

  String get _key =>
      'daily_guide_${widget.topic.name}_${DateUtils.dateOnly(DateTime.now()).millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _completed = prefs.getBool(_key) ?? false);
  }

  Future<void> _complete() async {
    await (await SharedPreferences.getInstance()).setBool(_key, true);
    if (mounted) setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lesson = _lessons[DateTime.now().weekday % _lessons.length];
    final isDream = widget.topic == DailyGuideTopic.lucidDreams;
    final title = isDream
        ? L.tr(context, 'guideDreamTitle')
        : L.tr(context, 'guideTulpaTitle');
    // Theme-driven gradient (primary → tertiary) with a subtle daily hue
    // rotation — the header and card always belong to the active theme yet
    // consecutive days stay visually distinct (mirrors the home banner).
    final dayShift = (DateTime.now().millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay *
            17) %
        360;
    Color shiftHue(Color c) => HSLColor.fromColor(c)
        .withHue((HSLColor.fromColor(c).hue + dayShift) % 360)
        .toColor();
    final themeGradient = isDream
        ? [shiftHue(scheme.primary), shiftHue(scheme.tertiary)]
        : [shiftHue(scheme.secondary), shiftHue(scheme.tertiary)];
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        flexibleSpace: PremiumHeader(colors: themeGradient),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildHeaderCard(context, lesson, isDream, scheme, themeGradient),
          const SizedBox(height: 20),
          _buildLessonCard(context, lesson, scheme),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              isDream
                  ? L.tr(context, 'guideHowItWorks')
                  : L.tr(context, 'guideWhyUseful'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          ..._tips(isDream).map((tip) {
            return _buildTipTile(context, tip, scheme);
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, _Lesson lesson, bool isDream,
      ColorScheme scheme, List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: (isDream ? scheme.primary : scheme.secondary)
                .withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(lesson.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 18),
          Text(
            isDream
                ? L.tr(context, 'guideDreamSubtitle')
                : L.tr(context, 'guideTulpaSubtitle'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          // Small label + big lesson title — no more "Практика дня: {title}"
          // crammed into one line (it read as raw "Практика дня: tittle").
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              L.tr(context, 'guideToday'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            lesson.title(context),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(BuildContext context, _Lesson lesson, ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                L.tr(context, 'guideToday'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lesson.text(context),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _completed ? null : _complete,
              icon: Icon(
                _completed ? Icons.check_rounded : Icons.task_alt_rounded,
              ),
              label: Text(
                _completed
                    ? L.tr(context, 'guideDone')
                    : L.tr(context, 'guideMarkDone'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipTile(BuildContext context, (IconData, String) tip,
      ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(tip.$1, color: scheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                tip.$2,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<(IconData, String)> _tips(bool isDream) {
    final code = Localizations.localeOf(context).languageCode;
    final l = (String ru, String en, String fr) => switch (code) {
          'en' => en,
          'fr' => fr,
          _ => ru,
        };
    return isDream
        ? [
            (
              Icons.auto_stories_rounded,
              l(
                'Дневник улучшает запоминание снов.',
                'A journal improves dream recall.',
                'Un journal améliore la mémorisation des rêves.',
              ),
            ),
            (
              Icons.repeat_rounded,
              l(
                'Короткая ежедневная практика надёжнее редких марафонов.',
                'Short daily practice beats rare marathons.',
                'Une pratique courte et quotidienne vaut mieux que de rares marathons.',
              ),
            ),
            (
              Icons.wb_twilight_rounded,
              l(
                'Осознанность строится на любопытстве, а не на усилии.',
                'Lucidity grows from curiosity, not effort.',
                'La lucidité naît de la curiosité, pas de l\'effort.',
              ),
            ),
          ]
        : [
            (
              Icons.diversity_3_rounded,
              l(
                'Воображаемый собеседник может поддерживать творческую рефлексию.',
                'An imaginary companion can support creative reflection.',
                'Un compagnon imaginaire peut soutenir la réflexion créative.',
              ),
            ),
            (
              Icons.balance_rounded,
              l(
                'Здоровые границы и обычный распорядок всегда важнее практики.',
                'Healthy boundaries and a normal routine always come before practice.',
                'Des limites saines et une routine normale passent toujours avant la pratique.',
              ),
            ),
            (
              Icons.support_rounded,
              l(
                'При тревоге или дискомфорте сделай паузу и поговори с близким или специалистом.',
                'If you feel anxious or uncomfortable, pause and talk to a loved one or a professional.',
                'En cas d\'anxiété ou d\'inconfort, fais une pause et parle à un proche ou à un professionnel.',
              ),
            ),
          ];
  }
}

class _Lesson {
  final String ru;
  final String en;
  final String fr;
  final String textRu;
  final String textEn;
  final String textFr;
  final IconData icon;
  const _Lesson({
    required this.ru,
    required this.en,
    required this.fr,
    required this.textRu,
    required this.textEn,
    required this.textFr,
    required this.icon,
  });

  String title(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return switch (code) {
      'en' => en,
      'fr' => fr,
      _ => ru,
    };
  }

  String text(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return switch (code) {
      'en' => textEn,
      'fr' => textFr,
      _ => textRu,
    };
  }
}
