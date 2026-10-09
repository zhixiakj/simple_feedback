import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'feedback_email_visibility.dart';
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

  /// Accent: selected type border, submit button, success icon.
  final Color? primary;

  /// Light accent for the success icon.
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
///
/// A per-call `showSimpleFeedback(config: ...)` **merges with the global
/// config field-by-field** (see [merge]): only the fields you set are
/// overridden, everything else is inherited from
/// `SimpleFeedback.configure`.
class SimpleFeedbackConfig {
  const SimpleFeedbackConfig({
    this.firebaseApp,
    this.userId,
    FeedbackEmailVisibility? emailVisibility,
    FeedbackImageStorage? imageStorage,
    String? collection,
    String? storagePrefix,
    int? maxImages,
    int? maxContentLength,
    this.colors,
    this.strings,
    this.service,
  })  : _emailVisibility = emailVisibility,
        _imageStorage = imageStorage,
        _collection = collection,
        _storagePrefix = storagePrefix,
        _maxImages = maxImages,
        _maxContentLength = maxContentLength;

  // Fields with package defaults are stored "unset" (null) so a per-call
  // config can inherit them from the global config; the public getters
  // below resolve the effective value (set value ?? package default).
  final FeedbackEmailVisibility? _emailVisibility;
  final FeedbackImageStorage? _imageStorage;
  final String? _collection;
  final String? _storagePrefix;
  final int? _maxImages;
  final int? _maxContentLength;

  /// Returns a config where every field unset on `this` is taken from
  /// [base], so a per-call config overrides only what it explicitly sets.
  /// Fields set on neither side resolve to the package defaults via the
  /// getters.
  SimpleFeedbackConfig merge(SimpleFeedbackConfig base) =>
      SimpleFeedbackConfig(
        firebaseApp: firebaseApp ?? base.firebaseApp,
        userId: userId ?? base.userId,
        emailVisibility: _emailVisibility ?? base._emailVisibility,
        imageStorage: _imageStorage ?? base._imageStorage,
        collection: _collection ?? base._collection,
        storagePrefix: _storagePrefix ?? base._storagePrefix,
        maxImages: _maxImages ?? base._maxImages,
        maxContentLength: _maxContentLength ?? base._maxContentLength,
        colors: colors ?? base.colors,
        strings: strings ?? base.strings,
        service: service ?? base.service,
      );

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

  /// Developer-supplied user id recorded as the `userId` field on every
  /// feedback document, so submissions can be correlated with real users
  /// (the anonymous device id is always recorded separately as
  /// `deviceId`).
  ///
  /// A per-call `showSimpleFeedback(userId: ...)` /
  /// `SimpleFeedbackButton(userId: ...)` takes precedence over this value.
  /// Update it on login/logout by calling `SimpleFeedback.configure` again,
  /// or pass it per call when the login state changes often.
  final String? userId;

  /// When the optional email input is shown in the dialog. Defaults to
  /// [FeedbackEmailVisibility.hideWithUserId] — once a [userId] is
  /// attached the developer already knows who is submitting, so the email
  /// input hides automatically. Use [FeedbackEmailVisibility.always] to
  /// keep collecting a reply-to address anyway, or
  /// [FeedbackEmailVisibility.never] to drop the input entirely.
  FeedbackEmailVisibility get emailVisibility =>
      _emailVisibility ?? FeedbackEmailVisibility.hideWithUserId;

  /// How screenshot attachments are stored. Defaults to
  /// [FeedbackImageStorage.firestore] (embedded into the document — no
  /// Storage bucket, works on the free Spark plan). Use
  /// [FeedbackImageStorage.storage] when your project is on Blaze and you
  /// prefer bucket uploads.
  FeedbackImageStorage get imageStorage =>
      _imageStorage ?? FeedbackImageStorage.firestore;

  /// Firestore collection the feedback documents are written to.
  /// Defaults to `feedback`.
  String get collection => _collection ?? 'feedback';

  /// Storage path prefix for uploaded screenshots:
  /// `<storagePrefix>/<deviceId>/<timestamp>_<index>.<ext>`.
  /// Defaults to `feedback`.
  String get storagePrefix => _storagePrefix ?? 'feedback';

  /// Maximum number of screenshot attachments per submission.
  /// Defaults to 4.
  int get maxImages => _maxImages ?? 4;

  /// Character limit for the description field. Defaults to 500.
  int get maxContentLength => _maxContentLength ?? 500;

  /// Color overrides; `null` fields follow the host `ColorScheme`.
  final FeedbackColors? colors;

  /// String overrides; `null` auto-resolves built-in strings from the
  /// ambient locale (zh/en/ja, falling back to English). Set here for a
  /// session-wide custom language; for custom strings that must follow
  /// runtime language switches, pass a per-call
  /// `showSimpleFeedback(config: ...)` instead — it merges with the global
  /// config, so the global strings are only overridden for that call.
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
