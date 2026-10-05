# simple_feedback

An in-app feedback dialog for Flutter, backed by Firebase (Firestore +
Firebase Storage). No Firebase Auth required.

Users pick a feedback type (bug / suggestion / other), describe the issue,
attach screenshots — including an automatic capture of the page they are on —
and submit. Everything lands in your Firebase project, where you read it from
the console.

## Features

- 🐛💡💬 Feedback type selector
- 📝 Description with character counter (default 500)
- 📸 Up to 4 screenshot attachments:
  - automatic capture of the current page (pass a `RepaintBoundary` key),
  - gallery picker (compressed to ~70% quality)
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
     simple_feedback: ^0.1.0
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

   And Storage rules for the screenshot uploads:

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

4. (Optional) brand the dialog once at startup:

   ```dart
   SimpleFeedback.configure(const SimpleFeedbackConfig(
     collection: 'feedback',            // default
     storagePrefix: 'feedback',         // default
     maxImages: 4,                      // default
     maxContentLength: 500,             // default
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
  metadata: {'appVersion': '3.2.1'},         // merged into the document
);
```

Or drop in a ready-made button:

```dart
SimpleFeedbackButton(source: 'HomePage')
```

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
more, up to `maxImages`).

## Data model

Every submission writes one document to the `feedback` collection:

| Field        | Type     | Description                                      |
|--------------|----------|--------------------------------------------------|
| `type`       | string   | `bug` / `suggestion` / `other`                   |
| `content`    | string   | user description (max `maxContentLength`)        |
| `source`     | string   | page/screen name passed by the caller            |
| `deviceId`   | string   | anonymous per-install id                         |
| `platform`   | string   | `ios` / `android` / ...                          |
| `createdAt`  | timestamp | server timestamp                                |
| `sourceData` | string   | read-only context block, if provided             |
| `imgs`       | array    | Storage paths of the screenshots, if any         |
| *(metadata)* | any      | extra fields merged as-is                        |

Screenshots are stored at
`<storagePrefix>/<deviceId>/<millis>_<index>.png|jpg` in Firebase Storage.

A full runnable demo lives in [example/](example/).

## Localization

Built-in strings cover `zh`, `en` and `ja`, resolved from
`Localizations.localeOf` (falling back to English). Pass your own:

```dart
SimpleFeedback.configure(SimpleFeedbackConfig(
  strings: FeedbackStrings(
    // ... provide all fields for your language
  ),
));
```

## Limitations

- Submit-only by design: there is no in-app "my feedback" thread yet. Read
  submissions in the Firebase console.
- The `allow create: if true` rules accept submissions from anyone; watch the
  Firestore usage dashboard, or tighten with App Check when needed.
