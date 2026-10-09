# simple_feedback

An in-app feedback dialog for Flutter, backed by Firestore. No Firebase Auth
required, no Storage bucket required (works on the free Spark plan).

Users pick a feedback type (bug / suggestion / other), describe the issue,
attach screenshots — including an automatic capture of the page they are on —
and submit. Everything lands in your Firebase project, where you read it from
the console.

## Features

- 🐛💡💬 Feedback type selector
- 📝 Description with character counter (default 500)
- ✉️ Optional contact-email field above the submit button — the copy invites
  users to leave an address so you can follow up (some issues need more than
  one sentence to explain); written as `email` when filled, omitted when blank
- 👤 Optional developer-supplied `userId` recorded on every submission, so
  feedback can be correlated with real users; by default the email input
  hides once a `userId` is attached (configurable via
  `FeedbackEmailVisibility`)
- 📸 Up to 4 screenshot attachments:
  - automatic capture of the current page (pass a `RepaintBoundary` key),
  - gallery picker (compressed on the platform side, then re-encoded)
- 💾 Session draft: closing the dialog — barrier tap, back button, ✕ — no
  longer loses what was typed. Text, email, type and attached images
  (compressed to ≤200 KB each) are parked in memory and restored the next
  time the dialog opens; a successful submit clears the draft. Kept in
  memory only, never written to disk.
- 🗜️ Images are resized/re-encoded (JPEG, ≤200 KB each, ≤900 KB per
  submission) and **embedded into the Firestore document** by default —
  fits Firestore's 1 MiB document limit, no Storage bucket needed; opt into
  Firebase Storage uploads with `imageStorage: FeedbackImageStorage.storage`
  if your project is on Blaze
- 🔒 Anonymous device id persisted in `SharedPreferences` — no Firebase Auth
  setup needed
- 🌏 Built-in **zh / en / ja** strings, auto-resolved from the ambient
  locale; fully overridable (add your own languages or tweak the wording)
- 🎨 Every color overridable via `FeedbackColors`; defaults follow your app's
  `ColorScheme`
- 🧩 Extra metadata (app version, experiment flags, ...) merged into every
  document

## Setup

1. Add the dependency:

   ```yaml
   dependencies:
     simple_feedback: ^1.0.0
   ```

2. Set up Firebase for your app if you haven't already
   (`flutterfire configure`, see the
   [FlutterFire docs](https://firebase.flutter.dev/docs/cli/)) and initialize
   it before `runApp`:

   ```dart
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```

3. Create the Firestore collection rules (write-only from clients — read the
   entries from the console):

   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /feedback/{doc} {
         allow create: if true;
         allow read, update, delete: if false;
       }
     }
   }
   ```

4. **(Optional, only for `imageStorage: FeedbackImageStorage.storage`)**
   Storage rules for bucket uploads. The default mode does not use Storage
   at all — skip this unless you opted in (Storage requires the Blaze plan):

   ```
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /feedback/{allPaths=**} {
         allow read: if false;
         allow create: if request.resource.size < 10 * 1024 * 1024
                       && request.resource.contentType.matches('image/.*');
       }
     }
   }
   ```

   > Note: if you use a custom `collection` / `storagePrefix` in
   > `SimpleFeedbackConfig`, adjust the rules accordingly.

5. (Optional) brand the dialog once at startup:

   ```dart
   SimpleFeedback.configure(const SimpleFeedbackConfig(
     collection: 'feedback',            // default
     storagePrefix: 'feedback',         // default
     maxImages: 4,                      // default
     maxContentLength: 500,             // default
     // userId: 'u-123',                // optional; recorded on every submission
     emailVisibility: FeedbackEmailVisibility.hideWithUserId, // default
     colors: FeedbackColors(primary: Color(0xFFFF8B45)),
   ));
   ```

### Using a separate Firebase project

By default, submissions go through the host app's default FirebaseApp (the
one `Firebase.initializeApp()` set up). To route feedback into its own
Firebase project instead — e.g. your app doesn't otherwise use Firebase, or
you want feedback data isolated — initialize a named app and pass it:

```dart
final feedbackApp = await Firebase.initializeApp(
  name: 'feedback',
  options: const FirebaseOptions(
    // values from the dedicated project's google-services /
    // GoogleService-Info.plist (named apps are not read from the plist)
    apiKey: '...',
    appId: '...',
    messagingSenderId: '...',
    projectId: '...',
    storageBucket: '...',
  ),
);

