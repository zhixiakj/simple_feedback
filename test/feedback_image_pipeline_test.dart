import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:simple_feedback/simple_feedback.dart';

/// 1400x1050 的真随机噪声图：不可压缩（保证源图超预算）、最长边超 1280
/// （触发缩放）。固定种子保持可复现。
Uint8List _bigNoisyPng() {
  final random = Random(7);
  final image = img.Image(width: 1400, height: 1050);
  for (final p in image) {
    p..r = random.nextInt(256)
    ..g = random.nextInt(256)
    ..b = random.nextInt(256);
  }
  return img.encodePng(image);
}

void main() {
  test('大图被缩到最长边 1280 内并压进 200KB 预算', () {
    final source = _bigNoisyPng();
    expect(source.length, greaterThan(FeedbackImagePipeline.maxPerImageBytes),
        reason: '前置：原始噪声 PNG 必须超预算，否则测试无意义');

    final out = FeedbackImagePipeline.process(source);

    expect(out.length, lessThanOrEqualTo(FeedbackImagePipeline.maxPerImageBytes));
    final decoded = img.decodeImage(out);
    expect(decoded, isNotNull, reason: '输出应为可解码的 JPEG');
    final longest = decoded!.width > decoded.height
        ? decoded.width
        : decoded.height;
    expect(longest, lessThanOrEqualTo(1280));
  });

  test('无法解码的小字节原样透传（尽力而为）', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(FeedbackImagePipeline.process(bytes), same(bytes));
  });

  test('无法解码且超预算的字节直接判超限', () {
    final bytes = Uint8List(FeedbackImagePipeline.maxPerImageBytes + 1);
    expect(() => FeedbackImagePipeline.process(bytes),
        throwsA(isA<FeedbackImageTooLargeException>()));
  });

  test('单张合规但总量超 900KB 时整体判超限', () {
    final per = Uint8List(190 * 1024); // 5 × 190KB = 950KB > 900KB
    expect(
      () => FeedbackImagePipeline.processAll([per, per, per, per, per]),
      throwsA(isA<FeedbackImageTooLargeException>()),
    );
  });
}
