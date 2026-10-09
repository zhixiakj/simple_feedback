/// An in-app feedback dialog backed by Firebase (Firestore + Storage).
///
/// Quick start:
///
/// ```dart
/// // after Firebase.initializeApp():
/// SimpleFeedback.configure(SimpleFeedbackConfig(
///   colors: FeedbackColors(primary: Color(0xFFFF8B45)),
/// ));
///
/// // anywhere:
/// showSimpleFeedback(context, source: 'HomePage');
/// ```
library;

export 'src/feedback_button.dart';
export 'src/feedback_config.dart';
export 'src/feedback_device_id.dart';
export 'src/feedback_dialog.dart'
    show showSimpleFeedback, captureBoundary;
export 'src/feedback_email_visibility.dart';
export 'src/feedback_image_pipeline.dart';
export 'src/feedback_image_storage.dart';
export 'src/feedback_service.dart';
export 'src/feedback_strings.dart';
export 'src/feedback_type.dart';
