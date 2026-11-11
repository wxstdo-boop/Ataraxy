import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мой дневник'**
  String get appTitle;

  /// No description provided for @tabDreams.
  ///
  /// In ru, this message translates to:
  /// **'Сны'**
  String get tabDreams;

  /// No description provided for @tabLife.
  ///
  /// In ru, this message translates to:
  /// **'Жизнь'**
  String get tabLife;

  /// No description provided for @tabAll.
  ///
  /// In ru, this message translates to:
  /// **'Всё'**
  String get tabAll;

  /// No description provided for @tabNotes.
  ///
  /// In ru, this message translates to:
  /// **'Заметки'**
  String get tabNotes;

  /// No description provided for @fabNew.
  ///
  /// In ru, this message translates to:
  /// **'Запись'**
  String get fabNew;

  /// No description provided for @refresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get refresh;

  /// No description provided for @entriesUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Записи обновлены'**
  String get entriesUpdated;

  /// No description provided for @emptyDream.
  ///
  /// In ru, this message translates to:
  /// **'Записей о снах пока нет'**
  String get emptyDream;

  /// No description provided for @emptyLife.
  ///
  /// In ru, this message translates to:
  /// **'Записей о жизни пока нет'**
  String get emptyLife;

  /// No description provided for @emptyNotes.
  ///
  /// In ru, this message translates to:
  /// **'Заметок пока нет'**
  String get emptyNotes;

  /// No description provided for @emptyAll.
  ///
  /// In ru, this message translates to:
  /// **'Записей пока нет'**
  String get emptyAll;

  /// No description provided for @emptyTulpa.
  ///
  /// In ru, this message translates to:
  /// **'Записей о тульпах пока нет'**
  String get emptyTulpa;

  /// No description provided for @entryNew.
  ///
  /// In ru, this message translates to:
  /// **'Новая запись'**
  String get entryNew;

  /// No description provided for @entryEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get entryEdit;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @saveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить — проверьте место на устройстве'**
  String get saveFailed;

  /// No description provided for @typeDream.
  ///
  /// In ru, this message translates to:
  /// **'Сон'**
  String get typeDream;

  /// No description provided for @typeLife.
  ///
  /// In ru, this message translates to:
  /// **'Жизнь'**
  String get typeLife;

  /// No description provided for @typeGeneral.
  ///
  /// In ru, this message translates to:
  /// **'Заметка'**
  String get typeGeneral;

  /// No description provided for @segDream.
  ///
  /// In ru, this message translates to:
  /// **'Сон'**
  String get segDream;

  /// No description provided for @segLife.
  ///
  /// In ru, this message translates to:
  /// **'Жизнь'**
  String get segLife;

  /// No description provided for @segGeneral.
  ///
  /// In ru, this message translates to:
  /// **'Заметка'**
  String get segGeneral;

  /// No description provided for @titleHint.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок'**
  String get titleHint;

  /// No description provided for @contentHint.
  ///
  /// In ru, this message translates to:
  /// **'Опишите свои мысли, сон или событие...'**
  String get contentHint;

  /// No description provided for @editTab.
  ///
  /// In ru, this message translates to:
  /// **'Редактор'**
  String get editTab;

  /// No description provided for @previewTab.
  ///
  /// In ru, this message translates to:
  /// **'Превью'**
  String get previewTab;

  /// No description provided for @previewEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Текст пока пуст — начните писать, и превью появится здесь'**
  String get previewEmpty;

  /// No description provided for @tapToExpandNotes.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы раскрыть заметки'**
  String get tapToExpandNotes;

  /// No description provided for @mood.
  ///
  /// In ru, this message translates to:
  /// **'Настроение'**
  String get mood;

  /// No description provided for @tags.
  ///
  /// In ru, this message translates to:
  /// **'Теги'**
  String get tags;

  /// No description provided for @addTag.
  ///
  /// In ru, this message translates to:
  /// **'Добавить тег'**
  String get addTag;

  /// No description provided for @tagsLimit.
  ///
  /// In ru, this message translates to:
  /// **'Максимум 3 тега'**
  String get tagsLimit;

  /// No description provided for @tagTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Тег не длиннее 10 символов'**
  String get tagTooLong;

  /// No description provided for @withoutTitle.
  ///
  /// In ru, this message translates to:
  /// **'Без названия'**
  String get withoutTitle;

  /// No description provided for @noText.
  ///
  /// In ru, this message translates to:
  /// **'Нет текста.'**
  String get noText;

  /// No description provided for @deleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить запись?'**
  String get deleteTitle;

  /// No description provided for @deleteContent.
  ///
  /// In ru, this message translates to:
  /// **'Это действие нельзя отменить.'**
  String get deleteContent;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @cut.
  ///
  /// In ru, this message translates to:
  /// **'Вырезать'**
  String get cut;

  /// No description provided for @copy.
  ///
  /// In ru, this message translates to:
  /// **'Копировать'**
  String get copy;

  /// No description provided for @paste.
  ///
  /// In ru, this message translates to:
  /// **'Вставить'**
  String get paste;

  /// No description provided for @share.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться'**
  String get share;

  /// No description provided for @clear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get clear;

  /// No description provided for @delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// No description provided for @entryDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Запись удалена'**
  String get entryDeleted;

  /// No description provided for @restore.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть'**
  String get restore;

  /// No description provided for @streak.
  ///
  /// In ru, this message translates to:
  /// **'Серия дней'**
  String get streak;

  /// No description provided for @streakDays.
  ///
  /// In ru, this message translates to:
  /// **'дн.'**
  String get streakDays;

  /// No description provided for @streakHint.
  ///
  /// In ru, this message translates to:
  /// **'Дни подряд, когда ты записываешь в дневник. Пропустишь день — серия начнётся заново. Записывай каждый день, чтобы серия росла!'**
  String get streakHint;

  /// No description provided for @rewardChat.
  ///
  /// In ru, this message translates to:
  /// **'🔥 Награда дня: +{n} ✨'**
  String rewardChat(Object n);

  /// No description provided for @rewardTask.
  ///
  /// In ru, this message translates to:
  /// **'✅ Задача выполнена: +{n} ✨'**
  String rewardTask(Object n);

  /// No description provided for @rewardStreak.
  ///
  /// In ru, this message translates to:
  /// **'Серия: {n} дн.'**
  String rewardStreak(Object n);

  /// No description provided for @settings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings;

  /// No description provided for @theme.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get language;

  /// No description provided for @pin.
  ///
  /// In ru, this message translates to:
  /// **'PIN-код'**
  String get pin;

  /// No description provided for @setPin.
  ///
  /// In ru, this message translates to:
  /// **'Установить PIN'**
  String get setPin;

  /// No description provided for @changePin.
  ///
  /// In ru, this message translates to:
  /// **'Изменить PIN'**
  String get changePin;

  /// No description provided for @removePin.
  ///
  /// In ru, this message translates to:
  /// **'Убрать PIN'**
  String get removePin;

  /// No description provided for @removePinConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены? PIN-код будет удалён.'**
  String get removePinConfirm;

  /// No description provided for @enterPin.
  ///
  /// In ru, this message translates to:
  /// **'Введите PIN'**
  String get enterPin;

  /// No description provided for @confirmPin.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите PIN'**
  String get confirmPin;

  /// No description provided for @unlock.
  ///
  /// In ru, this message translates to:
  /// **'Разблокировать'**
  String get unlock;

  /// No description provided for @pinMismatch.
  ///
  /// In ru, this message translates to:
  /// **'PIN не совпадает'**
  String get pinMismatch;

  /// No description provided for @pinWrong.
  ///
  /// In ru, this message translates to:
  /// **'Неверный PIN'**
  String get pinWrong;

  /// No description provided for @pinSetDone.
  ///
  /// In ru, this message translates to:
  /// **'PIN установлен'**
  String get pinSetDone;

  /// No description provided for @pinRemoved.
  ///
  /// In ru, this message translates to:
  /// **'PIN удалён'**
  String get pinRemoved;

  /// No description provided for @dreamKind.
  ///
  /// In ru, this message translates to:
  /// **'Тип сна'**
  String get dreamKind;

  /// No description provided for @dreamNormal.
  ///
  /// In ru, this message translates to:
  /// **'Обычный'**
  String get dreamNormal;

  /// No description provided for @dreamLucid.
  ///
  /// In ru, this message translates to:
  /// **'Осознанный'**
  String get dreamLucid;

  /// No description provided for @lucidBadge.
  ///
  /// In ru, this message translates to:
  /// **'Осознанный сон'**
  String get lucidBadge;

  /// No description provided for @normalBadge.
  ///
  /// In ru, this message translates to:
  /// **'Обычный сон'**
  String get normalBadge;

  /// No description provided for @search.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по записям...'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get noResults;

  /// No description provided for @data.
  ///
  /// In ru, this message translates to:
  /// **'Данные'**
  String get data;

  /// No description provided for @export.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт'**
  String get export;

  /// No description provided for @import.
  ///
  /// In ru, this message translates to:
  /// **'Импорт'**
  String get import;

  /// No description provided for @protectDeletedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не возвращать удалённое при импорте'**
  String get protectDeletedTitle;

  /// No description provided for @protectDeletedHint.
  ///
  /// In ru, this message translates to:
  /// **'Удалённые записи не появятся снова после импорта старого бэкапа'**
  String get protectDeletedHint;

  /// No description provided for @exportDone.
  ///
  /// In ru, this message translates to:
  /// **'Записи экспортированы'**
  String get exportDone;

  /// No description provided for @exportPickLocation.
  ///
  /// In ru, this message translates to:
  /// **'Куда сохранить резервную копию'**
  String get exportPickLocation;

  /// No description provided for @exportCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт отменён'**
  String get exportCancelled;

  /// No description provided for @importDone.
  ///
  /// In ru, this message translates to:
  /// **'Записи импортированы'**
  String get importDone;

  /// No description provided for @importError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось импортировать файл'**
  String get importError;

  /// No description provided for @clearData.
  ///
  /// In ru, this message translates to:
  /// **'Стереть данные'**
  String get clearData;

  /// No description provided for @confirmDelete.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите удаление'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteData.
  ///
  /// In ru, this message translates to:
  /// **'Это удалит все ваши записи и настройки. Вы уверены?'**
  String get confirmDeleteData;

  /// No description provided for @deleteData.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get deleteData;

  /// No description provided for @experimental.
  ///
  /// In ru, this message translates to:
  /// **'Экспериментальные'**
  String get experimental;

  /// No description provided for @tulpa.
  ///
  /// In ru, this message translates to:
  /// **'Тульпа (записи о тульпах)'**
  String get tulpa;

  /// No description provided for @tulpaHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавить тип записи «Тульпа» для заметок о своих тульпах'**
  String get tulpaHint;

  /// No description provided for @tabTulpa.
  ///
  /// In ru, this message translates to:
  /// **'Тульпы'**
  String get tabTulpa;

  /// No description provided for @segTulpa.
  ///
  /// In ru, this message translates to:
  /// **'Тульпа'**
  String get segTulpa;

  /// No description provided for @typeTulpa.
  ///
  /// In ru, this message translates to:
  /// **'Тульпа'**
  String get typeTulpa;

  /// No description provided for @about.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get about;

  /// No description provided for @aboutDesc.
  ///
  /// In ru, this message translates to:
  /// **'Дневник снов, жизни и тульп. Свободное ПО с открытым исходным кодом.'**
  String get aboutDesc;

  /// No description provided for @version.
  ///
  /// In ru, this message translates to:
  /// **'Версия'**
  String get version;

  /// No description provided for @enterCurrentPin.
  ///
  /// In ru, this message translates to:
  /// **'Введите текущий PIN'**
  String get enterCurrentPin;

  /// No description provided for @guideDreamTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мотивация и обучение'**
  String get guideDreamTitle;

  /// No description provided for @guideTulpaTitle.
  ///
  /// In ru, this message translates to:
  /// **'Тульпа: бережный диалог'**
  String get guideTulpaTitle;

  /// No description provided for @guideToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get guideToday;

  /// No description provided for @guidePracticeOfDay.
  ///
  /// In ru, this message translates to:
  /// **'Практика дня: {title}'**
  String guidePracticeOfDay(Object title);

  /// No description provided for @guideMarkDone.
  ///
  /// In ru, this message translates to:
  /// **'Отметить выполнение'**
  String get guideMarkDone;

  /// No description provided for @guideDone.
  ///
  /// In ru, this message translates to:
  /// **'Практика выполнена'**
  String get guideDone;

  /// No description provided for @guideHowItWorks.
  ///
  /// In ru, this message translates to:
  /// **'Как это работает'**
  String get guideHowItWorks;

  /// No description provided for @guideWhyUseful.
  ///
  /// In ru, this message translates to:
  /// **'Почему это может быть полезно'**
  String get guideWhyUseful;

  /// No description provided for @guideDreamSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Небольшой шаг к осознанному сну — каждый день'**
  String get guideDreamSubtitle;

  /// No description provided for @guideTulpaSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Польза, общение и забота о себе'**
  String get guideTulpaSubtitle;

  /// No description provided for @madeWithLove.
  ///
  /// In ru, this message translates to:
  /// **'Сделано с любовью'**
  String get madeWithLove;

  /// No description provided for @forcingDuration.
  ///
  /// In ru, this message translates to:
  /// **'Длительность форсинга'**
  String get forcingDuration;

  /// No description provided for @forcingHint.
  ///
  /// In ru, this message translates to:
  /// **'Укажите, сколько длился форсинг'**
  String get forcingHint;

  /// No description provided for @statistics.
  ///
  /// In ru, this message translates to:
  /// **'Статистика'**
  String get statistics;

  /// No description provided for @statsTotal.
  ///
  /// In ru, this message translates to:
  /// **'Всего записей'**
  String get statsTotal;

  /// No description provided for @statsByType.
  ///
  /// In ru, this message translates to:
  /// **'Записи по типам'**
  String get statsByType;

  /// No description provided for @statsMood.
  ///
  /// In ru, this message translates to:
  /// **'Настроение во времени'**
  String get statsMood;

  /// No description provided for @statsCalendar.
  ///
  /// In ru, this message translates to:
  /// **'Календарь записей'**
  String get statsCalendar;

  /// No description provided for @statsDreamSigns.
  ///
  /// In ru, this message translates to:
  /// **'Частые dream signs'**
  String get statsDreamSigns;

  /// No description provided for @statsNoData.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно данных'**
  String get statsNoData;

  /// No description provided for @editTime.
  ///
  /// In ru, this message translates to:
  /// **'Дата и время'**
  String get editTime;

  /// No description provided for @dreamSignsSection.
  ///
  /// In ru, this message translates to:
  /// **'Dream signs'**
  String get dreamSignsSection;

  /// No description provided for @addSign.
  ///
  /// In ru, this message translates to:
  /// **'Добавить своё'**
  String get addSign;

  /// No description provided for @month.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get month;

  /// No description provided for @category.
  ///
  /// In ru, this message translates to:
  /// **'Категория'**
  String get category;

  /// No description provided for @catAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get catAll;

  /// No description provided for @catGood.
  ///
  /// In ru, this message translates to:
  /// **'Хороший'**
  String get catGood;

  /// No description provided for @catBad.
  ///
  /// In ru, this message translates to:
  /// **'Плохой'**
  String get catBad;

  /// No description provided for @catRandom.
  ///
  /// In ru, this message translates to:
  /// **'Случайный'**
  String get catRandom;

  /// No description provided for @reminders.
  ///
  /// In ru, this message translates to:
  /// **'Напоминания'**
  String get reminders;

  /// No description provided for @reminderTime.
  ///
  /// In ru, this message translates to:
  /// **'Время уведомления'**
  String get reminderTime;

  /// No description provided for @reminderText.
  ///
  /// In ru, this message translates to:
  /// **'Текст уведомления'**
  String get reminderText;

  /// No description provided for @reminderHint.
  ///
  /// In ru, this message translates to:
  /// **'Что напомнить'**
  String get reminderHint;

  /// No description provided for @reminderSet.
  ///
  /// In ru, this message translates to:
  /// **'Напоминание установлено'**
  String get reminderSet;

  /// No description provided for @reminderDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Напоминание отключено'**
  String get reminderDisabled;

  /// No description provided for @reminderRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите текст уведомления'**
  String get reminderRequired;

  /// No description provided for @reminderNextFire.
  ///
  /// In ru, this message translates to:
  /// **'Это время уже прошло сегодня — первое срабатывание завтра в {time}'**
  String reminderNextFire(Object time);

  /// No description provided for @autosave.
  ///
  /// In ru, this message translates to:
  /// **'Автосохранение'**
  String get autosave;

  /// No description provided for @autosaveHint.
  ///
  /// In ru, this message translates to:
  /// **'Сохранять запись каждую секунду'**
  String get autosaveHint;

  /// No description provided for @expWater.
  ///
  /// In ru, this message translates to:
  /// **'Вода'**
  String get expWater;

  /// No description provided for @expFasting.
  ///
  /// In ru, this message translates to:
  /// **'Интерва'**
  String get expFasting;

  /// No description provided for @expPomodoro.
  ///
  /// In ru, this message translates to:
  /// **'Помодоро'**
  String get expPomodoro;

  /// No description provided for @expSteps.
  ///
  /// In ru, this message translates to:
  /// **'Шаги'**
  String get expSteps;

  /// No description provided for @water.
  ///
  /// In ru, this message translates to:
  /// **'Вода, л'**
  String get water;

  /// No description provided for @waterHint.
  ///
  /// In ru, this message translates to:
  /// **'Сколько литров выпили'**
  String get waterHint;

  /// No description provided for @waterStats.
  ///
  /// In ru, this message translates to:
  /// **'Статистика воды'**
  String get waterStats;

  /// No description provided for @fasting.
  ///
  /// In ru, this message translates to:
  /// **'Голодание'**
  String get fasting;

  /// No description provided for @fastingFrom.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get fastingFrom;

  /// No description provided for @fastingTo.
  ///
  /// In ru, this message translates to:
  /// **'Конец'**
  String get fastingTo;

  /// No description provided for @fastingWindow.
  ///
  /// In ru, this message translates to:
  /// **'Окно голодания'**
  String get fastingWindow;

  /// No description provided for @pomodoro.
  ///
  /// In ru, this message translates to:
  /// **'Помодоро'**
  String get pomodoro;

  /// No description provided for @pomodoroStart.
  ///
  /// In ru, this message translates to:
  /// **'Начало фокуса'**
  String get pomodoroStart;

  /// No description provided for @pomodoroEnd.
  ///
  /// In ru, this message translates to:
  /// **'Конец фокуса'**
  String get pomodoroEnd;

  /// No description provided for @pomodoroStartFocus.
  ///
  /// In ru, this message translates to:
  /// **'Запустить фокус'**
  String get pomodoroStartFocus;

  /// No description provided for @pomodoroRunning.
  ///
  /// In ru, this message translates to:
  /// **'Фокус'**
  String get pomodoroRunning;

  /// No description provided for @pomodoroDone.
  ///
  /// In ru, this message translates to:
  /// **'Фокус завершён'**
  String get pomodoroDone;

  /// No description provided for @steps.
  ///
  /// In ru, this message translates to:
  /// **'Шаги'**
  String get steps;

  /// No description provided for @stepsToday.
  ///
  /// In ru, this message translates to:
  /// **'Шагов сегодня'**
  String get stepsToday;

  /// No description provided for @stepsNotSupported.
  ///
  /// In ru, this message translates to:
  /// **'Шаги недоступны на этом устройстве'**
  String get stepsNotSupported;

  /// No description provided for @voiceInput.
  ///
  /// In ru, this message translates to:
  /// **'Голосовой ввод'**
  String get voiceInput;

  /// No description provided for @listening.
  ///
  /// In ru, this message translates to:
  /// **'Слушаю…'**
  String get listening;

  /// No description provided for @voiceUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Голосовой ввод недоступен'**
  String get voiceUnavailable;

  /// No description provided for @pinned.
  ///
  /// In ru, this message translates to:
  /// **'Закреплено'**
  String get pinned;

  /// No description provided for @unpinned.
  ///
  /// In ru, this message translates to:
  /// **'Откреплено'**
  String get unpinned;

  /// No description provided for @byWetidom.
  ///
  /// In ru, this message translates to:
  /// **'POWERED BY LARAF'**
  String get byWetidom;

  /// No description provided for @launchTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ataraxy'**
  String get launchTitle;

  /// No description provided for @newReminder.
  ///
  /// In ru, this message translates to:
  /// **'Новое напоминание'**
  String get newReminder;

  /// No description provided for @themeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системная (Material You)'**
  String get themeSystem;

  /// No description provided for @themeLightPeach.
  ///
  /// In ru, this message translates to:
  /// **'Светлая персиковая'**
  String get themeLightPeach;

  /// No description provided for @themeLightLavender.
  ///
  /// In ru, this message translates to:
  /// **'Лавандовая'**
  String get themeLightLavender;

  /// No description provided for @themeDarkPeach.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная персиковая'**
  String get themeDarkPeach;

  /// No description provided for @themeLightGrok.
  ///
  /// In ru, this message translates to:
  /// **'Светлая Grok'**
  String get themeLightGrok;

  /// No description provided for @themeDarkGrok.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная Grok'**
  String get themeDarkGrok;

  /// No description provided for @favoritesAddAnyFile.
  ///
  /// In ru, this message translates to:
  /// **'Добавить файл или фото'**
  String get favoritesAddAnyFile;

  /// No description provided for @favoritesPhotosEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет фото'**
  String get favoritesPhotosEmpty;

  /// No description provided for @favoritesPhotosEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на скрепку, чтобы добавить фотографии'**
  String get favoritesPhotosEmptyHint;

  /// No description provided for @langSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системный'**
  String get langSystem;

  /// No description provided for @langRussian.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get langRussian;

  /// No description provided for @langEnglish.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langFrench.
  ///
  /// In ru, this message translates to:
  /// **'Français'**
  String get langFrench;

  /// No description provided for @dev.
  ///
  /// In ru, this message translates to:
  /// **'Dev'**
  String get dev;

  /// No description provided for @devMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим разработчика'**
  String get devMode;

  /// No description provided for @devPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль разработчика'**
  String get devPassword;

  /// No description provided for @devWrongPassword.
  ///
  /// In ru, this message translates to:
  /// **'Неверный пароль'**
  String get devWrongPassword;

  /// No description provided for @devHrtTracking.
  ///
  /// In ru, this message translates to:
  /// **'Гормональная терапия (HRT)'**
  String get devHrtTracking;

  /// No description provided for @devTestNotification.
  ///
  /// In ru, this message translates to:
  /// **'Тест уведомления'**
  String get devTestNotification;

  /// No description provided for @devScheduleDaily.
  ///
  /// In ru, this message translates to:
  /// **'Запланировать ежедневное'**
  String get devScheduleDaily;

  /// No description provided for @devCancelAll.
  ///
  /// In ru, this message translates to:
  /// **'Отменить все'**
  String get devCancelAll;

  /// No description provided for @devCheckPermissions.
  ///
  /// In ru, this message translates to:
  /// **'Проверить разрешения'**
  String get devCheckPermissions;

  /// No description provided for @devClearAllData.
  ///
  /// In ru, this message translates to:
  /// **'Очистить все данные'**
  String get devClearAllData;

  /// No description provided for @hrtTime.
  ///
  /// In ru, this message translates to:
  /// **'Время приёма HRT'**
  String get hrtTime;

  /// No description provided for @hrtDosage.
  ///
  /// In ru, this message translates to:
  /// **'Дозировка HRT'**
  String get hrtDosage;

  /// No description provided for @license.
  ///
  /// In ru, this message translates to:
  /// **'Лицензия: MIT'**
  String get license;

  /// No description provided for @sortNewest.
  ///
  /// In ru, this message translates to:
  /// **'Сначала новые'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In ru, this message translates to:
  /// **'Сначала старые'**
  String get sortOldest;

  /// No description provided for @sortAlpha.
  ///
  /// In ru, this message translates to:
  /// **'По алфавиту'**
  String get sortAlpha;

  /// No description provided for @githubLink.
  ///
  /// In ru, this message translates to:
  /// **'github.com/wxstdo-boop/Ataraxy'**
  String get githubLink;

  /// No description provided for @themeMutilated.
  ///
  /// In ru, this message translates to:
  /// **'MUTILATED'**
  String get themeMutilated;

  /// No description provided for @testNotification.
  ///
  /// In ru, this message translates to:
  /// **'Тест уведомления'**
  String get testNotification;

  /// No description provided for @devScheduleDailyHint.
  ///
  /// In ru, this message translates to:
  /// **'Запланировать тестовое напоминание через минуту'**
  String get devScheduleDailyHint;

  /// No description provided for @devPermissionsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Разрешения'**
  String get devPermissionsTitle;

  /// No description provided for @devPermissionsHint.
  ///
  /// In ru, this message translates to:
  /// **'Проверить уведомления и точные будильники'**
  String get devPermissionsHint;

  /// No description provided for @devClearAllHint.
  ///
  /// In ru, this message translates to:
  /// **'ВНИМАНИЕ: удаляет все записи и настройки'**
  String get devClearAllHint;

  /// No description provided for @devFullReset.
  ///
  /// In ru, this message translates to:
  /// **'Полный сброс'**
  String get devFullReset;

  /// No description provided for @devFullResetConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Это удалит ВСЕ записи и настройки. Вы уверены?'**
  String get devFullResetConfirm;

  /// No description provided for @devResetTriggered.
  ///
  /// In ru, this message translates to:
  /// **'Сброс запущен'**
  String get devResetTriggered;

  /// No description provided for @ok.
  ///
  /// In ru, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @aiAssistant.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-ассистент'**
  String get aiAssistant;

  /// No description provided for @aiInputHint.
  ///
  /// In ru, this message translates to:
  /// **'Спроси что-нибудь о своих записях…'**
  String get aiInputHint;

  /// No description provided for @aiThinking.
  ///
  /// In ru, this message translates to:
  /// **'Думаю…'**
  String get aiThinking;

  /// No description provided for @aiEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Привет! Я твой ИИ-ассистент'**
  String get aiEmptyTitle;

  /// No description provided for @aiEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Анализирую твой дневник: сны, жизнь, тульпы. Спрашивай о паттернах, проси подвести итоги или создать запись.'**
  String get aiEmptyHint;

  /// No description provided for @aiAnalyzes.
  ///
  /// In ru, this message translates to:
  /// **'Вижу {n} записей в твоём дневнике'**
  String aiAnalyzes(Object n);

  /// No description provided for @aiDailyLimitReached.
  ///
  /// In ru, this message translates to:
  /// **'Достигнут дневной лимит сообщений'**
  String get aiDailyLimitReached;

  /// No description provided for @aiError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка ИИ'**
  String get aiError;

  /// No description provided for @aiEntryCreated.
  ///
  /// In ru, this message translates to:
  /// **'✅ Запись создана'**
  String get aiEntryCreated;

  /// No description provided for @aiEntryUpdated.
  ///
  /// In ru, this message translates to:
  /// **'✅ Запись обновлена'**
  String get aiEntryUpdated;

  /// No description provided for @aiCommandError.
  ///
  /// In ru, this message translates to:
  /// **'⚠ Не удалось выполнить команду'**
  String get aiCommandError;

  /// No description provided for @aiSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-ассистент'**
  String get aiSettingsTitle;

  /// No description provided for @aiSettingsHint.
  ///
  /// In ru, this message translates to:
  /// **'Умный чат по твоим записям (долгое нажатие на «+»)'**
  String get aiSettingsHint;

  /// No description provided for @aiProvider.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер'**
  String get aiProvider;

  /// No description provided for @aiFree.
  ///
  /// In ru, this message translates to:
  /// **'бесплатно, без ключа'**
  String get aiFree;

  /// No description provided for @aiKey.
  ///
  /// In ru, this message translates to:
  /// **'API-ключ'**
  String get aiKey;

  /// No description provided for @aiKeyEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Не задан'**
  String get aiKeyEmpty;

  /// No description provided for @aiDailyLimit.
  ///
  /// In ru, this message translates to:
  /// **'Дневной лимит'**
  String get aiDailyLimit;

  /// No description provided for @aiLimitPerDay.
  ///
  /// In ru, this message translates to:
  /// **'сообщений в день'**
  String get aiLimitPerDay;

  /// No description provided for @aiLimitUnlimited.
  ///
  /// In ru, this message translates to:
  /// **'Без лимита'**
  String get aiLimitUnlimited;

  /// No description provided for @aiDisabled.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-ассистент выключен — включи в настройках'**
  String get aiDisabled;

  /// No description provided for @minimize.
  ///
  /// In ru, this message translates to:
  /// **'Свернуть'**
  String get minimize;

  /// No description provided for @aiOnline.
  ///
  /// In ru, this message translates to:
  /// **'онлайн'**
  String get aiOnline;

  /// No description provided for @aiOnVacation.
  ///
  /// In ru, this message translates to:
  /// **'ИИ сейчас на курорте ☀️ — попробуй чуть позже'**
  String get aiOnVacation;

  /// No description provided for @aiAdaFallback.
  ///
  /// In ru, this message translates to:
  /// **'ADA временно недоступна (модель не развёрнута) — переключил на бесплатный канал'**
  String get aiAdaFallback;

  /// No description provided for @aiAdaNotDeployed.
  ///
  /// In ru, this message translates to:
  /// **'Модель ADA ещё не развёрнута на HuggingFace — включи Inference Endpoint в настройках модели (нужен Pro), или используй Free'**
  String get aiAdaNotDeployed;

  /// No description provided for @aiClearChat.
  ///
  /// In ru, this message translates to:
  /// **'Очистить чат'**
  String get aiClearChat;

  /// No description provided for @aiChatFull.
  ///
  /// In ru, this message translates to:
  /// **'Чат заполнен (1000 сообщений) — очисти его, чтобы продолжить'**
  String get aiChatFull;

  /// No description provided for @aiAdaLimitReached.
  ///
  /// In ru, this message translates to:
  /// **'Дневной лимит ADA (100) исчерпан — переключаю на бесплатный канал'**
  String get aiAdaLimitReached;

  /// No description provided for @aiRemaining.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня осталось {n} сообщений'**
  String aiRemaining(Object n);

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @autoExportTitle.
  ///
  /// In ru, this message translates to:
  /// **'Автоэкспорт'**
  String get autoExportTitle;

  /// No description provided for @autoExportHint.
  ///
  /// In ru, this message translates to:
  /// **'Ежечасовая копия в /Download'**
  String get autoExportHint;

  /// No description provided for @autoExportEnabled.
  ///
  /// In ru, this message translates to:
  /// **'Автоэкспорт включён'**
  String get autoExportEnabled;

  /// No description provided for @autoExportDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Автоэкспорт выключен'**
  String get autoExportDisabled;

  /// No description provided for @updateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Обновление Ataraxy'**
  String get updateTitle;

  /// No description provided for @updateHint.
  ///
  /// In ru, this message translates to:
  /// **'Проверить GitHub Releases и установить новую версию'**
  String get updateHint;

  /// No description provided for @updateChecking.
  ///
  /// In ru, this message translates to:
  /// **'Проверяем GitHub Releases…'**
  String get updateChecking;

  /// No description provided for @updateFound.
  ///
  /// In ru, this message translates to:
  /// **'Доступна версия'**
  String get updateFound;

  /// No description provided for @updateDownloading.
  ///
  /// In ru, this message translates to:
  /// **'Скачиваем обновление'**
  String get updateDownloading;

  /// No description provided for @updateCurrent.
  ///
  /// In ru, this message translates to:
  /// **'У вас установлена последняя версия'**
  String get updateCurrent;

  /// No description provided for @updatePermission.
  ///
  /// In ru, this message translates to:
  /// **'Разрешите установку приложений для Ataraxy и нажмите ещё раз'**
  String get updatePermission;

  /// No description provided for @updateInstalling.
  ///
  /// In ru, this message translates to:
  /// **'Открылся установщик Android — подтвердите обновление'**
  String get updateInstalling;

  /// No description provided for @updateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить или установить обновление'**
  String get updateFailed;

  /// No description provided for @cloudBackupTitle.
  ///
  /// In ru, this message translates to:
  /// **'Бэкап и восстановление'**
  String get cloudBackupTitle;

  /// No description provided for @shareBackup.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться бэкапом'**
  String get shareBackup;

  /// No description provided for @shareBackupHint.
  ///
  /// In ru, this message translates to:
  /// **'Отправить JSON-файл в Google Диск, Telegram, Dropbox или куда угодно'**
  String get shareBackupHint;

  /// No description provided for @comingSoon.
  ///
  /// In ru, this message translates to:
  /// **'Скоро'**
  String get comingSoon;

  /// No description provided for @welcomeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добро пожаловать в Ataraxy'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройте приложение для идеального опыта записи снов'**
  String get welcomeSubtitle;

  /// No description provided for @notifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notifications;

  /// No description provided for @notificationsDescription.
  ///
  /// In ru, this message translates to:
  /// **'Получать уведомления о новых функциях'**
  String get notificationsDescription;

  /// No description provided for @dailyReminder.
  ///
  /// In ru, this message translates to:
  /// **'Ежедневное напоминание'**
  String get dailyReminder;

  /// No description provided for @dailyReminderDescription.
  ///
  /// In ru, this message translates to:
  /// **'Напоминать записывать сны каждый день'**
  String get dailyReminderDescription;

  /// No description provided for @security.
  ///
  /// In ru, this message translates to:
  /// **'Безопасность'**
  String get security;

  /// No description provided for @securityDescription.
  ///
  /// In ru, this message translates to:
  /// **'Защитить приложение PIN-кодом'**
  String get securityDescription;

  /// No description provided for @dontShowAgain.
  ///
  /// In ru, this message translates to:
  /// **'Больше не показывать'**
  String get dontShowAgain;

  /// No description provided for @startUsing.
  ///
  /// In ru, this message translates to:
  /// **'Начать использовать'**
  String get startUsing;

  /// No description provided for @enableNotificationsFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала включите уведомления'**
  String get enableNotificationsFirst;

  /// No description provided for @setup.
  ///
  /// In ru, this message translates to:
  /// **'Настроить'**
  String get setup;

  /// No description provided for @resetSettings.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить настройки'**
  String get resetSettings;

  /// No description provided for @resetSettingsConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены что хотите сбросить все настройки?'**
  String get resetSettingsConfirm;

  /// No description provided for @reset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get reset;

  /// No description provided for @settingsReset.
  ///
  /// In ru, this message translates to:
  /// **'Настройки сброшены'**
  String get settingsReset;

  /// No description provided for @errorResettingSettings.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сброса настроек'**
  String get errorResettingSettings;

  /// No description provided for @favoriteActivities.
  ///
  /// In ru, this message translates to:
  /// **'Любимые дела'**
  String get favoriteActivities;

  /// No description provided for @favoriteActivity.
  ///
  /// In ru, this message translates to:
  /// **'Любимое дело'**
  String get favoriteActivity;

  /// No description provided for @favoriteActivityBannerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Любимое дело'**
  String get favoriteActivityBannerTitle;

  /// No description provided for @favoriteActivityBannerSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'То, что наполняет день смыслом'**
  String get favoriteActivityBannerSubtitle;

  /// No description provided for @favoriteActivityHint.
  ///
  /// In ru, this message translates to:
  /// **'Что вы любите делать?'**
  String get favoriteActivityHint;

  /// No description provided for @favoriteActivityReading.
  ///
  /// In ru, this message translates to:
  /// **'Режим чтения'**
  String get favoriteActivityReading;

  /// No description provided for @favoriteActivityEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет любимых дел'**
  String get favoriteActivityEmpty;

  /// No description provided for @favoriteActivityEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте то, что вас вдохновляет'**
  String get favoriteActivityEmptyHint;

  /// No description provided for @favoriteActivityAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить дело'**
  String get favoriteActivityAdd;

  /// No description provided for @favoriteActivityEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get favoriteActivityEdit;

  /// No description provided for @favoriteActivityDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get favoriteActivityDelete;

  /// No description provided for @favoriteActivityPin.
  ///
  /// In ru, this message translates to:
  /// **'Закрепить'**
  String get favoriteActivityPin;

  /// No description provided for @favoriteActivityUnpin.
  ///
  /// In ru, this message translates to:
  /// **'Открепить'**
  String get favoriteActivityUnpin;

  /// No description provided for @favoriteActivityHoldDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удерживайте для удаления'**
  String get favoriteActivityHoldDelete;

  /// No description provided for @favoriteActivityLimit.
  ///
  /// In ru, this message translates to:
  /// **'символов'**
  String get favoriteActivityLimit;

  /// No description provided for @closeSearch.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть поиск'**
  String get closeSearch;

  /// No description provided for @totalEntries.
  ///
  /// In ru, this message translates to:
  /// **'Всего записей'**
  String get totalEntries;

  /// No description provided for @sortManual.
  ///
  /// In ru, this message translates to:
  /// **'Вручную'**
  String get sortManual;

  /// No description provided for @favoritesBannerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Избранное'**
  String get favoritesBannerTitle;

  /// No description provided for @favoritesBannerSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Фото, видео, файлы и заметки'**
  String get favoritesBannerSubtitle;

  /// No description provided for @favoritesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Избранное'**
  String get favoritesTitle;

  /// No description provided for @fileNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Файл не найден'**
  String get fileNotFound;

  /// No description provided for @attachFile.
  ///
  /// In ru, this message translates to:
  /// **'Прикрепить файл'**
  String get attachFile;

  /// No description provided for @writeToFavorites.
  ///
  /// In ru, this message translates to:
  /// **'Написать в избранное…'**
  String get writeToFavorites;

  /// No description provided for @saveText.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить текст'**
  String get saveText;

  /// No description provided for @imageCropped.
  ///
  /// In ru, this message translates to:
  /// **'Изображение обрезано'**
  String get imageCropped;

  /// No description provided for @crop.
  ///
  /// In ru, this message translates to:
  /// **'Обрезка'**
  String get crop;

  /// No description provided for @apply.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get apply;

  /// No description provided for @cropHint.
  ///
  /// In ru, this message translates to:
  /// **'Проведите для выбора области обрезки'**
  String get cropHint;

  /// No description provided for @cropTooSmall.
  ///
  /// In ru, this message translates to:
  /// **'Область слишком мала'**
  String get cropTooSmall;

  /// No description provided for @editFile.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать файл'**
  String get editFile;

  /// No description provided for @editTextTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать текст'**
  String get editTextTitle;

  /// No description provided for @nameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get nameLabel;

  /// No description provided for @editTextHint.
  ///
  /// In ru, this message translates to:
  /// **'Измените текст…'**
  String get editTextHint;

  /// No description provided for @patchNotes.
  ///
  /// In ru, this message translates to:
  /// **'Патч-ноуты'**
  String get patchNotes;

  /// No description provided for @whatsLeft.
  ///
  /// In ru, this message translates to:
  /// **'Что осталось доработать'**
  String get whatsLeft;

  /// No description provided for @remindersTodo.
  ///
  /// In ru, this message translates to:
  /// **'Напоминания'**
  String get remindersTodo;

  /// No description provided for @autosaveTodo.
  ///
  /// In ru, this message translates to:
  /// **'Автосохранения'**
  String get autosaveTodo;

  /// No description provided for @favoritesTodo.
  ///
  /// In ru, this message translates to:
  /// **'Избранное'**
  String get favoritesTodo;

  /// No description provided for @steqtoqTag.
  ///
  /// In ru, this message translates to:
  /// **'лучше CapCut'**
  String get steqtoqTag;

  /// No description provided for @versionCurrent.
  ///
  /// In ru, this message translates to:
  /// **'текущая'**
  String get versionCurrent;

  /// No description provided for @pnPinnedFix.
  ///
  /// In ru, this message translates to:
  /// **'Закрепление сообщений в избранном теперь не сбивается'**
  String get pnPinnedFix;

  /// No description provided for @pnBlurVideo.
  ///
  /// In ru, this message translates to:
  /// **'Кнопка размытия теперь работает и на видео'**
  String get pnBlurVideo;

  /// No description provided for @pnNotesTab.
  ///
  /// In ru, this message translates to:
  /// **'Заметки больше не показываются в общем списке «Всё»'**
  String get pnNotesTab;

  /// No description provided for @pnExport.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт/импорт: заметки и закрепленные сообщения сохраняются'**
  String get pnExport;

  /// No description provided for @pnLocales.
  ///
  /// In ru, this message translates to:
  /// **'Полная локализация английского и французского'**
  String get pnLocales;

  /// No description provided for @pnFavorites.
  ///
  /// In ru, this message translates to:
  /// **'Избранное: фото, видео, файлы и заметки в одном месте'**
  String get pnFavorites;

  /// No description provided for @pnHeartbeatPlayer.
  ///
  /// In ru, this message translates to:
  /// **'Пульсирующая шкала времени в видеоплеере'**
  String get pnHeartbeatPlayer;

  /// No description provided for @pnPatchNotesSection.
  ///
  /// In ru, this message translates to:
  /// **'Раздел «Патч-ноуты» прямо в «О приложении»'**
  String get pnPatchNotesSection;

  /// No description provided for @pn13Web.
  ///
  /// In ru, this message translates to:
  /// **'Веб-версия: аватарка в сплеше и favicon приложения'**
  String get pn13Web;

  /// No description provided for @pn13Anim.
  ///
  /// In ru, this message translates to:
  /// **'Плавные переходы: сплеш, темы, языки, вкладки и типы записей'**
  String get pn13Anim;

  /// No description provided for @pn13Smooth.
  ///
  /// In ru, this message translates to:
  /// **'Плавное обновление ленты и карточки записей с анимированной обводкой'**
  String get pn13Smooth;

  /// No description provided for @pn13Limits.
  ///
  /// In ru, this message translates to:
  /// **'Лимиты ввода: теги (3 шт., 10 символов), dream sign (10), вода (2), напоминание (50)'**
  String get pn13Limits;

  /// No description provided for @pn13Card.
  ///
  /// In ru, this message translates to:
  /// **'Кнопка «Обновить» теперь действительно обновляет записи'**
  String get pn13Card;

  /// No description provided for @pn131Save.
  ///
  /// In ru, this message translates to:
  /// **'Записи больше не теряются: сохранение при любом выходе и при сворачивании'**
  String get pn131Save;

  /// No description provided for @pn131Meta.
  ///
  /// In ru, this message translates to:
  /// **'Закрепление, метки сна, люидность и таблетки теперь сохраняются сразу'**
  String get pn131Meta;

  /// No description provided for @pn131Export.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт: системный диалог «Куда сохранить» вместо доступа к файлам'**
  String get pn131Export;

  /// No description provided for @pn131Smooth.
  ///
  /// In ru, this message translates to:
  /// **'Плавность: лента не перестраивается при сворачивании пилюль, единый переход между экранами'**
  String get pn131Smooth;

  /// No description provided for @pn132Words.
  ///
  /// In ru, this message translates to:
  /// **'Потеря слов из ленты: перетаскивание и закрепление больше не перезаписывают текст старым снимком'**
  String get pn132Words;

  /// No description provided for @pn132Order.
  ///
  /// In ru, this message translates to:
  /// **'Ручной порядок записей сохраняется между запусками'**
  String get pn132Order;

  /// No description provided for @pn132Editor.
  ///
  /// In ru, this message translates to:
  /// **'Редактор: сбой сохранения больше не помечает текст как записанный — слова пишутся заново'**
  String get pn132Editor;

  /// No description provided for @pn132Spots.
  ///
  /// In ru, this message translates to:
  /// **'Цветные пятна под таблетками разделов: теперь читаемы и в тёмной, и в светлой теме'**
  String get pn132Spots;

  /// No description provided for @pn133Repeat.
  ///
  /// In ru, this message translates to:
  /// **'Потеря слов при повторном открытии: карточка больше не передаёт редактору старый снимок записи'**
  String get pn133Repeat;

  /// No description provided for @pn133Spots.
  ///
  /// In ru, this message translates to:
  /// **'Пятна разделов стали крупнее и насыщеннее: закрывают таблетку целиком, а не точку в центре'**
  String get pn133Spots;

  /// No description provided for @importSummary.
  ///
  /// In ru, this message translates to:
  /// **'Импорт завершён'**
  String get importSummary;

  /// No description provided for @importSummaryLine.
  ///
  /// In ru, this message translates to:
  /// **'Записей: {entries} · Избранное: {favorites} · Любимых дел: {activities}'**
  String importSummaryLine(Object activities, Object entries, Object favorites);

  /// No description provided for @importMediaMissing.
  ///
  /// In ru, this message translates to:
  /// **'{n} файл(ов) из «Избранного» не найдено на этом устройстве — откройте Избранное и прикрепите заново'**
  String importMediaMissing(Object n);

  /// No description provided for @importActivitiesTrimmed.
  ///
  /// In ru, this message translates to:
  /// **'{n} любимых дел обрезано (макс. 5)'**
  String importActivitiesTrimmed(Object n);

  /// No description provided for @importItemsSkipped.
  ///
  /// In ru, this message translates to:
  /// **'{n} повреждённых элементов пропущено'**
  String importItemsSkipped(Object n);

  /// No description provided for @supportButton.
  ///
  /// In ru, this message translates to:
  /// **'Поддержать'**
  String get supportButton;

  /// No description provided for @supportHint.
  ///
  /// In ru, this message translates to:
  /// **'Помочь развитию приложения'**
  String get supportHint;

  /// No description provided for @supportThanks.
  ///
  /// In ru, this message translates to:
  /// **'Спасибо за поддержку! 💖'**
  String get supportThanks;

  /// No description provided for @favoriteActivityLimitReached.
  ///
  /// In ru, this message translates to:
  /// **'Можно добавить не более 5 любимых дел'**
  String get favoriteActivityLimitReached;

  /// No description provided for @favoriteActivityAdded.
  ///
  /// In ru, this message translates to:
  /// **'Дело добавлено'**
  String get favoriteActivityAdded;

  /// No description provided for @favoriteActivityDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Дело удалено'**
  String get favoriteActivityDeleted;

  /// No description provided for @permissions.
  ///
  /// In ru, this message translates to:
  /// **'Разрешения'**
  String get permissions;

  /// No description provided for @checkPermissionsAction.
  ///
  /// In ru, this message translates to:
  /// **'Проверить разрешения'**
  String get checkPermissionsAction;

  /// No description provided for @permissionsOk.
  ///
  /// In ru, this message translates to:
  /// **'Разрешения OK'**
  String get permissionsOk;

  /// No description provided for @permissionsCheckFailed.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте разрешения'**
  String get permissionsCheckFailed;

  /// No description provided for @miuiHint.
  ///
  /// In ru, this message translates to:
  /// **'MIUI: включите Автозапуск и «Без ограничений» в Батарее — иначе система остановит фоновые уведомления.'**
  String get miuiHint;

  /// No description provided for @webHint.
  ///
  /// In ru, this message translates to:
  /// **'Уведомление сработает, пока вкладка открыта.'**
  String get webHint;

  /// No description provided for @sign_flying.
  ///
  /// In ru, this message translates to:
  /// **'Полёт'**
  String get sign_flying;

  /// No description provided for @sign_falling.
  ///
  /// In ru, this message translates to:
  /// **'Падение'**
  String get sign_falling;

  /// No description provided for @sign_chased.
  ///
  /// In ru, this message translates to:
  /// **'Погоня'**
  String get sign_chased;

  /// No description provided for @sign_teeth.
  ///
  /// In ru, this message translates to:
  /// **'Зубы'**
  String get sign_teeth;

  /// No description provided for @sign_water.
  ///
  /// In ru, this message translates to:
  /// **'Вода'**
  String get sign_water;

  /// No description provided for @sign_school.
  ///
  /// In ru, this message translates to:
  /// **'Школа'**
  String get sign_school;

  /// No description provided for @sign_paralysis.
  ///
  /// In ru, this message translates to:
  /// **'Паралич'**
  String get sign_paralysis;

  /// No description provided for @sign_lost.
  ///
  /// In ru, this message translates to:
  /// **'Потеря'**
  String get sign_lost;

  /// No description provided for @sign_animal.
  ///
  /// In ru, this message translates to:
  /// **'Животные'**
  String get sign_animal;

  /// No description provided for @sign_vehicle.
  ///
  /// In ru, this message translates to:
  /// **'Транспорт'**
  String get sign_vehicle;

  /// No description provided for @sign_celebrity.
  ///
  /// In ru, this message translates to:
  /// **'Знаменитости'**
  String get sign_celebrity;

  /// No description provided for @sign_naked.
  ///
  /// In ru, this message translates to:
  /// **'Нагота'**
  String get sign_naked;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