SimpleFeedback.configure(SimpleFeedbackConfig(firebaseApp: feedbackApp));
```

Precedence: an injected `service` (if you wire instances yourself) wins over
`firebaseApp`, which wins over the default app. The Firestore rules and
Storage rules above must be configured in whichever project receives the
data.

## Usage

Open the dialog from anywhere:

```dart
showSimpleFeedback(
  context,
  source: 'HomePage',                        // recorded as `source`
  userId: session.userId,                    // optional: recorded as `userId`
  metadata: {'appVersion': '3.2.1'},         // merged into the document
);
```

Or drop in a ready-made button:

```dart
SimpleFeedbackButton(source: 'HomePage')
```

### Associating feedback with users

Pass your app's user id and every submission records it as the `userId`
field — much more actionable than the anonymous `deviceId` alone:

```dart
showSimpleFeedback(context, source: 'HomePage', userId: session.userId);
SimpleFeedbackButton(source: 'HomePage', userId: session.userId);
```

You can also set it once globally instead of per call:

```dart
SimpleFeedback.configure(SimpleFeedbackConfig(userId: session.userId));
```

A per-call `userId` overrides the global one; call `SimpleFeedback.configure`
again on login/logout to keep the global value in sync.

Once a `userId` is attached, the optional email input hides automatically
(the default `FeedbackEmailVisibility.hideWithUserId`) — you already know
who is submitting. Keep collecting a reply-to address anyway with
`FeedbackEmailVisibility.always`, or drop the input entirely with
`FeedbackEmailVisibility.never`:

```dart
showSimpleFeedback(
  context,
  source: 'HomePage',
  userId: session.userId,
  config: const SimpleFeedbackConfig(
    emailVisibility: FeedbackEmailVisibility.always,
  ),
);
```

### Per-call configuration

A per-call `config` **merges with the global config field-by-field** —
only the fields you set are overridden; everything else (colors,
collection, service, ...) is inherited from `SimpleFeedback.configure`:

```dart
// global: branded colors + custom collection; per call: only strings
showSimpleFeedback(
  context,
  source: 'HomePage',
  config: SimpleFeedbackConfig(strings: stringsFor(currentLocale)),
);
```

Note that `null` means "inherit the global value" — to change a globally
set field for a single call, pass an explicit different value.

To let users attach a capture of the current page, wrap the page (or a
specific card) in a `RepaintBoundary` and pass its key:

```dart
final boundaryKey = GlobalKey();

RepaintBoundary(
  key: boundaryKey,
  child: MyPageContent(),
)

