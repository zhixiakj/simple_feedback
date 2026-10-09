## 1.1.1

* Fixed the "Buy me a coffee" QR images in the README not rendering on
  pub.dev: relative image paths are pruned there, so the images now use
  absolute URLs (pre-resized to 300 px wide, since pub.dev strips the
  `width` attribute).

## 1.1.0

* Optional developer-supplied `userId`: pass it per call
  (`showSimpleFeedback(userId: ...)` / `SimpleFeedbackButton(userId: ...)`)
  or globally (`SimpleFeedbackConfig(userId: ...)`); per call wins. Recorded
  as the `userId` field on every feedback document so submissions can be
  correlated with real users. Blank/whitespace values are treated as absent.
* New `FeedbackEmailVisibility` enum (`always` / `hideWithUserId` /
  `never`) via `SimpleFeedbackConfig.emailVisibility`. Default
  `hideWithUserId`: the optional email input hides automatically once a
  `userId` is attached — no extra configuration needed; use `always` to keep
  collecting a reply-to address anyway, `never` to drop the input entirely.
* A per-call `showSimpleFeedback(config: ...)` now **merges with the global
  config field-by-field** — only the fields you set are overridden,
  everything else is inherited from `SimpleFeedback.configure`. (Previously
  it replaced the global config entirely, silently dropping the global
  colors/collection/service/... and falling back to package defaults.)
* When the email input is hidden, a stale draft email restored from a
  previous session is no longer submitted.
* The submit button now uses a solid `primary` color instead of a gradient;
  `FeedbackColors.primaryContainer` no longer affects it (it still tones the
  success icon).

## 1.0.1

* Fix README install example to use `^1.0.0`.

## 1.0.0

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
