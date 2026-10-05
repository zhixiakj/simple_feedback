import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A random id persisted on the device, used to (loosely) attribute feedback
/// submissions without requiring Firebase Auth.
///
/// The id survives app restarts but not reinstalls (SharedPreferences is
/// removed with the app). It is included in every feedback document as
/// `deviceId` and used as the Storage upload folder.
class FeedbackDeviceId {
  FeedbackDeviceId._();

  static const String _prefsKey = 'simple_feedback.device_id';

  static String? _cached;

  /// Returns the stable device id, creating one on first use.
  static Future<String> get() async {
    final cached = _cached;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsKey);
    if (id == null || id.isEmpty) {
      id = _generate();
      await prefs.setString(_prefsKey, id);
    }
    _cached = id;
    return id;
  }

  /// `<base36 timestamp>-<16 hex chars>`; readable and collision-safe.
  static String _generate() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = Random.secure();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$ts-$hex';
  }

  /// Resets the in-memory cache; test-only.
  static void resetForTests() => _cached = null;
}