// elsewhere:
showSimpleFeedback(context, source: 'MyPage', screenshotKey: boundaryKey);
```

The captured page becomes the first screenshot (users can delete it or add
more, up to `maxImages`). If the dialog is closed with a draft parked, the
next open restores the text, email, type and the user-added images, and the
page capture is retaken fresh — restored drafts never carry a stale page
screenshot.

## Data model

Every submission writes one document to the `feedback` collection:

| Field        | Type     | Description                                      |
|--------------|----------|--------------------------------------------------|
| `type`       | string   | `bug` / `suggestion` / `other`                   |
| `content`    | string   | user description (max `maxContentLength`)        |
| `source`     | string   | page/screen name passed by the caller            |
| `deviceId`   | string   | anonymous per-install id                         |
| `userId`     | string   | developer-supplied user id, if provided          |
| `platform`   | string   | `ios` / `android` / ...                          |
| `createdAt`  | timestamp | server timestamp                                |
| `sourceData` | string   | read-only context block, if provided             |
| `email`      | string   | optional contact email, if provided              |
| `imgs`       | array of Blob (default) or path strings | screenshots, if any |
| *(metadata)* | any      | extra fields merged as-is                        |

Screenshots are compressed first (`FeedbackImagePipeline`): resized to a
1280px longest side and re-encoded as JPEG, stepping down quality/size until
≤200 KB per image and ≤900 KB per submission — safely inside Firestore's
1 MiB document limit. In `storage` mode the same compressed images are
uploaded to `feedback/<deviceId>/<millis>_<index>.jpg` in Firebase Storage
instead, and `imgs` holds their paths.

## Viewing screenshots

In the default firestore mode the images are `Blob`s in the document — the
console shows them as base64 text. Open
[tool/blob_to_image.html](tool/blob_to_image.html) locally, paste the base64,
and the picture renders (with size/format info and a download button). In
storage mode just use the Storage console's built-in image preview.

A full runnable demo lives in [example/](example/).

## Localization / 多语言

The dialog ships with built-in strings for **Chinese (zh), English (en) and
Japanese (ja)** — no configuration needed. The language is resolved every
time the dialog opens:

1. `SimpleFeedbackConfig.strings` if you passed one (full override),
2. otherwise the app's current locale (`Localizations.localeOf` — follows
   `MaterialApp` / `Get.updateLocale`),
3. otherwise the device locale,
4. any language other than zh/ja falls back to **English**.

### Built-in default strings

| Field | zh | en | ja |
|---|---|---|---|
| title | 意见反馈 | Send feedback | フィードバック |
| subtitle | 你的反馈对我们非常重要 | Your feedback matters to us | あなたの声をお聞かせください |
| typeLabel | 反馈类型 | Type | 種類 |
| typeBug | 问题反馈 | Bug | 不具合 |
| typeSuggestion | 功能建议 | Suggestion | 提案 |
| typeOther | 其他 | Other | その他 |
| contentLabel | 详细描述 | Description | 詳細 |
| contentHint | 请描述你遇到的问题或建议... | Describe the problem or your suggestion... | 問題やご提案をご記入ください... |
| emailLabel | 邮箱（选填） | Email (optional) | メールアドレス（任意） |
| emailHint | 有些问题一句话说不清，留下邮箱方便我们和你继续沟通 | Some issues take more than one sentence to explain — leave your email so we can follow up. | 一言では伝えきれない場合にご連絡できるよう、メールアドレスを残していただけると幸いです |
| sourceDataTitle | 附带的信息 | Attached context | 添付情報 |
| readOnly | 只读 | read-only | 読み取り専用 |
| screenshotsLabel | 截图 | Screenshots | スクリーンショット |
| screenshotsHint(max) | 选填，最多 {max} 张 | optional, up to {max} | 任意、最大{max}枚 |
| addScreenshotTitle | 添加截图 | Add screenshot | スクリーンショットを追加 |
| captureCurrentPage | 截取当前页面 | Capture current page | 現在の画面を撮る |
| pickFromGallery | 从相册选择 | Choose from gallery | アルバムから選択 |
| pageLabelPrefix | 所在页面 | Page | ページ |
| submit | 提交反馈 | Submit | 送信 |
| successTitle | 感谢你的反馈！ | Thanks for your feedback! | フィードバックありがとうございます！ |
| successSubtitle | 我们会认真阅读每一条反馈 | We read every piece of feedback carefully | ひとつひとつ丁寧に読ませていただきます |
| errorSubmit | 提交失败，请稍后重试 | Failed to submit, please try again later | 送信に失敗しました。しばらくしてからもう一度お試しください |
| errorUpload | 图片处理失败，请换一张或减少张数试试 | Failed to process images — try another one or fewer | 画像の処理に失敗しました。別の画像か少なめの枚数でお試しください |
| errorCapture | 截图失败，请重试 | Capture failed, please try again | キャプチャに失敗しました。もう一度お試しください |
| errorPick | 选择图片失败 | Failed to pick image | 画像の選択に失敗しました |
| errorTooManyImages(max) | 最多 {max} 张图片 | Up to {max} images | 画像は最大{max}枚です |

### Providing your own strings (other languages / rewording)

`FeedbackStrings` is a plain data class — fill in every field for your
language and pass it via the config. Example: Korean.

```dart
const koStrings = FeedbackStrings(
  title: '피드백',
  subtitle: '소중한 의견을 기다리고 있습니다',
  typeLabel: '유형',
  typeBug: '오류',
  typeSuggestion: '제안',
  typeOther: '기타',
  contentLabel: '내용',
  contentHint: '문제나 제안을 입력해 주세요...',
  // ... fill in the remaining fields, see the FeedbackStrings API docs
  submit: '보내기',
  successTitle: '피드백 감사합니다!',
  successSubtitle: '모든 피드백을 꼼꼼히 읽겠습니다',
  errorSubmit: '전송에 실패했습니다. 잠시 후 다시 시도해 주세요',
  errorUpload: '이미지 처리에 실패했습니다. 다른 이미지를 사용하거나 개수를 줄여 보세요',
  errorCapture: '캡처에 실패했습니다. 다시 시도해 주세요',
  errorPick: '이미지 선택에 실패했습니다',
);

SimpleFeedback.configure(SimpleFeedbackConfig(strings: koStrings));
```

Two ways to hand it over:

- **Startup (global):** `SimpleFeedback.configure(...)` as above — the
  strings are then fixed for the whole session.
- **Per call (dynamic):** if your app switches languages at runtime *and*
  uses custom strings, pass a config per call — it merges with the global
  config, so the global colors/collection/... stay active:

  ```dart
  showSimpleFeedback(
    context,
    source: 'HomePage',
    config: SimpleFeedbackConfig(strings: stringsFor(currentLocale)),
  );
  ```

With the built-in languages you never need the per-call form — automatic
resolution re-runs on every dialog open and follows live locale switches.

## Limitations

- Submit-only by design: there is no in-app "my feedback" thread yet. Read
  submissions in the Firebase console.
- Screenshots are capped at ~900 KB per submission (Firestore document
  limit); more or heavier images fail with a localized error.
- The `allow create: if true` rules accept submissions from anyone; watch the
  Firestore usage dashboard, or tighten with App Check when needed.

## Buy me a coffee

If this package saves you time, consider buying me a coffee ☕
(WeChat Pay on the left, Alipay on the right):

<p>
  <img src="https://raw.githubusercontent.com/zhixiakj/simple_feedback/main/weixin.png" width="300" alt="WeChat Pay" />
  &nbsp;&nbsp;
  <img src="https://raw.githubusercontent.com/zhixiakj/simple_feedback/main/zfb.png" width="300" alt="Alipay" />
</p>
