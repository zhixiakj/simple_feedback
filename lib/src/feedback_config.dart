import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'feedback_image_storage.dart';
import 'feedback_service.dart';
import 'feedback_strings.dart';

/// Optional color overrides for the feedback dialog.
///
/// Every field defaults to deriving from the host app's `ColorScheme`.
/// Override just what you need, e.g. only [primary] to brand the submit
/// button and type selector.
class FeedbackColors {
  const FeedbackColors({
    this.surface,
    this.surfaceLow,
    this.onSurface,
    this.onSurfaceVariant,
    this.primary,
    this.primaryContainer,
    this.onPrimary,
    this.outlineVariant,
    this.error,
  });

  /// Dialog background.
  final Color? surface;

  /// Background of inputs, thumbnails and the type-selector chips.
  final Color? surfaceLow;

  /// Main text color.
  final Color? onSurface;

  /// Secondary text color.
  final Color? onSurfaceVariant;

  /// Accent: selected type border, submit gradient, success icon.
  final Color? primary;

  /// Light end of the submit button gradient.
  final Color? primaryContainer;

  /// Text on the submit button.
  final Color? onPrimary;

  /// Hairline borders.
  final Color? outlineVariant;

  /// Error snack bar background.
  final Color? error;
}

/// Global configuration for [SimpleFeedback].
///
/// Usage: call `SimpleFeedback.configure(SimpleFeedbackConfig(...))` once at
/// app startup. Everything has a sensible default; a bare
/// `showSimpleFeedback(context, source: 'Home')` works out of the box once
/// `Firebase.initializeApp()` has run.
class SimpleFeedbackConfig {
  const SimpleFeedbackConfig({
    this.firebaseApp,
    this.imageStorage = FeedbackImageStorage.firestore,
    this.collection = 'feedback',
    this.storagePrefix = 'feedback',
    this.maxImages = 4,
    this.maxContentLength = 500,
    this.colors,
    this.strings,
    this.service,
  });

  /// Use a dedicated [FirebaseApp] for feedback instead of the host's
  /// default app. `null` (the default) submits through whatever
  /// `Firebase.initializeApp()` set up — typically the host app's own
  /// Firebase project.
  ///
  /// Ignored when [service] is given (the service's own instances win).
  ///
  /// To route feedback into its own Firebase project:
  ///
  /// ```dart
  /// final feedbackApp = await Firebase.initializeApp(
  ///   name: 'feedback',
  ///   options: FirebaseOptions( // the dedicated project's config
  ///     apiKey: ..., appId: ..., messagingSenderId: ...,
  ///     projectId: ..., storageBucket: ...,
  ///   ),
  /// );
  /// SimpleFeedback.configure(SimpleFeedbackConfig(firebaseApp: feedbackApp));
  /// ```
  final FirebaseApp? firebaseApp;

  /// How screenshot attachments are stored. Defaults to
  /// [FeedbackImageStorage.firestore] (embedded into the document — no
  /// Storage bucket, works on the free Spark plan). Use
  /// [FeedbackImageStorage.storage] when your project is on Blaze and you
  /// prefer bucket uploads.
  final FeedbackImageStorage imageStorage;

  /// Firestore collection the feedback documents are written to.
  final String collection;

  /// Storage path prefix for uploaded screenshots:
  /// `<storagePrefix>/<deviceId>/<timestamp>_<index>.<ext>`.
  final String storagePrefix;

  /// Maximum number of screenshot attachments per submission.
  final int maxImages;

  /// Character limit for the description field.
  final int maxContentLength;

  /// Color overrides; `null` fields follow the host `ColorScheme`.
  final FeedbackColors? colors;

  /// String overrides; `null` auto-resolves built-in strings from the
  /// ambient locale (zh/en/ja, falling back to English). Set here for a
  /// session-wide custom language; for custom strings that must follow
  /// runtime language switches, pass a per-call
  /// `showSimpleFeedback(config: ...)` instead — the global config's
  /// strings are fixed at startup.
  final FeedbackStrings? strings;

  /// Service override (mainly for tests, or full manual wiring of the
  /// Firestore/Storage instances). When given, it takes precedence over
  /// [firebaseApp]. `null` uses the default [FeedbackService], which
  /// resolves instances from [firebaseApp] or the host's default app.
  final FeedbackService? service;
}

/// Entry point for configuring the package globally.
///
/// ```dart
/// SimpleFeedback.configure(SimpleFeedbackConfig(
///   collection: 'feedback',
///   colors: FeedbackColors(primary: Color(0xFFFF8B45)),
/// ));
/// ```
class SimpleFeedback {
  SimpleFeedback._();

  static SimpleFeedbackConfig _config = const SimpleFeedbackConfig();

  /// The active configuration (defaults if [configure] was never called).
  static SimpleFeedbackConfig get config => _config;

  /// Replaces the global configuration.
  static void configure(SimpleFeedbackConfig config) => _config = config;
}
