import 'dart:convert';

import 'package:ataraxy/services/update_checker.dart';
import 'package:ataraxy/services/github_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _release(String tag) => {
      'tag_name': tag,
      'html_url': 'https://github.com/wxstdo-boop/Ataraxy/releases/tag/$tag',
      'draft': false,
      'prerelease': false,
      'assets': [
        {
          'name': 'Ataraxy-$tag.apk',
          'browser_download_url':
              'https://github.com/wxstdo-boop/Ataraxy/releases/download/$tag/Ataraxy-$tag.apk',
          'size': 123,
        },
      ],
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('finds a newer release on the first launch', () async {
    var requests = 0;
    final checker = UpdateChecker(
      service: GithubUpdateService(
        client: MockClient((_) async {
          requests++;
          return http.Response(jsonEncode(_release('v1.4.0')), 200);
        }),
        currentVersion: '1.3.32',
      ),
    );

    final release = await checker.checkIfDue();

    expect(release?.version, '1.4.0');
    expect(requests, 1);
  });

  test('does not ask GitHub twice within a day', () async {
    // Without the gate, every launch of the app hits the API — the 60/hour
    // unauthenticated limit is shared per IP, so a busy user starts seeing
    // failed checks instead of updates.
    var requests = 0;
    Future<void> run() async {
      final checker = UpdateChecker(
        service: GithubUpdateService(
          client: MockClient((_) async {
            requests++;
            return http.Response(jsonEncode(_release('v1.4.0')), 200);
          }),
          currentVersion: '1.3.32',
        ),
      );
      await checker.checkIfDue();
    }

    await run();
    await run();
    await run();

    expect(requests, 1);
  });

  test('records a failed attempt so an offline device stops retrying', () async {
    var requests = 0;
    Future<GithubRelease?> run() {
      return UpdateChecker(
        service: GithubUpdateService(
          client: MockClient((_) async {
            requests++;
            return http.Response('boom', 500);
          }),
          currentVersion: '1.3.32',
        ),
      ).checkIfDue();
    }

    expect(await run(), isNull);
    expect(await run(), isNull);
    expect(requests, 1);
  });

  test('returns nothing when the installed build is the latest', () async {
    final checker = UpdateChecker(
      service: GithubUpdateService(
        client: MockClient(
          (_) async => http.Response(jsonEncode(_release('v1.3.32')), 200),
        ),
        currentVersion: '1.3.32',
      ),
    );

    expect(await checker.checkIfDue(), isNull);
  });
}
