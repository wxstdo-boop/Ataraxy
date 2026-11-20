/// Version of the running build.
///
/// The release workflow passes `--dart-define=APP_VERSION=<pubspec version>`,
/// so a released APK knows exactly what it is. Local builds (`flutter run`,
/// `tools/build_apk_arm64.sh`) do not pass the define, and the old fallback
/// hardcoded `1.3.5` — which is why the updater kept offering "1.3.32
/// available" to a build that was already newer, and why About claimed
/// `1.3.4` for every release since.
///
/// Keep this the ONLY place that knows the version: `GithubUpdateService`
/// compares against it and About renders it.
class AppVersion {
  AppVersion._();

  /// Injected at build time; empty for local builds.
  static const String _injected = String.fromEnvironment('APP_VERSION');

  /// `major.minor.patch` of this build, or `null` when the build did not
  /// declare one.
  ///
  /// Null is deliberate: guessing a version here made the updater compare
  /// against a stale constant, so a newer local build was told an older
  /// release was an update. Callers must treat "unknown" as "cannot check"
  /// instead of inventing a number.
  static String? get current => _injected.isEmpty ? null : _injected;

  /// Whether this build can compare itself against GitHub releases.
  static bool get isKnown => current != null;
}
