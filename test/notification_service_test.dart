import 'package:flutter_test/flutter_test.dart';
import 'package:dream_journal/services/notification_service.dart';

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
}
