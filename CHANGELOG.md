## 0.1.0

* Initial release.
* `showSimpleFeedback()` dialog with type selection (bug / suggestion /
  other), description with counter, up to 4 screenshot attachments
  (automatic page capture via `RepaintBoundary` + gallery picker).
* Firebase backend: screenshots to Firebase Storage, feedback documents to
  Firestore. Submits through the host's default FirebaseApp, or a dedicated
  one via `SimpleFeedbackConfig.firebaseApp` / injected `FeedbackService`
  instances.
* Anonymous device id persisted in `SharedPreferences` (no Firebase Auth
  required).
* Built-in zh / en / ja strings, auto-resolved from the ambient locale and
  fully overridable; all colors overridable via `FeedbackColors`.
* `SimpleFeedbackButton` ready-made button widget.
