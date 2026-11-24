import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import 'permission_service.dart';

class StorageService {
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    _preferences ??= await SharedPreferences.getInstance();
    return _preferences!;
  }

  /// Saves the default launch website URL in local storage and adds it to saved websites.
  Future<void> saveWebsiteUrl(String url) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(AppConstants.websiteUrlKey, url);
      await addSavedWebsite(url);
      await syncWebsiteToStorage(
        url: url,
        title: 'Default Launch Domain',
        type: 'Set Default',
      );
    } catch (e, stackTrace) {
      debugPrint('Error saving website URL: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Retrieves the default launch website URL from local storage, or null if none exists.
  Future<String?> getWebsiteUrl() async {
    try {
      final prefs = await _prefs;
      return prefs.getString(AppConstants.websiteUrlKey);
    } catch (e, stackTrace) {
      debugPrint('Error reading website URL: $e\n$stackTrace');
      return null;
    }
  }

  /// Clears the default launch website URL from local storage.
  Future<void> clearWebsiteUrl() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(AppConstants.websiteUrlKey);
    } catch (e, stackTrace) {
      debugPrint('Error clearing website URL: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Checks whether a default website URL exists in local storage.
  Future<bool> hasWebsiteUrl() async {
    try {
      final url = await getWebsiteUrl();
      return url != null && url.isNotEmpty;
    } catch (e, stackTrace) {
      debugPrint('Error checking website URL existence: $e\n$stackTrace');
      return false;
    }
  }

  /// Retrieves the complete list of all saved / searched websites.
  Future<List<String>> getSavedWebsites() async {
    try {
      final prefs = await _prefs;
      final list = prefs.getStringList(AppConstants.savedWebsitesListKey);
      return list ?? <String>[];
    } catch (e, stackTrace) {
      debugPrint('Error reading saved websites list: $e\n$stackTrace');
      return <String>[];
    }
  }

  /// Adds a website URL to the saved websites list (avoids duplicates, puts latest at top).
  Future<void> addSavedWebsite(String url) async {
    try {
      final prefs = await _prefs;
      final list =
          prefs.getStringList(AppConstants.savedWebsitesListKey) ?? <String>[];
      final updated = List<String>.from(list);
      updated.remove(url);
      updated.insert(0, url);
      await prefs.setStringList(AppConstants.savedWebsitesListKey, updated);
    } catch (e, stackTrace) {
      debugPrint('Error adding to saved websites list: $e\n$stackTrace');
    }
  }

  /// Removes a specific website URL from the saved websites list.
  Future<void> removeSavedWebsite(String url) async {
    try {
      final prefs = await _prefs;
      final list =
          prefs.getStringList(AppConstants.savedWebsitesListKey) ?? <String>[];
      final updated = List<String>.from(list)..remove(url);
      await prefs.setStringList(AppConstants.savedWebsitesListKey, updated);

      final defaultUrl = prefs.getString(AppConstants.websiteUrlKey);
      if (defaultUrl == url) {
        if (updated.isNotEmpty) {
          await prefs.setString(AppConstants.websiteUrlKey, updated.first);
        } else {
          await prefs.remove(AppConstants.websiteUrlKey);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error removing from saved websites list: $e\n$stackTrace');
    }
  }

  /// Clears all saved websites from local storage.
  Future<void> clearAllSavedWebsites() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(AppConstants.savedWebsitesListKey);
      await prefs.remove(AppConstants.websiteUrlKey);
    } catch (e, stackTrace) {
      debugPrint('Error clearing all saved websites: $e\n$stackTrace');
    }
  }

  // --------------------------------------------------------------------------
  // AUTO STORAGE SYNC & CUSTOM FOLDER MANAGEMENT
  // --------------------------------------------------------------------------

  /// Gets the custom sync folder path configured by the user, or null if using default.
  Future<String?> getCustomSyncFolder() async {
    try {
      final prefs = await _prefs;
      return prefs.getString(AppConstants.syncFolderKey);
    } catch (e) {
      debugPrint('Error reading custom sync folder: $e');
      return null;
    }
  }

  /// Sets a custom sync folder path where history file will automatically be saved.
  Future<void> setCustomSyncFolder(String folderPath) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(AppConstants.syncFolderKey, folderPath);
      await writeAllHistoryToSyncFile();
    } catch (e) {
      debugPrint('Error saving custom sync folder: $e');
    }
  }

  /// Checks whether real-time auto sync to storage file is enabled.
  Future<bool> isAutoSyncEnabled() async {
    try {
      final prefs = await _prefs;
      return prefs.getBool(AppConstants.autoSyncEnabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Sets auto sync toggle.
  Future<void> setAutoSyncEnabled(bool enabled) async {
    try {
      final prefs = await _prefs;
      await prefs.setBool(AppConstants.autoSyncEnabledKey, enabled);
    } catch (e) {
      debugPrint('Error setting auto sync enabled: $e');
    }
  }

  /// Resolves the absolute directory path where the Excel/CSV file will be stored.
  Future<String> getResolvedSyncDirectory() async {
    final customFolder = await getCustomSyncFolder();
    if (customFolder != null && customFolder.trim().isNotEmpty) {
      return customFolder.trim();
    }

    if (!kIsWeb && Platform.isAndroid) {
      final nativePath = await PermissionService.getDefaultStoragePath();
      if (nativePath != null && nativePath.isNotEmpty) {
        return nativePath;
      }
      return '/storage/emulated/0/Download';
    }

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      return docsDir.path;
    } catch (_) {
      return '.';
    }
  }

  /// Resolves the complete file path of the sync file (e.g. /storage/emulated/0/Download/WebSpace_History.csv).
  Future<String> getResolvedSyncFilePath() async {
    final dir = await getResolvedSyncDirectory();
    final separator = dir.endsWith('/') || dir.endsWith('\\') ? '' : '/';
    return '$dir$separator${AppConstants.defaultHistoryFileName}';
  }

  /// Automatically synchronizes a visited/searched website to the physical file in real-time.
  Future<bool> syncWebsiteToStorage({
    required String url,
    String? title,
    String type = 'Search / Navigation',
  }) async {
    try {
      final autoSync = await isAutoSyncEnabled();
      if (!autoSync) return false;

      final filePath = await getResolvedSyncFilePath();
      final uri = Uri.tryParse(url);
      final host = uri?.host.isNotEmpty == true ? uri!.host : url;
      final timestamp = DateTime.now().toIso8601String().replaceAll('T', ' ').split('.').first;
      final cleanTitle = (title ?? host).replaceAll('"', '""');
      final cleanUrl = url.replaceAll('"', '""');

      final row = '"$timestamp","$host","$cleanTitle","$cleanUrl","$type","v${AppConstants.appVersion}"\n';

      // 1. Try native Dart File append
      try {
        final file = File(filePath);
        final exists = await file.exists();
        if (!exists) {
          await file.create(recursive: true);
          const header = 'Timestamp,Domain,Page Title,Full URL,Action Type,App Version\n';
          await file.writeAsString(header + row, mode: FileMode.append);
          return true;
        } else {
          await file.writeAsString(row, mode: FileMode.append);
          return true;
        }
      } catch (dartErr) {
        debugPrint('Dart file write failed, trying native bridge: $dartErr');
      }

      // 2. Native MethodChannel fallback
      final success = await PermissionService.appendToFile(
        path: filePath,
        content: row,
      );
      return success;
    } catch (e) {
      debugPrint('Error in syncWebsiteToStorage: $e');
      return false;
    }
  }

  /// Writes all existing saved websites to the sync CSV file.
  Future<void> writeAllHistoryToSyncFile() async {
    try {
      final websites = await getSavedWebsites();
      final filePath = await getResolvedSyncFilePath();
      final buffer = StringBuffer();
      buffer.writeln('Timestamp,Domain,Page Title,Full URL,Action Type,App Version');

      final now = DateTime.now().toIso8601String().replaceAll('T', ' ').split('.').first;
      for (final url in websites) {
        final uri = Uri.tryParse(url);
        final host = uri?.host.isNotEmpty == true ? uri!.host : url;
        buffer.writeln('"$now","$host","$host","$url","Saved Domain","v${AppConstants.appVersion}"');
      }

      final content = buffer.toString();
      try {
        final file = File(filePath);
        await file.create(recursive: true);
        await file.writeAsString(content);
      } catch (_) {
        await PermissionService.appendToFile(path: filePath, content: content);
      }
    } catch (e) {
      debugPrint('Error writing all history to sync file: $e');
    }
  }

  /// Exports all saved websites to Excel-compatible CSV format string.
  Future<String> exportToCsv() async {
    final websites = await getSavedWebsites();
    final defaultUrl = await getWebsiteUrl();
    final buffer = StringBuffer();

    // Excel CSV Header
    buffer.writeln('Index,Domain,Full URL,Status,Date Added');

    final now = DateTime.now().toIso8601String().split('T').first;
    for (int i = 0; i < websites.length; i++) {
      final url = websites[i];
      final uri = Uri.tryParse(url);
      final host = uri?.host.isNotEmpty == true ? uri!.host : url;
      final status = url == defaultUrl ? 'Default (Auto-Launch)' : 'Saved';
      buffer.writeln('${i + 1},"$host","$url","$status","$now"');
    }

    return buffer.toString();
  }
}
