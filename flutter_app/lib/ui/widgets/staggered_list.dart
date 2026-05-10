import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/design/tokens.dart';

/// Wraps a list child so each entry fades + slides in with a staggered delay.
///
/// Usage:
/// ```dart
/// StaggeredList(
///   children: items.map((e) => MyTile(e)).toList(),
/// )
/// ```
class StaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration interval;
  final Duration duration;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final double slideOffset;

  const StaggeredList({
    super.key,
    required this.children,
    this.interval = const Duration(milliseconds: 60),
    this.duration = AppMotion.medium,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.shrinkWrap = false,
    this.slideOffset = 16,
  });

  Widget _wrap(Widget child, int index) {
    return child
        .animate(delay: interval * index)
        .fadeIn(duration: duration, curve: Curves.easeOut)
        .moveY(
          begin: slideOffset,
          end: 0,
          duration: duration,
          curve: AppMotion.emphasized,
        );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      itemCount: children.length,
      itemBuilder: (_, i) => _wrap(children[i], i),
    );
  }
}

/// Apply staggered entrance to an arbitrary list of widgets in a Column/Wrap
/// without forcing a ListView container.
class StaggeredEntrance extends StatelessWidget {
  final List<Widget> children;
  final Duration interval;
  final Duration duration;
  final double slideOffset;
  final Axis axis;
  final CrossAxisAlignment crossAxisAlignment;

  const StaggeredEntrance({
    super.key,
    required this.children,
    this.interval = const Duration(milliseconds: 60),
    this.duration = AppMotion.medium,
    this.slideOffset = 16,
    this.axis = Axis.vertical,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    final wrapped = <Widget>[
      for (var i = 0; i < children.length; i++)
        children[i]
            .animate(delay: interval * i)
            .fadeIn(duration: duration, curve: Curves.easeOut)
            .moveY(
              begin: slideOffset,
              end: 0,
              duration: duration,
              curve: AppMotion.emphasized,
            ),
    ];
    return axis == Axis.horizontal
        ? Row(children: wrapped)
        : Column(crossAxisAlignment: crossAxisAlignment, children: wrapped);
  }
}
