import 'dart:convert';
import 'dart:io';

import 'package:ataraxy/services/github_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> releaseJson({
  String tag = 'v1.3.10',
  bool prerelease = false,
}) =>
    {
      'tag_name': tag,
      'html_url': 'https://github.com/wxstdo-boop/Ataraxy/releases/tag/$tag',
      'draft': false,
      'prerelease': prerelease,
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
  test('finds an update using numeric semantic version comparison', () async {
    final service = GithubUpdateService(
      client: MockClient((_) async => http.Response(
        jsonEncode(releaseJson()),
        200,
      )),
      currentVersion: '1.3.9',
    );

    final release = await service.checkForUpdate();

    expect(release?.version, '1.3.10');
    expect(release?.apkSize, 123);
  });

  test('does not offer the installed version again', () async {
    final service = GithubUpdateService(
      client: MockClient((_) async => http.Response(
        jsonEncode(releaseJson(tag: 'v1.3.5')),
        200,
      )),
      currentVersion: '1.3.5',
    );

    expect(await service.checkForUpdate(), isNull);
  });

  test('rejects prereleases and APKs hosted outside the repository', () {
    expect(
      () => GithubRelease.fromJson(
        releaseJson(tag: 'v1.4.0-beta.1'),
      ),
      throwsFormatException,
    );

    final json = releaseJson();
    (json['assets'] as List).single['browser_download_url'] =
        'https://example.com/Ataraxy-v1.3.10.apk';
    expect(() => GithubRelease.fromJson(json), throwsFormatException);
  });

  test('sends an explicit User-Agent for the GitHub API', () async {
    // GitHub rejects requests that lack a User-Agent. dart:io defaults one,
    // but the service must not depend on that for every possible client.
    late Map<String, String> sentHeaders;
    final service = GithubUpdateService(
      client: MockClient((request) async {
        sentHeaders = request.headers;
        return http.Response(jsonEncode(releaseJson()), 200);
      }),
      currentVersion: '1.3.9',
    );

    await service.checkForUpdate();

    expect(sentHeaders['User-Agent'], isNotEmpty);
  });

  test('offers the latest release when the build version is unknown', () async {
    // A local build passes no --dart-define=APP_VERSION. Guessing a version
    // made the app compare against a stale constant, so it either hid a real
    // update or re-offered an older one.
    final service = GithubUpdateService(
      client: MockClient((_) async => http.Response(
            jsonEncode(releaseJson()),
            200,
          )),
      currentVersion: null,
    );

    expect((await service.checkForUpdate())?.version, '1.3.10');
  });

  test('reports a failed check instead of claiming the build is current',
      () async {
    final service = GithubUpdateService(
      client: MockClient((_) async => http.Response('forbidden', 403)),
      currentVersion: '1.3.9',
    );

    expect(service.checkForUpdate(), throwsA(isA<HttpException>()));
  });
}
