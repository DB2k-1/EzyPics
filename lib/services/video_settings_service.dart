import 'package:shared_preferences/shared_preferences.dart';

class VideoSettingsService {
  static const String _keyMuted = 'video_muted';

  /// Get whether videos are muted
  static Future<bool> isMuted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMuted) ?? false; // Default to unmuted
  }

  /// Set mute state
  static Future<void> setMuted(bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMuted, muted);
  }

  /// Toggle mute state
  static Future<bool> toggleMute() async {
    final currentMuted = await isMuted();
    final newMuted = !currentMuted;
    await setMuted(newMuted);
    return newMuted;
  }
}

