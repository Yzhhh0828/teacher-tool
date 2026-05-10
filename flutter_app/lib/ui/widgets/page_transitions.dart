import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';

/// A [CustomTransitionPage] that uses the Material fade-through effect.
/// Use this in GoRoute `pageBuilder` for shell sub-routes.
class FadeThroughPage extends CustomTransitionPage<void> {
  FadeThroughPage({
    required super.child,
    super.key,
  }) : super(
          transitionDuration: AppMotion.medium,
          reverseTransitionDuration: AppMotion.medium,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            fillColor: Colors.transparent,
            child: child,
          ),
        );
}

/// Push a route with a Material 3 SharedAxis (Z-axis) transition.
Future<T?> pushSharedAxis<T>(
  BuildContext context,
  WidgetBuilder builder, {
  SharedAxisTransitionType type = SharedAxisTransitionType.scaled,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<T>(
      transitionDuration: AppMotion.medium,
      reverseTransitionDuration: AppMotion.medium,
      pageBuilder: (ctx, animation, secondary) => builder(ctx),
      transitionsBuilder: (_, animation, secondary, child) =>
          SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondary,
        transitionType: type,
        fillColor: Colors.transparent,
        child: child,
      ),
    ),
  );
}

/// Wraps two widgets with a fade-through swap when the [child] key changes.
class FadeThroughSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const FadeThroughSwitcher({
    super.key,
    required this.child,
    this.duration = AppMotion.medium,
  });

  @override
  Widget build(BuildContext context) {
    return PageTransitionSwitcher(
      duration: duration,
      transitionBuilder: (child, animation, secondary) =>
          FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondary,
        fillColor: Colors.transparent,
        child: child,
      ),
      child: child,
    );
  }
}
