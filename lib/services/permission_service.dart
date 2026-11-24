import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PermissionService {
  static const MethodChannel channel = MethodChannel(
    'com.example.website_webview_app/permissions',
  );

  /// Requests all necessary device runtime permissions from the user.
  static Future<bool> requestAllPermissions() async {
    try {
      final bool? granted = await channel.invokeMethod<bool>(
        'requestAllPermissions',
      );
      return granted ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error requesting permissions via MethodChannel: $e');
      return false;
    } catch (e) {
      debugPrint('Unexpected error in requestAllPermissions: $e');
      return false;
    }
  }

  /// Checks whether all permissions are currently granted.
  static Future<bool> checkPermissions() async {
    try {
      final bool? granted = await channel.invokeMethod<bool>(
        'checkPermissions',
      );
      return granted ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking permissions: $e');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves the default public storage path (e.g. /storage/emulated/0/Download).
  static Future<String?> getDefaultStoragePath() async {
    try {
      final String? path = await channel.invokeMethod<String>(
        'getDefaultStoragePath',
      );
      return path;
    } catch (e) {
      debugPrint('Error getting default storage path: $e');
      return null;
    }
  }

  /// Launches Android native folder picker dialog so user can select any folder.
  static Future<String?> pickFolder() async {
    try {
      final String? selectedPath = await channel.invokeMethod<String>(
        'pickFolder',
      );
      return selectedPath;
    } catch (e) {
      debugPrint('Error opening folder picker: $e');
      return null;
    }
  }

  /// Appends text content to a physical file on the device.
  static Future<bool> appendToFile({
    required String path,
    required String content,
  }) async {
    try {
      final bool? success = await channel.invokeMethod<bool>(
        'appendToFile',
        {'path': path, 'content': content},
      );
      return success ?? false;
    } catch (e) {
      debugPrint('Error appending to file via native bridge: $e');
      return false;
    }
  }
}
