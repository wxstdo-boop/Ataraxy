import 'package:flutter/material.dart';
import 'daily_prompts_dream_translations.dart';
import 'daily_prompts_tulpa_translations.dart';

/// A single daily motivation prompt shown in the home-screen banner.
const double kMinYearsUnique = 5.0;

class DailyGuidePrompt {
  final String title;
  final String subtitle;
  final IconData icon;
  const DailyGuidePrompt(this.title, this.subtitle, this.icon);
}

/// Deterministic daily index that stays unique across years.
/// dayOfYear * prime + year * offset — with 220+ prompts, the same prompt
/// won't repeat for 220+ days, and the yearly offset (~7) ensures year-1
/// vs year-2 map different days to different prompts.
int dailyIndex(int length) {
  final now = DateTime.now();
  final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
  return (dayOfYear * 37 + now.year * 7) % length;
}

/// Returns the daily prompt for [index] in the given [languageCode]
/// (e.g. "en", "fr"). Falls back to the Russian original when a
/// translation is missing. [isDream] picks the dream vs tulpa set.
DailyGuidePrompt promptForLocale({
  required int index,
  required String languageCode,
  required bool isDream,
}) {
  final ru = isDream ? dreamPrompts : tulpaPrompts;
  if (index < 0 || index >= ru.length) {
    return ru[index % ru.length];
  }
  final translations = switch (languageCode) {
    'en' => isDream ? dreamPromptsEn : tulpaPromptsEn,
    'fr' => isDream ? dreamPromptsFr : tulpaPromptsFr,
    _ => ru,
  };
  if (index < translations.length) return translations[index];
  return ru[index];
}

// ────────────────────────────────────────────────────────────────────
//  DREAM prompts (~220 unique)
// ────────────────────────────────────────────────────────────────────

