import 'package:flutter/foundation.dart';

import 'feedback_image_pipeline.dart';
import 'feedback_type.dart';

/// A feedback draft kept between dialog opens within the app session.
///
/// Restored when the dialog reopens; cleared after a successful submit. The
/// draft dies with the process — nothing is written to disk.
class FeedbackDraft {
  const FeedbackDraft({
    required this.content,
    required this.email,
    required this.type,
    required this.images,
  });

  final String content;
  final String email;
  final FeedbackType type;

  /// Compressed copies (pipeline output, ≤ [FeedbackImagePipeline.maxPerImageBytes]
  /// each), so the parked draft never holds raw multi-megabyte captures.
  final List<Uint8List> images;
}

/// Session-scoped home for the draft the dialog parks on close.
///
/// Text/email/type land synchronously; images are compressed off the UI
/// isolate and filled in asynchronously. A generation counter invalidates
/// in-flight compression when a newer save or a clear takes over.
class FeedbackDraftStore {
  FeedbackDraftStore._();

  static FeedbackDraft? _draft;
  static int _generation = 0;

  /// Current draft, or `null` after a submit or when nothing worth keeping
  /// was entered.
  static FeedbackDraft? peek() => _draft;

  /// Parks [content]/[email]/[type] synchronously, then compresses [images]
  /// asynchronously (raw bytes kept until each replacement is ready).
  ///
  /// A draft with neither text nor images clears the store instead. The
  /// returned future completes once the images are compressed.
  static Future<void> save({
    required String content,
    required String email,
    required FeedbackType type,
    required List<Uint8List> images,
  }) async {
    if (content.trim().isEmpty && images.isEmpty) {
      clear();
      return;
    }

    final previous = _draft?.images ?? const <Uint8List>[];
    final generation = ++_generation;
    _draft = FeedbackDraft(
      content: content,
      email: email,
      type: type,
      images: List.of(images),
    );
    if (images.isEmpty) return;

    final compressed = <Uint8List>[];
    for (final bytes in images) {
      // 与上一份草稿同一对象说明已是压缩产物，避免 JPEG 一代代重编码。
      final alreadyCompressed = previous.any((b) => identical(b, bytes)) &&
          bytes.length <= FeedbackImagePipeline.maxPerImageBytes;
      if (alreadyCompressed) {
        compressed.add(bytes);
        continue;
      }
      try {
        compressed.add(await compute(FeedbackImagePipeline.process, bytes));
      } on FeedbackImageTooLargeException {
        // 压不进预算的图放弃保留（提交路径仍会给出明确报错）。
      }
      if (generation != _generation) return;
    }
    final current = _draft;
    if (generation != _generation || current == null) return;
    _draft = FeedbackDraft(
      content: current.content,
      email: current.email,
      type: current.type,
      images: compressed,
    );
  }

  /// Drops the draft (called after a successful submit).
  static void clear() {
    _generation++;
    _draft = null;
  }

  @visibleForTesting
  static void resetForTest() => clear();
}
