import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:simple_feedback/simple_feedback.dart';

/// Whether `Firebase.initializeApp()` succeeded. Without a configured
/// Firebase project (google-services.json / GoogleService-Info.plist) the
/// dialog still opens, but submissions will fail with an error snack bar.
var firebaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase not configured: $e');
  }

  // Brand the dialog; every color is optional and follows the app theme
  // by default.
  SimpleFeedback.configure(const SimpleFeedbackConfig(
    collection: 'feedback',
    colors: FeedbackColors(
      primary: Color(0xFFFF8B45),
      primaryContainer: Color(0xFFFFB37E),
      surface: Color(0xFFFAF5EE),
      surfaceLow: Color(0xFFFFF9F2),
    ),
  ));

  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  Locale _locale = const Locale('en');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'simple_feedback example',
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: DemoPage(
        locale: _locale,
        onLocaleChanged: (locale) => setState(() => _locale = locale),
      ),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final _boundaryKey = GlobalKey();

  /// Simulated login state: when set, the id is passed as `userId` so the
  /// submission can be correlated with the user — and (by default) the
  /// optional email input hides since the developer already knows who is
  /// reporting. See SimpleFeedbackConfig.emailVisibility to change that.
  String? _userId = 'u-42';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('simple_feedback example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!firebaseReady)
            const Card(
              color: Color(0xFFFFE7C4),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Firebase is not configured in this example app. The dialog '
                  'opens fine, but submissions will fail until you add your '
                  'own google-services.json / GoogleService-Info.plist and run '
                  'flutterfire configure. See example/README.md.',
                ),
              ),
            ),
          const SizedBox(height: 8),
          SegmentedButton<Locale>(
            segments: const [
              ButtonSegment(value: Locale('en'), label: Text('EN')),
              ButtonSegment(value: Locale('zh'), label: Text('中文')),
              ButtonSegment(value: Locale('ja'), label: Text('日本語')),
            ],
            selected: {widget.locale},
            onSelectionChanged: (selection) =>
                widget.onLocaleChanged(selection.first),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _userId == null
                          ? 'Signed out — the dialog asks for an email.'
                          : 'Signed in as $_userId — the email input hides.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () =>
                        setState(() => _userId = _userId == null ? 'u-42' : null),
                    child: Text(_userId == null ? 'Sign in' : 'Sign out'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => showSimpleFeedback(
              context,
              source: 'DemoPage',
              userId: _userId,
              metadata: const {'appVersion': '1.0.0'},
            ),
            child: const Text('Open feedback dialog'),
          ),
          const SizedBox(height: 24),
          // Everything below can be captured automatically as the first
          // screenshot when opening the dialog with screenshotKey.
          RepaintBoundary(
            key: _boundaryKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A card worth reporting',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                        'Open feedback from the button below and the card is '
                        'captured as the first screenshot automatically.'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => showSimpleFeedback(
                        context,
                        source: 'DemoCard',
                        userId: _userId,
                        sourceData: 'card: demo\nlocale: ${widget.locale}',
                        screenshotKey: _boundaryKey,
                      ),
                      child: const Text('Feedback with page capture'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
