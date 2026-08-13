import 'package:flutter/widgets.dart';

/// App-wide route observer: lets any widget (e.g. the floating AI chat)
/// learn when another route is pushed on top of it. Used to release the
/// keyboard focus — without this, Flutter's focus restoration re-opens the
/// keyboard on the AI input the moment the user comes back from Settings.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
