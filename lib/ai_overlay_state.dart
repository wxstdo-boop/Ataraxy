import 'package:flutter/foundation.dart';

/// App-wide visibility of the floating AI assistant. Lives at the AppShell
/// level (ABOVE the Navigator) so the chat window and bubble hover over
/// EVERY section — settings, stats, favorites — and never disappear when
/// the user navigates between them.
final ValueNotifier<bool> aiOverlayOpen = ValueNotifier<bool>(false);

/// Set by the floating assistant to release the keyboard when any new route
/// is pushed on top of it. Without this, Flutter's focus restoration
/// re-opens the keyboard on the chat input the moment the user comes back
/// from another screen.
void Function()? aiReleaseKeyboard;
