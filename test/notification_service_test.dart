import 'package:flutter_test/flutter_test.dart';
import 'package:ataraxy/providers/chat_controller.dart';
import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/services/notification_service.dart';

void main() {
  _promptLanguageTests();
  _oemHintTests();
  _permissionReportContractTests();
  _reportWordingTests();
  group('NotificationService.parseScheduleTime', () {
    test('valid times parse to hour/minute', () {
      expect(
        NotificationService.parseScheduleTime('08:00'),
        (hour: 8, minute: 0),
      );
      expect(
        NotificationService.parseScheduleTime('8:00'),
        (hour: 8, minute: 0),
      );
      expect(
        NotificationService.parseScheduleTime('23:59'),
        (hour: 23, minute: 59),
      );
      expect(
        NotificationService.parseScheduleTime('00:00'),
        (hour: 0, minute: 0),
      );
      expect(
        NotificationService.parseScheduleTime('12:30'),
        (hour: 12, minute: 30),
      );
      // Leading/trailing whitespace is tolerated.
      expect(
        NotificationService.parseScheduleTime(' 09:15 '),
        (hour: 9, minute: 15),
      );
    });

    test('malformed times are rejected', () {
      const invalidCases = <String>[
        '0800', // missing colon
        '25:00', // out-of-range hour
        '08:60', // out-of-range minute
        '23:70', // out-of-range minute
        '1:99', // out-of-range minute
        '', // empty
        'abc', // non-numeric
        ':00', // missing hour
        '08:', // missing minute
      ];
      for (final tc in invalidCases) {
        expect(
          NotificationService.parseScheduleTime(tc),
          isNull,
          reason: 'expected "$tc" to be rejected',
        );
      }
    });
  });
}

/// `requestAllPermissions` reports verdicts as enums, so the UI never has to
/// sniff the report text.
///
/// It used to search the Russian «ОТКЛОНЕНО» substring. On iOS and desktop the
/// service answered 'OK'/'Denied', so a real denial rendered as a green success
/// snack — and the report could not be translated at all.
void _permissionReportContractTests() {
  PermissionReport reportOf(PermissionOutcome outcome) =>
      PermissionReport([PermissionCheck(PermissionKind.notifications, outcome)]);

  test('every denial outcome marks the report as denied', () {
    for (final outcome in [
      PermissionOutcome.denied,
      PermissionOutcome.deniedOpenedSettings,
      PermissionOutcome.deniedInBrowser,
    ]) {
      expect(reportOf(outcome).denied, isTrue, reason: '$outcome');
    }
  });

  test('granted outcomes never mark the report as denied', () {
    for (final outcome in [
      PermissionOutcome.granted,
      PermissionOutcome.alreadyGranted,
      PermissionOutcome.grantedInBrowser,
    ]) {
      expect(reportOf(outcome).denied, isFalse, reason: '$outcome');
    }
  });

  test('one denial among grants still marks the whole report denied', () {
    const report = PermissionReport([
      PermissionCheck(
        PermissionKind.notifications,
        PermissionOutcome.alreadyGranted,
      ),
      PermissionCheck(
        PermissionKind.exactAlarms,
        PermissionOutcome.denied,
      ),
      PermissionCheck(
        PermissionKind.batteryOptimizations,
        PermissionOutcome.granted,
      ),
    ]);
    expect(report.denied, isTrue);
  });

  test('an empty report is not denied', () {
    expect(const PermissionReport([]).denied, isFalse);
  });

  test('the report carries no user-facing wording', () {
    // Wording lives in permission_report_text.dart and follows the locale;
    // a `details` string here would silently re-introduce Russian text.
    expect(reportOf(PermissionOutcome.denied).checks.single.outcome,
        PermissionOutcome.denied);
  });
}

