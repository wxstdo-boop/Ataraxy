// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Мой дневник';

  @override
  String get tabDreams => 'Сны';

  @override
  String get tabLife => 'Жизнь';

  @override
  String get tabAll => 'Всё';

  @override
  String get tabNotes => 'Заметки';

  @override
  String get fabNew => 'Запись';

  @override
  String get refresh => 'Обновить';

  @override
  String get entriesUpdated => 'Записи обновлены';

  @override
  String get emptyDream => 'Записей о снах пока нет';

  @override
  String get emptyLife => 'Записей о жизни пока нет';

  @override
  String get emptyNotes => 'Заметок пока нет';

  @override
  String get emptyAll => 'Записей пока нет';

  @override
  String get emptyTulpa => 'Записей о тульпах пока нет';

  @override
  String get entryNew => 'Новая запись';

  @override
  String get entryEdit => 'Редактировать';

  @override
  String get save => 'Сохранить';

  @override
  String get saveFailed =>
      'Не удалось сохранить — проверьте место на устройстве';

  @override
  String get typeDream => 'Сон';

  @override
  String get typeLife => 'Жизнь';

  @override
  String get typeGeneral => 'Заметка';

  @override
  String get segDream => 'Сон';

  @override
  String get segLife => 'Жизнь';

  @override
  String get segGeneral => 'Заметка';

  @override
  String get titleHint => 'Заголовок';

  @override
  String get contentHint => 'Опишите свои мысли, сон или событие...';

  @override
  String get editTab => 'Редактор';

  @override
  String get previewTab => 'Превью';

  @override
  String get previewEmpty =>
      'Текст пока пуст — начните писать, и превью появится здесь';

  @override
  String get tapToExpandNotes => 'Нажмите, чтобы раскрыть заметки';

  @override
  String get mood => 'Настроение';

  @override
  String get tags => 'Теги';

  @override
  String get addTag => 'Добавить тег';

  @override
  String get tagsLimit => 'Максимум 3 тега';

  @override
  String get tagTooLong => 'Тег не длиннее 10 символов';

  @override
  String get withoutTitle => 'Без названия';

  @override
  String get noText => 'Нет текста.';

  @override
  String get deleteTitle => 'Удалить запись?';

  @override
  String get deleteContent => 'Это действие нельзя отменить.';

  @override
  String get cancel => 'Отмена';

  @override
  String get cut => 'Вырезать';

  @override
  String get copy => 'Копировать';

  @override
  String get paste => 'Вставить';

  @override
  String get share => 'Поделиться';

  @override
  String get clear => 'Очистить';

  @override
  String get delete => 'Удалить';

  @override
  String get entryDeleted => 'Запись удалена';

  @override
  String get restore => 'Вернуть';

  @override
  String get streak => 'Серия дней';

  @override
  String get streakDays => 'дн.';

  @override
  String get streakHint =>
      'Дни подряд, когда ты записываешь в дневник. Пропустишь день — серия начнётся заново. Записывай каждый день, чтобы серия росла!';

  @override
  String rewardChat(Object n) {
    return '🔥 Награда дня: +$n ✨';
  }

  @override
  String rewardTask(Object n) {
    return '✅ Задача выполнена: +$n ✨';
  }

  @override
  String rewardStreak(Object n) {
    return 'Серия: $n дн.';
  }

  @override
  String get settings => 'Настройки';

  @override
  String get theme => 'Тема';

  @override
  String get language => 'Язык';

  @override
  String get pin => 'PIN-код';

  @override
  String get setPin => 'Установить PIN';

  @override
  String get changePin => 'Изменить PIN';

  @override
  String get removePin => 'Убрать PIN';

  @override
  String get removePinConfirm => 'Вы уверены? PIN-код будет удалён.';

  @override
  String get enterPin => 'Введите PIN';

  @override
  String get confirmPin => 'Подтвердите PIN';

  @override
  String get unlock => 'Разблокировать';

  @override
  String get pinMismatch => 'PIN не совпадает';

  @override
  String get pinWrong => 'Неверный PIN';

  @override
  String get pinSetDone => 'PIN установлен';

  @override
  String get pinRemoved => 'PIN удалён';

  @override
  String get dreamKind => 'Тип сна';

  @override
  String get dreamNormal => 'Обычный';

  @override
  String get dreamLucid => 'Осознанный';

  @override
  String get lucidBadge => 'Осознанный сон';

  @override
  String get normalBadge => 'Обычный сон';

  @override
  String get search => 'Поиск';

  @override
  String get searchHint => 'Поиск по записям...';

  @override
  String get noResults => 'Ничего не найдено';

  @override
  String get data => 'Данные';

  @override
  String get export => 'Экспорт';

  @override
  String get import => 'Импорт';

  @override
  String get protectDeletedTitle => 'Не возвращать удалённое при импорте';

  @override
  String get protectDeletedHint =>
      'Удалённые записи не появятся снова после импорта старого бэкапа';

  @override
  String get exportDone => 'Записи экспортированы';

  @override
  String get exportPickLocation => 'Куда сохранить резервную копию';

  @override
  String get exportCancelled => 'Экспорт отменён';

  @override
  String get importDone => 'Записи импортированы';

  @override
  String get importError => 'Не удалось импортировать файл';

  @override
  String get clearData => 'Стереть данные';

  @override
  String get confirmDelete => 'Подтвердите удаление';

  @override
  String get confirmDeleteData =>
      'Это удалит все ваши записи и настройки. Вы уверены?';

  @override
  String get deleteData => 'Удалить';

  @override
  String get experimental => 'Экспериментальные';

  @override
  String get tulpa => 'Тульпа (записи о тульпах)';

  @override
  String get tulpaHint =>
      'Добавить тип записи «Тульпа» для заметок о своих тульпах';

  @override
  String get tabTulpa => 'Тульпы';

  @override
  String get segTulpa => 'Тульпа';

  @override
  String get typeTulpa => 'Тульпа';

  @override
  String get about => 'О приложении';

  @override
  String get aboutDesc =>
      'Дневник снов, жизни и тульп. Свободное ПО с открытым исходным кодом.';

  @override
  String get version => 'Версия';

  @override
  String get enterCurrentPin => 'Введите текущий PIN';

  @override
  String get guideDreamTitle => 'Мотивация и обучение';

  @override
  String get guideTulpaTitle => 'Тульпа: бережный диалог';

  @override
  String get guideToday => 'Сегодня';

  @override
  String guidePracticeOfDay(Object title) {
    return 'Практика дня: $title';
  }

  @override
  String get guideMarkDone => 'Отметить выполнение';

  @override
  String get guideDone => 'Практика выполнена';

  @override
  String get guideHowItWorks => 'Как это работает';

  @override
  String get guideWhyUseful => 'Почему это может быть полезно';

  @override
  String get guideDreamSubtitle =>
      'Небольшой шаг к осознанному сну — каждый день';

  @override
  String get guideTulpaSubtitle => 'Польза, общение и забота о себе';

  @override
  String get madeWithLove => 'Сделано с любовью';

  @override
  String get forcingDuration => 'Длительность форсинга';

  @override
  String get forcingHint => 'Укажите, сколько длился форсинг';

  @override
  String get statistics => 'Статистика';

  @override
  String get statsTotal => 'Всего записей';

  @override
  String get statsByType => 'Записи по типам';

  @override
  String get statsMood => 'Настроение во времени';

  @override
  String get statsCalendar => 'Календарь записей';

  @override
  String get statsDreamSigns => 'Частые dream signs';

  @override
  String get statsNoData => 'Недостаточно данных';

  @override
  String get editTime => 'Дата и время';

  @override
  String get dreamSignsSection => 'Dream signs';

  @override
  String get addSign => 'Добавить своё';

  @override
  String get month => 'Месяц';

  @override
  String get category => 'Категория';

  @override
  String get catAll => 'Все';

  @override
  String get catGood => 'Хороший';

  @override
  String get catBad => 'Плохой';

  @override
  String get catRandom => 'Случайный';

  @override
  String get reminders => 'Напоминания';

  @override
  String get reminderTime => 'Время уведомления';

  @override
  String get reminderText => 'Текст уведомления';

  @override
  String get reminderHint => 'Что напомнить (обязательно)';

  @override
  String get reminderSet => 'Напоминание установлено';

  @override
  String get reminderDisabled => 'Напоминание отключено';

  @override
  String get reminderRequired => 'Укажите текст уведомления';

  @override
  String reminderNextFire(Object time) {
    return 'Это время уже прошло сегодня — первое срабатывание завтра в $time';
  }

  @override
  String get autosave => 'Автосохранение';

  @override
  String get autosaveHint => 'Сохранять запись каждую секунду';

  @override
  String get expWater => 'Вода';

  @override
  String get expFasting => 'Интерва';

  @override
  String get expPomodoro => 'Помодоро';

  @override
  String get expSteps => 'Шаги';

  @override
  String get water => 'Вода, л';

  @override
  String get waterHint => 'Сколько литров выпили';

  @override
  String get waterStats => 'Статистика воды';

  @override
  String get fasting => 'Голодание';

  @override
  String get fastingFrom => 'Начало';

  @override
  String get fastingTo => 'Конец';

  @override
  String get fastingWindow => 'Окно голодания';

  @override
  String get pomodoro => 'Помодоро';

  @override
  String get pomodoroStart => 'Начало фокуса';

  @override
  String get pomodoroEnd => 'Конец фокуса';

  @override
  String get pomodoroStartFocus => 'Запустить фокус';

  @override
  String get pomodoroRunning => 'Фокус';

  @override
  String get pomodoroDone => 'Фокус завершён';

  @override
  String get steps => 'Шаги';

  @override
  String get stepsToday => 'Шагов сегодня';

  @override
  String get stepsNotSupported => 'Шаги недоступны на этом устройстве';

  @override
  String get voiceInput => 'Голосовой ввод';

  @override
  String get listening => 'Слушаю…';

  @override
  String get voiceUnavailable => 'Голосовой ввод недоступен';

  @override
  String get pinned => 'Закреплено';

  @override
  String get unpinned => 'Откреплено';

  @override
  String get byWetidom => 'BY WETIDOM';

  @override
  String get launchTitle => 'Ataraxy';

  @override
  String get newReminder => 'Новое напоминание';

  @override
  String get themeSystem => 'Системная (Material You)';

  @override
  String get themeLightPeach => 'Светлая персиковая';

  @override
  String get themeLightLavender => 'Лавандовая';

  @override
  String get themeDarkPeach => 'Тёмная персиковая';

  @override
  String get themeLightGrok => 'Светлая Grok';

  @override
  String get favoritesAddAnyFile => 'Добавить файл или фото';

  @override
  String get favoritesPhotosEmpty => 'Пока нет фото';

  @override
  String get favoritesPhotosEmptyHint =>
      'Нажмите на скрепку, чтобы добавить фотографии';

  @override
  String get langSystem => 'Системный';

  @override
  String get langRussian => 'Русский';

  @override
  String get langEnglish => 'English';

  @override
  String get langFrench => 'Français';

  @override
  String get dev => 'Dev';

  @override
  String get devMode => 'Режим разработчика';

  @override
  String get devPassword => 'Пароль разработчика';

  @override
  String get devWrongPassword => 'Неверный пароль';

  @override
  String get devHrtTracking => 'Гормональная терапия (HRT)';

  @override
  String get devTestNotification => 'Тест уведомления';

  @override
  String get devScheduleDaily => 'Запланировать ежедневное';

  @override
  String get devCancelAll => 'Отменить все';

  @override
  String get devCheckPermissions => 'Проверить разрешения';

  @override
  String get devClearAllData => 'Очистить все данные';

  @override
  String get hrtTime => 'Время приёма HRT';

  @override
  String get hrtDosage => 'Дозировка HRT';

  @override
  String get license => 'Лицензия: MIT';

  @override
  String get sortNewest => 'Сначала новые';

  @override
  String get sortOldest => 'Сначала старые';

  @override
  String get sortAlpha => 'По алфавиту';

  @override
  String get githubLink => 'github.com/wxstdo-boop/Ataraxy';

  @override
  String get themeMutilated => 'MUTILATED';

  @override
  String get testNotification => 'Тест уведомления';

  @override
  String get devScheduleDailyHint =>
      'Запланировать тестовое напоминание через минуту';

  @override
  String get devPermissionsTitle => 'Разрешения';

  @override
  String get devPermissionsHint => 'Проверить уведомления и точные будильники';

  @override
  String get devClearAllHint => 'ВНИМАНИЕ: удаляет все записи и настройки';

  @override
  String get devFullReset => 'Полный сброс';

  @override
  String get devFullResetConfirm =>
      'Это удалит ВСЕ записи и настройки. Вы уверены?';

  @override
  String get devResetTriggered => 'Сброс запущен';

  @override
  String get ok => 'OK';

  @override
  String get aiAssistant => 'ИИ-ассистент';

  @override
  String get aiInputHint => 'Спроси что-нибудь о своих записях…';

  @override
  String get aiThinking => 'Думаю…';

  @override
  String get aiEmptyTitle => 'Привет! Я твой ИИ-ассистент';

  @override
  String get aiEmptyHint =>
      'Анализирую твой дневник: сны, жизнь, тульпы. Спрашивай о паттернах, проси подвести итоги или создать запись.';

  @override
  String aiAnalyzes(Object n) {
    return 'Вижу $n записей в твоём дневнике';
  }

  @override
  String get aiDailyLimitReached => 'Достигнут дневной лимит сообщений';

  @override
  String get aiError => 'Ошибка ИИ';

  @override
  String get aiEntryCreated => '✅ Запись создана';

  @override
  String get aiEntryUpdated => '✅ Запись обновлена';

  @override
  String get aiCommandError => '⚠ Не удалось выполнить команду';

  @override
  String get aiSettingsTitle => 'ИИ-ассистент';

  @override
  String get aiSettingsHint =>
      'Умный чат по твоим записям (долгое нажатие на «+»)';

  @override
  String get aiProvider => 'Провайдер';

  @override
  String get aiFree => 'бесплатно, без ключа';

  @override
  String get aiKey => 'API-ключ';

  @override
  String get aiKeyEmpty => 'Не задан';

  @override
  String get aiDailyLimit => 'Дневной лимит';

  @override
  String get aiLimitPerDay => 'сообщений в день';

  @override
  String get aiLimitUnlimited => 'Без лимита';

  @override
  String get aiDisabled => 'ИИ-ассистент выключен — включи в настройках';

  @override
  String get minimize => 'Свернуть';

  @override
  String get aiOnline => 'онлайн';

  @override
  String get aiOnVacation => 'ИИ сейчас на курорте ☀️ — попробуй чуть позже';

  @override
  String get aiAdaFallback =>
      'ADA временно недоступна (модель не развёрнута) — переключил на бесплатный канал';

  @override
  String get aiAdaNotDeployed =>
      'Модель ADA ещё не развёрнута на HuggingFace — включи Inference Endpoint в настройках модели (нужен Pro), или используй Free';

  @override
  String get aiClearChat => 'Очистить чат';

  @override
  String get aiChatFull =>
      'Чат заполнен (1000 сообщений) — очисти его, чтобы продолжить';

  @override
  String get aiAdaLimitReached =>
      'Дневной лимит ADA (100) исчерпан — переключаю на бесплатный канал';

  @override
  String aiRemaining(Object n) {
    return 'Сегодня осталось $n сообщений';
  }

  @override
  String get close => 'Закрыть';

  @override
  String get autoExportTitle => 'Автоэкспорт';

  @override
  String get autoExportHint => 'Ежечасовая копия в /Download';

  @override
  String get autoExportEnabled => 'Автоэкспорт включён';

  @override
  String get autoExportDisabled => 'Автоэкспорт выключен';

  @override
  String get updateTitle => 'Обновление Ataraxy';

  @override
  String get updateHint =>
      'Проверить GitHub Releases и установить новую версию';

  @override
  String get updateChecking => 'Проверяем GitHub Releases…';

  @override
  String get updateFound => 'Доступна версия';

  @override
  String get updateDownloading => 'Скачиваем обновление';

  @override
  String get updateCurrent => 'У вас установлена последняя версия';

  @override
  String get updatePermission =>
      'Разрешите установку приложений для Ataraxy и нажмите ещё раз';

  @override
  String get updateInstalling =>
      'Открылся установщик Android — подтвердите обновление';

  @override
  String get updateFailed => 'Не удалось проверить или установить обновление';

  @override
  String get cloudBackupTitle => 'Бэкап и восстановление';

  @override
  String get shareBackup => 'Поделиться бэкапом';

  @override
  String get shareBackupHint =>
      'Отправить JSON-файл в Google Диск, Telegram, Dropbox или куда угодно';

  @override
  String get comingSoon => 'Скоро';

  @override
  String get welcomeTitle => 'Добро пожаловать в Ataraxy';

  @override
  String get welcomeSubtitle =>
      'Настройте приложение для идеального опыта записи снов';

  @override
  String get notifications => 'Уведомления';

  @override
  String get notificationsDescription =>
      'Получать уведомления о новых функциях';

  @override
  String get dailyReminder => 'Ежедневное напоминание';

  @override
  String get dailyReminderDescription =>
      'Напоминать записывать сны каждый день';

  @override
  String get security => 'Безопасность';

  @override
  String get securityDescription => 'Защитить приложение PIN-кодом';

  @override
  String get dontShowAgain => 'Больше не показывать';

  @override
  String get startUsing => 'Начать использовать';

  @override
  String get enableNotificationsFirst => 'Сначала включите уведомления';

  @override
  String get setup => 'Настроить';

  @override
  String get resetSettings => 'Сбросить настройки';

  @override
  String get resetSettingsConfirm =>
      'Вы уверены что хотите сбросить все настройки?';

  @override
  String get reset => 'Сбросить';

  @override
  String get settingsReset => 'Настройки сброшены';

  @override
  String get errorResettingSettings => 'Ошибка сброса настроек';

  @override
  String get favoriteActivities => 'Любимые дела';

  @override
  String get favoriteActivity => 'Любимое дело';

  @override
  String get favoriteActivityBannerTitle => 'Любимое дело';

  @override
  String get favoriteActivityBannerSubtitle => 'То, что наполняет день смыслом';

  @override
  String get favoriteActivityHint => 'Что вы любите делать?';

  @override
  String get favoriteActivityReading => 'Режим чтения';

  @override
  String get favoriteActivityEmpty => 'Пока нет любимых дел';

  @override
  String get favoriteActivityEmptyHint => 'Добавьте то, что вас вдохновляет';

  @override
  String get favoriteActivityAdd => 'Добавить дело';

  @override
  String get favoriteActivityEdit => 'Изменить';

  @override
  String get favoriteActivityDelete => 'Удалить';

  @override
  String get favoriteActivityPin => 'Закрепить';

  @override
  String get favoriteActivityUnpin => 'Открепить';

  @override
  String get favoriteActivityHoldDelete => 'Удерживайте для удаления';

  @override
  String get favoriteActivityLimit => 'символов';

  @override
  String get closeSearch => 'Закрыть поиск';

  @override
  String get totalEntries => 'Всего записей';

  @override
  String get sortManual => 'Вручную';

  @override
  String get favoritesBannerTitle => 'Избранное';

  @override
  String get favoritesBannerSubtitle => 'Фото, видео, файлы и заметки';

  @override
  String get favoritesTitle => 'Избранное';

  @override
  String get fileNotFound => 'Файл не найден';

  @override
  String get attachFile => 'Прикрепить файл';

  @override
  String get writeToFavorites => 'Написать в избранное…';

  @override
  String get saveText => 'Сохранить текст';

  @override
  String get imageCropped => 'Изображение обрезано';

  @override
  String get crop => 'Обрезка';

  @override
  String get apply => 'Применить';

  @override
  String get cropHint => 'Проведите для выбора области обрезки';

  @override
  String get cropTooSmall => 'Область слишком мала';

  @override
  String get editFile => 'Редактировать файл';

  @override
  String get editTextTitle => 'Редактировать текст';

  @override
  String get nameLabel => 'Название';

  @override
  String get editTextHint => 'Измените текст…';

  @override
  String get patchNotes => 'Патч-ноуты';

  @override
  String get whatsLeft => 'Что осталось доработать';

  @override
  String get remindersTodo => 'Напоминания';

  @override
  String get autosaveTodo => 'Автосохранения';

  @override
  String get favoritesTodo => 'Избранное';

  @override
  String get steqtoqTag => 'лучше CapCut';

  @override
  String get versionCurrent => 'текущая';

  @override
  String get pnPinnedFix =>
      'Закрепление сообщений в избранном теперь не сбивается';

  @override
  String get pnBlurVideo => 'Кнопка размытия теперь работает и на видео';

  @override
  String get pnNotesTab =>
      'Заметки больше не показываются в общем списке «Всё»';

  @override
  String get pnExport =>
      'Экспорт/импорт: заметки и закрепленные сообщения сохраняются';

  @override
  String get pnLocales => 'Полная локализация английского и французского';

  @override
  String get pnFavorites =>
      'Избранное: фото, видео, файлы и заметки в одном месте';

  @override
  String get pnHeartbeatPlayer => 'Пульсирующая шкала времени в видеоплеере';

  @override
  String get pnPatchNotesSection =>
      'Раздел «Патч-ноуты» прямо в «О приложении»';

  @override
  String get pn13Web => 'Веб-версия: аватарка в сплеше и favicon приложения';

  @override
  String get pn13Anim =>
      'Плавные переходы: сплеш, темы, языки, вкладки и типы записей';

  @override
  String get pn13Smooth =>
      'Плавное обновление ленты и карточки записей с анимированной обводкой';

  @override
  String get pn13Limits =>
      'Лимиты ввода: теги (3 шт., 10 символов), dream sign (10), вода (2), напоминание (50)';

  @override
  String get pn13Card =>
      'Кнопка «Обновить» теперь действительно обновляет записи';

  @override
  String get pn131Save =>
      'Записи больше не теряются: сохранение при любом выходе и при сворачивании';

  @override
  String get pn131Meta =>
      'Закрепление, метки сна, люидность и таблетки теперь сохраняются сразу';

  @override
  String get pn131Export =>
      'Экспорт: системный диалог «Куда сохранить» вместо доступа к файлам';

  @override
  String get pn131Smooth =>
      'Плавность: лента не перестраивается при сворачивании пилюль, единый переход между экранами';

  @override
  String get pn132Words =>
      'Потеря слов из ленты: перетаскивание и закрепление больше не перезаписывают текст старым снимком';

  @override
  String get pn132Order => 'Ручной порядок записей сохраняется между запусками';

  @override
  String get pn132Editor =>
      'Редактор: сбой сохранения больше не помечает текст как записанный — слова пишутся заново';

  @override
  String get pn132Spots =>
      'Цветные пятна под таблетками разделов: теперь читаемы и в тёмной, и в светлой теме';

  @override
  String get pn133Repeat =>
      'Потеря слов при повторном открытии: карточка больше не передаёт редактору старый снимок записи';

  @override
  String get pn133Spots =>
      'Пятна разделов стали крупнее и насыщеннее: закрывают таблетку целиком, а не точку в центре';

  @override
  String get importSummary => 'Импорт завершён';

  @override
  String importSummaryLine(
    Object activities,
    Object entries,
    Object favorites,
  ) {
    return 'Записей: $entries · Избранное: $favorites · Любимых дел: $activities';
  }

  @override
  String importMediaMissing(Object n) {
    return '$n файл(ов) из «Избранного» не найдено на этом устройстве — откройте Избранное и прикрепите заново';
  }

  @override
  String importActivitiesTrimmed(Object n) {
    return '$n любимых дел обрезано (макс. 5)';
  }

  @override
  String importItemsSkipped(Object n) {
    return '$n повреждённых элементов пропущено';
  }

  @override
  String get supportButton => 'Поддержать';

  @override
  String get supportHint => 'Помочь развитию приложения';

  @override
  String get supportThanks => 'Спасибо за поддержку! 💖';

  @override
  String get favoriteActivityLimitReached =>
      'Можно добавить не более 5 любимых дел';

  @override
  String get favoriteActivityAdded => 'Дело добавлено';

  @override
  String get favoriteActivityDeleted => 'Дело удалено';

  @override
  String get permissions => 'Разрешения';

  @override
  String get miuiHint =>
      'MIUI: включите Автозапуск и «Без ограничений» в Батарее — иначе система остановит фоновые уведомления.';

  @override
  String get webHint => 'Уведомление сработает, пока вкладка открыта.';

  @override
  String get sign_flying => 'Полёт';

  @override
  String get sign_falling => 'Падение';

  @override
  String get sign_chased => 'Погоня';

  @override
  String get sign_teeth => 'Зубы';

  @override
  String get sign_water => 'Вода';

  @override
  String get sign_school => 'Школа';

  @override
  String get sign_paralysis => 'Паралич';

  @override
  String get sign_lost => 'Потеря';

  @override
  String get sign_animal => 'Животные';

  @override
  String get sign_vehicle => 'Транспорт';

  @override
  String get sign_celebrity => 'Знаменитости';

  @override
  String get sign_naked => 'Нагота';
}
