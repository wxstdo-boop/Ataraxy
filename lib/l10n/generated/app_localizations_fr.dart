// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Mon Journal';

  @override
  String get tabDreams => 'Rêves';

  @override
  String get tabLife => 'Vie';

  @override
  String get tabAll => 'Tout';

  @override
  String get tabNotes => 'Notes';

  @override
  String get fabNew => 'Nouveau';

  @override
  String get refresh => 'Actualiser';

  @override
  String get entriesUpdated => 'Entrées actualisées';

  @override
  String get emptyDream => 'Aucune entrée de rêve pour l\'instant';

  @override
  String get emptyLife => 'Aucune entrée de vie pour l\'instant';

  @override
  String get emptyNotes => 'Aucune note pour l\'instant';

  @override
  String get emptyAll => 'Aucune entrée pour l\'instant';

  @override
  String get emptyTulpa => 'Aucune entrée de tulpe pour l\'instant';

  @override
  String get entryNew => 'Nouvelle entrée';

  @override
  String get entryEdit => 'Modifier';

  @override
  String get save => 'Enregistrer';

  @override
  String get saveFailed =>
      'Échec de l\'enregistrement — vérifiez l\'espace de stockage';

  @override
  String get typeDream => 'Rêve';

  @override
  String get typeLife => 'Vie';

  @override
  String get typeGeneral => 'Note';

  @override
  String get segDream => 'Rêve';

  @override
  String get segLife => 'Vie';

  @override
  String get segGeneral => 'Note';

  @override
  String get titleHint => 'Titre';

  @override
  String get contentHint => 'Décrivez vos pensées, rêve ou événement...';

  @override
  String get editTab => 'Éditeur';

  @override
  String get previewTab => 'Aperçu';

  @override
  String get previewEmpty =>
      'Rien à prévisualiser — écrivez et l\'aperçu apparaîtra ici';

  @override
  String get tapToExpandNotes => 'Appuyez pour développer les notes';

  @override
  String get mood => 'Humeur';

  @override
  String get tags => 'Tags';

  @override
  String get addTag => 'Ajouter un tag';

  @override
  String get tagsLimit => '3 tags maximum';

  @override
  String get tagTooLong => 'Tag limité à 10 caractères';

  @override
  String get withoutTitle => 'Sans titre';

  @override
  String get noText => 'Aucun texte.';

  @override
  String get deleteTitle => 'Supprimer l\'entrée ?';

  @override
  String get deleteContent => 'Cette action est irréversible.';

  @override
  String get cancel => 'Annuler';

  @override
  String get cut => 'Couper';

  @override
  String get copy => 'Copier';

  @override
  String get paste => 'Coller';

  @override
  String get share => 'Partager';

  @override
  String get clear => 'Effacer';

  @override
  String get delete => 'Supprimer';

  @override
  String get entryDeleted => 'Entrée supprimée';

  @override
  String get restore => 'Restaurer';

  @override
  String get streak => 'Série de jours';

  @override
  String get streakDays => 'j.';

  @override
  String get streakHint =>
      'Jours consécutifs où tu as écrit dans ton journal. Rate un jour et la série recommence. Écris chaque jour pour la faire grandir !';

  @override
  String rewardChat(Object n) {
    return '🔥 Récompense du jour : +$n ✨';
  }

  @override
  String rewardTask(Object n) {
    return '✅ Tâche accomplie : +$n ✨';
  }

  @override
  String rewardStreak(Object n) {
    return 'Série : $n j.';
  }

  @override
  String get settings => 'Paramètres';

  @override
  String get theme => 'Thème';

  @override
  String get language => 'Langue';

  @override
  String get pin => 'Code PIN';

  @override
  String get setPin => 'Définir le code';

  @override
  String get changePin => 'Changer le code';

  @override
  String get removePin => 'Retirer le code';

  @override
  String get removePinConfirm => 'Êtes-vous sûr ? Le code PIN sera supprimé.';

  @override
  String get enterPin => 'Entrez le code';

  @override
  String get confirmPin => 'Confirmez le code';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String get pinMismatch => 'Le code ne correspond pas';

  @override
  String get pinWrong => 'Code incorrect';

  @override
  String get pinSetDone => 'Code défini';

  @override
  String get pinRemoved => 'Code retiré';

  @override
  String get dreamKind => 'Type de rêve';

  @override
  String get dreamNormal => 'Normal';

  @override
  String get dreamLucid => 'Lucide';

  @override
  String get lucidBadge => 'Rêve lucide';

  @override
  String get normalBadge => 'Rêve normal';

  @override
  String get search => 'Recherche';

  @override
  String get searchHint => 'Rechercher...';

  @override
  String get noResults => 'Aucun résultat';

  @override
  String get data => 'Données';

  @override
  String get export => 'Exporter';

  @override
  String get import => 'Importer';

  @override
  String get protectDeletedTitle =>
      'Ne pas restaurer les éléments supprimés à l\'import';

  @override
  String get protectDeletedHint =>
      'Les entrées supprimées restent supprimées après l\'import d\'une ancienne sauvegarde';

  @override
  String get exportDone => 'Entrées exportées';

  @override
  String get exportPickLocation => 'Où enregistrer la sauvegarde';

  @override
  String get exportCancelled => 'Export annulé';

  @override
  String get importDone => 'Entrées importées';

  @override
  String get importError => 'Import impossible';

  @override
  String get clearData => 'Effacer les données';

  @override
  String get confirmDelete => 'Confirmer la suppression';

  @override
  String get confirmDeleteData =>
      'Cela supprimera toutes vos entrées et paramètres. Êtes-vous sûr ?';

  @override
  String get deleteData => 'Supprimer';

  @override
  String get experimental => 'Expérimental';

  @override
  String get tulpa => 'Tulpe (entrées sur les tulpas)';

  @override
  String get tulpaHint =>
      'Ajoute un type « Tulpe » pour vos notes sur vos tulpas';

  @override
  String get tabTulpa => 'Tulpes';

  @override
  String get segTulpa => 'Tulpe';

  @override
  String get typeTulpa => 'Tulpe';

  @override
  String get about => 'À propos';

  @override
  String get aboutDesc =>
      'Journal de rêves, de vie et de tulpas. Logiciel libre et open-source.';

  @override
  String get version => 'Version';

  @override
  String get enterCurrentPin => 'Entrez le code actuel';

  @override
  String get guideDreamTitle => 'Motivation et apprentissage';

  @override
  String get guideTulpaTitle => 'Tulpa : dialogue doux';

  @override
  String get guideToday => 'Aujourd\'hui';

  @override
  String guidePracticeOfDay(Object title) {
    return 'Pratique du jour : $title';
  }

  @override
  String get guideMarkDone => 'Marquer comme fait';

  @override
  String get guideDone => 'Pratique terminée';

  @override
  String get guideHowItWorks => 'Comment ça marche';

  @override
  String get guideWhyUseful => 'Pourquoi cela peut être utile';

  @override
  String get guideDreamSubtitle =>
      'Un petit pas vers un sommeil lucide — chaque jour';

  @override
  String get guideTulpaSubtitle => 'Croissance, communication et soin de soi';

  @override
  String get madeWithLove => 'Fait avec amour';

  @override
  String get forcingDuration => 'Durée du forcing';

  @override
  String get forcingHint => 'Combien a duré le forcing';

  @override
  String get statistics => 'Statistiques';

  @override
  String get statsTotal => 'Entrées totales';

  @override
  String get statsByType => 'Entrées par type';

  @override
  String get statsMood => 'Humeur dans le temps';

  @override
  String get statsCalendar => 'Calendrier des entrées';

  @override
  String get statsDreamSigns => 'Dream signs fréquents';

  @override
  String get statsNoData => 'Pas assez de données';

  @override
  String get editTime => 'Date et heure';

  @override
  String get dreamSignsSection => 'Dream signs';

  @override
  String get addSign => 'Ajouter';

  @override
  String get month => 'Mois';

  @override
  String get category => 'Catégorie';

  @override
  String get catAll => 'Tout';

  @override
  String get catGood => 'Bonne journée';

  @override
  String get catBad => 'Mauvaise journée';

  @override
  String get catRandom => 'Aléatoire';

  @override
  String get reminders => 'Rappels';

  @override
  String get reminderTime => 'Heure de notification';

  @override
  String get reminderText => 'Texte de notification';

  @override
  String get reminderHint => 'Quoi rappeler';

  @override
  String get reminderSet => 'Rappel défini';

  @override
  String get reminderDisabled => 'Rappel désactivé';

  @override
  String get reminderRequired => 'Saisissez le texte';

  @override
  String reminderNextFire(Object time) {
    return 'Cette heure est déjà passée aujourd\'hui — premier rappel demain à $time';
  }

  @override
  String get autosave => 'Sauvegarde auto';

  @override
  String get autosaveHint => 'Enregistrer chaque seconde';

  @override
  String get expWater => 'Eau';

  @override
  String get expFasting => 'Jeûne intermittent';

  @override
  String get expPomodoro => 'Pomodoro';

  @override
  String get expSteps => 'Pas';

  @override
  String get water => 'Eau, L';

  @override
  String get waterHint => 'Litres bus';

  @override
  String get waterStats => 'Stats deau';

  @override
  String get fasting => 'Jeûne';

  @override
  String get fastingFrom => 'Début';

  @override
  String get fastingTo => 'Fin';

  @override
  String get fastingWindow => 'Fenêtre de jeûne';

  @override
  String get pomodoro => 'Pomodoro';

  @override
  String get pomodoroStart => 'Début de focus';

  @override
  String get pomodoroEnd => 'Fin de focus';

  @override
  String get pomodoroStartFocus => 'Démarrer le focus';

  @override
  String get pomodoroRunning => 'Focus';

  @override
  String get pomodoroDone => 'Focus terminé';

  @override
  String get steps => 'Pas';

  @override
  String get stepsToday => 'Pas aujourdhui';

  @override
  String get stepsNotSupported => 'Pas indisponibles';

  @override
  String get voiceInput => 'Saisie vocale';

  @override
  String get listening => 'Écoute…';

  @override
  String get voiceUnavailable => 'Saisie vocale indisponible';

  @override
  String get pinned => 'Épinglé';

  @override
  String get unpinned => 'Détaché';

  @override
  String get byWetidom => 'POWERED BY LARAF';

  @override
  String get launchTitle => 'Ataraxy';

  @override
  String get newReminder => 'Nouveau rappel';

  @override
  String get themeSystem => 'Système (Material You)';

  @override
  String get themeLightPeach => 'Pêche Clair';

  @override
  String get themeLightLavender => 'Lavande';

  @override
  String get themeDarkPeach => 'Pêche Sombre';

  @override
  String get themeLightGrok => 'Grok Clair';

  @override
  String get themeDarkGrok => 'Grok Sombre';

  @override
  String get favoritesAddAnyFile => 'Ajouter un fichier ou une photo';

  @override
  String get favoritesPhotosEmpty => 'Pas encore de photos';

  @override
  String get favoritesPhotosEmptyHint =>
      'Appuyez sur le trombone pour ajouter des photos';

  @override
  String get langSystem => 'Système';

  @override
  String get langRussian => 'Russe';

  @override
  String get langEnglish => 'Anglais';

  @override
  String get langFrench => 'Français';

  @override
  String get dev => 'Dev';

  @override
  String get devMode => 'Mode développeur';

  @override
  String get devPassword => 'Mot de passe développeur';

  @override
  String get devWrongPassword => 'Mot de passe incorrect';

  @override
  String get devHrtTracking => 'Thérapie hormonale substitutive (THS)';

  @override
  String get devTestNotification => 'Notification de test';

  @override
  String get devScheduleDaily => 'Programmer quotidien';

  @override
  String get devCancelAll => 'Annuler tout';

  @override
  String get devCheckPermissions => 'Vérifier les permissions';

  @override
  String get devClearAllData => 'Effacer toutes les données';

  @override
  String get hrtTime => 'Heure de prise THS';

  @override
  String get hrtDosage => 'Dosage THS';

  @override
  String get license => 'Licence: MIT';

  @override
  String get sortNewest => 'Nouveaux d\'abord';

  @override
  String get sortOldest => 'Anciens d\'abord';

  @override
  String get sortAlpha => 'Alphabétique';

  @override
  String get githubLink => 'github.com/wxstdo-boop/Ataraxy';

  @override
  String get themeMutilated => 'MUTILATED';

  @override
  String get testNotification => 'Notification de test';

  @override
  String get devScheduleDailyHint =>
      'Planifier un rappel de test dans une minute';

  @override
  String get devPermissionsTitle => 'Permissions';

  @override
  String get devPermissionsHint =>
      'Vérifier les notifications et les alarmes exactes';

  @override
  String get devClearAllHint =>
      'ATTENTION : supprime toutes les entrées et réglages';

  @override
  String get devFullReset => 'Réinitialisation complète';

  @override
  String get devFullResetConfirm =>
      'Cela supprimera TOUTES les entrées et réglages. Êtes-vous sûr ?';

  @override
  String get devResetTriggered => 'Réinitialisation déclenchée';

  @override
  String get ok => 'OK';

  @override
  String get aiAssistant => 'Assistant IA';

  @override
  String get aiInputHint => 'Interrogez vos entrées…';

  @override
  String get aiThinking => 'Réflexion…';

  @override
  String get aiEmptyTitle => 'Bonjour ! Je suis votre assistant IA';

  @override
  String get aiEmptyHint =>
      'J\'analyse votre journal : rêves, vie, tulpas. Interrogez-moi sur les schémas, demandez un résumé ou une création d\'entrée.';

  @override
  String aiAnalyzes(Object n) {
    return 'Je vois $n entrées dans votre journal';
  }

  @override
  String get aiDailyLimitReached => 'Limite quotidienne de messages atteinte';

  @override
  String get aiError => 'Erreur IA';

  @override
  String get aiEntryCreated => '✅ Entrée créée';

  @override
  String get aiEntryUpdated => '✅ Entrée mise à jour';

  @override
  String get aiCommandError => '⚠ Impossible d\'exécuter la commande';

  @override
  String get aiSettingsTitle => 'Assistant IA';

  @override
  String get aiSettingsHint =>
      'Chat intelligent sur vos entrées (appui long sur «+»)';

  @override
  String get aiProvider => 'Fournisseur';

  @override
  String get aiFree => 'gratuit, sans clé';

  @override
  String get aiKey => 'Clé API';

  @override
  String get aiKeyEmpty => 'Non défini';

  @override
  String get aiDailyLimit => 'Limite quotidienne';

  @override
  String get aiLimitPerDay => 'messages par jour';

  @override
  String get aiLimitUnlimited => 'Illimité';

  @override
  String get aiDisabled =>
      'Assistant IA désactivé — activez-le dans les réglages';

  @override
  String get minimize => 'Réduire';

  @override
  String get aiOnline => 'en ligne';

  @override
  String get aiOnVacation =>
      'L\'IA est en vacances en ce moment ☀️ — réessayez dans un instant';

  @override
  String get aiAdaFallback =>
      'ADA temporairement indisponible (modèle non déployé) — basculé sur le fournisseur gratuit';

  @override
  String get aiAdaNotDeployed =>
      'Le modèle ADA n\'est pas encore déployé sur HuggingFace — activez un Inference Endpoint dans les réglages du modèle (Pro requis), ou utilisez Free';

  @override
  String get aiClearChat => 'Vider le chat';

  @override
  String get aiChatFull =>
      'Chat plein (1000 messages) — videz-le pour continuer';

  @override
  String get aiAdaLimitReached =>
      'Limite quotidienne ADA (100) atteinte — bascule sur le fournisseur gratuit';

  @override
  String aiRemaining(Object n) {
    return '$n messages restants aujourd\'hui';
  }

  @override
  String get close => 'Fermer';

  @override
  String get autoExportTitle => 'Export automatique';

  @override
  String get autoExportHint => 'Sauvegarde horaire dans /Download';

  @override
  String get autoExportEnabled => 'Export automatique activé';

  @override
  String get autoExportDisabled => 'Export automatique désactivé';

  @override
  String get updateTitle => 'Mettre à jour Ataraxy';

  @override
  String get updateHint =>
      'Vérifier GitHub Releases et installer la dernière version';

  @override
  String get updateChecking => 'Vérification de GitHub Releases…';

  @override
  String get updateFound => 'Version disponible :';

  @override
  String get updateDownloading => 'Téléchargement de la mise à jour';

  @override
  String get updateCurrent => 'Vous avez la dernière version';

  @override
  String get updatePermission =>
      'Autorisez Ataraxy à installer des applications, puis réessayez';

  @override
  String get updateInstalling =>
      'Installateur Android ouvert — confirmez la mise à jour';

  @override
  String get updateFailed =>
      'Impossible de vérifier ou installer la mise à jour';

  @override
  String get cloudBackupTitle => 'Sauvegarde & Restauration';

  @override
  String get shareBackup => 'Partager la sauvegarde';

  @override
  String get shareBackupHint =>
      'Envoyer le fichier JSON vers Google Drive, Telegram, Dropbox ou ailleurs';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get welcomeTitle => 'Bienvenue dans Ataraxy';

  @override
  String get welcomeSubtitle =>
      'Configurez l\'application pour une expérience de journal de rêves parfaite';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsDescription =>
      'Recevoir des notifications sur les nouvelles fonctionnalités';

  @override
  String get dailyReminder => 'Rappel quotidien';

  @override
  String get dailyReminderDescription =>
      'Rappeler d\'enregistrer les rêves chaque jour';

  @override
  String get security => 'Sécurité';

  @override
  String get securityDescription => 'Protéger l\'application avec un code PIN';

  @override
  String get dontShowAgain => 'Ne plus montrer';

  @override
  String get startUsing => 'Commencer à utiliser';

  @override
  String get enableNotificationsFirst => 'Activez d\'abord les notifications';

  @override
  String get setup => 'Configurer';

  @override
  String get resetSettings => 'Réinitialiser les paramètres';

  @override
  String get resetSettingsConfirm =>
      'Êtes-vous sûr de vouloir réinitialiser tous les paramètres?';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get settingsReset => 'Paramètres réinitialisés';

  @override
  String get errorResettingSettings =>
      'Erreur lors de la réinitialisation des paramètres';

  @override
  String get favoriteActivities => 'Activités préférées';

  @override
  String get favoriteActivity => 'Activité préférée';

  @override
  String get favoriteActivityBannerTitle => 'Activité préférée';

  @override
  String get favoriteActivityBannerSubtitle =>
      'Ce qui donne du sens à votre journée';

  @override
  String get favoriteActivityHint => 'Qu\'aimez-vous faire ?';

  @override
  String get favoriteActivityReading => 'Mode lecture';

  @override
  String get favoriteActivityEmpty =>
      'Aucune activité préférée pour l\'instant';

  @override
  String get favoriteActivityEmptyHint => 'Ajoutez ce qui vous inspire';

  @override
  String get favoriteActivityAdd => 'Ajouter une activité';

  @override
  String get favoriteActivityEdit => 'Modifier';

  @override
  String get favoriteActivityDelete => 'Supprimer';

  @override
  String get favoriteActivityPin => 'Épingler';

  @override
  String get favoriteActivityUnpin => 'Détacher';

  @override
  String get favoriteActivityHoldDelete => 'Maintenir pour supprimer';

  @override
  String get favoriteActivityLimit => 'caractères';

  @override
  String get closeSearch => 'Fermer la recherche';

  @override
  String get totalEntries => 'Total des entrées';

  @override
  String get sortManual => 'Manuel';

  @override
  String get favoritesBannerTitle => 'Favoris';

  @override
  String get favoritesBannerSubtitle => 'Photos, vidéos, fichiers et notes';

  @override
  String get favoritesTitle => 'Favoris';

  @override
  String get fileNotFound => 'Fichier introuvable';

  @override
  String get attachFile => 'Joindre un fichier';

  @override
  String get writeToFavorites => 'Écrire dans les favoris…';

  @override
  String get saveText => 'Enregistrer le texte';

  @override
  String get imageCropped => 'Image recadrée';

  @override
  String get crop => 'Recadrer';

  @override
  String get apply => 'Appliquer';

  @override
  String get cropHint => 'Faites glisser pour sélectionner la zone';

  @override
  String get cropTooSmall => 'Zone de recadrage trop petite';

  @override
  String get editFile => 'Modifier le fichier';

  @override
  String get editTextTitle => 'Modifier le texte';

  @override
  String get nameLabel => 'Nom';

  @override
  String get editTextHint => 'Modifier le texte…';

  @override
  String get patchNotes => 'Notes de version';

  @override
  String get whatsLeft => 'Ce qui reste à finaliser';

  @override
  String get remindersTodo => 'Rappels';

  @override
  String get autosaveTodo => 'Sauvegarde automatique';

  @override
  String get favoritesTodo => 'Favoris';

  @override
  String get steqtoqTag => 'mieux que CapCut';

  @override
  String get versionCurrent => 'actuelle';

  @override
  String get pnPinnedFix => 'L\'épinglage des messages ne glisse plus';

  @override
  String get pnBlurVideo => 'Le bouton de flou fonctionne aussi sur les vidéos';

  @override
  String get pnNotesTab =>
      'Les notes ne s\'affichent plus dans l\'onglet « Tout »';

  @override
  String get pnExport => 'Export/import : notes et épingles préservés';

  @override
  String get pnLocales => 'Localisation complète en anglais et en français';

  @override
  String get pnFavorites =>
      'Favoris : photos, vidéos, fichiers et notes au même endroit';

  @override
  String get pnHeartbeatPlayer =>
      'Barre de temps pulsante dans le lecteur vidéo';

  @override
  String get pnPatchNotesSection =>
      'Section Notes de version intégrée dans « À propos »';

  @override
  String get pn13Web =>
      'Web : avatar dans le splash et favicon de l\'application';

  @override
  String get pn13Anim =>
      'Transitions fluides : splash, thèmes, langues, onglets et types';

  @override
  String get pn13Smooth => 'Actualisation fluide et cartes avec contour animé';

  @override
  String get pn13Limits =>
      'Limites de saisie : tags (3, 10 car.), signes (10), eau (2), rappel (50)';

  @override
  String get pn13Card =>
      'Le bouton Actualiser actualise réellement les entrées';

  @override
  String get pn131Save =>
      'Les notes ne se perdent plus : sauvegarde à chaque sortie et en arrière-plan';

  @override
  String get pn131Meta =>
      'Épinglage, signes, lucidité et médicaments sont enregistrés aussitôt';

  @override
  String get pn131Export =>
      'Export : fenêtre « Enregistrer sous » au lieu d\'accéder aux fichiers';

  @override
  String get pn131Smooth =>
      'Fluidité : le fil ne se reconstruit plus lors du repli des pastilles, une seule transition';

  @override
  String get pn132Words =>
      'Perte de texte depuis le fil : déplacer et épingler n\'écrasent plus le texte';

  @override
  String get pn132Order => 'L\'ordre manuel des notes survit au redémarrage';

  @override
  String get pn132Editor =>
      'Éditeur : un échec d\'enregistrement relance l\'écriture du texte';

  @override
  String get pn132Spots =>
      'Taches colorées sous les pastilles : lisibles en thème sombre et clair';

  @override
  String get pn133Repeat =>
      'Perte de texte à la réouverture : la fiche ne transmet plus d\'ancienne copie';

  @override
  String get pn133Spots =>
      'Taches plus grandes et plus saturées : elles remplissent la pastille';

  @override
  String get importSummary => 'Importation terminée';

  @override
  String importSummaryLine(
    Object activities,
    Object entries,
    Object favorites,
  ) {
    return 'Entrées : $entries · Favoris : $favorites · Activités : $activities';
  }

  @override
  String importMediaMissing(Object n) {
    return '$n fichier(s) média des Favoris introuvable(s) sur cet appareil — ré-ouvrez Favoris pour les rattacher';
  }

  @override
  String importActivitiesTrimmed(Object n) {
    return '$n activités coupées (limite 5)';
  }

  @override
  String importItemsSkipped(Object n) {
    return '$n éléments endommagés ignorés';
  }

  @override
  String get supportButton => 'Soutenir';

  @override
  String get supportHint => 'Aider l\'application à grandir';

  @override
  String get supportThanks => 'Merci pour votre soutien ! 💖';

  @override
  String get favoriteActivityLimitReached =>
      'Vous pouvez ajouter jusqu\'à 5 activités préférées';

  @override
  String get favoriteActivityAdded => 'Activité ajoutée';

  @override
  String get favoriteActivityDeleted => 'Activité supprimée';

  @override
  String get permissions => 'Permissions';

  @override
  String get checkPermissionsAction => 'Vérifier les permissions';

  @override
  String get permissionsOk => 'Permissions OK';

  @override
  String get permissionsCheckFailed => 'Vérifiez les permissions';

  @override
  String get miuiHint =>
      'MIUI : activez le Démarrage auto et « Sans restrictions » dans Batterie — sinon les notifications en arrière-plan sont bloquées.';

  @override
  String get webHint => 'Le rappel s\'active tant que l\'onglet est ouvert.';

  @override
  String get sign_flying => 'Voler';

  @override
  String get sign_falling => 'Chute';

  @override
  String get sign_chased => 'Pourchassé';

  @override
  String get sign_teeth => 'Dents';

  @override
  String get sign_water => 'Eau';

  @override
  String get sign_school => 'École';

  @override
  String get sign_paralysis => 'Paralysie';

  @override
  String get sign_lost => 'Perdu';

  @override
  String get sign_animal => 'Animaux';

  @override
  String get sign_vehicle => 'Véhicules';

  @override
  String get sign_celebrity => 'Célébrités';

  @override
  String get sign_naked => 'Nudité';
}
