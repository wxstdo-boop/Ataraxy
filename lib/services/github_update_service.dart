import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class GithubRelease {
  const GithubRelease({
    required this.tag,
    required this.version,
    required this.url,
    required this.apkUrl,
    required this.apkSize,
  });

  final String tag;
  final String version;
  final String url;
  final String apkUrl;
  final int apkSize;

  factory GithubRelease.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    final releaseUrl = json['html_url'];
    final assets = json['assets'];
    if (tag is! String ||
        releaseUrl is! String ||
        assets is! List ||
        json['draft'] == true ||
        json['prerelease'] == true) {
      throw const FormatException('GitHub returned an invalid release');
    }
    final releaseUri = Uri.tryParse(releaseUrl);
    if (releaseUri == null ||
        releaseUri.scheme != 'https' ||
        releaseUri.host != 'github.com' ||
        !releaseUri.path.startsWith('/wxstdo-boop/Ataraxy/releases/tag/')) {
      throw const FormatException('Release page URL is not trusted');
    }

    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    if (!_isVersion(version)) {
      throw const FormatException('Release tag is not a stable version');
    }

    final assetName = 'Ataraxy-$tag.apk';
    Map<String, dynamic>? apk;
    for (final asset in assets.whereType<Map<String, dynamic>>()) {
      if (asset['name'] == assetName) {
        apk = asset;
        break;
      }
    }
    final apkUrl = apk?['browser_download_url'];
    final apkSize = apk?['size'];
    if (apkUrl is! String ||
        apkSize is! int ||
        apkSize <= 0 ||
        apkSize > 250 * 1024 * 1024) {
      throw const FormatException('Release does not contain a valid APK');
    }

    final uri = Uri.tryParse(apkUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        !uri.path.startsWith('/wxstdo-boop/Ataraxy/releases/download/')) {
      throw const FormatException('Release APK URL is not trusted');
    }

    return GithubRelease(
      tag: tag,
      version: version,
      url: releaseUrl,
      apkUrl: apkUrl,
      apkSize: apkSize,
    );
  }
}

class GithubUpdateService {
  GithubUpdateService({
    http.Client? client,
    required this.currentVersion,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  static const _latestReleaseUrl =
      'https://api.github.com/repos/wxstdo-boop/Ataraxy/releases/latest';
  static const _maxApkBytes = 250 * 1024 * 1024;

  final http.Client _client;
  final bool _ownsClient;
  final String currentVersion;

  Future<GithubRelease?> checkForUpdate() async {
    final response = await _client.get(
      Uri.parse(_latestReleaseUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'GitHub release check failed (${response.statusCode})',
      );
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('GitHub returned invalid release data');
    }
    final release = GithubRelease.fromJson(json);
    return _compareVersions(release.version, currentVersion) > 0
        ? release
        : null;
  }

  Future<File> findDownloadedApk(
    GithubRelease release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}updates',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}Ataraxy-${release.tag}.apk',
    );
    return await file.exists() && await file.length() == release.apkSize
        ? file
        : downloadApk(release, onProgress: onProgress);
  }

  Future<File> downloadApk(
    GithubRelease release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(release.apkUrl));
    final response = await _client.send(request);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('APK download failed (${response.statusCode})');
    }
    if (response.contentLength != null &&
        (response.contentLength! <= 0 ||
            response.contentLength! > _maxApkBytes)) {
      throw const HttpException('APK download has an invalid size');
    }

    final directory = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}updates',
    );
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}Ataraxy-${release.tag}.apk',
    );
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > _maxApkBytes || received > release.apkSize) {
          throw const HttpException('APK download exceeded the expected size');
        }
        sink.add(chunk);
        onProgress?.call(received, release.apkSize);
      }
      await sink.close();
      if (received != release.apkSize) {
        throw const HttpException('APK download was incomplete');
      }
      return file;
    } catch (_) {
      await sink.close();
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

bool _isVersion(String version) =>
    RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version);

int _compareVersions(String left, String right) {
  if (!_isVersion(left) || !_isVersion(right)) {
    throw const FormatException('Version must use major.minor.patch format');
  }
  final a = left.split('.').map(int.parse).toList();
  final b = right.split('.').map(int.parse).toList();
  for (var index = 0; index < a.length; index++) {
    final comparison = a[index].compareTo(b[index]);
    if (comparison != 0) {
      return comparison;
    }
  }
  return 0;
}
