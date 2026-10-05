# simple_feedback example

A demo app with:

- a plain feedback button,
- a page-capture variant (`RepaintBoundary` + `screenshotKey`),
- a zh / en / ja locale switcher to demo the built-in strings,
- a warm custom palette via `FeedbackColors`.

## Running with your own Firebase project

The app runs without Firebase configured — the dialog opens, but submissions
fail with an error snack bar (you'll see a warning card explaining this).

To submit for real:

1. Create a Firebase project at <https://console.firebase.google.com>.
2. Add an iOS/Android app and download `GoogleService-Info.plist` /
   `google-services.json` into the matching platform folder of this example.
3. Run `flutterfire configure` in this folder to generate
   `lib/firebase_options.dart`, and switch `main.dart` to
   `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
4. Apply the Firestore and Storage rules from the package README.
5. `flutter run`.
