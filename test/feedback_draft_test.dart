import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:simple_feedback/src/feedback_draft.dart';
import 'package:simple_feedback/simple_feedback.dart';

/// 600x400 的真随机噪声图：PNG 体积远超 200KB 预算，保证压缩真实发生。
/// 固定种子保持可复现。
Uint8List _noisyPng() {
  final random = Random(11);
  final image = img.Image(width: 600, height: 400);
  for (final p in image) {
    p
      ..r = random.nextInt(256)
      ..g = random.nextInt(256)
      ..b = random.nextInt(256);
  }
  return img.encodePng(image);
}

void main() {
  setUp(FeedbackDraftStore.resetForTest);

  test('文字与图片入库，图片压进单张预算', () async {
    final source = _noisyPng();
    expect(source.length, greaterThan(FeedbackImagePipeline.maxPerImageBytes));

    await FeedbackDraftStore.save(
      content: '播放器在第二课卡住了',
      email: 'user@example.com',
      type: FeedbackType.bug,
      images: [source],
    );

    final draft = FeedbackDraftStore.peek();
    expect(draft, isNotNull);
    expect(draft!.content, '播放器在第二课卡住了');
    expect(draft.email, 'user@example.com');
    expect(draft.type, FeedbackType.bug);
    expect(draft.images, hasLength(1));
    expect(draft.images.single.length,
        lessThanOrEqualTo(FeedbackImagePipeline.maxPerImageBytes));
  });

  test('上一份草稿里的压缩产物被原对象复用，不重编码', () async {
    await FeedbackDraftStore.save(
      content: 'a',
      email: '',
      type: FeedbackType.suggestion,
      images: [_noisyPng()],
    );
    final kept = FeedbackDraftStore.peek()!.images.single;

    await FeedbackDraftStore.save(
      content: 'a',
      email: '',
      type: FeedbackType.suggestion,
      images: [kept],
    );

    expect(FeedbackDraftStore.peek()!.images.single, same(kept));
  });

  test('压不进预算的图片被跳过，文字照常保留', () async {
    final hopeless =
        Uint8List(FeedbackImagePipeline.maxPerImageBytes + 1); // 无法解码

    await FeedbackDraftStore.save(
      content: 'hello',
      email: '',
      type: FeedbackType.other,
      images: [hopeless],
    );

    final draft = FeedbackDraftStore.peek();
    expect(draft, isNotNull);
    expect(draft!.content, 'hello');
    expect(draft.images, isEmpty);
  });

  test('无文字且无图片视为空草稿，直接清空', () async {
    await FeedbackDraftStore.save(
      content: '   ',
      email: 'user@example.com',
      type: FeedbackType.suggestion,
      images: const [],
    );
    expect(FeedbackDraftStore.peek(), isNull);
  });

  test('save 进行中被 clear 打断，不再回写', () async {
    final pending = FeedbackDraftStore.save(
      content: 'x',
      email: '',
      type: FeedbackType.bug,
      images: [_noisyPng()],
    );
    FeedbackDraftStore.clear();
    await pending;

    expect(FeedbackDraftStore.peek(), isNull);
  });

  test('clear 后重开为空，resetForTest 兜底隔离用例', () async {
    await FeedbackDraftStore.save(
      content: 'x',
      email: '',
      type: FeedbackType.bug,
      images: const [],
    );
    FeedbackDraftStore.clear();
    expect(FeedbackDraftStore.peek(), isNull);
  });
}
