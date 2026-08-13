import 'package:flutter/material.dart';

class L {
  static const Map<String, Map<String, String>> _strings = {
    'appTitle': {
      'ru': 'Мой дневник',
      'en': 'My Journal',
      'fr': 'Mon Journal',
    },
    'tabDreams': {'ru': 'Сны', 'en': 'Dreams', 'fr': 'Rêves'},
    'tabLife': {'ru': 'Жизнь', 'en': 'Life', 'fr': 'Vie'},
    'tabAll': {'ru': 'Всё', 'en': 'All', 'fr': 'Tout'},
    'tabNotes': {'ru': 'Заметки', 'en': 'Notes', 'fr': 'Notes'},
    'fabNew': {'ru': 'Запись', 'en': 'New', 'fr': 'Nouveau'},
    'refresh': {'ru': 'Обновить', 'en': 'Refresh', 'fr': 'Actualiser'},
    'entriesUpdated': {
      'ru': 'Записи обновлены',
      'en': 'Entries refreshed',
      'fr': 'Entrées actualisées',
    },
    'emptyDream': {
      'ru': 'Записей о снах пока нет',
      'en': 'No dream entries yet',
      'fr': 'Aucune entrée de rêve pour l\'instant',
    },
    'emptyLife': {
      'ru': 'Записей о жизни пока нет',
      'en': 'No life entries yet',
      'fr': 'Aucune entrée de vie pour l\'instant',
    },
    'emptyNotes': {
      'ru': 'Заметок пока нет',
      'en': 'No notes yet',
      'fr': 'Aucune note pour l\'instant',
    },
    'emptyAll': {
      'ru': 'Записей пока нет',
      'en': 'No entries yet',
      'fr': 'Aucune entrée pour l\'instant',
    },
    'emptyTulpa': {
      'ru': 'Записей о тульпах пока нет',
      'en': 'No tulpa entries yet',
      'fr': 'Aucune entrée de tulpe pour l\'instant',
    },
    'entryNew': {
      'ru': 'Новая запись',
      'en': 'New entry',
      'fr': 'Nouvelle entrée',
    },
    'entryEdit': {
      'ru': 'Редактировать',
      'en': 'Edit',
      'fr': 'Modifier',
    },
    'save': {'ru': 'Сохранить', 'en': 'Save', 'fr': 'Enregistrer'},
    'saveFailed': {
      'ru': 'Не удалось сохранить — проверьте место на устройстве',
      'en': 'Could not save — check your device storage',
      'fr': 'Échec de l\'enregistrement — vérifiez l\'espace de stockage',
    },
    'typeDream': {'ru': 'Сон', 'en': 'Dream', 'fr': 'Rêve'},
    'typeLife': {'ru': 'Жизнь', 'en': 'Life', 'fr': 'Vie'},
    'typeGeneral': {'ru': 'Заметка', 'en': 'Note', 'fr': 'Note'},
    'segDream': {'ru': 'Сон', 'en': 'Dream', 'fr': 'Rêve'},
    'segLife': {'ru': 'Жизнь', 'en': 'Life', 'fr': 'Vie'},
    'segGeneral': {'ru': 'Заметка', 'en': 'Note', 'fr': 'Note'},
    'titleHint': {'ru': 'Заголовок', 'en': 'Title', 'fr': 'Titre'},
    'contentHint': {
      'ru': 'Опишите свои мысли, сон или событие...',
      'en': 'Describe your thoughts, dream or event...',
      'fr': 'Décrivez vos pensées, rêve ou événement...',
    },
    'editTab': {'ru': 'Редактор', 'en': 'Edit', 'fr': 'Éditeur'},
    'previewTab': {'ru': 'Превью', 'en': 'Preview', 'fr': 'Aperçu'},
    'previewEmpty': {
      'ru': 'Текст пока пуст — начните писать, и превью появится здесь',
      'en': 'Nothing to preview yet — start typing and it will show here',
      'fr': "Rien à prévisualiser — écrivez et l'aperçu apparaîtra ici",
    },
    'tapToExpandNotes': {
      'ru': 'Нажмите, чтобы раскрыть заметки',
      'en': 'Tap to expand notes',
      'fr': 'Appuyez pour développer les notes',
    },
    'mood': {'ru': 'Настроение', 'en': 'Mood', 'fr': 'Humeur'},
    'tags': {'ru': 'Теги', 'en': 'Tags', 'fr': 'Tags'},
    'addTag': {'ru': 'Добавить тег', 'en': 'Add tag', 'fr': 'Ajouter un tag'},
    'tagsLimit': {
      'ru': 'Максимум 3 тега',
      'en': 'Up to 3 tags',
      'fr': '3 tags maximum',
    },
    'tagTooLong': {
      'ru': 'Тег не длиннее 10 символов',
      'en': 'Tag is limited to 10 characters',
      'fr': 'Tag limité à 10 caractères',
    },
    'withoutTitle': {
      'ru': 'Без названия',
      'en': 'Untitled',
      'fr': 'Sans titre',
    },
    'noText': {'ru': 'Нет текста.', 'en': 'No text.', 'fr': 'Aucun texte.'},
    'deleteTitle': {
      'ru': 'Удалить запись?',
      'en': 'Delete entry?',
      'fr': 'Supprimer l\'entrée ?',
    },
    'deleteContent': {
      'ru': 'Это действие нельзя отменить.',
      'en': 'This action cannot be undone.',
      'fr': 'Cette action est irréversible.',
    },
    'cancel': {'ru': 'Отмена', 'en': 'Cancel', 'fr': 'Annuler'},
    'cut': {'ru': 'Вырезать', 'en': 'Cut', 'fr': 'Couper'},
    'copy': {'ru': 'Копировать', 'en': 'Copy', 'fr': 'Copier'},
    'paste': {'ru': 'Вставить', 'en': 'Paste', 'fr': 'Coller'},
    'share': {'ru': 'Поделиться', 'en': 'Share', 'fr': 'Partager'},
    'clear': {'ru': 'Очистить', 'en': 'Clear', 'fr': 'Effacer'},
    'delete': {'ru': 'Удалить', 'en': 'Delete', 'fr': 'Supprimer'},
    'entryDeleted': {
      'ru': 'Запись удалена',
      'en': 'Entry deleted',
      'fr': 'Entrée supprimée',
    },
    'restore': {'ru': 'Вернуть', 'en': 'Restore', 'fr': 'Restaurer'},
    'streak': {
      'ru': 'Серия дней',
      'en': 'Day streak',
      'fr': 'Série de jours',
    },
    'streakDays': {
      'ru': 'дн.',
      'en': 'd.',
      'fr': 'j.',
    },
    'streakHint': {
      'ru': 'Дни подряд, когда ты записываешь в дневник. Пропустишь день — серия начнётся заново. Записывай каждый день, чтобы серия росла!',
      'en': 'Days in a row you wrote in your journal. Miss a day and the streak resets. Write every day to keep it growing!',
      'fr': 'Jours consécutifs où tu as écrit dans ton journal. Rate un jour et la série recommence. Écris chaque jour pour la faire grandir !',
    },
    'rewardChat': {
      'ru': '🔥 Награда дня: +{n} ✨',
      'en': '🔥 Daily reward: +{n} ✨',
      'fr': '🔥 Récompense du jour : +{n} ✨',
    },
    'rewardTask': {
      'ru': '✅ Задача выполнена: +{n} ✨',
      'en': '✅ Task done: +{n} ✨',
      'fr': '✅ Tâche accomplie : +{n} ✨',
    },
    'rewardStreak': {
      'ru': 'Серия: {n} дн.',
      'en': 'Streak: {n} d.',
      'fr': 'Série : {n} j.',
    },
    'settings': {'ru': 'Настройки', 'en': 'Settings', 'fr': 'Paramètres'},
    'theme': {'ru': 'Тема', 'en': 'Theme', 'fr': 'Thème'},
    'language': {'ru': 'Язык', 'en': 'Language', 'fr': 'Langue'},

    'pin': {'ru': 'PIN-код', 'en': 'PIN code', 'fr': 'Code PIN'},
    'setPin': {'ru': 'Установить PIN', 'en': 'Set PIN', 'fr': 'Définir le code'},
    'changePin': {
      'ru': 'Изменить PIN',
      'en': 'Change PIN',
      'fr': 'Changer le code',
    },
    'removePin': {'ru': 'Убрать PIN', 'en': 'Remove PIN', 'fr': 'Retirer le code'},
    'removePinConfirm': {
      'ru': 'Вы уверены? PIN-код будет удалён.',
      'en': 'Are you sure? PIN will be removed.',
      'fr': 'Êtes-vous sûr ? Le code PIN sera supprimé.',
    },
    'enterPin': {'ru': 'Введите PIN', 'en': 'Enter PIN', 'fr': 'Entrez le code'},
    'confirmPin': {
      'ru': 'Подтвердите PIN',
      'en': 'Confirm PIN',
      'fr': 'Confirmez le code',
    },
    'unlock': {'ru': 'Разблокировать', 'en': 'Unlock', 'fr': 'Déverrouiller'},
    'pinMismatch': {
      'ru': 'PIN не совпадает',
      'en': 'PIN does not match',
      'fr': 'Le code ne correspond pas',
    },
    'pinWrong': {
      'ru': 'Неверный PIN',
      'en': 'Wrong PIN',
      'fr': 'Code incorrect',
    },
    'pinSetDone': {
      'ru': 'PIN установлен',
      'en': 'PIN set',
      'fr': 'Code défini',
    },
    'pinRemoved': {
      'ru': 'PIN удалён',
      'en': 'PIN removed',
      'fr': 'Code retiré',
    },
    'dreamKind': {
      'ru': 'Тип сна',
      'en': 'Dream type',
      'fr': 'Type de rêve',
    },
    'dreamNormal': {
      'ru': 'Обычный',
      'en': 'Normal',
      'fr': 'Normal',
    },
    'dreamLucid': {
      'ru': 'Осознанный',
      'en': 'Lucid',
      'fr': 'Lucide',
    },
    'lucidBadge': {
      'ru': 'Осознанный сон',
      'en': 'Lucid dream',
      'fr': 'Rêve lucide',
    },
    'normalBadge': {
      'ru': 'Обычный сон',
      'en': 'Normal dream',
      'fr': 'Rêve normal',
    },
    'search': {'ru': 'Поиск', 'en': 'Search', 'fr': 'Recherche'},
    'searchHint': {
      'ru': 'Поиск по записям...',
      'en': 'Search entries...',
      'fr': 'Rechercher...',
    },
    'noResults': {
      'ru': 'Ничего не найдено',
      'en': 'Nothing found',
      'fr': 'Aucun résultat',
    },
    'data': {'ru': 'Данные', 'en': 'Data', 'fr': 'Données'},
    'export': {'ru': 'Экспорт', 'en': 'Export', 'fr': 'Exporter'},
    'import': {'ru': 'Импорт', 'en': 'Import', 'fr': 'Importer'},
    'protectDeletedTitle': {
      'ru': 'Не возвращать удалённое при импорте',
      'en': "Don't restore deleted on import",
      'fr': "Ne pas restaurer les éléments supprimés à l'import",
    },
    'protectDeletedHint': {
      'ru': 'Удалённые записи не появятся снова после импорта старого бэкапа',
      'en': 'Deleted entries stay deleted even after importing an old backup',
      'fr': "Les entrées supprimées restent supprimées après l'import d'une ancienne sauvegarde",
    },
    'exportDone': {
      'ru': 'Записи экспортированы',
      'en': 'Entries exported',
      'fr': 'Entrées exportées',
    },
    'importDone': {
      'ru': 'Записи импортированы',
      'en': 'Entries imported',
      'fr': 'Entrées importées',
    },
    'importError': {
      'ru': 'Не удалось импортировать файл',
      'en': 'Could not import file',
      'fr': 'Import impossible',
    },
    'clearData': {'ru': 'Стереть данные', 'en': 'Clear Data', 'fr': 'Effacer les données'},
    'confirmDelete': {'ru': 'Подтвердите удаление', 'en': 'Confirm Deletion', 'fr': 'Confirmer la suppression'},
    'confirmDeleteData': {
      'ru': 'Это удалит все ваши записи и настройки. Вы уверены?',
      'en': 'This will delete all your entries and settings. Are you sure?',
      'fr': 'Cela supprimera toutes vos entrées et paramètres. Êtes-vous sûr ?',
    },
    'deleteData': {'ru': 'Удалить', 'en': 'Delete', 'fr': 'Supprimer'},
    'experimental': {
      'ru': 'Экспериментальные',
      'en': 'Experimental',
      'fr': 'Expérimental',
    },
    'tulpa': {
      'ru': 'Тульпа (записи о тульпах)',
      'en': 'Tulpa (entries about tulpas)',
      'fr': 'Tulpe (entrées sur les tulpas)',
    },
    'tulpaHint': {
      'ru': 'Добавить тип записи «Тульпа» для заметок о своих тульпах',
      'en': 'Adds a "Tulpa" entry type for notes about your tulpas',
      'fr': 'Ajoute un type « Tulpe » pour vos notes sur vos tulpas',
    },
    'tabTulpa': {'ru': 'Тульпы', 'en': 'Tulpas', 'fr': 'Tulpes'},
    'segTulpa': {'ru': 'Тульпа', 'en': 'Tulpa', 'fr': 'Tulpe'},
    'typeTulpa': {'ru': 'Тульпа', 'en': 'Tulpa', 'fr': 'Tulpe'},
    'about': {'ru': 'О приложении', 'en': 'About', 'fr': 'À propos'},
    'aboutDesc': {
      'ru': 'Дневник снов, жизни и тульп. Свободное ПО с открытым исходным кодом.',
      'en': 'A journal for dreams, life and tulpas. Free and open-source software.',
      'fr': 'Journal de rêves, de vie et de tulpas. Logiciel libre et open-source.',
    },
    'version': {'ru': 'Версия', 'en': 'Version', 'fr': 'Version'},
    'enterCurrentPin': {
      'ru': 'Введите текущий PIN',
      'en': 'Enter current PIN',
      'fr': 'Entrez le code actuel',
    },
    'guideDreamTitle': {
      'ru': 'Мотивация и обучение',
      'en': 'Motivation & learning',
      'fr': 'Motivation et apprentissage',
    },
    'guideTulpaTitle': {
      'ru': 'Тульпа: бережный диалог',
      'en': 'Tulpa: gentle dialogue',
      'fr': 'Tulpa : dialogue doux',
    },
    'guideToday': {
      'ru': 'Сегодня',
      'en': 'Today',
      'fr': "Aujourd'hui",
    },
    'guidePracticeOfDay': {
      'ru': 'Практика дня: {title}',
      'en': "Today's practice: {title}",
      'fr': 'Pratique du jour : {title}',
    },
    'guideMarkDone': {
      'ru': 'Отметить выполнение',
      'en': 'Mark as done',
      'fr': 'Marquer comme fait',
    },
    'guideDone': {
      'ru': 'Практика выполнена',
      'en': 'Practice completed',
      'fr': 'Pratique terminée',
    },
    'guideHowItWorks': {
      'ru': 'Как это работает',
      'en': 'How it works',
      'fr': 'Comment ça marche',
    },
    'guideWhyUseful': {
      'ru': 'Почему это может быть полезно',
      'en': 'Why this can be useful',
      'fr': 'Pourquoi cela peut être utile',
    },
    'guideDreamSubtitle': {
      'ru': 'Небольшой шаг к осознанному сну — каждый день',
      'en': 'A small step toward lucid sleep — every day',
      'fr': 'Un petit pas vers un sommeil lucide — chaque jour',
    },
    'guideTulpaSubtitle': {
      'ru': 'Польза, общение и забота о себе',
      'en': 'Growth, communication and self-care',
      'fr': 'Croissance, communication et soin de soi',
    },
    'madeWithLove': {
      'ru': 'Сделано с любовью',
      'en': 'Made with love',
      'fr': 'Fait avec amour',
    },
    'forcingDuration': {
      'ru': 'Длительность форсинга',
      'en': 'Forcing duration',
      'fr': 'Durée du forcing',
    },
    'forcingHint': {
      'ru': 'Укажите, сколько длился форсинг',
      'en': 'How long the forcing lasted',
      'fr': 'Combien a duré le forcing',
    },
    'statistics': {
      'ru': 'Статистика',
      'en': 'Statistics',
      'fr': 'Statistiques',
    },
    'statsTotal': {
      'ru': 'Всего записей',
      'en': 'Total entries',
      'fr': 'Entrées totales',
    },
    'statsByType': {
      'ru': 'Записи по типам',
      'en': 'Entries by type',
      'fr': 'Entrées par type',
    },
    'statsMood': {
      'ru': 'Настроение во времени',
      'en': 'Mood over time',
      'fr': 'Humeur dans le temps',
    },
    'statsCalendar': {
      'ru': 'Календарь записей',
      'en': 'Entries calendar',
      'fr': 'Calendrier des entrées',
    },
    'statsDreamSigns': {
      'ru': 'Частые dream signs',
      'en': 'Frequent dream signs',
      'fr': 'Dream signs fréquents',
    },
    'statsNoData': {
      'ru': 'Недостаточно данных',
      'en': 'Not enough data',
      'fr': 'Pas assez de données',
    },
    'editTime': {
      'ru': 'Дата и время',
      'en': 'Date and time',
      'fr': 'Date et heure',
    },
    'dreamSignsSection': {
      'ru': 'Dream signs',
      'en': 'Dream signs',
      'fr': 'Dream signs',
    },
    'addSign': {
      'ru': 'Добавить своё',
      'en': 'Add custom',
      'fr': 'Ajouter',
    },
    'month': {
      'ru': 'Месяц',
      'en': 'Month',
      'fr': 'Mois',
    },
    'category': {
      'ru': 'Категория',
      'en': 'Category',
      'fr': 'Catégorie',
    },
    'catAll': {'ru': 'Все', 'en': 'All', 'fr': 'Tout'},
    'catGood': {
      'ru': 'Хороший',
      'en': 'Good day',
      'fr': 'Bonne journée',
    },
    'catBad': {'ru': 'Плохой', 'en': 'Bad day', 'fr': 'Mauvaise journée'},
    'catRandom': {'ru': 'Случайный', 'en': 'Random', 'fr': 'Aléatoire'},
    'reminders': {
      'ru': 'Напоминания',
      'en': 'Reminders',
      'fr': 'Rappels',
    },
    'reminderTime': {
      'ru': 'Время уведомления',
      'en': 'Notification time',
      'fr': 'Heure de notification',
    },
    'reminderText': {
      'ru': 'Текст уведомления',
      'en': 'Notification text',
      'fr': 'Texte de notification',
    },
    'reminderHint': {
      'ru': 'Что напомнить (обязательно)',
      'en': 'What to remember (required)',
      'fr': 'Quoi rappeler (obligatoire)',
    },
    'reminderSet': {
      'ru': 'Напоминание установлено',
      'en': 'Reminder set',
      'fr': 'Rappel défini',
    },
    'reminderDisabled': {
      'ru': 'Напоминание отключено',
      'en': 'Reminder disabled',
      'fr': 'Rappel désactivé',
    },
    'reminderRequired': {
      'ru': 'Укажите текст уведомления',
      'en': 'Enter the notification text',
      'fr': 'Saisissez le texte',
    },
    'reminderNextFire': {
      'ru': 'Это время уже прошло сегодня — первое срабатывание завтра в {time}',
      'en': 'That time has passed today — the first reminder fires tomorrow at {time}',
      'fr': 'Cette heure est déjà passée aujourd\'hui — premier rappel demain à {time}',
    },
    'autosave': {
      'ru': 'Автосохранение',
      'en': 'Autosave',
      'fr': 'Sauvegarde auto',
    },
    'autosaveHint': {
      'ru': 'Сохранять запись каждую секунду',
      'en': 'Save entry every second',
      'fr': 'Enregistrer chaque seconde',
    },
    'expWater': {'ru': 'Вода', 'en': 'Water', 'fr': 'Eau'},
    'expFasting': {
      'ru': 'Интерва',
      'en': 'Intermittent fasting',
      'fr': 'Jeûne intermittent',
    },
    'expPomodoro': {'ru': 'Помодоро', 'en': 'Pomodoro', 'fr': 'Pomodoro'},
    'expSteps': {'ru': 'Шаги', 'en': 'Steps', 'fr': 'Pas'},
    'water': {'ru': 'Вода, л', 'en': 'Water, L', 'fr': 'Eau, L'},
    'waterHint': {
      'ru': 'Сколько литров выпили',
      'en': 'Liters drunk',
      'fr': 'Litres bus',
    },
    'waterStats': {
      'ru': 'Статистика воды',
      'en': 'Water stats',
      'fr': 'Stats deau',
    },
    'fasting': {'ru': 'Голодание', 'en': 'Fasting', 'fr': 'Jeûne'},
    'fastingFrom': {'ru': 'Начало', 'en': 'Start', 'fr': 'Début'},
    'fastingTo': {'ru': 'Конец', 'en': 'End', 'fr': 'Fin'},
    'fastingWindow': {
      'ru': 'Окно голодания',
      'en': 'Fasting window',
      'fr': 'Fenêtre de jeûne',
    },
    'pomodoro': {'ru': 'Помодоро', 'en': 'Pomodoro', 'fr': 'Pomodoro'},
    'pomodoroStart': {
      'ru': 'Начало фокуса',
      'en': 'Focus start',
      'fr': 'Début de focus',
    },
    'pomodoroEnd': {
      'ru': 'Конец фокуса',
      'en': 'Focus end',
      'fr': 'Fin de focus',
    },
    'pomodoroStartFocus': {
      'ru': 'Запустить фокус',
      'en': 'Start focus',
      'fr': 'Démarrer le focus',
    },
    'pomodoroRunning': {'ru': 'Фокус', 'en': 'Focus', 'fr': 'Focus'},
    'pomodoroDone': {
      'ru': 'Фокус завершён',
      'en': 'Focus done',
      'fr': 'Focus terminé',
    },
    'steps': {'ru': 'Шаги', 'en': 'Steps', 'fr': 'Pas'},
    'stepsToday': {
      'ru': 'Шагов сегодня',
      'en': 'Steps today',
      'fr': 'Pas aujourdhui',
    },
    'stepsNotSupported': {
      'ru': 'Шаги недоступны на этом устройстве',
      'en': 'Steps unavailable on this device',
      'fr': 'Pas indisponibles',
    },
    'voiceInput': {
      'ru': 'Голосовой ввод',
      'en': 'Voice input',
      'fr': 'Saisie vocale',
    },
    'listening': {'ru': 'Слушаю…', 'en': 'Listening…', 'fr': 'Écoute…'},
    'voiceUnavailable': {
      'ru': 'Голосовой ввод недоступен',
      'en': 'Voice input unavailable',
      'fr': 'Saisie vocale indisponible',
    },
    'pinned': {'ru': 'Закреплено', 'en': 'Pinned', 'fr': 'Épinglé'},
    'unpinned': {'ru': 'Откреплено', 'en': 'Unpinned', 'fr': 'Détaché'},
    'byWetidom': {'ru': 'BY WETIDOM', 'en': 'BY WETIDOM', 'fr': 'BY WETIDOM'},
    'launchTitle': {'ru': 'Ataraxy', 'en': 'Ataraxy', 'fr': 'Ataraxy'},
    'newReminder': {
      'ru': 'Новое напоминание',
      'en': 'New reminder',
      'fr': 'Nouveau rappel',
    },
    'themeSystem': {
      'ru': 'Системная (Material You)',
      'en': 'System (Material You)',
      'fr': 'Système (Material You)',
    },
    'themeLightPeach': {
      'ru': 'Светлая персиковая',
      'en': 'Light Peach',
      'fr': 'Pêche Clair',
    },
    'themeLightLavender': {
      'ru': 'Лавандовая',
      'en': 'Lavender',
      'fr': 'Lavande',
    },
    'themeDarkPeach': {
      'ru': 'Тёмная персиковая',
      'en': 'Dark Peach',
      'fr': 'Pêche Sombre',
    },
    'themeLightGrok': {
      'ru': 'Светлая Grok',
      'en': 'Light Grok',
      'fr': 'Grok Clair',
    },
    'favoritesAddAnyFile': {
      'ru': 'Добавить файл или фото',
      'en': 'Add file or photo',
      'fr': 'Ajouter un fichier ou une photo',
    },
    'favoritesPhotosEmpty': {
      'ru': 'Пока нет фото',
      'en': 'No photos yet',
      'fr': 'Pas encore de photos',
    },
    'favoritesPhotosEmptyHint': {
      'ru': 'Нажмите на скрепку, чтобы добавить фотографии',
      'en': 'Tap the paperclip to add photos',
      'fr': 'Appuyez sur le trombone pour ajouter des photos',
    },
    'langSystem': {
      'ru': 'Системный',
      'en': 'System',
      'fr': 'Système',
    },
    'langRussian': {
      'ru': 'Русский',
      'en': 'Russian',
      'fr': 'Russe',
    },
    'langEnglish': {
      'ru': 'English',
      'en': 'English',
      'fr': 'Anglais',
    },
    'langFrench': {
      'ru': 'Français',
      'en': 'French',
      'fr': 'Français',
    },
    'dev': {'ru': 'Dev', 'en': 'Dev', 'fr': 'Dev'},
    'devMode': {
      'ru': 'Режим разработчика',
      'en': 'Developer mode',
      'fr': 'Mode développeur',
    },
    'devPassword': {
      'ru': 'Пароль разработчика',
      'en': 'Developer password',
      'fr': 'Mot de passe développeur',
    },
    'devWrongPassword': {
      'ru': 'Неверный пароль',
      'en': 'Wrong password',
      'fr': 'Mot de passe incorrect',
    },
    'devHrtTracking': {
      'ru': 'Гормональная терапия (HRT)',
      'en': 'Hormone replacement therapy (HRT)',
      'fr': 'Thérapie hormonale substitutive (THS)',
    },
    'devTestNotification': {
      'ru': 'Тест уведомления',
      'en': 'Test notification',
      'fr': 'Notification de test',
    },
    'devScheduleDaily': {
      'ru': 'Запланировать ежедневное',
      'en': 'Schedule daily',
      'fr': 'Programmer quotidien',
    },
    'devCancelAll': {
      'ru': 'Отменить все',
      'en': 'Cancel all',
      'fr': 'Annuler tout',
    },
    'devCheckPermissions': {
      'ru': 'Проверить разрешения',
      'en': 'Check permissions',
      'fr': 'Vérifier les permissions',
    },
    'devClearAllData': {
      'ru': 'Очистить все данные',
      'en': 'Clear all data',
      'fr': 'Effacer toutes les données',
    },
    'hrtTime': {
      'ru': 'Время приёма HRT',
      'en': 'HRT medication time',
      'fr': 'Heure de prise THS',
    },
    'hrtDosage': {
      'ru': 'Дозировка HRT',
      'en': 'HRT dosage',
      'fr': 'Dosage THS',
    },
    'license': {
      'ru': 'Лицензия: MIT',
      'en': 'License: MIT',
      'fr': 'Licence: MIT',
    },
    'sortNewest': {
      'ru': 'Сначала новые',
      'en': 'Newest first',
      'fr': 'Nouveaux d\'abord',
    },
    'sortOldest': {
      'ru': 'Сначала старые',
      'en': 'Oldest first',
      'fr': 'Anciens d\'abord',
    },
    'sortAlpha': {
      'ru': 'По алфавиту',
      'en': 'Alphabetical',
      'fr': 'Alphabétique',
    },
    'githubLink': {
      'ru': 'github.com/wxstdo-boop/Ataraxy',
      'en': 'github.com/wxstdo-boop/Ataraxy',
      'fr': 'github.com/wxstdo-boop/Ataraxy',
    },
    'themeMutilated': {
      'ru': 'MUTILATED',
      'en': 'MUTILATED',
      'fr': 'MUTILATED',
    },
    'testNotification': {
      'ru': 'Тест уведомления',
      'en': 'Test notification',
      'fr': 'Notification de test',
    },
    'devScheduleDailyHint': {
      'ru': 'Запланировать тестовое напоминание через минуту',
      'en': 'Schedule a test reminder one minute from now',
      'fr': 'Planifier un rappel de test dans une minute',
    },
    'devPermissionsTitle': {
      'ru': 'Разрешения',
      'en': 'Permissions',
      'fr': 'Permissions',
    },
    'devPermissionsHint': {
      'ru': 'Проверить уведомления и точные будильники',
      'en': 'Check notification and exact alarm permissions',
      'fr': 'Vérifier les notifications et les alarmes exactes',
    },
    'devClearAllHint': {
      'ru': 'ВНИМАНИЕ: удаляет все записи и настройки',
      'en': 'WARNING: Deletes all entries and settings',
      'fr': 'ATTENTION : supprime toutes les entrées et réglages',
    },
    'devFullReset': {
      'ru': 'Полный сброс',
      'en': 'Full reset',
      'fr': 'Réinitialisation complète',
    },
    'devFullResetConfirm': {
      'ru': 'Это удалит ВСЕ записи и настройки. Вы уверены?',
      'en': 'This will delete ALL entries and settings. Are you sure?',
      'fr': 'Cela supprimera TOUTES les entrées et réglages. Êtes-vous sûr ?',
    },
    'devResetTriggered': {
      'ru': 'Сброс запущен',
      'en': 'Full reset triggered',
      'fr': 'Réinitialisation déclenchée',
    },
    'ok': {'ru': 'OK', 'en': 'OK', 'fr': 'OK'},
    'aiAssistant': {
      'ru': 'ИИ-ассистент',
      'en': 'AI assistant',
      'fr': 'Assistant IA',
    },
    'aiInputHint': {
      'ru': 'Спроси что-нибудь о своих записях…',
      'en': 'Ask about your entries…',
      'fr': 'Interrogez vos entrées…',
    },
    'aiThinking': {
      'ru': 'Думаю…',
      'en': 'Thinking…',
      'fr': 'Réflexion…',
    },
    'aiEmptyTitle': {
      'ru': 'Привет! Я твой ИИ-ассистент',
      'en': 'Hi! I\'m your AI assistant',
      'fr': 'Bonjour ! Je suis votre assistant IA',
    },
    'aiEmptyHint': {
      'ru': 'Анализирую твой дневник: сны, жизнь, тульпы. Спрашивай о паттернах, проси подвести итоги или создать запись.',
      'en': 'I analyze your journal: dreams, life, tulpas. Ask about patterns, summaries, or ask me to create an entry.',
      'fr': 'J\'analyse votre journal : rêves, vie, tulpas. Interrogez-moi sur les schémas, demandez un résumé ou une création d\'entrée.',
    },
    'aiAnalyzes': {
      'ru': 'Вижу {n} записей в твоём дневнике',
      'en': 'I can see {n} entries in your journal',
      'fr': 'Je vois {n} entrées dans votre journal',
    },
    'aiDailyLimitReached': {
      'ru': 'Достигнут дневной лимит сообщений',
      'en': 'Daily message limit reached',
      'fr': 'Limite quotidienne de messages atteinte',
    },
    'aiError': {
      'ru': 'Ошибка ИИ',
      'en': 'AI error',
      'fr': 'Erreur IA',
    },
    'aiEntryCreated': {
      'ru': '✅ Запись создана',
      'en': '✅ Entry created',
      'fr': '✅ Entrée créée',
    },
    'aiEntryUpdated': {
      'ru': '✅ Запись обновлена',
      'en': '✅ Entry updated',
      'fr': '✅ Entrée mise à jour',
    },
    'aiCommandError': {
      'ru': '⚠ Не удалось выполнить команду',
      'en': '⚠ Failed to run the command',
      'fr': '⚠ Impossible d\'exécuter la commande',
    },
    'aiSettingsTitle': {
      'ru': 'ИИ-ассистент',
      'en': 'AI assistant',
      'fr': 'Assistant IA',
    },
    'aiSettingsHint': {
      'ru': 'Умный чат по твоим записям (долгое нажатие на «+»)',
      'en': 'Smart chat about your entries (long-press “+”)',
      'fr': 'Chat intelligent sur vos entrées (appui long sur «+»)',
    },
    'aiProvider': {
      'ru': 'Провайдер',
      'en': 'Provider',
      'fr': 'Fournisseur',
    },
    'aiFree': {
      'ru': 'бесплатно, без ключа',
      'en': 'free, no key needed',
      'fr': 'gratuit, sans clé',
    },
    'aiKey': {
      'ru': 'API-ключ',
      'en': 'API key',
      'fr': 'Clé API',
    },
    'aiKeyEmpty': {
      'ru': 'Не задан',
      'en': 'Not set',
      'fr': 'Non défini',
    },
    'aiDailyLimit': {
      'ru': 'Дневной лимит',
      'en': 'Daily limit',
      'fr': 'Limite quotidienne',
    },
    'aiLimitPerDay': {
      'ru': 'сообщений в день',
      'en': 'messages per day',
      'fr': 'messages par jour',
    },
    'aiLimitUnlimited': {
      'ru': 'Без лимита',
      'en': 'Unlimited',
      'fr': 'Illimité',
    },
    'aiDisabled': {
      'ru': 'ИИ-ассистент выключен — включи в настройках',
      'en': 'AI assistant is off — enable it in Settings',
      'fr': 'Assistant IA désactivé — activez-le dans les réglages',
    },
    'minimize': {
      'ru': 'Свернуть',
      'en': 'Minimize',
      'fr': 'Réduire',
    },
    'aiOnline': {
      'ru': 'онлайн',
      'en': 'online',
      'fr': 'en ligne',
    },
    'aiOnVacation': {
      'ru': 'ИИ сейчас на курорте ☀️ — попробуй чуть позже',
      'en': 'AI is on vacation right now ☀️ — try again in a moment',
      'fr': 'L\'IA est en vacances en ce moment ☀️ — réessayez dans un instant',
    },
    'aiAdaFallback': {
      'ru': 'ADA временно недоступна (модель не развёрнута) — переключил на бесплатный канал',
      'en': 'ADA is temporarily unavailable (model not deployed) — switched to the free provider',
      'fr': 'ADA temporairement indisponible (modèle non déployé) — basculé sur le fournisseur gratuit',
    },
    'aiAdaNotDeployed': {
      'ru': 'Модель ADA ещё не развёрнута на HuggingFace — включи Inference Endpoint в настройках модели (нужен Pro), или используй Free',
      'en': 'The ADA model is not deployed on HuggingFace yet — enable an Inference Endpoint in the model settings (Pro required), or use Free',
      'fr': 'Le modèle ADA n\'est pas encore déployé sur HuggingFace — activez un Inference Endpoint dans les réglages du modèle (Pro requis), ou utilisez Free',
    },
    'aiClearChat': {
      'ru': 'Очистить чат',
      'en': 'Clear chat',
      'fr': 'Vider le chat',
    },
    'aiChatFull': {
      'ru': 'Чат заполнен (1000 сообщений) — очисти его, чтобы продолжить',
      'en': 'Chat is full (1000 messages) — clear it to continue',
      'fr': 'Chat plein (1000 messages) — videz-le pour continuer',
    },
    'aiAdaLimitReached': {
      'ru': 'Дневной лимит ADA (100) исчерпан — переключаю на бесплатный канал',
      'en': 'Daily ADA limit (100) reached — switching to the free provider',
      'fr': 'Limite quotidienne ADA (100) atteinte — bascule sur le fournisseur gratuit',
    },
    'aiRemaining': {
      'ru': 'Сегодня осталось {n} сообщений',
      'en': '{n} messages left today',
      'fr': '{n} messages restants aujourd\'hui',
    },
    'close': {
      'ru': 'Закрыть',
      'en': 'Close',
      'fr': 'Fermer',
    },
    'autoExportTitle': {
      'ru': 'Автоэкспорт',
      'en': 'Auto export',
      'fr': 'Export automatique',
    },
    'autoExportHint': {
      'ru': 'Ежечасовая копия в /Download',
      'en': 'Hourly backup to /Download',
      'fr': 'Sauvegarde horaire dans /Download',
    },
    'autoExportEnabled': {
      'ru': 'Автоэкспорт включён',
      'en': 'Auto export enabled',
      'fr': 'Export automatique activé',
    },
    'autoExportDisabled': {
      'ru': 'Автоэкспорт выключен',
      'en': 'Auto export disabled',
      'fr': 'Export automatique désactivé',
    },
    'cloudBackupTitle': {
      'ru': 'Бэкап и восстановление',
      'en': 'Backup & Restore',
      'fr': 'Sauvegarde & Restauration',
    },
    'shareBackup': {
      'ru': 'Поделиться бэкапом',
      'en': 'Share backup',
      'fr': 'Partager la sauvegarde',
    },
    'shareBackupHint': {
      'ru': 'Отправить JSON-файл в Google Диск, Telegram, Dropbox или куда угодно',
      'en': 'Send JSON file to Google Drive, Telegram, Dropbox or anywhere',
      'fr': 'Envoyer le fichier JSON vers Google Drive, Telegram, Dropbox ou ailleurs',
    },
    'comingSoon': {
      'ru': 'Скоро',
      'en': 'Coming soon',
      'fr': 'Bientôt disponible',
    },
    'welcomeTitle': {
      'ru': 'Добро пожаловать в Ataraxy',
      'en': 'Welcome to Ataraxy',
      'fr': 'Bienvenue dans Ataraxy',
    },
    'welcomeSubtitle': {
      'ru': 'Настройте приложение для идеального опыта записи снов',
      'en': 'Configure the app for the perfect dream journaling experience',
      'fr': 'Configurez l\'application pour une expérience de journal de rêves parfaite',
    },
    'notifications': {
      'ru': 'Уведомления',
      'en': 'Notifications',
      'fr': 'Notifications',
    },
    'notificationsDescription': {
      'ru': 'Получать уведомления о новых функциях',
      'en': 'Receive notifications about new features',
      'fr': 'Recevoir des notifications sur les nouvelles fonctionnalités',
    },
    'dailyReminder': {
      'ru': 'Ежедневное напоминание',
      'en': 'Daily Reminder',
      'fr': 'Rappel quotidien',
    },
    'dailyReminderDescription': {
      'ru': 'Напоминать записывать сны каждый день',
      'en': 'Remind to record dreams every day',
      'fr': 'Rappeler d\'enregistrer les rêves chaque jour',
    },
    'security': {
      'ru': 'Безопасность',
      'en': 'Security',
      'fr': 'Sécurité',
    },
    'securityDescription': {
      'ru': 'Защитить приложение PIN-кодом',
      'en': 'Protect app with PIN code',
      'fr': 'Protéger l\'application avec un code PIN',
    },
    'dontShowAgain': {
      'ru': 'Больше не показывать',
      'en': 'Don\'t show again',
      'fr': 'Ne plus montrer',
    },
    'startUsing': {
      'ru': 'Начать использовать',
      'en': 'Start Using',
      'fr': 'Commencer à utiliser',
    },
    'enableNotificationsFirst': {
      'ru': 'Сначала включите уведомления',
      'en': 'Enable notifications first',
      'fr': 'Activez d\'abord les notifications',
    },
    'setup': {
      'ru': 'Настроить',
      'en': 'Setup',
      'fr': 'Configurer',
    },
    'resetSettings': {
      'ru': 'Сбросить настройки',
      'en': 'Reset Settings',
      'fr': 'Réinitialiser les paramètres',
    },
    'resetSettingsConfirm': {
      'ru': 'Вы уверены что хотите сбросить все настройки?',
      'en': 'Are you sure you want to reset all settings?',
      'fr': 'Êtes-vous sûr de vouloir réinitialiser tous les paramètres?',
    },
    'reset': {
      'ru': 'Сбросить',
      'en': 'Reset',
      'fr': 'Réinitialiser',
    },
    'settingsReset': {
      'ru': 'Настройки сброшены',
      'en': 'Settings reset',
      'fr': 'Paramètres réinitialisés',
    },
    'errorResettingSettings': {
      'ru': 'Ошибка сброса настроек',
      'en': 'Error resetting settings',
      'fr': 'Erreur lors de la réinitialisation des paramètres',
    },
    'favoriteActivities': {
      'ru': 'Любимые дела',
      'en': 'Favorite activities',
      'fr': 'Activités préférées',
    },
    'favoriteActivity': {
      'ru': 'Любимое дело',
      'en': 'Favorite activity',
      'fr': 'Activité préférée',
    },
    'favoriteActivityBannerTitle': {
      'ru': 'Любимое дело',
      'en': 'Favorite activity',
      'fr': 'Activité préférée',
    },
    'favoriteActivityBannerSubtitle': {
      'ru': 'То, что наполняет день смыслом',
      'en': 'What makes your day meaningful',
      'fr': 'Ce qui donne du sens à votre journée',
    },
    'favoriteActivityHint': {
      'ru': 'Что вы любите делать?',
      'en': 'What do you love doing?',
      'fr': 'Qu\'aimez-vous faire ?',
    },
    'favoriteActivityReading': {
      'ru': 'Режим чтения',
      'en': 'Reading mode',
      'fr': 'Mode lecture',
    },
    'favoriteActivityEmpty': {
      'ru': 'Пока нет любимых дел',
      'en': 'No favorite activities yet',
      'fr': 'Aucune activité préférée pour l\'instant',
    },
    'favoriteActivityEmptyHint': {
      'ru': 'Добавьте то, что вас вдохновляет',
      'en': 'Add what inspires you',
      'fr': 'Ajoutez ce qui vous inspire',
    },
    'favoriteActivityAdd': {
      'ru': 'Добавить дело',
      'en': 'Add activity',
      'fr': 'Ajouter une activité',
    },
    'favoriteActivityEdit': {
      'ru': 'Изменить',
      'en': 'Edit',
      'fr': 'Modifier',
    },
    'favoriteActivityDelete': {
      'ru': 'Удалить',
      'en': 'Delete',
      'fr': 'Supprimer',
    },
    'favoriteActivityPin': {
      'ru': 'Закрепить',
      'en': 'Pin',
      'fr': 'Épingler',
    },
    'favoriteActivityUnpin': {
      'ru': 'Открепить',
      'en': 'Unpin',
      'fr': 'Détacher',
    },
    'favoriteActivityHoldDelete': {
      'ru': 'Удерживайте для удаления',
      'en': 'Hold to delete',
      'fr': 'Maintenir pour supprimer',
    },
    'favoriteActivityLimit': {
      'ru': 'символов',
      'en': 'characters',
      'fr': 'caractères',
    },
    'closeSearch': {
      'ru': 'Закрыть поиск',
      'en': 'Close search',
      'fr': 'Fermer la recherche',
    },
    'totalEntries': {
      'ru': 'Всего записей',
      'en': 'Total entries',
      'fr': 'Total des entrées',
    },
    'sortManual': {
      'ru': 'Вручную',
      'en': 'Manual',
      'fr': 'Manuel',
    },
    'favoritesBannerTitle': {
      'ru': 'Избранное',
      'en': 'Favorites',
      'fr': 'Favoris',
    },
    'favoritesBannerSubtitle': {
      'ru': 'Фото, видео, файлы и заметки',
      'en': 'Photos, videos, files and notes',
      'fr': 'Photos, vidéos, fichiers et notes',
    },
    'favoritesTitle': {
      'ru': 'Избранное',
      'en': 'Favorites',
      'fr': 'Favoris',
    },
    'fileNotFound': {
      'ru': 'Файл не найден',
      'en': 'File not found',
      'fr': 'Fichier introuvable',
    },
    'attachFile': {
      'ru': 'Прикрепить файл',
      'en': 'Attach file',
      'fr': 'Joindre un fichier',
    },
    'writeToFavorites': {
      'ru': 'Написать в избранное…',
      'en': 'Write to favorites…',
      'fr': 'Écrire dans les favoris…',
    },
    'saveText': {
      'ru': 'Сохранить текст',
      'en': 'Save text',
      'fr': 'Enregistrer le texte',
    },
    'imageCropped': {
      'ru': 'Изображение обрезано',
      'en': 'Image cropped',
      'fr': 'Image recadrée',
    },
    'crop': {
      'ru': 'Обрезка',
      'en': 'Crop',
      'fr': 'Recadrer',
    },
    'apply': {
      'ru': 'Применить',
      'en': 'Apply',
      'fr': 'Appliquer',
    },
    'cropHint': {
      'ru': 'Проведите для выбора области обрезки',
      'en': 'Drag to select crop area',
      'fr': 'Faites glisser pour sélectionner la zone',
    },
    'cropTooSmall': {
      'ru': 'Область слишком мала',
      'en': 'Crop area too small',
      'fr': 'Zone de recadrage trop petite',
    },
    'editFile': {
      'ru': 'Редактировать файл',
      'en': 'Edit file',
      'fr': 'Modifier le fichier',
    },
    'editTextTitle': {
      'ru': 'Редактировать текст',
      'en': 'Edit text',
      'fr': 'Modifier le texte',
    },
    'nameLabel': {
      'ru': 'Название',
      'en': 'Name',
      'fr': 'Nom',
    },
    'editTextHint': {
      'ru': 'Измените текст…',
      'en': 'Edit text…',
      'fr': 'Modifier le texte…',
    },
    'patchNotes': {
      'ru': 'Патч-ноуты',
      'en': 'Patch notes',
      'fr': 'Notes de version',
    },
    'whatsLeft': {
      'ru': 'Что осталось доработать',
      'en': 'What remains to refine',
      'fr': 'Ce qui reste à finaliser',
    },
    'remindersTodo': {
      'ru': 'Напоминания',
      'en': 'Reminders',
      'fr': 'Rappels',
    },
    'autosaveTodo': {
      'ru': 'Автосохранения',
      'en': 'Auto-save',
      'fr': 'Sauvegarde automatique',
    },
    'favoritesTodo': {
      'ru': 'Избранное',
      'en': 'Favorites',
      'fr': 'Favoris',
    },
    'steqtoqTag': {
      'ru': 'лучше CapCut',
      'en': 'better than CapCut',
      'fr': 'mieux que CapCut',
    },
    'versionCurrent': {
      'ru': 'текущая',
      'en': 'current',
      'fr': 'actuelle',
    },
    'pnPinnedFix': {
      'ru': 'Закрепление сообщений в избранном теперь не сбивается',
      'en': 'Pinning messages in Favorites no longer slips off',
      'fr': 'L\'épinglage des messages ne glisse plus',
    },
    'pnBlurVideo': {
      'ru': 'Кнопка размытия теперь работает и на видео',
      'en': 'Blur button now works on videos too',
      'fr': 'Le bouton de flou fonctionne aussi sur les vidéos',
    },
    'pnNotesTab': {
      'ru': 'Заметки больше не показываются в общем списке «Всё»',
      'en': 'Notes no longer appear in the "All" tab list',
      'fr': 'Les notes ne s\'affichent plus dans l\'onglet « Tout »',
    },
    'pnExport': {
      'ru': 'Экспорт/импорт: заметки и закрепленные сообщения сохраняются',
      'en': 'Export/import: notes and pinned messages preserved',
      'fr': 'Export/import : notes et épingles préservés',
    },
    'pnLocales': {
      'ru': 'Полная локализация английского и французского',
      'en': 'Full English and French localization',
      'fr': 'Localisation complète en anglais et en français',
    },
    'pnFavorites': {
      'ru': 'Избранное: фото, видео, файлы и заметки в одном месте',
      'en': 'Favorites: photos, videos, files and notes in one place',
      'fr': 'Favoris : photos, vidéos, fichiers et notes au même endroit',
    },
    'pnHeartbeatPlayer': {
      'ru': 'Пульсирующая шкала времени в видеоплеере',
      'en': 'Pulsating time bar in the video player',
      'fr': 'Barre de temps pulsante dans le lecteur vidéo',
    },
    'pnPatchNotesSection': {
      'ru': 'Раздел «Патч-ноуты» прямо в «О приложении»',
      'en': 'In-app Patch notes section on the About screen',
      'fr': 'Section Notes de version intégrée dans « À propos »',
    },
    'pn13Web': {
      'ru': 'Веб-версия: аватарка в сплеше и favicon приложения',
      'en': 'Web: app avatar in splash and app favicon',
      'fr': 'Web : avatar dans le splash et favicon de l\'application',
    },
    'pn13Anim': {
      'ru': 'Плавные переходы: сплеш, темы, языки, вкладки и типы записей',
      'en': 'Smooth transitions: splash, themes, languages, tabs and entry types',
      'fr': 'Transitions fluides : splash, thèmes, langues, onglets et types',
    },
    'pn13Smooth': {
      'ru': 'Плавное обновление ленты и карточки записей с анимированной обводкой',
      'en': 'Smooth feed refresh and entry cards with animated outline',
      'fr': 'Actualisation fluide et cartes avec contour animé',
    },
    'pn13Limits': {
      'ru': 'Лимиты ввода: теги (3 шт., 10 символов), dream sign (10), вода (2), напоминание (50)',
      'en': 'Input limits: tags (3, 10 chars), dream signs (10), water (2), reminder (50)',
      'fr': 'Limites de saisie : tags (3, 10 car.), signes (10), eau (2), rappel (50)',
    },
    'pn13Card': {
      'ru': 'Кнопка «Обновить» теперь действительно обновляет записи',
      'en': 'The Refresh button now actually refreshes entries',
      'fr': 'Le bouton Actualiser actualise réellement les entrées',
    },
    'importSummary': {
      'ru': 'Импорт завершён',
      'en': 'Import complete',
      'fr': 'Importation terminée',
    },
    'importSummaryLine': {
      'ru': 'Записей: %{entries} · Избранное: %{favorites} · Любимых дел: %{activities}',
      'en':
          'Entries: %{entries} · Favorites: %{favorites} · Activities: %{activities}',
      'fr':
          'Entrées : %{entries} · Favoris : %{favorites} · Activités : %{activities}',
    },
    'importMediaMissing': {
      'ru':
          '%{n} файл(ов) из «Избранного» не найдено на этом устройстве — откройте Избранное и прикрепите заново',
      'en':
          '%{n} media file(s) from Favorites weren\u2019t found on this device — open Favorites and re-attach them',
      'fr':
          '%{n} fichier(s) média des Favoris introuvable(s) sur cet appareil — r\u00e9-ouvrez Favoris pour les rattacher',
    },
    'importActivitiesTrimmed': {
      'ru': '%{n} любимых дел обрезано (макс. 5)',
      'en': '%{n} activities were trimmed (cap is 5)',
      'fr': '%{n} activit\u00e9s coup\u00e9es (limite 5)',
    },
    'importItemsSkipped': {
      'ru': '%{n} повреждённых элементов пропущено',
      'en': '%{n} malformed items were skipped',
      'fr': '%{n} \u00e9l\u00e9ments endommag\u00e9s ignor\u00e9s',
    },
    'supportButton': {
      'ru': 'Поддержать',
      'en': 'Support',
      'fr': 'Soutenir',
    },
    'supportHint': {
      'ru': 'Помочь развитию приложения',
      'en': 'Help the app grow',
      'fr': 'Aider l\'application à grandir',
    },
    'supportThanks': {
      'ru': 'Спасибо за поддержку! 💖',
      'en': 'Thank you for your support! 💖',
      'fr': 'Merci pour votre soutien ! 💖',
    },
    'favoriteActivityLimitReached': {
      'ru': 'Можно добавить не более 5 любимых дел',
      'en': 'You can add up to 5 favorite activities',
      'fr': 'Vous pouvez ajouter jusqu\'à 5 activités préférées',
    },
    'favoriteActivityAdded': {
      'ru': 'Дело добавлено',
      'en': 'Activity added',
      'fr': 'Activité ajoutée',
    },
    'favoriteActivityDeleted': {
      'ru': 'Дело удалено',
      'en': 'Activity deleted',
      'fr': 'Activité supprimée',
    },
    'permissions': {
      'ru': 'Разрешения',
      'en': 'Permissions',
      'fr': 'Permissions',
    },
    'miuiHint': {
      'ru': 'MIUI: включите Автозапуск и «Без ограничений» в Батарее — иначе система остановит фоновые уведомления.',
      'en': 'MIUI: enable Autostart and "No restrictions" in Battery — otherwise background notifications get killed.',
      'fr': 'MIUI : activez le Démarrage auto et « Sans restrictions » dans Batterie — sinon les notifications en arrière-plan sont bloquées.',
    },
    'webHint': {
      'ru': 'Уведомление сработает, пока вкладка открыта.',
      'en': 'Reminder fires while the tab is open.',
      'fr': 'Le rappel s\'active tant que l\'onglet est ouvert.',
    },
  };

