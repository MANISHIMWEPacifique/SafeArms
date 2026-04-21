// App Transitions
// Shared page route and AnimatedSwitcher transition helpers for SafeArms.
// Use these instead of plain MaterialPageRoute for all auth and dashboard navigation.

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Page Route Builders
// ---------------------------------------------------------------------------

/// Fade-only route — used for auth flow (Login ↔ OTP).
/// Opacity 0 → 1 over [duration].
PageRoute<T> fadeRoute<T>(
  Widget page, {
  Duration duration = const Duration(milliseconds: 320),
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: duration,
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/// Slide-up + fade route — used for dashboard entry after auth.
/// Slides up 18px while fading in over [duration].
PageRoute<T> slideFadeRoute<T>(
  Widget page, {
  Duration duration = const Duration(milliseconds: 380),
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: duration,
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (_, animation, __, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04), // 4% of screen height ≈ ~18 px
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// AnimatedSwitcher Transition Builders
// ---------------------------------------------------------------------------

/// Cross-fade builder — drop-in for AnimatedSwitcher.transitionBuilder.
/// Simple opacity cross-fade; safest choice for content areas.
Widget crossFadeBuilder(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  );
}

/// Slide-up + fade builder — for tab/section switches inside dashboards.
/// New content slides up 12px while fading in.
Widget slideFadeBuilder(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.03),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// Staggered Item Helper
// ---------------------------------------------------------------------------

/// Wraps [child] in a staggered entrance animation.
/// Each item fades in and slides up, with a delay proportional to [index].
/// Cap ensures items beyond index ~10 all enter at ≤ 400 ms total duration.
Widget staggeredItem(Widget child, int index) {
  final totalDuration = Duration(
    milliseconds: (200 + (index * 45)).clamp(200, 600),
  );
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: totalDuration,
    curve: Curves.easeOut,
    builder: (_, value, __) {
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14.0 * (1.0 - value)),
          child: child,
        ),
      );
    },
    child: child,
  );
}
