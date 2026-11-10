// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'My Journal';

  @override
  String get tabDreams => 'Dreams';

  @override
  String get tabLife => 'Life';

  @override
  String get tabAll => 'All';

  @override
  String get tabNotes => 'Notes';

  @override
  String get fabNew => 'New';

  @override
  String get refresh => 'Refresh';

  @override
  String get entriesUpdated => 'Entries refreshed';

  @override
  String get emptyDream => 'No dream entries yet';

  @override
  String get emptyLife => 'No life entries yet';

  @override
  String get emptyNotes => 'No notes yet';

  @override
  String get emptyAll => 'No entries yet';

  @override
  String get emptyTulpa => 'No tulpa entries yet';

  @override
  String get entryNew => 'New entry';

  @override
  String get entryEdit => 'Edit';

  @override
  String get save => 'Save';

  @override
  String get saveFailed => 'Could not save — check your device storage';

  @override
  String get typeDream => 'Dream';

  @override
  String get typeLife => 'Life';

  @override
  String get typeGeneral => 'Note';

  @override
  String get segDream => 'Dream';

  @override
  String get segLife => 'Life';

  @override
  String get segGeneral => 'Note';

  @override
  String get titleHint => 'Title';

  @override
  String get contentHint => 'Describe your thoughts, dream or event...';

  @override
  String get editTab => 'Edit';

  @override
  String get previewTab => 'Preview';

  @override
  String get previewEmpty =>
      'Nothing to preview yet — start typing and it will show here';

  @override
  String get tapToExpandNotes => 'Tap to expand notes';

  @override
  String get mood => 'Mood';

  @override
  String get tags => 'Tags';

  @override
  String get addTag => 'Add tag';

  @override
  String get tagsLimit => 'Up to 3 tags';

  @override
  String get tagTooLong => 'Tag is limited to 10 characters';

  @override
  String get withoutTitle => 'Untitled';

  @override
  String get noText => 'No text.';

  @override
  String get deleteTitle => 'Delete entry?';

  @override
  String get deleteContent => 'This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get cut => 'Cut';

  @override
  String get copy => 'Copy';

  @override
  String get paste => 'Paste';

  @override
  String get share => 'Share';

  @override
  String get clear => 'Clear';

  @override
  String get delete => 'Delete';

  @override
  String get entryDeleted => 'Entry deleted';

  @override
  String get restore => 'Restore';

  @override
  String get streak => 'Day streak';

  @override
  String get streakDays => 'd.';

  @override
  String get streakHint =>
      'Days in a row you wrote in your journal. Miss a day and the streak resets. Write every day to keep it growing!';

  @override
  String rewardChat(Object n) {
    return '🔥 Daily reward: +$n ✨';
  }

  @override
  String rewardTask(Object n) {
    return '✅ Task done: +$n ✨';
  }

  @override
  String rewardStreak(Object n) {
    return 'Streak: $n d.';
  }

  @override
  String get settings => 'Settings';

  @override
  String get theme => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get pin => 'PIN code';

  @override
  String get setPin => 'Set PIN';

  @override
  String get changePin => 'Change PIN';

  @override
  String get removePin => 'Remove PIN';

  @override
  String get removePinConfirm => 'Are you sure? PIN will be removed.';

  @override
  String get enterPin => 'Enter PIN';

  @override
  String get confirmPin => 'Confirm PIN';

  @override
  String get unlock => 'Unlock';

  @override
  String get pinMismatch => 'PIN does not match';

  @override
  String get pinWrong => 'Wrong PIN';

  @override
  String get pinSetDone => 'PIN set';

  @override
  String get pinRemoved => 'PIN removed';

  @override
  String get dreamKind => 'Dream type';

  @override
  String get dreamNormal => 'Normal';

  @override
  String get dreamLucid => 'Lucid';

  @override
  String get lucidBadge => 'Lucid dream';

  @override
  String get normalBadge => 'Normal dream';

  @override
  String get search => 'Search';

  @override
  String get searchHint => 'Search entries...';

  @override
  String get noResults => 'Nothing found';

  @override
  String get data => 'Data';

  @override
  String get export => 'Export';

  @override
  String get import => 'Import';

  @override
  String get protectDeletedTitle => 'Don\'t restore deleted on import';

  @override
  String get protectDeletedHint =>
      'Deleted entries stay deleted even after importing an old backup';

  @override
  String get exportDone => 'Entries exported';

  @override
  String get exportPickLocation => 'Where to save the backup';

  @override
  String get exportCancelled => 'Export canceled';

  @override
  String get importDone => 'Entries imported';

  @override
  String get importError => 'Could not import file';

  @override
  String get clearData => 'Clear Data';

  @override
  String get confirmDelete => 'Confirm Deletion';

  @override
  String get confirmDeleteData =>
      'This will delete all your entries and settings. Are you sure?';

  @override
  String get deleteData => 'Delete';

  @override
  String get experimental => 'Experimental';

  @override
  String get tulpa => 'Tulpa (entries about tulpas)';

  @override
  String get tulpaHint =>
      'Adds a \"Tulpa\" entry type for notes about your tulpas';

  @override
  String get tabTulpa => 'Tulpas';

  @override
  String get segTulpa => 'Tulpa';

  @override
  String get typeTulpa => 'Tulpa';

  @override
  String get about => 'About';

  @override
  String get aboutDesc =>
      'A journal for dreams, life and tulpas. Free and open-source software.';

  @override
  String get version => 'Version';

  @override
  String get enterCurrentPin => 'Enter current PIN';

  @override
  String get guideDreamTitle => 'Motivation & learning';

  @override
  String get guideTulpaTitle => 'Tulpa: gentle dialogue';

  @override
  String get guideToday => 'Today';

  @override
  String guidePracticeOfDay(Object title) {
    return 'Today\'s practice: $title';
  }

  @override
  String get guideMarkDone => 'Mark as done';

  @override
  String get guideDone => 'Practice completed';

  @override
  String get guideHowItWorks => 'How it works';

  @override
  String get guideWhyUseful => 'Why this can be useful';

  @override
  String get guideDreamSubtitle =>
      'A small step toward lucid sleep — every day';

  @override
  String get guideTulpaSubtitle => 'Growth, communication and self-care';

  @override
  String get madeWithLove => 'Made with love';

  @override
  String get forcingDuration => 'Forcing duration';

  @override
  String get forcingHint => 'How long the forcing lasted';

  @override
  String get statistics => 'Statistics';

  @override
  String get statsTotal => 'Total entries';

  @override
  String get statsByType => 'Entries by type';

  @override
  String get statsMood => 'Mood over time';

  @override
  String get statsCalendar => 'Entries calendar';

  @override
  String get statsDreamSigns => 'Frequent dream signs';

  @override
  String get statsNoData => 'Not enough data';

  @override
  String get editTime => 'Date and time';

  @override
  String get dreamSignsSection => 'Dream signs';

  @override
  String get addSign => 'Add custom';

  @override
  String get month => 'Month';

  @override
  String get category => 'Category';

  @override
  String get catAll => 'All';

  @override
  String get catGood => 'Good day';

  @override
  String get catBad => 'Bad day';

  @override
  String get catRandom => 'Random';

  @override
  String get reminders => 'Reminders';

  @override
  String get reminderTime => 'Notification time';

  @override
  String get reminderText => 'Notification text';

  @override
  String get reminderHint => 'What to remember (required)';

  @override
  String get reminderSet => 'Reminder set';

  @override
  String get reminderDisabled => 'Reminder disabled';

  @override
  String get reminderRequired => 'Enter the notification text';

  @override
  String reminderNextFire(Object time) {
    return 'That time has passed today — the first reminder fires tomorrow at $time';
  }

  @override
  String get autosave => 'Autosave';

  @override
  String get autosaveHint => 'Save entry every second';

  @override
  String get expWater => 'Water';

  @override
  String get expFasting => 'Intermittent fasting';

  @override
  String get expPomodoro => 'Pomodoro';

  @override
  String get expSteps => 'Steps';

  @override
  String get water => 'Water, L';

  @override
  String get waterHint => 'Liters drunk';

  @override
  String get waterStats => 'Water stats';

  @override
  String get fasting => 'Fasting';

  @override
  String get fastingFrom => 'Start';

  @override
  String get fastingTo => 'End';

  @override
  String get fastingWindow => 'Fasting window';

  @override
  String get pomodoro => 'Pomodoro';

  @override
  String get pomodoroStart => 'Focus start';

  @override
  String get pomodoroEnd => 'Focus end';

  @override
  String get pomodoroStartFocus => 'Start focus';

  @override
  String get pomodoroRunning => 'Focus';

  @override
  String get pomodoroDone => 'Focus done';

  @override
  String get steps => 'Steps';

  @override
  String get stepsToday => 'Steps today';

  @override
  String get stepsNotSupported => 'Steps unavailable on this device';

  @override
  String get voiceInput => 'Voice input';

  @override
  String get listening => 'Listening…';

  @override
  String get voiceUnavailable => 'Voice input unavailable';

  @override
  String get pinned => 'Pinned';

  @override
  String get unpinned => 'Unpinned';

  @override
  String get byWetidom => 'POWERED BY LARAF';

  @override
  String get launchTitle => 'Ataraxy';

  @override
  String get newReminder => 'New reminder';

  @override
  String get themeSystem => 'System (Material You)';

  @override
  String get themeLightPeach => 'Light Peach';

  @override
  String get themeLightLavender => 'Lavender';

  @override
  String get themeDarkPeach => 'Dark Peach';

  @override
  String get themeLightGrok => 'Light Grok';

  @override
  String get favoritesAddAnyFile => 'Add file or photo';

  @override
  String get favoritesPhotosEmpty => 'No photos yet';

  @override
  String get favoritesPhotosEmptyHint => 'Tap the paperclip to add photos';

  @override
  String get langSystem => 'System';

  @override
  String get langRussian => 'Russian';

  @override
  String get langEnglish => 'English';

  @override
  String get langFrench => 'French';

  @override
  String get dev => 'Dev';

  @override
  String get devMode => 'Developer mode';

  @override
  String get devPassword => 'Developer password';

  @override
  String get devWrongPassword => 'Wrong password';

  @override
  String get devHrtTracking => 'Hormone replacement therapy (HRT)';

  @override
  String get devTestNotification => 'Test notification';

  @override
  String get devScheduleDaily => 'Schedule daily';

  @override
  String get devCancelAll => 'Cancel all';

  @override
  String get devCheckPermissions => 'Check permissions';

  @override
  String get devClearAllData => 'Clear all data';

  @override
  String get hrtTime => 'HRT medication time';

  @override
  String get hrtDosage => 'HRT dosage';

  @override
  String get license => 'License: MIT';

  @override
  String get sortNewest => 'Newest first';

  @override
  String get sortOldest => 'Oldest first';

  @override
  String get sortAlpha => 'Alphabetical';

  @override
  String get githubLink => 'github.com/wxstdo-boop/Ataraxy';

  @override
  String get themeMutilated => 'MUTILATED';

  @override
  String get testNotification => 'Test notification';

  @override
  String get devScheduleDailyHint =>
      'Schedule a test reminder one minute from now';

  @override
  String get devPermissionsTitle => 'Permissions';

  @override
  String get devPermissionsHint =>
      'Check notification and exact alarm permissions';

  @override
  String get devClearAllHint => 'WARNING: Deletes all entries and settings';

  @override
  String get devFullReset => 'Full reset';

  @override
  String get devFullResetConfirm =>
      'This will delete ALL entries and settings. Are you sure?';

  @override
  String get devResetTriggered => 'Full reset triggered';

  @override
  String get ok => 'OK';

  @override
  String get aiAssistant => 'AI assistant';

  @override
  String get aiInputHint => 'Ask about your entries…';

  @override
  String get aiThinking => 'Thinking…';

  @override
  String get aiEmptyTitle => 'Hi! I\'m your AI assistant';

  @override
  String get aiEmptyHint =>
      'I analyze your journal: dreams, life, tulpas. Ask about patterns, summaries, or ask me to create an entry.';

  @override
  String aiAnalyzes(Object n) {
    return 'I can see $n entries in your journal';
  }

  @override
  String get aiDailyLimitReached => 'Daily message limit reached';

  @override
  String get aiError => 'AI error';

  @override
  String get aiEntryCreated => '✅ Entry created';

  @override
  String get aiEntryUpdated => '✅ Entry updated';

  @override
  String get aiCommandError => '⚠ Failed to run the command';

  @override
  String get aiSettingsTitle => 'AI assistant';

  @override
  String get aiSettingsHint => 'Smart chat about your entries (long-press “+”)';

  @override
  String get aiProvider => 'Provider';

  @override
  String get aiFree => 'free, no key needed';

  @override
  String get aiKey => 'API key';

  @override
  String get aiKeyEmpty => 'Not set';

  @override
  String get aiDailyLimit => 'Daily limit';

  @override
  String get aiLimitPerDay => 'messages per day';

  @override
  String get aiLimitUnlimited => 'Unlimited';

  @override
  String get aiDisabled => 'AI assistant is off — enable it in Settings';

  @override
  String get minimize => 'Minimize';

  @override
  String get aiOnline => 'online';

  @override
  String get aiOnVacation =>
      'AI is on vacation right now ☀️ — try again in a moment';

  @override
  String get aiAdaFallback =>
      'ADA is temporarily unavailable (model not deployed) — switched to the free provider';

  @override
  String get aiAdaNotDeployed =>
      'The ADA model is not deployed on HuggingFace yet — enable an Inference Endpoint in the model settings (Pro required), or use Free';

  @override
  String get aiClearChat => 'Clear chat';

  @override
  String get aiChatFull =>
      'Chat is full (1000 messages) — clear it to continue';

  @override
  String get aiAdaLimitReached =>
      'Daily ADA limit (100) reached — switching to the free provider';

  @override
  String aiRemaining(Object n) {
    return '$n messages left today';
  }

  @override
  String get close => 'Close';

  @override
  String get autoExportTitle => 'Auto export';

  @override
  String get autoExportHint => 'Hourly backup to /Download';

  @override
  String get autoExportEnabled => 'Auto export enabled';

  @override
  String get autoExportDisabled => 'Auto export disabled';

  @override
  String get updateTitle => 'Update Ataraxy';

  @override
  String get updateHint =>
      'Check GitHub Releases and install the latest version';

  @override
  String get updateChecking => 'Checking GitHub Releases…';

  @override
  String get updateFound => 'Version available:';

  @override
  String get updateDownloading => 'Downloading update';

  @override
  String get updateCurrent => 'You have the latest version';

  @override
  String get updatePermission =>
      'Allow Ataraxy to install apps, then tap again';

  @override
  String get updateInstalling =>
      'Android installer opened — confirm the update';

  @override
  String get updateFailed => 'Could not check or install the update';

  @override
  String get cloudBackupTitle => 'Backup & Restore';

  @override
  String get shareBackup => 'Share backup';

  @override
  String get shareBackupHint =>
      'Send JSON file to Google Drive, Telegram, Dropbox or anywhere';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get welcomeTitle => 'Welcome to Ataraxy';

  @override
  String get welcomeSubtitle =>
      'Configure the app for the perfect dream journaling experience';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsDescription =>
      'Receive notifications about new features';

  @override
  String get dailyReminder => 'Daily Reminder';

  @override
  String get dailyReminderDescription => 'Remind to record dreams every day';

  @override
  String get security => 'Security';

  @override
  String get securityDescription => 'Protect app with PIN code';

  @override
  String get dontShowAgain => 'Don\'t show again';

  @override
  String get startUsing => 'Start Using';

  @override
  String get enableNotificationsFirst => 'Enable notifications first';

  @override
  String get setup => 'Setup';

  @override
  String get resetSettings => 'Reset Settings';

  @override
  String get resetSettingsConfirm =>
      'Are you sure you want to reset all settings?';

  @override
  String get reset => 'Reset';

  @override
  String get settingsReset => 'Settings reset';

  @override
  String get errorResettingSettings => 'Error resetting settings';

  @override
  String get favoriteActivities => 'Favorite activities';

  @override
  String get favoriteActivity => 'Favorite activity';

  @override
  String get favoriteActivityBannerTitle => 'Favorite activity';

  @override
  String get favoriteActivityBannerSubtitle => 'What makes your day meaningful';

  @override
  String get favoriteActivityHint => 'What do you love doing?';

  @override
  String get favoriteActivityReading => 'Reading mode';

  @override
  String get favoriteActivityEmpty => 'No favorite activities yet';

  @override
  String get favoriteActivityEmptyHint => 'Add what inspires you';

  @override
  String get favoriteActivityAdd => 'Add activity';

  @override
  String get favoriteActivityEdit => 'Edit';

  @override
  String get favoriteActivityDelete => 'Delete';

  @override
  String get favoriteActivityPin => 'Pin';

  @override
  String get favoriteActivityUnpin => 'Unpin';

  @override
  String get favoriteActivityHoldDelete => 'Hold to delete';

  @override
  String get favoriteActivityLimit => 'characters';

  @override
  String get closeSearch => 'Close search';

  @override
  String get totalEntries => 'Total entries';

  @override
  String get sortManual => 'Manual';

  @override
  String get favoritesBannerTitle => 'Favorites';

  @override
  String get favoritesBannerSubtitle => 'Photos, videos, files and notes';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get attachFile => 'Attach file';

  @override
  String get writeToFavorites => 'Write to favorites…';

  @override
  String get saveText => 'Save text';

  @override
  String get imageCropped => 'Image cropped';

  @override
  String get crop => 'Crop';

  @override
  String get apply => 'Apply';

  @override
  String get cropHint => 'Drag to select crop area';

  @override
  String get cropTooSmall => 'Crop area too small';

  @override
  String get editFile => 'Edit file';

  @override
  String get editTextTitle => 'Edit text';

  @override
  String get nameLabel => 'Name';

  @override
  String get editTextHint => 'Edit text…';

  @override
  String get patchNotes => 'Patch notes';

  @override
  String get whatsLeft => 'What remains to refine';

  @override
  String get remindersTodo => 'Reminders';

  @override
  String get autosaveTodo => 'Auto-save';

  @override
  String get favoritesTodo => 'Favorites';

  @override
  String get steqtoqTag => 'better than CapCut';

  @override
  String get versionCurrent => 'current';

  @override
  String get pnPinnedFix => 'Pinning messages in Favorites no longer slips off';

  @override
  String get pnBlurVideo => 'Blur button now works on videos too';

  @override
  String get pnNotesTab => 'Notes no longer appear in the \"All\" tab list';

  @override
  String get pnExport => 'Export/import: notes and pinned messages preserved';

  @override
  String get pnLocales => 'Full English and French localization';

  @override
  String get pnFavorites =>
      'Favorites: photos, videos, files and notes in one place';

  @override
  String get pnHeartbeatPlayer => 'Pulsating time bar in the video player';

  @override
  String get pnPatchNotesSection =>
      'In-app Patch notes section on the About screen';

  @override
  String get pn13Web => 'Web: app avatar in splash and app favicon';

  @override
  String get pn13Anim =>
      'Smooth transitions: splash, themes, languages, tabs and entry types';

  @override
  String get pn13Smooth =>
      'Smooth feed refresh and entry cards with animated outline';

  @override
  String get pn13Limits =>
      'Input limits: tags (3, 10 chars), dream signs (10), water (2), reminder (50)';

  @override
  String get pn13Card => 'The Refresh button now actually refreshes entries';

  @override
  String get pn131Save =>
      'Entries no longer lost: saved on every exit and when the app is backgrounded';

  @override
  String get pn131Meta =>
      'Pinning, dream signs, lucidity and medication now save right away';

  @override
  String get pn131Export =>
      'Export: a system \"Save as\" sheet instead of file access';

  @override
  String get pn131Smooth =>
      'Smoothness: the feed no longer rebuilds while the pills retract, one page transition everywhere';

  @override
  String get pn132Words =>
      'Word loss from the feed: dragging and pinning no longer overwrite text with a stale snapshot';

  @override
  String get pn132Order => 'Manual entry order now survives app restarts';

  @override
  String get pn132Editor =>
      'Editor: a failed save no longer marks text as written, so the words are retried';

  @override
  String get pn132Spots =>
      'Section spots behind the pills: now legible on both dark and light themes';

  @override
  String get pn133Repeat =>
      'Word loss on re-open: a card no longer hands the editor a stale snapshot of the entry';

  @override
  String get pn133Spots =>
      'Section spots are larger and richer: they fill the whole pill, not a dot in the middle';

  @override
  String get importSummary => 'Import complete';

  @override
  String importSummaryLine(
    Object activities,
    Object entries,
    Object favorites,
  ) {
    return 'Entries: $entries · Favorites: $favorites · Activities: $activities';
  }

  @override
  String importMediaMissing(Object n) {
    return '$n media file(s) from Favorites weren’t found on this device — open Favorites and re-attach them';
  }

  @override
  String importActivitiesTrimmed(Object n) {
    return '$n activities were trimmed (cap is 5)';
  }

  @override
  String importItemsSkipped(Object n) {
    return '$n malformed items were skipped';
  }

  @override
  String get supportButton => 'Support';

  @override
  String get supportHint => 'Help the app grow';

  @override
  String get supportThanks => 'Thank you for your support! 💖';

  @override
  String get favoriteActivityLimitReached =>
      'You can add up to 5 favorite activities';

  @override
  String get favoriteActivityAdded => 'Activity added';

  @override
  String get favoriteActivityDeleted => 'Activity deleted';

  @override
  String get permissions => 'Permissions';

  @override
  String get miuiHint =>
      'MIUI: enable Autostart and \"No restrictions\" in Battery — otherwise background notifications get killed.';

  @override
  String get webHint => 'Reminder fires while the tab is open.';

  @override
  String get sign_flying => 'Flying';

  @override
  String get sign_falling => 'Falling';

  @override
  String get sign_chased => 'Being chased';

  @override
  String get sign_teeth => 'Teeth';

  @override
  String get sign_water => 'Water';

  @override
  String get sign_school => 'School';

  @override
  String get sign_paralysis => 'Sleep paralysis';

  @override
  String get sign_lost => 'Being lost';

  @override
  String get sign_animal => 'Animals';

  @override
  String get sign_vehicle => 'Vehicles';

  @override
  String get sign_celebrity => 'Celebrities';

  @override
  String get sign_naked => 'Nudity';
}
