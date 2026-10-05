import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_feedback/simple_feedback.dart';
import 'package:simple_feedback/src/feedback_draft.dart';

class _RecordingService extends FeedbackService {
  _RecordingService({this.error});

  final Exception? error;

  final List<Map<String, dynamic>> calls = [];

  @override
  Future<void> submit({
    required FeedbackType type,
    required String content,
    required String source,
    required String deviceId,
    String? email,
    String? sourceData,
    Map<String, dynamic>? metadata,
    List<Uint8List> images = const [],
    FeedbackImageStorage imageStorage = FeedbackImageStorage.firestore,
    String collection = 'feedback',
    String storagePrefix = 'feedback',
  }) async {
    if (error != null) throw error!;
    calls.add({
      'type': type,
      'content': content,
      'source': source,
      'deviceId': deviceId,
      'email': email,
      'sourceData': sourceData,
      'metadata': metadata,
      'images': images,
      'imageStorage': imageStorage,
    });
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FeedbackDeviceId.resetForTests();
    FeedbackDraftStore.resetForTest();
  });

  Future<void> pumpWithDialog(
    WidgetTester tester, {
    SimpleFeedbackConfig? config,
  }) async {
    // 手机比例视口：默认 800x600 太矮，弹窗内容折叠导致提交按钮 tap 落空。
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showSimpleFeedback(
                context,
                source: 'TestPage',
                config: config,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(); // dialog route
    await tester.pump(const Duration(milliseconds: 350)); // entrance animation
  }

  testWidgets('renders with built-in English strings by default',
      (tester) async {
    await pumpWithDialog(tester);
    expect(find.text('Send feedback'), findsOneWidget);
    expect(find.text('Bug'), findsOneWidget);
    expect(find.text('Suggestion'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
    expect(find.text('Page: TestPage'), findsOneWidget);
  });

  testWidgets('honours a strings override (zh)', (tester) async {
    await pumpWithDialog(
      tester,
      config: SimpleFeedbackConfig(
        strings: FeedbackStrings.builtin(const Locale('zh')),
      ),
    );
    expect(find.text('意见反馈'), findsOneWidget);
    expect(find.text('问题反馈'), findsOneWidget);
  });

  testWidgets('tapping outside a text field dismisses the keyboard',
      (tester) async {
    await pumpWithDialog(tester);

    // 内容框获得焦点 → 键盘客户端连上（相当于软键盘弹出）
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isTrue);

    // 点击输入框外的空白区域（标题）→ 失焦，键盘收起
    await tester.tap(find.text('Send feedback'));
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isFalse);

    // 邮箱框同样验证（先滚动到可见）
    await tester.ensureVisible(find.byType(TextField).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isTrue);

    await tester.tap(find.text(
        'Some issues take more than one sentence to explain — leave your email so we can follow up.'));
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isFalse);
  });

  testWidgets('empty content focuses the field instead of submitting',
      (tester) async {
    final service = _RecordingService();
    await pumpWithDialog(tester,
        config: SimpleFeedbackConfig(service: service));

    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(service.calls, isEmpty);
    expect(find.text('Send feedback'), findsOneWidget, reason: '弹窗应停留在表单页');
  });

  testWidgets('submits the selected type and content, then auto-closes',
      (tester) async {
    final service = _RecordingService();
    await pumpWithDialog(tester,
        config: SimpleFeedbackConfig(service: service));

    await tester.tap(find.text('Bug'));
    await tester.enterText(find.byType(TextField).first, '播放器在第二课卡住了');
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pump(); // submit setState
    await tester.pump(const Duration(milliseconds: 300)); // switcher transition
    await tester.pump(const Duration(milliseconds: 300)); // old form removed

    expect(service.calls, hasLength(1));
    final call = service.calls.single;
    expect(call['type'], FeedbackType.bug);
    expect(call['content'], '播放器在第二课卡住了');
    expect(call['source'], 'TestPage');
    expect(call['deviceId'], isNotEmpty);

    expect(find.text('Thanks for your feedback!'), findsOneWidget);
    expect(find.text('Send feedback'), findsNothing, reason: '应已切换到成功页');

    await tester.pump(const Duration(milliseconds: 1600)); // 1.5s delay fires
    await tester.pumpAndSettle(); // dialog exit transition
    expect(find.text('Thanks for your feedback!'), findsNothing,
        reason: '成功页 1.5 秒后应自动关闭');
  });

  testWidgets('a failing service shows the localized error snack bar',
      (tester) async {
    final service = _RecordingService(error: Exception('network down'));
    await pumpWithDialog(tester,
        config: SimpleFeedbackConfig(service: service));

    await tester.enterText(find.byType(TextField).first, 'hello');
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(
        find.text('Failed to submit, please try again later'), findsOneWidget);
    expect(find.text('Send feedback'), findsOneWidget, reason: '失败后应留在表单页');
  });

  testWidgets('passes the trimmed email through when filled', (tester) async {
    final service = _RecordingService();
    await pumpWithDialog(tester,
        config: SimpleFeedbackConfig(service: service));

    expect(find.text('Email (optional)'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '播放器在第二课卡住了');
    await tester.enterText(find.byType(TextField).last, '  user@example.com  ');
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pump(); // submit setState
    await tester
        .pump(const Duration(milliseconds: 1600)); // 1.5s auto-close delay
    await tester.pumpAndSettle(); // dialog exit transition

    expect(service.calls, hasLength(1));
    expect(service.calls.single['email'], 'user@example.com');
  });

  testWidgets('passes a null email when left blank', (tester) async {
    final service = _RecordingService();
    await pumpWithDialog(tester,
        config: SimpleFeedbackConfig(service: service));

    await tester.enterText(find.byType(TextField).first, '建议增加倍速');
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pump(); // submit setState
    await tester
        .pump(const Duration(milliseconds: 1600)); // 1.5s auto-close delay
    await tester.pumpAndSettle(); // dialog exit transition

    expect(service.calls, hasLength(1));
    expect(service.calls.single['email'], isNull);
  });

  testWidgets('restores content, email and type after closing via the X button',
      (tester) async {
    final service = _RecordingService();
    await pumpWithDialog(tester,
        config: SimpleFeedbackConfig(service: service));

    await tester.tap(find.text('Bug'));
    await tester.enterText(find.byType(TextField).first, '播放器在第二课卡住了');
    await tester.enterText(find.byType(TextField).last, 'user@example.com');
    await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
    await tester.pumpAndSettle(); // exit transition, dispose 停入草稿

    await tester.tap(find.widgetWithText(ElevatedButton, 'open'), warnIfMissed: false); // 重新打开
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '播放器在第二课卡住了',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'user@example.com',
    );

    // 用提交记录验证类型也被恢复。
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pump(); // submit setState
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(service.calls, hasLength(1));
    expect(service.calls.single['type'], FeedbackType.bug);
    expect(service.calls.single['content'], '播放器在第二课卡住了');
    expect(service.calls.single['email'], 'user@example.com');
  });

  testWidgets('clears the draft after a successful submit', (tester) async {
    final service = _RecordingService();
    await pumpWithDialog(tester,
        config: SimpleFeedbackConfig(service: service));

    await tester.enterText(find.byType(TextField).first, '建议增加倍速');
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle(); // 成功页 1.5s 后自动关闭并清空草稿

    await tester.tap(find.widgetWithText(ElevatedButton, 'open'), warnIfMissed: false); // 重新打开
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '',
      reason: '提交成功后重开应为空白表单',
    );
  });

  testWidgets('closing with nothing entered parks no draft', (tester) async {
    await pumpWithDialog(tester);

    await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'open'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '',
    );
  });
}
