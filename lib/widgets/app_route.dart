import 'package:flutter/material.dart';

/// The app's single page transition: a soft cross-fade.
///
/// Every full-screen push goes through this so the whole journal reads as one
/// surface swapping content, instead of Material's default slide-in-per-page.
/// A slide plus a Hero flight (the card → detail transition) fought each other
/// and made the shared element look like it was dragging the page with it.
Route<T> fadeRoute<T>(Widget page, {Duration duration = const Duration(milliseconds: 280)}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
    transitionDuration: duration,
    reverseTransitionDuration: duration,
  );
}
