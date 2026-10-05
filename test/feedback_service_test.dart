import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_feedback/simple_feedback.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
  });

  FeedbackService serviceWith({FeedbackImageUploader? uploader}) =>
      FeedbackService(firestore: db, imageUploader: uploader);

  test('writes the core fields of a text-only feedback', () async {
    await serviceWith().submit(
      type: FeedbackType.bug,
      content: '播放没声音',
      source: 'StudyPage',
      deviceId: 'dev-1',
    );

    final snap = await db.collection('feedback').get();
    expect(snap.docs, hasLength(1));
    final data = snap.docs.first.data();
    expect(data['type'], 'bug');
    expect(data['content'], '播放没声音');
    expect(data['source'], 'StudyPage');
    expect(data['deviceId'], 'dev-1');
    expect(data['platform'], isNotEmpty);
    expect(data['createdAt'], isNotNull);
    expect(data.containsKey('imgs'), isFalse,
        reason: '无图反馈不应写 imgs 字段');
    expect(data.containsKey('sourceData'), isFalse,
        reason: '无上下文不应写 sourceData 字段');
  });

  test('merges metadata as-is into the document', () async {
    await serviceWith().submit(
      type: FeedbackType.suggestion,
      content: '希望支持深色模式',
      source: 'SettingPage',
      deviceId: 'dev-1',
      metadata: {'appVersion': '3.2.1', 'abGroup': 'B'},
    );

    final data = (await db.collection('feedback').get()).docs.first.data();
    expect(data['appVersion'], '3.2.1');
    expect(data['abGroup'], 'B');
  });

  test('trims and stores sourceData; blank sourceData is omitted', () async {
    await serviceWith().submit(
      type: FeedbackType.other,
      content: 'x',
      source: 'p',
      deviceId: 'd',
      sourceData: '  rule: 连读  \n',
    );
    await serviceWith().submit(
      type: FeedbackType.other,
      content: 'y',
      source: 'p',
      deviceId: 'd',
      sourceData: '   ',
    );

    final docs = (await db.collection('feedback').get()).docs;
    expect(docs[0].data()['sourceData'], 'rule: 连读');
    expect(docs[1].data().containsKey('sourceData'), isFalse);
  });

  test('uploads images first and stores their storage paths', () async {
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);
    var uploaded = <Uint8List>[];
    final service = serviceWith(
      uploader: (images, deviceId, storagePrefix) async {
        uploaded = images;
        return [
          for (var i = 0; i < images.length; i++) '$storagePrefix/$deviceId/$i.png'
        ];
      },
    );

    await service.submit(
      type: FeedbackType.bug,
      content: '截图见附件',
      source: 'RuleDetailPage',
      deviceId: 'dev-9',
      images: [png, png],
      storagePrefix: 'fb',
    );

    expect(uploaded, hasLength(2));
    final data = (await db.collection('feedback').get()).docs.first.data();
    expect(data['imgs'], ['fb/dev-9/0.png', 'fb/dev-9/1.png']);
  });

  test('any failed upload aborts the whole submission', () async {
    final service = serviceWith(
      uploader: (images, deviceId, storagePrefix) async =>
          [for (var i = 0; i < images.length; i++) i == 1 ? null : 'ok/$i.png'],
    );

    await expectLater(
      service.submit(
        type: FeedbackType.bug,
        content: 'c',
        source: 's',
        deviceId: 'd',
        images: [Uint8List.fromList([1]), Uint8List.fromList([2])],
      ),
      throwsA(isA<FeedbackUploadException>()),
    );

    expect((await db.collection('feedback').get()).docs, isEmpty,
        reason: '上传失败时不应写入 Firestore');
  });

  test('respects the configured collection name', () async {
    await serviceWith().submit(
      type: FeedbackType.other,
      content: 'c',
      source: 's',
      deviceId: 'd',
      collection: 'app_feedback',
    );

    expect((await db.collection('feedback').get()).docs, isEmpty);
    expect((await db.collection('app_feedback').get()).docs, hasLength(1));
  });
}
