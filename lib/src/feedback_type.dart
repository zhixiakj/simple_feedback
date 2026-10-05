/// The kind of feedback a user is submitting.
enum FeedbackType {
  /// Something is broken or behaves incorrectly.
  bug('bug', '🐛'),

  /// The user proposes a new feature or improvement.
  suggestion('suggestion', '💡'),

  /// Anything else.
  other('other', '💬');

  const FeedbackType(this.value, this.emoji);

  /// Value persisted to Firestore.
  final String value;

  /// Emoji shown on the type selector.
  final String emoji;
}
