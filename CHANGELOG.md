## 0.1.0

* Initial release.
* `showSimpleFeedback()` dialog with type selection (bug / suggestion /
  other), description with counter, up to 4 screenshot attachments
  (automatic page capture via `RepaintBoundary` + gallery picker).
* Optional contact-email field above the submit button (zh/en/ja built-in
  strings); written as the `email` document field when filled, omitted when
  blank. Not validated — submitted as typed.
* Session draft: closing the dialog (barrier tap, back, ✕) no longer loses
  the entered text, email, type and images — they are parked in memory and
  restored on the next open, and cleared after a successful submit.
  In-memory only; nothing is written to disk.
* Firebase backend: feedback documents in Firestore. Screenshots are
  compressed (resize + JPEG re-encode, ≤200 KB each / ≤900 KB per
  submission) and embedded into the document as Blobs by default — no
  Storage bucket needed, works on the free Spark plan. Opt into Firebase
  Storage uploads via `FeedbackImageStorage.storage`.
* Submits through the host's default FirebaseApp, or a dedicated one via
  `SimpleFeedbackConfig.firebaseApp` / injected `FeedbackService` instances.
* Anonymous device id persisted in `SharedPreferences` (no Firebase Auth
  required).
* Built-in zh / en / ja strings, auto-resolved from the ambient locale and
  fully overridable; all colors overridable via `FeedbackColors`.
* `SimpleFeedbackButton` ready-made button widget.
* Tapping outside the description/email fields (blank dialog areas, buttons)
  now unfocuses them so the soft keyboard dismisses on Android/iOS — the
  framework default intentionally keeps touch focus on those platforms.
