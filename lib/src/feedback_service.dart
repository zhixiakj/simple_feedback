import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import 'feedback_image_pipeline.dart';
import 'feedback_image_storage.dart';
import 'feedback_type.dart';

/// Thrown when any screenshot upload fails; the whole submission is aborted
/// so no feedback document ends up with missing images.
class FeedbackUploadException implements Exception {
  const FeedbackUploadException();

  @override
  String toString() => 'FeedbackUploadException: image upload failed';
}

/// Uploads [images] for [deviceId], returning a same-length list of storage
/// paths (or `null` entries for failed uploads).
typedef FeedbackImageUploader = Future<List<String?>> Function(
  List<Uint8List> images,
  String deviceId,
  String storagePrefix,
);

/// Writes feedback documents to Firestore and screenshots to Storage.
///
/// Firebase instances are resolved in this order (first wins):
/// 1. explicit [firestore] / [storage] / [imageUploader] passed to the
///    constructor,
/// 2. [firebaseApp] when given — its Firestore/Storage via `instanceFor`,
/// 3. the host app's default FirebaseApp (`Firebase.initializeApp()`).
///
/// Instances are resolved lazily at [submit] time, so constructing a
/// `FeedbackService` never touches Firebase.
class FeedbackService {
  FeedbackService({
    FirebaseApp? firebaseApp,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FeedbackImageUploader? imageUploader,
  })  : _firebaseApp = firebaseApp,
        _firestore = firestore,
        _storage = storage,
        _imageUploader = imageUploader;

  final FirebaseApp? _firebaseApp;
  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;
  final FeedbackImageUploader? _imageUploader;

  FirebaseFirestore get _db => _firestore ?? (_firebaseApp == null
      ? FirebaseFirestore.instance
      : FirebaseFirestore.instanceFor(app: _firebaseApp));

  FirebaseStorage get _bucket => _storage ?? (_firebaseApp == null
      ? FirebaseStorage.instance
      : FirebaseStorage.instanceFor(app: _firebaseApp));

  /// Submits one feedback entry.
  ///
  /// Images always go through [FeedbackImagePipeline] first (resize +
  /// JPEG re-encode to fit the byte budget). In
  /// [FeedbackImageStorage.firestore] mode they are then embedded into the
  /// document as `Blob`s; in storage mode they are uploaded first and the
  /// document stores their paths. Any pipeline/upload failure aborts the
  /// submission with [FeedbackUploadException].
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
    List<Uint8List>? normalized;
    if (images.isNotEmpty) {
      try {
        normalized = FeedbackImagePipeline.processAll(images);
      } on FeedbackImageTooLargeException {
        throw const FeedbackUploadException();
      }
    }

    List<Blob>? imageBlobs;
    List<String>? imagePaths;
    if (normalized != null && normalized.isNotEmpty) {
      if (imageStorage == FeedbackImageStorage.firestore) {
        imageBlobs = [for (final bytes in normalized) Blob(bytes)];
      } else {
        final List<String?> results;
        if (_imageUploader != null) {
          results = await _imageUploader(normalized, deviceId, storagePrefix);
        } else {
          results = await _uploadToFirebaseStorage(
            _bucket, normalized, deviceId, storagePrefix,
          );
        }
        if (results.any((path) => path == null)) {
          throw const FeedbackUploadException();
        }
        imagePaths = results.cast<String>();
      }
    }

    final trimmedContext = sourceData?.trim();
    final trimmedEmail = email?.trim();
    final data = <String, dynamic>{
      'type': type.value,
      'content': content,
      'source': source,
      'deviceId': deviceId,
      'platform': _platformName(),
      'createdAt': FieldValue.serverTimestamp(),
      if (trimmedEmail != null && trimmedEmail.isNotEmpty)
        'email': trimmedEmail,
      if (trimmedContext != null && trimmedContext.isNotEmpty)
        'sourceData': trimmedContext,
      if (imageBlobs != null && imageBlobs.isNotEmpty) 'imgs': imageBlobs,
      if (imagePaths != null && imagePaths.isNotEmpty) 'imgs': imagePaths,
      ...?metadata,
    };

    await _db.collection(collection).add(data);
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem; // ios / android / macos / ...
  }

  /// Default uploader: concurrent uploads to
  /// `<storagePrefix>/<deviceId>/<millis>_<index>.<ext>` with content-type
  /// sniffed from the magic bytes (PNG from page capture, JPEG from gallery).
  @visibleForTesting
  static Future<List<String?>> uploadToFirebaseStorage(
    FirebaseStorage storage,
    List<Uint8List> images,
    String deviceId,
    String storagePrefix,
  ) =>
      _uploadToFirebaseStorage(storage, images, deviceId, storagePrefix);

  static Future<List<String?>> _uploadToFirebaseStorage(
    FirebaseStorage storage,
    List<Uint8List> images,
    String deviceId,
    String storagePrefix,
  ) async {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final results = await Future.wait(
      images.asMap().entries.map((entry) async {
        try {
          final isPng = _isPng(entry.value);
          final ext = isPng ? 'png' : 'jpg';
          final ref = storage.ref().child(
                '$storagePrefix/$deviceId/${millis}_${entry.key}.$ext',
              );
          await ref.putData(
            entry.value,
            SettableMetadata(
              contentType: isPng ? 'image/png' : 'image/jpeg',
            ),
          );
          return ref.fullPath;
        } catch (_) {
          return null;
        }
      }),
    );
    return results;
  }

  static bool _isPng(Uint8List bytes) {
    if (bytes.length < 8) return false;
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
  }
}
