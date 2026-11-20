import 'package:ataraxy/compat/material.dart';

import 'package:ataraxy/services/notification_service.dart';
import 'strings.dart';

/// Renders a [PermissionReport] as localized, line-per-permission text.
///
/// The service returns raw verdicts precisely so this text can be built with a
/// `BuildContext`; it used to be a Russian string assembled inside the service.
String permissionReportText(BuildContext context, PermissionReport report) {
  final lines = <String>[];
  for (final check in report.checks) {
    final label = L.tr(context, _kindKey(check.kind));
    final state = L.tr(context, _stateKey(check));
    final hint = _hintKey(check);
    final suffix = hint == null ? '' : ' — ${L.tr(context, hint)}';
    lines.add('$label: $state$suffix');
  }
  return lines.join('\n');
}

String _kindKey(PermissionKind kind) => switch (kind) {
  PermissionKind.notifications => 'permNotifications',
  PermissionKind.exactAlarms => 'permExactAlarms',
  PermissionKind.batteryOptimizations => 'permBattery',
};

String _stateKey(PermissionCheck check) {
  return switch (check.outcome) {
    PermissionOutcome.granted => 'permStateGranted',
    PermissionOutcome.alreadyGranted => 'permStateAlreadyGranted',
    PermissionOutcome.denied => 'permStateDenied',
    PermissionOutcome.deniedOpenedSettings => 'permStateDeniedSettings',
    PermissionOutcome.grantedInBrowser => 'permStateGrantedBrowser',
    PermissionOutcome.deniedInBrowser => 'permStateDeniedBrowser',
  };
}

/// Extra guidance for the two denials the user must fix by hand in the system
/// settings — without it "DENIED" alone leaves them with no next step.
String? _hintKey(PermissionCheck check) {
  if (check.outcome != PermissionOutcome.deniedOpenedSettings) return null;
  return check.kind == PermissionKind.batteryOptimizations
      ? 'permHintBattery'
      : 'permHintExactAlarms';
}
