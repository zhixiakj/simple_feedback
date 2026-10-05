import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart';

/// Thrown when an image cannot be squeezed under the byte budget.
class FeedbackImageTooLargeException implements Exception {
  const FeedbackImageTooLargeException();

  @override
  String toString() => 'FeedbackImageTooLargeException: image exceeds budget';
}

/// Shrinks screenshot attachments to fit Firestore's 1 MiB document limit.
///
/// Firestore hard-caps a whole document at 1 MiB, so images embedded into
/// the feedback document must be aggressively compressed:
/// decode → resize the longest side → re-encode as JPEG, stepping down
/// quality/size until within budget. Images that cannot be decoded (already
/// tiny test bytes, corrupt data) pass through unchanged as long as they
/// fit the budget themselves.
class FeedbackImagePipeline {
  FeedbackImagePipeline._();

  /// Per-image budget. Four images + text must stay below [maxTotalBytes].
  static const int maxPerImageBytes = 200 * 1024;

  /// Total budget for all images of one submission (document limit is 1 MiB;
  /// leave room for the text and metadata fields).
  static const int maxTotalBytes = 900 * 1024;

  /// (quality, maxSide) stages, tried in order until the budget is met.
  /// Real screenshots/photos pass in the first stages; the deep stages only
  /// serve pathological inputs (pure noise, huge collages).
  static const List<(int, int)> _stages = [
    (70, 1280),
    (55, 1280),
    (55, 960),
    (45, 840),
    (35, 720),
    (30, 560),
    (25, 480),
  ];

  /// Processes every image and enforces the total budget.
  ///
  /// Throws [FeedbackImageTooLargeException] when a single image cannot be
  /// squeezed under [maxPerImageBytes] or the batch exceeds
  /// [maxTotalBytes].
  static List<Uint8List> processAll(List<Uint8List> images) {
    final processed = [for (final bytes in images) process(bytes)];
    final total = processed.fold<int>(0, (sum, b) => sum + b.length);
    if (total > maxTotalBytes) {
      throw const FeedbackImageTooLargeException();
    }
    return processed;
  }

  /// Compresses one image to a JPEG within [maxPerImageBytes].
  static Uint8List process(Uint8List bytes) {
    final decoded = _tryDecode(bytes);
    if (decoded == null) {
      // Undecodable (corrupt bytes, or test fixtures): pass through if it
      // already fits, otherwise there is nothing we can shrink.
      if (bytes.length <= maxPerImageBytes) return bytes;
      throw const FeedbackImageTooLargeException();
    }

    // 同一尺寸只缩放一次（相邻档位常共享 maxSide）。
    final scaledBySide = <int, Image>{};
    Image scaled(int side) =>
        scaledBySide.putIfAbsent(side, () => _resizeLongestSide(decoded, side));

    for (final (quality, maxSide) in _stages) {
      final encoded = encodeJpg(scaled(maxSide), quality: quality);
      if (encoded.length <= maxPerImageBytes) return encoded;
    }
    throw const FeedbackImageTooLargeException();
  }

  static Image? _tryDecode(Uint8List bytes) {
    try {
      return decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Scales [image] so its longest side is at most [maxSide]; returns it
  /// unchanged when already small enough.
  static Image _resizeLongestSide(Image image, int maxSide) {
    final longest = max(image.width, image.height);
    if (longest <= maxSide) return image;
    final scale = maxSide / longest;
    return copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
  }
}