  static final Map<String, Map<String, String>> _signLabels = {
    'flying': {'ru': 'Полёт', 'en': 'Flying', 'fr': 'Voler'},
    'falling': {'ru': 'Падение', 'en': 'Falling', 'fr': 'Chute'},
    'chased': {'ru': 'Погоня', 'en': 'Being chased', 'fr': 'Pourchassé'},
    'teeth': {'ru': 'Зубы', 'en': 'Teeth', 'fr': 'Dents'},
    'water': {'ru': 'Вода', 'en': 'Water', 'fr': 'Eau'},
    'school': {'ru': 'Школа', 'en': 'School', 'fr': 'École'},
    'paralysis': {'ru': 'Паралич', 'en': 'Sleep paralysis', 'fr': 'Paralysie'},
    'lost': {'ru': 'Потеря', 'en': 'Being lost', 'fr': 'Perdu'},
    'animal': {'ru': 'Животные', 'en': 'Animals', 'fr': 'Animaux'},
    'vehicle': {'ru': 'Транспорт', 'en': 'Vehicles', 'fr': 'Véhicules'},
    'celebrity': {
      'ru': 'Знаменитости',
      'en': 'Celebrities',
      'fr': 'Célébrités',
    },
    'naked': {'ru': 'Нагота', 'en': 'Nudity', 'fr': 'Nudité'},
  };

  static String dreamSign(BuildContext context, String id) {
    final code = Localizations.localeOf(context).languageCode;
    final map = _signLabels[id];
    if (map == null) return id;
    return map[code] ?? map['en'] ?? id;
  }

  static String tr(
    BuildContext context,
    String key, {
    Map<String, Object?>? params,
  }) {
    final code = Localizations.localeOf(context).languageCode;
    return trStatic(key, languageCode: code, params: params);
  }

  /// Same as [tr] but without a [BuildContext] — for code that runs outside
  /// the widget tree (e.g. an AI controller). Falls back to Russian.
  static String trStatic(
    String key, {
    String languageCode = 'ru',
    Map<String, Object?>? params,
  }) {
    final map = _strings[key];
    if (map == null) return key;
    final raw = map[languageCode] ?? map['en'] ?? key;
    if (params == null || !raw.contains('%{')) return raw;
    var value = raw;
    params.forEach((k, v) {
      value = value.replaceAll('%{$k}', v?.toString() ?? '');
    });
    return value;
  }
}
