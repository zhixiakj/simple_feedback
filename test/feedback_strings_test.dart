import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_feedback/src/feedback_strings.dart';

void main() {
  group('FeedbackStrings.builtin', () {
    test('resolves zh', () {
      final s = FeedbackStrings.builtin(const Locale('zh', 'CN'));
      expect(s.title, '意见反馈');
      expect(s.typeBug, '问题反馈');
      expect(s.successTitle, '感谢你的反馈！');
      expect(s.emailLabel, '邮箱（选填）');
      expect(s.emailHint, '有些问题一句话说不清，留下邮箱方便我们和你继续沟通');
    });

    test('resolves ja', () {
      final s = FeedbackStrings.builtin(const Locale('ja'));
      expect(s.title, 'フィードバック');
      expect(s.typeBug, '不具合');
      expect(s.emailLabel, 'メールアドレス（任意）');
    });

    test('falls back to en for unknown languages', () {
      final s = FeedbackStrings.builtin(const Locale('ko'));
      expect(s.title, 'Send feedback');
      expect(s.emailLabel, 'Email (optional)');
      expect(identical(s, FeedbackStrings.builtin(const Locale('en'))), true);
    });
  });

  group('templated strings', () {
    for (final entry in const {'zh': '选填，最多 4 张', 'en': 'optional, up to 4', 'ja': '任意、最大4枚'}.entries) {
      test('screenshotsHint for ${entry.key}', () {
        final s = FeedbackStrings.builtin(Locale(entry.key));
        expect(s.screenshotsHint(4), entry.value);
      });
    }

    test('errorTooManyImages interpolates the limit', () {
      final s = FeedbackStrings.builtin(const Locale('zh'));
      expect(s.errorTooManyImages(4), '最多 4 张图片');
    });
  });
}
