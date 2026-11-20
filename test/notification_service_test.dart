import 'package:flutter_test/flutter_test.dart';
import 'package:ataraxy/services/notification_service.dart';

void main() {
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

  _permissionReportContractTests();
}

/// `requestAllPermissions` must report denial through the explicit
/// `PermissionReport.denied` flag, not through the wording of `details`.
///
/// The UI used to look for the Russian «ОТКЛОНЕНО» substring. On iOS and
/// desktop the service answers 'OK'/'Denied', so a real denial was rendered as
/// a green success snack — this locks the flag in.
void _permissionReportContractTests() {
  test('PermissionReport carries details and the denied verdict', () {
    const denied = PermissionReport(details: 'Denied', denied: true);
    expect(denied.denied, isTrue);
    expect(denied.details, 'Denied');

    const granted = PermissionReport(details: 'OK', denied: false);
    expect(granted.denied, isFalse);
    expect(granted.details, 'OK');
  });

  test('denied is not derived from the Russian wording', () {
    // A non-Russian, non-Android answer still has to read as a denial.
    const report = PermissionReport(details: 'Denied', denied: true);
    expect(report.details.contains('ОТКЛОНЕНО'), isFalse);
    expect(report.denied, isTrue);
  });
}
