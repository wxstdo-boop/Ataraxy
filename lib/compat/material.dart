// Flutter 3.50 deprecated `package:flutter/material.dart` in favour of
// `package:material_ui/material_ui.dart` (Material is moving out of the SDK).
// The migration is not viable yet: `material_ui` declares its OWN ThemeData /
// MaterialApp / ColorScheme / GlobalMaterialLocalizations types, so the
// third-party packages this app builds on (flutter_markdown_plus,
// dynamic_color, ...) and the generated l10n file would stop type-checking.
//
// This barrel re-exports the legacy library in one place so the
// transition-period library deprecation stays out of every call site while
// `deprecated_member_use` keeps firing for genuine member-level deprecations
// elsewhere. Drop it and import `package:material_ui/material_ui.dart`
// directly once the ecosystem has migrated.
//
// ignore_for_file: deprecated_member_use
export 'package:flutter/material.dart';