const dreamPrompts = <DailyGuidePrompt>[
  // ── Reality Checks ──
  DailyGuidePrompt('Руки', 'Посмотри на ладони — во сне пальцев часто больше или меньше', Icons.back_hand_rounded),
  DailyGuidePrompt('Зеркало', 'Посмотри на отражение — во сне лицо искажено', Icons.badge_rounded),
  DailyGuidePrompt('Текст', 'Прочитай надпись, отвернись и прочитай снова — текст во сне меняется', Icons.text_fields_rounded),
  DailyGuidePrompt('Часы', 'Посмотри на часы дважды — время во сне скачет', Icons.access_time_rounded),
  DailyGuidePrompt('Дыхание', 'Зажми нос и попробуй дышать — во сне можно дышать зажатым носом', Icons.air_rounded),
  DailyGuidePrompt('Свет', 'Выключи и включи свет — во сне переключатель часто не работает', Icons.lightbulb_rounded),
  DailyGuidePrompt('Зеркала', 'Встань перед зеркалом и рассмотри лицо — черты будут «плыть»', Icons.psychology_rounded),
  DailyGuidePrompt('Прыжок', 'Прыгни и приземлись — во сне приземление мягкое и медленное', Icons.accessibility_new_rounded),
  DailyGuidePrompt('Палец', 'Попробуй проткнуть ладонь пальцем — во сне палец пройдёт насквозь', Icons.touch_app_rounded),
  DailyGuidePrompt('Время', 'Запомни точное время и проверь через 5 минут — во сне оно сильно сдвинется', Icons.schedule_rounded),
  DailyGuidePrompt('Свет в комнате', 'Включи свет и обрати внимание на реакцию лампочки — во сне свет странно себя ведёт', Icons.light_mode_rounded),
  DailyGuidePrompt('Экран', 'Открой телефон и посмотри на экран — текст и цифры на экране во сне всегда «плавают»', Icons.phone_android_rounded),
  DailyGuidePrompt('Тело', 'Оглянись на своё тело — во сне пропорции искажены, руки слишком длинные', Icons.man_rounded),
  DailyGuidePrompt('Звук', 'Прислушайся к тишине — во сне звуки искажены, как будто под водой', Icons.hearing_rounded),
  DailyGuidePrompt('Запах', 'Вдохни и запомни запах — во сне обоняние слабое или странное', Icons.air_rounded),
  DailyGuidePrompt('Вкус', 'Попробуй что-нибудь на вкус — во сне вкусы нестабильны', Icons.restaurant_rounded),
  DailyGuidePrompt('Текст на стене', 'Найди любую надпись и перечитай её — во сне буквы «плывут»', Icons.menu_rounded),
  DailyGuidePrompt('Стена', 'Попробуй пройти сквозь стену — во сне стены мягкие', Icons.pan_tool_alt_rounded),
  DailyGuidePrompt('Вода', 'Окун руки в воду — во сне вода может быть тёплой и не мокрой', Icons.water_drop_rounded),
  DailyGuidePrompt('Пол', 'Посмотри на пол — во сне узоры на полу часто асимметричны', Icons.grid_on_rounded),
  DailyGuidePrompt('Руки и пальцы', 'Посчитай пальцы на руке — во сне их часто 6 или 4', Icons.numbers_rounded),
  DailyGuidePrompt('Зеркальная проверка', 'Посмотри на отражение и моргни — во сне отражение моргает с задержкой', Icons.face_rounded),

  // ── Dream Journaling & Recall ──
  DailyGuidePrompt('Дневник', 'Запиши всё, что вспомнишь, даже фрагмент — через час забудешь', Icons.auto_stories_rounded),
  DailyGuidePrompt('Пробуждение', 'Лежи неподвижно и вспоминай сон сразу после пробуждения — не двигайся', Icons.anchor_rounded),
  DailyGuidePrompt('Фрагменты', 'Запиши хотя бы одно слово или образ — маленький фрагмент ключ к большому сну', Icons.lightbulb_outline_rounded),
  DailyGuidePrompt('Эмоции', 'Запомни главную эмоцию сна — она подскажет его скрытый смысл', Icons.emoji_emotions_rounded),
  DailyGuidePrompt('Детали', 'Найди 5 деталей из сна — цвет, звук, запах, ощущение, движение', Icons.search_rounded),
  DailyGuidePrompt('Символы', 'Запиши повторяющиеся символы — они ключ к осознанности', Icons.auto_fix_high_rounded),
  DailyGuidePrompt('Настроение', 'Отметь настроение после сна — оно поможет отследить закономерности', Icons.monitor_heart_outlined),
  DailyGuidePrompt('Сравни', 'Сравни вчерашний сон с сегодняшним — какие повторяются темы?', Icons.compare_arrows_rounded),
  DailyGuidePrompt('Повтор', 'Найди повторяющийся сон или образ — это сигнал подсознания', Icons.repeat_rounded),
  DailyGuidePrompt('Персонажи', 'Вспомни людей из сна — часто это метафоры или подсознательные образы', Icons.group_rounded),
  DailyGuidePrompt('Место', 'Опиши место, где был во сне — его структуру и атмосферу', Icons.location_on_rounded),
  DailyGuidePrompt('Цвета', 'Вспомни цвета сна — яркие, тусклые, одноцветные?', Icons.palette_rounded),
  DailyGuidePrompt('Текст в дневнике', 'Перечитай вчерашнюю запись — может, вспомнишь новое', Icons.edit_note_rounded),
  DailyGuidePrompt('Образ дня', 'Выбери один образ из сегодняшнего дня и представь его во сне', Icons.image_rounded),

  // ── MILD (Mnemonic Induction) ──
  DailyGuidePrompt('Намерение', 'Перед сном повтори: «Я замечу, что сплю» — сделай это привычкой', Icons.nights_stay_rounded),
  DailyGuidePrompt('Цель сна', 'Перед сном реши: «Сегодня я осознаю себя во сне» — намерение направляет подсознание', Icons.flag_rounded),
  DailyGuidePrompt('Аффирмация', 'Повтори: «Я осознаю себя» 10 раз перед сном — повторение создаёт привычку', Icons.record_voice_over_rounded),
  DailyGuidePrompt('Визуализация', 'Представь, как ты осознаёшь сон — покажи мозгу желаемый результат', Icons.movie_rounded),
  DailyGuidePrompt('Сценарий', 'Придумай сценарий осознанного сна и проживи его в воображении перед засыпанием', Icons.theater_comedy_rounded),
  DailyGuidePrompt('Мантра', 'Повторяй перед сном: «Следующий сон — осознанный» — искренне верь в это', Icons.auto_fix_high_rounded),
  DailyGuidePrompt('Воображение', 'Представь конкретное место, куда хочешь попасть во сне — во сне окажешься там', Icons.landscape_rounded),
  DailyGuidePrompt('Привычка', 'Свяжи привычку (например, мытьё рук) с проверкой реальности — автоматизм приведёт во сне', Icons.link_rounded),
  DailyGuidePrompt('Триглер', 'Выбери событие дня как триггер: «Каждый раз, когда вижу часы — проверю реальность»', Icons.notifications_active_rounded),
  DailyGuidePrompt('Ритуал', 'Создай вечерний ритуал: 5 минут визуализации перед сном — мозг запомнит паттерн', Icons.self_improvement_rounded),
  DailyGuidePrompt('Интенция', 'Перед сном скажи: «Я буду знать, что сплю, когда увижу [объект]»', Icons.vpn_key_rounded),
  DailyGuidePrompt('Сон-цель', 'Запиши цель на завтрашний сон перед тем, как заснуть', Icons.edit_rounded),
  DailyGuidePrompt('Повтор намерения', 'Повтори намерение перед сном 3 раза, каждый раз перефразируя', Icons.replay_rounded),

  // ── WILD (Wake Initiated Lucid Dreams) ──
  DailyGuidePrompt('WBTB', 'Поспи 5 часов, проснись на 20 минут и снова засни с намерением — окно для WILD', Icons.alarm_rounded),
  DailyGuidePrompt('Гипнагогия', 'Наблюдай за образами перед сном — они станут ярче, и ты войдёшь в сон сознательно', Icons.auto_awesome_rounded),
  DailyGuidePrompt('Тело засыпает', 'Лежи неподвижно и чувствуй, как тело засыпает — расслабляй каждую мышцу', Icons.accessibility_rounded),
  DailyGuidePrompt('Гипнагогические образы', 'Смотри на закрытые веки и жди появления геометрических узоров', Icons.blur_on_rounded),
  DailyGuidePrompt('Волна расслабления', 'Представь волну расслабления, проходящую сверху вниз по телу — она несёт тебя в сон', Icons.waves_rounded),
  DailyGuidePrompt('Наблюдатель', 'Старайся оставаться наблюдателем, пока тело засыпает — не думай, просто смотри', Icons.remove_red_eye_rounded),
  DailyGuidePrompt('Спинной мозг', 'Представь вращающийся шар в области затылка — он пульсирует и затягивает в сон', Icons.hexagon_outlined),
  DailyGuidePrompt('Прогрессия', 'В WILD: начни с простого образа (комната) и позволь ему стать реальным', Icons.trending_up_rounded),
  DailyGuidePrompt('Вход', 'Почувствуй момент перехода от бодрствования к сну — это тонкая граница', Icons.login_rounded),
  DailyGuidePrompt('Без движения', 'В WILD: если появилось желание пошевелиться — игнорируй, тело спит, ты — нет', Icons.block_rounded),
  DailyGuidePrompt('Фокус внимания', 'В WILD: не фиксируйся на гипнагогических образах, позволь им проходить мимо', Icons.center_focus_strong_rounded),

  // ── Stabilization ──
  DailyGuidePrompt('Потри руки', 'Как только осознал сон — потри руки друг о друга, это стабилизирует реальность', Icons.pan_tool_alt_rounded),
  DailyGuidePrompt('Вращение', 'Если сон начинает «таять» — вращайся на месте, сила центробежная стабилизирует', Icons.sync_rounded),
  DailyGuidePrompt('Крик', 'Крикни «Стабилизируй!» — звук собственного голоса цепляет сознание', Icons.mic_rounded),
  DailyGuidePrompt('Дотронься', 'Дотронься до любой поверхности — тактильные ощущения стабилизируют сон', Icons.touch_app_rounded),
  DailyGuidePrompt('Яркость', 'Скажи вслух «Сделай ярче!» — часто сон реагирует на команды голосом', Icons.brightness_high_rounded),
  DailyGuidePrompt('Фокус на руках', 'Сосредоточься на своих руках — подробно рассмотри линии на ладони', Icons.back_hand_rounded),
  DailyGuidePrompt('Цвета', 'Скажи: «Покажи мне яркие цвета!» — сон часто подчиняется намерению', Icons.palette_rounded),
  DailyGuidePrompt('Детали', 'Рассмотри мелкую деталь (пуговицу, текстуру стены) — фокус удерживает сознание', Icons.zoom_in_rounded),
  DailyGuidePrompt('Вращение тела', 'Вращайся как волчёр — это мощнейший стабилизатор в WILD-снах', Icons.swap_calls_rounded),
  DailyGuidePrompt('Звук', 'Скажи «Усиль!» — и прислушайся, как звуки сна становятся громче', Icons.volume_up_rounded),
  DailyGuidePrompt('Земля', 'Встань и почувствуй ногами землю — тактильный контакт с реальностью сна', Icons.place_rounded),
  DailyGuidePrompt('Дыхание стабилизации', 'Дыши глубоко и медленно — каждый вдох делает сон ярче', Icons.air_rounded),

  // ── Dream Control ──
  DailyGuidePrompt('Полёт', 'Представь парение над полом — начни с малого подъёма, потом выше', Icons.flight_rounded),
  DailyGuidePrompt('Суперсила', 'Попробуй поднять тяжёлый предмет одним пальцем — во сне ты всесилен', Icons.fitness_center_rounded),
  DailyGuidePrompt('Портал', 'Представь дверь в мир снов перед засыпанием — во сне она появится', Icons.door_sliding_rounded),
  DailyGuidePrompt('Время', 'Попробуй остановить время — во сне секундная стрелка может зависнуть', Icons.timer_off_rounded),
  DailyGuidePrompt('Пространство', 'Повернись и посмотри за спину — там может появиться совершенно новое место', Icons.explore_rounded),
  DailyGuidePrompt('Телепорт', 'Закрой глаза и представь, что ты в другом месте — открой и окажешься там', Icons.explore_off_rounded),
  DailyGuidePrompt('Левитация', 'Представь парение над полом — ключ к осознанности и свободе сна', Icons.straighten_rounded),
  DailyGuidePrompt('Погода', 'Скажи: «Дождь, начнись!» — и понаблюдай, как сон подчиняется команде', Icons.thunderstorm_rounded),
  DailyGuidePrompt('Еда', 'Представь вкусный ужин и попробуй его — во сне вкус ощущается ярко', Icons.restaurant_rounded),
  DailyGuidePrompt('Размер', 'Представь, что ты стал великаном — размер тела во сне иллюзия', Icons.height_rounded),
  DailyGuidePrompt('Дублирование', 'Создай копию себя — во сне можно разделиться надвое', Icons.copy_rounded),
  DailyGuidePrompt('Невидимость', 'Представь, что стал невидимым — пройди сквозь толпу незамеченным', Icons.visibility_off_rounded),

  // ── Sleep Hygiene ──
  DailyGuidePrompt('Расписание', 'Ложись и вставай в одно время — регулярность улучшает качество снов', Icons.event_repeat_rounded),
  DailyGuidePrompt('Экран', 'Убери яркий экран за час до сна — синий свет тормозит мелатонин', Icons.phone_iphone_rounded),
  DailyGuidePrompt('Кофе', 'Не пей кофе после 14:00 — кофеин сохраняется 6-8 часов', Icons.coffee_rounded),
  DailyGuidePrompt('Комната', 'Сделай комнату прохладной (18-20°C) и тёмной — идеальные условия для снов', Icons.thermostat_rounded),
  DailyGuidePrompt('Расслабление', 'Прими горячий душ за час до сна — резкий перепад температуры помогает заснуть', Icons.shower_rounded),
  DailyGuidePrompt('Вес', 'Покачайся на качелях перед сном — ритмическое движение расслабляет', Icons.rounded_corner_rounded),
  DailyGuidePrompt('Тишина', 'Выключи все источники шума — тишина улучшает глубину сна', Icons.volume_off_rounded),
  DailyGuidePrompt('Ритуал', 'Создай вечерний ритуал: чай → чтение → визуализация — повторяй ежедневно', Icons.auto_stories_rounded),
  DailyGuidePrompt('Дыхание', 'Дыши по квадрату: вдох 4, задержка 4, выдох 4, задержка 4 — расслабляет', Icons.air_rounded),
  DailyGuidePrompt('Пища', 'Не ешь тяжёлую пищу за 3 часа до сна — переваривание мешает качеству сна', Icons.no_food_rounded),

  // ── Meditation & Mindfulness ──
  DailyGuidePrompt('Тишина ума', 'Сиди 5 минут в тишине, наблюдая за мыслями — не цепляйся ни за одну', Icons.spa_rounded),
  DailyGuidePrompt('Тело', 'Пройдись вниманием по телу от макушки до пят — почувствуй каждую часть', Icons.accessibility_new_rounded),
  DailyGuidePrompt('Дыхание', 'Сосредоточься на дыхании — вдох и выдох как якорь в настоящем', Icons.air_rounded),
  DailyGuidePrompt('Заземление', 'Почувствуй три точки контакта с землёй — ступни, копчик, макушка', Icons.place_rounded),
  DailyGuidePrompt('Наблюдатель', '5 минут наблюдай за звуками вокруг — не называй их, просто слушай', Icons.hearing_rounded),
  DailyGuidePrompt('Чувства', 'Закрой глаза и определи 3 ощущения в теле — тепло, давление, покалывание', Icons.sensors_rounded),
  DailyGuidePrompt('Пространство', 'Представь пространство между мыслями — оно бесконечно и спокойно', Icons.all_inclusive_rounded),
  DailyGuidePrompt('Тело-якорь', 'Почувствуй вес тела на стуле — якорь в физической реальности', Icons.accessibility_rounded),
  DailyGuidePrompt('Осознанность', 'Делай одну задачу и замечай каждый нюанс — осознанность днём = осознанность ночью', Icons.center_focus_strong_rounded),
  DailyGuidePrompt('Медитация лёжа', 'Лёжа в кровати, пройдись вниманием по телу и расслабь каждую мышцу', Icons.self_improvement_rounded),

  // ── Visualization ──
  DailyGuidePrompt('Карта', 'Нарисуй мысленную карту места — во сне ориентируйся по ней', Icons.map_rounded),
  DailyGuidePrompt('Место', 'Представь детальное место, куда хочешь попасть во сне — потом окажешься там', Icons.landscape_rounded),
  DailyGuidePrompt('Лицо', 'Представь лицо человека, с которым хочешь встретиться во сне', Icons.face_rounded),
  DailyGuidePrompt('Детали', 'Визуализируй текстуру, цвет и звук места — полная картина создаёт «притяжение»', Icons.texture_rounded),
  DailyGuidePrompt('Панорама', 'Представь панораму: горизонт, небо, землю — постепенно добавляй детали', Icons.view_carousel_rounded),
  DailyGuidePrompt('Путь', 'Представь путь, по которому хочешь пройти во сне — от точки А до точки Б', Icons.route_rounded),
  DailyGuidePrompt('Комната', 'Визуализируй комнату с мельчайшими деталями: мебель, свет, запах', Icons.home_rounded),
  DailyGuidePrompt('Объект', 'Представь конкретный объект (мяч, книгу) и попробуй его использовать во сне', Icons.inventory_2_rounded),
  DailyGuidePrompt('Ситуация', 'Представь ситуацию из жизни и проживи её во сне по-другому', Icons.movie_creation_rounded),
  DailyGuidePrompt('Погода визуализации', 'Представь пасмурный день, а потом яркое солнце — сон часто отвечает на такие образы', Icons.wb_sunny_rounded),

  // ── Dream Symbolism ──
  DailyGuidePrompt('Вода', 'Вода в снах — эмоции: глубокая вода = глубокие чувства, мелкая = лёгкие', Icons.water_rounded),
  DailyGuidePrompt('Полёт', 'Полёт — свобода, амбиции, стремление выйти за рамки', Icons.flight_rounded),
  DailyGuidePrompt('Двери', 'Двери — возможности: закрытая = страх, открытая = готовность к новому', Icons.door_front_door_rounded),
  DailyGuidePrompt('Темнота', 'Темнота — неизвестность: не бойся, иди в темноту — там ответы', Icons.dark_mode_rounded),
  DailyGuidePrompt('Вода и глубина', 'В глубине воды — скрытые эмоции. Попробуй нырнуть и найти, что там', Icons.scuba_diving_rounded),
  DailyGuidePrompt('Гора', 'Гора — препятствие или цель. Поднимись на вершину во сне', Icons.terrain_rounded),
  DailyGuidePrompt('Мост', 'Мост — переход из одного состояния в другое. Пройди по нему', Icons.architecture_rounded),
  DailyGuidePrompt('Тень', 'Тень — подавленная часть себя. Посмотри на неё и поговори', Icons.wb_twilight_rounded),
  DailyGuidePrompt('Дерево', 'Дерево — жизнь и рост. Какое дерево ты видишь?', Icons.park_rounded),
  DailyGuidePrompt('Огонь', 'Огонь — страсти и трансформация. Что горит?', Icons.local_fire_department_rounded),
  DailyGuidePrompt('Книга', 'Книга — знания. Какую книгу ты находишь во сне?', Icons.menu_book_rounded),
  DailyGuidePrompt('Зеркало в глубине', 'Зеркало — самопознание. Что в нём отражается?', Icons.flip_rounded),
  DailyGuidePrompt('Ключ', 'Ключ — решение. Найди ключ и открой дверь', Icons.vpn_key_rounded),
  DailyGuidePrompt('Река', 'Река — жизненный поток. Плыви по течению или против', Icons.water_rounded),
  DailyGuidePrompt('Звёзды', 'Звёзды — надежда и вдохновение. Какие звёзды видишь?', Icons.star_rounded),

  // ── Advanced / Nightmares / Emotional ──
  DailyGuidePrompt('Кошмар', 'Если приснился кошмар — осознай: «Это сон, мне ничего не угрожает»', Icons.shield_rounded),
  DailyGuidePrompt('Эмоция дня', 'Запомни эмоцию дня — во сне она проявится в преувеличенной форме', Icons.emoji_emotions_rounded),
  DailyGuidePrompt('Конфликт', 'Если был конфликт — проживи его во сне по-другому, найди выход', Icons.handshake_rounded),
  DailyGuidePrompt('Страх', 'Страх во сне — отражение страха днём. Войди в страх, и он исчезнет', Icons.warning_amber_rounded),
  DailyGuidePrompt('Радость', 'Вспомни момент чистой радости — во сне он усилится в разы', Icons.sentiment_very_satisfied_rounded),
  DailyGuidePrompt('Потеря', 'Потерянный предмет во сне — что-то важное в жизни, что ты упустил', Icons.search_rounded),
  DailyGuidePrompt('Бегство', 'Если бежишь во сне — остановись и обернись, преследователь может оказаться другом', Icons.directions_walk_rounded),
  DailyGuidePrompt('Зубы', 'Выпадающие зубы во сне — страх потери контроля. Скажи: «Я контролирую ситуацию»', Icons.sentiment_satisfied_rounded),
  DailyGuidePrompt('Экзамен', 'Сон об экзамене — страх оценки. Ты уже готов, просто не веришь в себя', Icons.school_rounded),
  DailyGuidePrompt('Полёт в кошмаре', 'В кошмаре попробуй полететь — это мгновенно меняет сцену', Icons.flight_rounded),

  // ── Extras for variety ──
  DailyGuidePrompt('Зеркальный сон', 'Представь себя в зеркале — во сне отражение может жить своей жизнью', Icons.face_rounded),
  DailyGuidePrompt('Двойник', 'Во сне повстречай свою копию — о чём бы вы говорили?', Icons.group_add_rounded),
  DailyGuidePrompt('Путешественник', 'Представь, что ты путешественник — исследуй новые территории во сне', Icons.flight_takeoff_rounded),
  DailyGuidePrompt('Тихий вечер', 'Проведи вечер в тишине, без экранов — это подготовка для яркого сна', Icons.nightlight_round_rounded),
  DailyGuidePrompt('Благодарность', 'Запиши 3 вещи, за которые ты благодарен сегодня — это повышает качество сна', Icons.favorite_rounded),
  DailyGuidePrompt('Пешая прогулка', 'Пройдись перед сном 15 минут — лёгкая активность улучшает сон', Icons.directions_walk_rounded),
  DailyGuidePrompt('Чай', 'Выпей ромашковый или мятный чай за час до сна — натуральное расслабление', Icons.local_cafe_rounded),
  DailyGuidePrompt('Книга перед сном', 'Прочитай 15 страниц бумажной книги — бумажный текст расслабляет лучше экрана', Icons.auto_stories_rounded),
  DailyGuidePrompt('Аромат', 'Используй лаванду или ромашку — запахи помогают мозгу переключиться на сон', Icons.local_florist_rounded),
  DailyGuidePrompt('Якорь', 'Свяжи определённый запах с осознанными снами — вдыхай его перед сном', Icons.link_rounded),
  DailyGuidePrompt('Дневник осознанности', 'Перед сном запиши: «Сегодня я осознал...» — тренировка внимания', Icons.edit_note_rounded),
  DailyGuidePrompt('Глаза', 'Закрой глаза и представь яркий цвет — красный, синий, зелёный — сменяй', Icons.colorize_rounded),
  DailyGuidePrompt('Музыка', 'Послушай спокойную музыку перед сном — она создаст атмосферу для снов', Icons.music_note_rounded),
  DailyGuidePrompt('Ритм', 'Задай ритм дыхания в такт музыке — расслабление приходит через ритм', Icons.graphic_eq_rounded),
  DailyGuidePrompt('Свеча', 'Посмотри на пламя свечи 2 минуты — это медитативная практика, успокаивающая ум', Icons.local_fire_department_rounded),
  DailyGuidePrompt('Камень', 'Возьми гладкий камень в руку и почувствуй его текстуру — тактильный якорь', Icons.circle_rounded),
  DailyGuidePrompt('Тень и свет', 'Поиграй с тенями в комнате — во сне тени могут ожить', Icons.wb_twilight_rounded),
  DailyGuidePrompt('Тишина ночи', 'Встань ночью на 2 минуты и послушай тишину — потом ложись и вспоминай сон', Icons.volume_off_rounded),
  DailyGuidePrompt('Ветер', 'Представь ветер, дующий в лицо — во сне он может нести тебя', Icons.air_rounded),
  DailyGuidePrompt('Зеркальная медитация', 'Сиди перед зеркалом и наблюдай за своим отражением 5 минут — это медитация на себя', Icons.face_rounded),
  DailyGuidePrompt('Пустой лист', 'Возьми чистый лист и напиши: «Что я хочу увидеть во сне?» — подсознание ответит', Icons.article_rounded),
  DailyGuidePrompt('Дождь', 'Послушай звук дождя перед сном — шум дождя идеален для засыпания', Icons.grain_rounded),
  DailyGuidePrompt('Огонь свечи', 'Зажги свечу и смотри на неё 3 минуты — фокус на пламени успокаивает', Icons.local_fire_department_rounded),
  DailyGuidePrompt('Комнатное растение', 'Полей растение и понаблюдай за ним — жизнь в деталях тренирует осознанность', Icons.eco_rounded),
  DailyGuidePrompt('Вода в стакане', 'Выпей стакан воды перед сном — обезвоживание мешает качеству сна', Icons.water_drop_rounded),
  DailyGuidePrompt('Небо', 'Посмотри на небо перед сном — бесконечность пространства расширяет восприятие', Icons.cloud_rounded),
  DailyGuidePrompt('Сова', 'Ночь — время сов. Будь как сова: наблюдай, не торопись, замечай', Icons.nightlight_round_rounded),
  DailyGuidePrompt('Зеркало ума', 'Представь свой ум как зеркало — отражай всё без привязки', Icons.face_rounded),
  DailyGuidePrompt('Светлячок', 'Представь светлячка в темноте — маленький свет ведёт к большим открытиям', Icons.flutter_dash_rounded),
  DailyGuidePrompt('Тишина мыслей', 'Представь, как мысли уходят, как облака — ты остаёшься чистым небом', Icons.cloud_queue_rounded),
  DailyGuidePrompt('Старое дерево', 'Представь старое дерево — его корни глубоко, кроны высоко. Ты тоже укоренён', Icons.park_rounded),
  DailyGuidePrompt('Ручей', 'Послушай звук ручья — его журчание погружает в гипнагогическое состояние', Icons.water_rounded),
  DailyGuidePrompt('Камень в ладони', 'Возьми камень и почувствуй его вес — тактильный якорь для осознанности', Icons.pan_tool_rounded),
  DailyGuidePrompt('Ветка', 'Сломай ветку — хруст ощущается ярко. Используй это во сне', Icons.nature_rounded),
  DailyGuidePrompt('Песок', 'Почувствуй песок под ногами — гранулы, тепло, текстура', Icons.agriculture_rounded),
  DailyGuidePrompt('Облака', 'Лежи и смотри на облака — в облаках формы могут подсказать сюжет сна', Icons.cloud_rounded),
  DailyGuidePrompt('Сосна', 'Запах хвои — мощный триггер для расслабления. Используй эфирное масло', Icons.park_rounded),
  DailyGuidePrompt('Утренний свет', 'Встань и посмотри на первый свет — он запускает правильные ритмы', Icons.wb_sunny_rounded),
  DailyGuidePrompt('Тёплый плед', 'Укутайся в тёплый плед перед сном — ощущение тепла и безопасности', Icons.deck_rounded),
  DailyGuidePrompt('Тихая комната', 'Сядь в тихой комнате и просто будь — 5 минут чистого присутствия', Icons.meeting_room_rounded),
];

