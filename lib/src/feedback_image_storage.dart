/// Where screenshot attachments end up.
enum FeedbackImageStorage {
  /// Images are compressed and embedded into the Firestore feedback
  /// document as `Blob`s in the `imgs` field (default). No Firebase Storage
  /// bucket needed — works on the free Spark plan. Kept within Firestore's
  /// 1 MiB document limit by [FeedbackImagePipeline].
  firestore,

  /// Images are uploaded to Firebase Storage and the document stores their
  /// paths instead. Requires the Blaze plan (Storage is unavailable on
  /// Spark) plus Storage security rules.
  storage,
}
