import 'dart:ui' show Locale;

/// All user-visible strings of the feedback dialog.
///
/// Built-in translations for Chinese, English and Japanese are provided via
/// [FeedbackStrings.builtin]. Pass an instance to
/// [SimpleFeedbackConfig.strings] to override them (or to add languages).
///
/// Resolution order (evaluated on every dialog open): a config-provided
/// override wins; otherwise the ambient locale (`Localizations.localeOf`,
/// falling back to the device locale) picks a built-in translation; any
/// language without a built-in translation falls back to English. See the
/// package README for the full default-strings table.
class FeedbackStrings {
  const FeedbackStrings({
    required this.title,
    required this.subtitle,
    required this.typeLabel,
    required this.typeBug,
    required this.typeSuggestion,
    required this.typeOther,
    required this.contentLabel,
    required this.contentHint,
    required this.emailLabel,
    required this.emailHint,
    required this.sourceDataTitle,
    required this.readOnly,
    required this.screenshotsLabel,
    required this.addScreenshotTitle,
    required this.captureCurrentPage,
    required this.pickFromGallery,
    required this.pageLabelPrefix,
    required this.submit,
    required this.successTitle,
    required this.successSubtitle,
    required this.errorSubmit,
    required this.errorUpload,
    required this.errorCapture,
    required this.errorPick,
  });

  /// Resolves the built-in strings for [locale]; falls back to English for
  /// languages without a translation.
  factory FeedbackStrings.builtin(Locale locale) {
    final map = _builtins[locale.languageCode] ?? _builtins['en']!;
    return map;
  }

  static final Map<String, FeedbackStrings> _builtins = {
    'zh': _zh,
    'en': _en,
    'ja': _ja,
  };

  // ── Dialog header ──
  final String title;
  final String subtitle;

  // ── Type selector ──
  final String typeLabel;
  final String typeBug;
  final String typeSuggestion;
  final String typeOther;

  // ── Content input ──
  final String contentLabel;
  final String contentHint;

  // ── Email (optional contact) ──
  final String emailLabel;
  final String emailHint;

  // ── Read-only attached context block ──
  final String sourceDataTitle;
  final String readOnly;

  // ── Screenshots ──
  final String screenshotsLabel;
  final String addScreenshotTitle;
  final String captureCurrentPage;
  final String pickFromGallery;

  // ── Page tag / submit ──
  final String pageLabelPrefix;
  final String submit;

  // ── Success state ──
  final String successTitle;
  final String successSubtitle;

  // ── Errors ──
  final String errorSubmit;
  final String errorUpload;
  final String errorCapture;
  final String errorPick;

  /// Hint next to the screenshots label, e.g. "optional, up to 4".
  String screenshotsHint(int maxImages) {
    final template = _screenshotsHintTemplates[languageCode] ?? _screenshotsHintTemplates['en']!;
    return template.replaceFirst('%d', '$maxImages');
  }

  /// Snack bar shown when the user tries to exceed the image limit.
  String errorTooManyImages(int maxImages) {
    final template = _tooManyImagesTemplates[languageCode] ?? _tooManyImagesTemplates['en']!;
    return template.replaceFirst('%d', '$maxImages');
  }

  /// Language code of this instance; used to pick the right plural template.
  String get languageCode {
    for (final entry in _builtins.entries) {
      if (identical(entry.value, this)) return entry.key;
    }
    return 'en';
  }

  static const Map<String, String> _screenshotsHintTemplates = {
    'zh': '选填，最多 %d 张',
    'en': 'optional, up to %d',
    'ja': '任意、最大%d枚',
  };

  static const Map<String, String> _tooManyImagesTemplates = {
    'zh': '最多 %d 张图片',
    'en': 'Up to %d images',
    'ja': '画像は最大%d枚です',
  };

  static const FeedbackStrings _zh = FeedbackStrings(
    title: '意见反馈',
    subtitle: '你的反馈对我们非常重要',
    typeLabel: '反馈类型',
    typeBug: '问题反馈',
    typeSuggestion: '功能建议',
    typeOther: '其他',
    contentLabel: '详细描述',
    contentHint: '请描述你遇到的问题或建议...',
    emailLabel: '邮箱（选填）',
    emailHint: '有些问题一句话说不清，留下邮箱方便我们和你继续沟通',
    sourceDataTitle: '附带的信息',
    readOnly: '只读',
    screenshotsLabel: '截图',
    addScreenshotTitle: '添加截图',
    captureCurrentPage: '截取当前页面',
    pickFromGallery: '从相册选择',
    pageLabelPrefix: '所在页面',
    submit: '提交反馈',
    successTitle: '感谢你的反馈！',
    successSubtitle: '我们会认真阅读每一条反馈',
    errorSubmit: '提交失败，请稍后重试',
    errorUpload: '图片处理失败，请换一张或减少张数试试',
    errorCapture: '截图失败，请重试',
    errorPick: '选择图片失败',
  );

  static const FeedbackStrings _en = FeedbackStrings(
    title: 'Send feedback',
    subtitle: 'Your feedback matters to us',
    typeLabel: 'Type',
    typeBug: 'Bug',
    typeSuggestion: 'Suggestion',
    typeOther: 'Other',
    contentLabel: 'Description',
    contentHint: 'Describe the problem or your suggestion...',
    emailLabel: 'Email (optional)',
    emailHint:
        'Some issues take more than one sentence to explain — leave your email so we can follow up.',
    sourceDataTitle: 'Attached context',
    readOnly: 'read-only',
    screenshotsLabel: 'Screenshots',
    addScreenshotTitle: 'Add screenshot',
    captureCurrentPage: 'Capture current page',
    pickFromGallery: 'Choose from gallery',
    pageLabelPrefix: 'Page',
    submit: 'Submit',
    successTitle: 'Thanks for your feedback!',
    successSubtitle: 'We read every piece of feedback carefully',
    errorSubmit: 'Failed to submit, please try again later',
    errorUpload: 'Failed to process images — try another one or fewer',
    errorCapture: 'Capture failed, please try again',
    errorPick: 'Failed to pick image',
  );

  static const FeedbackStrings _ja = FeedbackStrings(
    title: 'フィードバック',
    subtitle: 'あなたの声をお聞かせください',
    typeLabel: '種類',
    typeBug: '不具合',
    typeSuggestion: '提案',
    typeOther: 'その他',
    contentLabel: '詳細',
    contentHint: '問題やご提案をご記入ください...',
    emailLabel: 'メールアドレス（任意）',
    emailHint: '一言では伝えきれない場合にご連絡できるよう、メールアドレスを残していただけると幸いです',
    sourceDataTitle: '添付情報',
    readOnly: '読み取り専用',
    screenshotsLabel: 'スクリーンショット',
    addScreenshotTitle: 'スクリーンショットを追加',
    captureCurrentPage: '現在の画面を撮る',
    pickFromGallery: 'アルバムから選択',
    pageLabelPrefix: 'ページ',
    submit: '送信',
    successTitle: 'フィードバックありがとうございます！',
    successSubtitle: 'ひとつひとつ丁寧に読ませていただきます',
    errorSubmit: '送信に失敗しました。しばらくしてからもう一度お試しください',
    errorUpload: '画像の処理に失敗しました。別の画像か少なめの枚数でお試しください',
    errorCapture: 'キャプチャに失敗しました。もう一度お試しください',
    errorPick: '画像の選択に失敗しました',
  );
}
