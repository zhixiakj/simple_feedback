import 'package:flutter/material.dart';

import 'feedback_dialog.dart';

/// A ready-made feedback button that opens the feedback dialog on tap.
///
/// ```dart
/// SimpleFeedbackButton(source: 'HomePage')
/// ```
///
/// Provide [child] to fully customize the appearance; the default look is a
/// rounded 40x40 surface container with a chat icon.
class SimpleFeedbackButton extends StatelessWidget {
  const SimpleFeedbackButton({
    super.key,
    required this.source,
    this.userId,
    this.sourceData,
    this.metadata,
    this.screenshotKey,
    this.child,
    this.icon = Icons.chat_bubble_outline,
    this.backgroundColor,
    this.iconColor,
    this.size = 40,
    this.borderRadius = 12,
  });

  /// Recorded with the submission (page name / screen id).
  final String source;

  /// Host app's user id, recorded as the `userId` field; when given, the
  /// optional email input hides by default
  /// (see [SimpleFeedbackConfig.emailVisibility]).
  final String? userId;

  /// Read-only context submitted as `sourceData`.
  final String? sourceData;

  /// Extra fields merged into the Firestore document.
  final Map<String, dynamic>? metadata;

  /// Pass the page's [RepaintBoundary] key to enable page capture.
  final GlobalKey? screenshotKey;

  /// Fully custom button content.
  final Widget? child;

  final IconData icon;

  /// Background of the default button; defaults to
  /// `ColorScheme.surfaceContainerHigh`.
  final Color? backgroundColor;

  /// Icon color of the default button; defaults to
  /// `ColorScheme.onSurfaceVariant`.
  final Color? iconColor;

  final double size;

  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => showSimpleFeedback(
        context,
        source: source,
        userId: userId,
        sourceData: sourceData,
        metadata: metadata,
        screenshotKey: screenshotKey,
      ),
      child: child ??
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor ?? scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Icon(
              icon,
              color: iconColor ?? scheme.onSurfaceVariant,
              size: size / 2,
            ),
          ),
    );
  }
}