/// The AI reply language used to be hardcoded to Russian: the system prompt
/// told the model «всегда отвечай по-русски» regardless of the app locale, so
/// an English or French user got Russian answers.
void _promptLanguageTests() {
  group('ChatController.buildSystemPrompt', () {
    String prompt(String lang) => ChatController.buildSystemPrompt(
          languageCode: lang,
          journalContext: '',
        );

    test('names the active language', () {
      expect(prompt('en'), contains('ANSWER IN English'));
      expect(prompt('fr'), contains('ANSWER IN French'));
      expect(prompt('ru'), contains('ANSWER IN Russian'));
    });

    test('never asks for Russian when the locale is not Russian', () {
      for (final lang in ['en', 'fr']) {
        expect(
          prompt(lang),
          isNot(contains('Russian')),
          reason: 'the $lang prompt still mentions Russian',
        );
      }
    });

    test('still forbids Chinese drift in every locale', () {
      for (final lang in ['en', 'fr', 'ru']) {
        expect(prompt(lang), contains('never drift into Chinese'));
      }
    });

    test('still forbids thinking out loud in every locale', () {
      for (final lang in ['en', 'fr', 'ru']) {
        expect(prompt(lang), contains('DO NOT THINK OUT LOUD'));
      }
    });

    test('appends the journal context verbatim', () {
      final text = ChatController.buildSystemPrompt(
        languageCode: 'en',
        journalContext: 'ENTRY-42',
      );
      expect(text, contains('ENTRY-42'));
    });

    test('an unknown locale falls back to Russian', () {
      expect(prompt('de'), contains('ANSWER IN Russian'));
    });
  });
}

/// The reminder dialog used to show the MIUI battery steps to every Android
/// user, so a Samsung owner was told to find an "Autostart" menu their ROM does
/// not have. The hint now follows the actual vendor.
void _oemHintTests() {
  group('NotificationService.oemHintKey', () {
    test('xiaomi gets the MIUI hint', () {
      expect(NotificationService.oemHintKey('xiaomi'), 'oemHintXiaomi');
    });

    test('other known vendors get their own hint', () {
      expect(NotificationService.oemHintKey('huawei'), 'oemHintHuawei');
      expect(NotificationService.oemHintKey('oppo'), 'oemHintOppo');
      expect(NotificationService.oemHintKey('vivo'), 'oemHintVivo');
    });

    test('unknown, unresolved and non-Android devices get the generic hint', () {
      // "other" is what resolveOem stores on iOS, desktop, web and for vendors
      // without special battery rules; null means "not resolved yet".
      for (final oem in ['other', 'samsung', null, '', 'somethingelse']) {
        expect(
          NotificationService.oemHintKey(oem),
          'oemHintAndroid',
          reason: 'oem $oem',
        );
      }
    });

    test('the MIUI hint is never shown to a non-Xiaomi device', () {
      for (final oem in ['samsung', 'other', null]) {
        expect(NotificationService.oemHintKey(oem), isNot('oemHintXiaomi'));
      }
    });
  });
}

/// The report used to be a Russian string built inside the service, so every
/// denial read «ОТКЛОНЕНО» in en/fr too. Wording now lives in the ARB files.
void _reportWordingTests() {
  group('permission report wording', () {
    test('denial text follows the locale', () {
      for (final lang in ['ru', 'en', 'fr']) {
        final denied = L.trStatic('permStateDenied', languageCode: lang);
        expect(denied, isNotEmpty);
        if (lang != 'ru') {
          expect(
            denied,
            isNot(contains('ОТКЛОНЕНО')),
            reason: 'the $lang denial still carries Russian wording',
          );
        }
      }
    });

    test('labels exist for every permission kind', () {
      for (final key in [
        'permNotifications',
        'permExactAlarms',
        'permBattery',
      ]) {
        for (final lang in ['ru', 'en', 'fr']) {
          expect(L.trStatic(key, languageCode: lang), isNot(key));
        }
      }
    });

    test('notification channel and reminder strings are localized', () {
      for (final key in [
        'notifChannelDailyName',
        'notifChannelDailyDescription',
        'notifReminderBody',
        'reminder',
        'testNotification',
        'notifTestBody',
      ]) {
        for (final lang in ['ru', 'en', 'fr']) {
          final text = L.trStatic(key, languageCode: lang);
          expect(text, isNot(key), reason: '$key missing for $lang');
          if (lang != 'ru') {
            expect(
              text,
              isNot(matches(RegExp(r'[А-Яа-яЁё]'))),
              reason: '$key is Russian in $lang',
            );
          }
        }
      }
    });
  });
}
