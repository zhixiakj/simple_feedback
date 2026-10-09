/// When the optional email input is shown in the feedback dialog.
enum FeedbackEmailVisibility {
  /// Always show the email input, even when a `userId` is attached —
  /// useful when the user id is not a reachable contact channel and you
  /// still want an optional reply-to address.
  always,

  /// Hide the email input whenever a `userId` is attached (the default) —
  /// the developer already knows who is submitting, so asking for an
  /// email again is just friction.
  hideWithUserId,

  /// Never show the email input.
  never,
}
