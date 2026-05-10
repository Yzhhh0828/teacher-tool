import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Unified snackbar / toast component for consistent feedback.
///
/// Usage:
/// ```dart
/// AppSnackbar.success(context, message: 'Saved!');
/// AppSnackbar.error(context, message: 'Something went wrong');
/// AppSnackbar.info(context, message: 'Tip: try swiping left');
/// ```
class AppSnackbar {
  AppSnackbar._();

  static void success(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(context, message: message, type: _SnackType.success, duration: duration);
  }

  static void error(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(context, message: message, type: _SnackType.error, duration: duration);
  }

  static void info(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(context, message: message, type: _SnackType.info, duration: duration);
  }

  static void _show(
    BuildContext context, {
    required String message,
    required _SnackType type,
    required Duration duration,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, bgColor, fgColor) = switch (type) {
      _SnackType.success => (
          Icons.check_circle_rounded,
          Color.alphaBlend(Colors.green.withValues(alpha: 0.15), scheme.surface),
          Colors.green.shade700,
        ),
      _SnackType.error => (
          Icons.error_rounded,
          Color.alphaBlend(scheme.error.withValues(alpha: 0.15), scheme.surface),
          scheme.error,
        ),
      _SnackType.info => (
          Icons.info_rounded,
          Color.alphaBlend(scheme.primary.withValues(alpha: 0.12), scheme.surface),
          scheme.primary,
        ),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
            vertical: AppSpacing.gap3,
          ),
          duration: duration,
          content: Row(
            children: [
              Icon(icon, color: fgColor, size: 20),
              const SizedBox(width: AppSpacing.gap3),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: '关闭',
            textColor: fgColor,
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
  }
}

enum _SnackType { success, error, info }