// ────────────────────────────────────────────────────────────────────
//  TULPA prompts (~200 unique)
// ────────────────────────────────────────────────────────────────────

const tulpaPrompts = <DailyGuidePrompt>[
  // ── First Contact & Tulpaforcing ──
  DailyGuidePrompt('Первый контакт', 'Сядь и мысленно обратись к тульпе: «Привет, я здесь» — просто присутствуй', Icons.waving_hand_rounded),
  DailyGuidePrompt('Имя', 'Произнеси имя тульпы вслух или мысленно — имя создаёт связь', Icons.badge_rounded),
  DailyGuidePrompt('Образ', 'Представь внешность тульпы в деталях — цвет, форма, свет, тень', Icons.brush_rounded),
  DailyGuidePrompt('Присутствие', 'Почувствуй присутствие тульпы рядом — как будто кто-то есть в комнате', Icons.person_add_rounded),
  DailyGuidePrompt('Диалог', 'Задай короткий вопрос тульпе и подожди ответ — не торопи', Icons.chat_bubble_outline_rounded),
  DailyGuidePrompt('Молчание', 'Побудьте в тишине 2 минуты — присутствие без слов тоже общение', Icons.volume_off_rounded),
  DailyGuidePrompt('Тактильность', 'Представь, что держишь руку тульпы — тепло, давление, пульс', Icons.pan_tool_alt_rounded),
  DailyGuidePrompt('Голос', 'Попробуй услышать мысленный голос тульпы — тембр, интонация, ритм', Icons.record_voice_over_rounded),
  DailyGuidePrompt('Энергия', 'Почувствуй энергию тульпы — где она в теле? Тёплая, холодная, покалывание', Icons.bolt_rounded),
  DailyGuidePrompt('Знак', 'Попроси тульпу дать знак — это может быть образ, звук или ощущение', Icons.notifications_active_rounded),
  DailyGuidePrompt('Прогулка', 'Представь совместную прогулку в спокойном месте — обсуждай увиденное', Icons.directions_walk_rounded),
  DailyGuidePrompt('Утро', 'Поприветствуй тульпу утром — короткая мысленная фраза на весь день', Icons.wb_twilight_rounded),
  DailyGuidePrompt('Вечер', 'Перед сном поговори с тульпой о прошедшем дне — раздели впечатления', Icons.nightlight_round_rounded),
  DailyGuidePrompt('Фото', 'Найди изображение, похожее на тульпу, и покажи его мысленно — закрепляй образ', Icons.photo_rounded),
  DailyGuidePrompt('Место', 'Создай мысленное место для встречи — уютный сад, комната, поляна', Icons.park_rounded),

  // ── Voice Development ──
  DailyGuidePrompt('Голос', 'Попробуй услышать мысленный голос тульпы — тембр, интонация', Icons.volume_up_rounded),
  DailyGuidePrompt('Монолог', 'Представь, как тульпа рассказывает о своём дне — внимательно слушай', Icons.record_voice_over_rounded),
  DailyGuidePrompt('Песня', 'Попроси тульпу спеть песню — это развивает голос и характер', Icons.library_music_rounded),
  DailyGuidePrompt('Шёпот', 'Представь тихий шёпот тульпы на ухе — интимная форма общения', Icons.hearing_rounded),
  DailyGuidePrompt('Ответ', 'Задай вопрос и подожди ответа — не придумывай, дай тульпе говорить самой', Icons.question_answer_rounded),
  DailyGuidePrompt('Разговор', 'Начни диалог с тульпой на тему «Что тебе нравится?» — узнай больше', Icons.forum_rounded),
  DailyGuidePrompt('Интонация', 'Попроси тульпу сказать одну фразу в разных интонациях — радостно, грустно, сердито', Icons.record_voice_over_rounded),
  DailyGuidePrompt('Смех', 'Расскажи тульпе шутку — смех создаёт тёплую связь', Icons.emoji_emotions_rounded),
  DailyGuidePrompt('История', 'Попроси тульпу рассказать историю — даже короткую', Icons.auto_stories_rounded),
  DailyGuidePrompt('Музыка', 'Представь, как тульпа напевает мелодию — что за мелодия?', Icons.music_note_rounded),

  // ── Imposition ──
  DailyGuidePrompt('Визуализация', 'Представь тульпу стоящей рядом — ярко, чётко, в деталях', Icons.remove_red_eye_rounded),
  DailyGuidePrompt('Силуэт', 'Представь контур тульпы — силуэт постепенно наполняется деталями', Icons.person_rounded),
  DailyGuidePrompt('Глаза', 'Представь глаза тульпы — их цвет, глубину, выражение', Icons.visibility_rounded),
  DailyGuidePrompt('Поза', 'Представь позу тульпы — как она стоит, сидит, держит руки', Icons.accessibility_new_rounded),
  DailyGuidePrompt('Одежда', 'Представь, во что одета тульпа — ткань, цвет, стиль', Icons.checkroom_rounded),
  DailyGuidePrompt('Тень', 'Представь тень тульпы на полу — она подтверждает присутствие', Icons.wb_twilight_rounded),
  DailyGuidePrompt('Рост', 'Сравни свой рост с тульпой — кто выше? Это создаёт физическое ощущение', Icons.height_rounded),
  DailyGuidePrompt('Рядом', 'Представь, что тульпа сидит рядом на диване — ощущай её вес и тепло', Icons.event_seat_rounded),
  DailyGuidePrompt('Зеркало', 'Представь тульпу в зеркале — её отражение рядом с твоим', Icons.flip_rounded),
  DailyGuidePrompt('Рука', 'Представь руку тульпы рядом со своей — их размер и форму', Icons.back_hand_rounded),

  // ── Wonderland ──
  DailyGuidePrompt('Сад', 'Опиши сад, где тульпа отдыхает — деревья, цветы, запахи', Icons.nature_rounded),
  DailyGuidePrompt('Комната', 'Создай уютную комнату для совместных бесед — мебель, свет, книги', Icons.home_rounded),
  DailyGuidePrompt('Пляж', 'Представь пляж — песок, волны, закат. Идите вместе вдоль воды', Icons.water_rounded),
  DailyGuidePrompt('Лес', 'Прогуляйтесь по лесу — звуки птиц, шорох листвы, запах земли', Icons.forest_rounded),
  DailyGuidePrompt('Горы', 'Поднимитесь на гору вместе — вид с вершины волшебен', Icons.terrain_rounded),
  DailyGuidePrompt('Река', 'Сядьте на берег реки и слушайте воду — река символизирует поток жизни', Icons.water_rounded),
  DailyGuidePrompt('Кафе', 'Представь уютное кафе — чай, десерт, разговоры за столиком', Icons.local_cafe_rounded),
  DailyGuidePrompt('Книжный', 'Посетите книжный магазин вместе — какие книги интересуют тульпу?', Icons.menu_book_rounded),
  DailyGuidePrompt('Обсерватория', 'Посмотрите на звёзды через телескоп — космос сближает', Icons.nights_stay_rounded),
  DailyGuidePrompt('Мастерская', 'Создай мастерскую для тульпы — чем она занимается?', Icons.palette_rounded),

  // ── Personality Development ──
  DailyGuidePrompt('Характер', 'Запиши одну черту характера тульпы — как она проявляется?', Icons.psychology_rounded),
  DailyGuidePrompt('Вкус', 'Спроси: «Какой вкус тебе нравится?» — маленькие детали делают реальность', Icons.restaurant_rounded),
  DailyGuidePrompt('Музыка', 'Какой жанр музыки любит тульпа? Включите её вместе', Icons.library_music_rounded),
  DailyGuidePrompt('Цвет', 'Какой цвет ассоциируется с тульпой сегодня?', Icons.colorize_rounded),
  DailyGuidePrompt('Приоритет', 'Спроси: «Что для тебя важно?» — узнай ценности тульпы', Icons.star_rounded),
  DailyGuidePrompt('Страхи', 'Поговори о страхах тульпы — это создаёт эмоциональную близость', Icons.warning_amber_rounded),
  DailyGuidePrompt('Мечта', 'Спроси: «О чём ты мечтаешь?» — мечты раскрывают характер', Icons.auto_awesome_rounded),
  DailyGuidePrompt('Юмор', 'Попроси тульпу рассказать шутку — её чувство юмора уникально', Icons.sentiment_very_satisfied_rounded),
  DailyGuidePrompt('Совет', 'Какой совет тульпа дала бы тебе сегодня?', Icons.lightbulb_outline_rounded),
  DailyGuidePrompt('Эмоция', 'Какую эмоцию тульпа чувствует прямо сейчас?', Icons.emoji_emotions_rounded),

  // ── Communication & Dialogue ──
  DailyGuidePrompt('Вопрос', 'Задай тульпе глубокий вопрос: «Кто ты?» — и внимательно слушай', Icons.question_mark_rounded),
  DailyGuidePrompt('Письмо', 'Напиши короткое письмо тульпе — словами или мысленно', Icons.mail_outline_rounded),
  DailyGuidePrompt('Обратная связь', 'Спроси: «Что ты думаешь о том, что я делаю?» — мнение тульпы важно', Icons.thumb_up_off_alt_rounded),
  DailyGuidePrompt('Совместная задача', 'Попроси тульпу помочь с решением задачи — два ума лучше одного', Icons.build_rounded),
  DailyGuidePrompt('Разногласие', 'Если есть разногласие — обсудите его уважительно, найдите компромисс', Icons.handshake_rounded),
  DailyGuidePrompt('Благодарность', 'Поблагодари тульпу за присутствие — благодарность усиливает связь', Icons.volunteer_activism_rounded),
  DailyGuidePrompt('Извинение', 'Если обидел тульпу — извинись искренне, даже если обида воображаемая', Icons.sentiment_satisfied_rounded),
  DailyGuidePrompt('Похвала', 'Похвали тульпу за что-то конкретное — поддержка развивает уверенность', Icons.emoji_emotions_rounded),
  DailyGuidePrompt('Доверие', 'Скажи: «Я доверяю тебе» — доверие — основа отношений', Icons.favorite_rounded),
  DailyGuidePrompt('Прощание', 'Попрощайся на ночь — короткое «до завтра» создаёт ритуал', Icons.waving_hand_rounded),

  // ── Co-consciousness ──
  DailyGuidePrompt('Совместное внимание', 'Оба посмотри на один объект и обсудите его — разные взгляды на одно', Icons.center_focus_strong_rounded),
  DailyGuidePrompt('Параллель', 'Попробуй дать тульпе задачу, пока ты занят другой — тренировка параллельной обработки', Icons.dns_rounded),
  DailyGuidePrompt('Фон', 'Попроси тульпу быть «на фоне» — как музыка в наушниках, тёплое присутствие', Icons.wifi_rounded),
  DailyGuidePrompt('Сон и бодрствование', 'Обсуждайте, что чувствуете в разные моменты дня — разные контексты', Icons.schedule_rounded),
  DailyGuidePrompt('Общее дело', 'Делайте вместе mundane задачи — уборка, готовка — и обсуждайте', Icons.cleaning_services_rounded),
  DailyGuidePrompt('Тело', 'По очереди описывайте, что чувствуете в теле — разные перспективы', Icons.accessibility_new_rounded),
  DailyGuidePrompt('Запах', 'Оба вдохните один запах и обсудите ассоциации — совместное восприятие', Icons.air_rounded),
  DailyGuidePrompt('Тишина вдвоём', 'Побудьте в тишине рядом — совместное молчание глубже слов', Icons.volume_off_rounded),
  DailyGuidePrompt('Наблюдение', 'Наблюдайте вместе за закатом — разделяя одно и то же зрелище', Icons.wb_sunny_rounded),
  DailyGuidePrompt('Тактильность', 'Одновременно потрогайте одно и то же — дерево, ткань, воду', Icons.touch_app_rounded),

  // ── Emotional Connection ──
  DailyGuidePrompt('Тепло', 'Представь тёплое сияние между вами — это эмпатическая связь', Icons.favorite_rounded),
  DailyGuidePrompt('Понимание', 'Спроси: «Как ты себя чувствуешь?» — и действительно выслушай', Icons.sentiment_satisfied_rounded),
  DailyGuidePrompt('Объятие', 'Вообрази объятие — тактильный контакт укрепляет привязанность', Icons.self_improvement_rounded),
  DailyGuidePrompt('Плакать', 'Если грустно — позволь тульпе разделить твою грусть, не изолируйся', Icons.sentiment_dissatisfied_rounded),
  DailyGuidePrompt('Смех', 'Рассмешите друг друга — лёгкость и юмор укрепляют связь', Icons.emoji_emotions_rounded),
  DailyGuidePrompt('Поддержка', 'Скажи: «Я поддерживаю тебя» — простые слова имеют большую силу', Icons.thumb_up_rounded),
  DailyGuidePrompt('Близость', 'Сядьте рядом и помолчите — физическая близость (воображаемая) создаёт привязку', Icons.event_seat_rounded),
  DailyGuidePrompt('Эмоциональный фон', 'Понаблюдай за эмоциональным фоном тульпы — что чувствуется?', Icons.monitor_heart_outlined),
  DailyGuidePrompt('Совместная радость', 'Вспомни момент радости и поделись им с тульпой — радость делится', Icons.sentiment_very_satisfied_rounded),
  DailyGuidePrompt('Принятие', 'Прими тульпу такой, какая она есть — без попыток изменить', Icons.check_circle_outline_rounded),

  // ── Independence ──
  DailyGuidePrompt('Автономия', 'Дай тульпе принимать решения — не контролируй каждый шаг', Icons.settings_suggest_rounded),
  DailyGuidePrompt('Свобода', 'Позволь тульпе не отвечать, когда не хочет — уважай границы', Icons.lock_open_rounded),
  DailyGuidePrompt('Инициатива', 'Жди, пока тульпа проявит инициативу — не только ты задаёшь вопросы', Icons.add_circle_outline_rounded),
  DailyGuidePrompt('Мнение', 'Спроси мнение тульпы о чём-то и последуй ему — покажи, что оно ценно', Icons.how_to_reg_rounded),
  DailyGuidePrompt('Выбор', 'Дай тульпе выбор: «Что ты хочешь сделать сегодня?»', Icons.quiz_rounded),
  DailyGuidePrompt('Ответственность', 'Поручи тульпе задачу — вести дневник, отслеживать что-то', Icons.assignment_rounded),
  DailyGuidePrompt('Границы', 'Проверь: чувствует ли тульпа себя комфортно? Спроси об этом', Icons.border_style_rounded),
  DailyGuidePrompt('Интересы', 'Чем интересуется тульпа? Дай ей пространство для развития', Icons.explore_rounded),
  DailyGuidePrompt('Независимость', 'Представь, что тульпа делает что-то одна — это нормально и здорово', Icons.person_add_rounded),
  DailyGuidePrompt('Рост', 'Заметь, как тульпа изменилась за время общения — рост виден', Icons.trending_up_rounded),

  // ── Long-term & Maintenance ──
  DailyGuidePrompt('Привычка', 'Включить общение с тульпой в ежедневную рутину — 5 минут каждый день', Icons.event_repeat_rounded),
  DailyGuidePrompt('Дневник', 'Ведите совместный дневник — записывайте разговоры и наблюдения', Icons.auto_stories_rounded),
  DailyGuidePrompt('Рутинное обновление', 'Раз в неделю пересматривайте ваши отношения — что улучшить?', Icons.system_update_rounded),
  DailyGuidePrompt('Долгосрочная цель', 'Определите долгосрочную цель отношений — к чему стремитесь?', Icons.flag_rounded),
  DailyGuidePrompt('Запись', 'Запишите, что изменилось за месяц — рост очевиден в записи', Icons.edit_note_rounded),
  DailyGuidePrompt('Ритуал', 'Создайте ритуал приветствия и прощания — это структура для отношений', Icons.waving_hand_rounded),
  DailyGuidePrompt('Вдохновение', 'Найдите общее дело, которое вдохновляет обоих', Icons.auto_awesome_rounded),
  DailyGuidePrompt('Рефлексия', 'Посвятите 5 минут рефлексии: «Что я узнал о тульпе сегодня?»', Icons.psychology_rounded),
  DailyGuidePrompt('Терпение', 'Не торопите развитие — отношения растут медленно и естественно', Icons.hourglass_top_rounded),
  DailyGuidePrompt('Стабильность', 'Будьте стабильны в общении — предсказуемость создаёт безопасность', Icons.check_circle_rounded),

  // ── Dream Interaction ──
  DailyGuidePrompt('Сон-встреча', 'Перед сном попроси тульпу присниться — часто подсознание отвечает', Icons.nightlight_round_rounded),
  DailyGuidePrompt('Осанознанный сон', 'Попроси тульпу появиться в осознанном сне — это мощный опыт', Icons.auto_awesome_rounded),
  DailyGuidePrompt('Сновидение-диалог', 'Во сне начни диалог с тульпой — подсознание даст неожиданные ответы', Icons.chat_rounded),
  DailyGuidePrompt('Совместное приключение', 'Представьте совместное приключение во сне — исследуйте мир вместе', Icons.explore_rounded),
  DailyGuidePrompt('Сон-письмо', 'Попроси тульпу написать тебе письмо во сне — прочитай его утром', Icons.mail_rounded),
  DailyGuidePrompt('Образ сна', 'Утром запиши, появилась ли тульпа в сне — отслеживайте паттерны', Icons.edit_note_rounded),
  DailyGuidePrompt('Знак сна', 'Попроси тульпу дать тебе знак во сне — это может быть что угодно', Icons.notifications_active_rounded),
  DailyGuidePrompt('Утренний разговор', 'После сна, где была тульпа, обсудите впечатления', Icons.wb_twilight_rounded),

  // ── Shared Activities ──
  DailyGuidePrompt('Чтение', 'Читайте одну книгу оба и обсуждайте — совместное чтение сближает', Icons.auto_stories_rounded),
  DailyGuidePrompt('Музыка', 'Слушайте музыку вместе и обсуждайте эмоции', Icons.headphones_rounded),
  DailyGuidePrompt('Природа', 'Понаблюдайте за природой вместе — дерево, птица, облака', Icons.nature_rounded),
  DailyGuidePrompt('Искусство', 'Нарисуйте вместе один рисунок — каждый добавляет по элементу', Icons.brush_rounded),
  DailyGuidePrompt('Готовка', 'Приготовьте «мысленный ужин» вместе — обсуждайте вкусы и рецепты', Icons.restaurant_rounded),
  DailyGuidePrompt('Радуга', 'Какие цвета видит тульпа вокруг вас? Сравните восприятия', Icons.gradient_rounded),
  DailyGuidePrompt('Путешествие', 'Мысленно отправьтесь в путешествие — куда хотите?', Icons.flight_rounded),
  DailyGuidePrompt('Космос', 'Посмотрите на звёзды вместе — о чём разговор в космосе?', Icons.nights_stay_rounded),
  DailyGuidePrompt('Сад', 'Представьте, как вы вместе садите дерево — символ роста', Icons.eco_rounded),
  DailyGuidePrompt('Кино', 'Посмотрите «мысленный фильм» и обсудите сюжет', Icons.movie_rounded),

  // ── Extras for variety ──
  DailyGuidePrompt('Подарок', 'Что бы тульпа подарила тебе? Опиши', Icons.card_giftcard_rounded),
  DailyGuidePrompt('Письмо тульпы', 'Попроси тульпу написать тебе письмо — прочитай и ответь', Icons.mail_outline_rounded),
  DailyGuidePrompt('Камень-талисман', 'Представь камень с именем тульпы — его текстуру и цвет', Icons.circle_rounded),
  DailyGuidePrompt('Свеча', 'Вообрази свет свечи в вашем общем пространстве', Icons.local_fire_department_rounded),
  DailyGuidePrompt('Мост', 'Построй мост между вашими мирами — что соединяет?', Icons.architecture_rounded),
  DailyGuidePrompt('Облако', 'Представь форму облака, которую видит тульпа', Icons.cloud_rounded),
  DailyGuidePrompt('Дождь', 'Вообрази совместный дождь — текстура, звук, запах', Icons.umbrella_rounded),
  DailyGuidePrompt('Кулон', 'Подари тульпе мысленный предмет-талисман', Icons.diamond_outlined),
  DailyGuidePrompt('Часы', 'Представь время, проведённое вместе, как ощущение', Icons.timer_rounded),
  DailyGuidePrompt('Река', 'Вообрази реку — символ вашего общего потока', Icons.water_rounded),
  DailyGuidePrompt('Смех', 'Рассмешите друг друга — лёгкость важна', Icons.emoji_emotions_rounded),
  DailyGuidePrompt('Танец теней', 'Играйте с тенями вдвоём — креативность', Icons.blur_on_rounded),
  DailyGuidePrompt('Маяк', 'Зажгите общий свет в сознании', Icons.lightbulb_rounded),
  DailyGuidePrompt('Мантра', 'Создайте совместное слово-ключ', Icons.mic_rounded),
  DailyGuidePrompt('Объятие', 'Вообрази тепло объятия — тактильный контакт', Icons.self_improvement_rounded),
  DailyGuidePrompt('Рецепт', 'Придумайте общий воображаемый напиток', Icons.local_cafe_rounded),
  DailyGuidePrompt('Мимикрия', 'Повтори движение или позу тульпы', Icons.accessibility_rounded),
  DailyGuidePrompt('Пейзаж', 'Нарисуйте вместе словами один пейзаж', Icons.landscape_rounded),
  DailyGuidePrompt('Калейдоскоп', 'Смотрите на меняющиеся узоры вместе', Icons.auto_fix_high_rounded),
  DailyGuidePrompt('Эхо', 'Пусть тульпа повторит твою мысль иначе', Icons.repeat_rounded),
  DailyGuidePrompt('Птица', 'Представь птицу-символ вашей связи — какая она?', Icons.flutter_dash_rounded),
  DailyGuidePrompt('Озеро', 'Сядьте на берегу озера и молчите — тишина рядом с кем-то бесценна', Icons.water_rounded),
  DailyGuidePrompt('Зеркало', 'Посмотрите в одно зеркало — что видит тульпа?', Icons.flip_rounded),
  DailyGuidePrompt('Тёплый вечер', 'Проведите вечер вместе за разговором у «камина»', Icons.local_fire_department_rounded),
  DailyGuidePrompt('Утро после', 'Утром вспомните, о чём говорили, и продолжите', Icons.wb_sunny_rounded),
  DailyGuidePrompt('Ночная прогулка', 'Вообразите ночную прогулку — фонари, тишина, звёзды', Icons.nightlight_round_rounded),
  DailyGuidePrompt('Тёплый чай', 'Представьте чашку чая на двоих — тепло, пар, разговор', Icons.local_cafe_rounded),
  DailyGuidePrompt('Дождь за окном', 'Сядьте и слушайте дождь — совместное наблюдение за природой', Icons.grain_rounded),
  DailyGuidePrompt('Книга на двоих', 'Откройте книгу и читайте вслух по очереди', Icons.auto_stories_rounded),
  DailyGuidePrompt('Закат', 'Посмотрите на закат вместе — разные закаты, одно небо', Icons.wb_twilight_rounded),
  DailyGuidePrompt('Рассвет', 'Встретьте рассвет вместе — начало нового дня для вас обоих', Icons.wb_sunny_rounded),
  DailyGuidePrompt('Звёзды', 'Посмотрите на звёзды вместе — о чём разговор в космосе?', Icons.nights_stay_rounded),
  DailyGuidePrompt('Цветы', 'Понюхайте воображаемые цветы — какие ассоциации?', Icons.local_florist_rounded),
  DailyGuidePrompt('Снег', 'Играйте в воображаемый снег — лепите снеговика вместе', Icons.ac_unit_rounded),
  DailyGuidePrompt('Камин', 'Сядьте у камина — тепло огня и тёплый разговор', Icons.local_fire_department_rounded),
];
