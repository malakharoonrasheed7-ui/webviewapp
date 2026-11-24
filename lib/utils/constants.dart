class AppConstants {
  AppConstants._();

  static const String appName = 'WebSpace';
  static const String appVersion = '1.0.0';
  static const String websiteUrlKey = 'website_url';
  static const String savedWebsitesListKey = 'saved_websites_list';
  static const String biometricLockKey = 'biometric_lock_enabled';
  static const String syncFolderKey = 'sync_folder_path';
  static const String autoSyncEnabledKey = 'auto_sync_storage_enabled';
  static const String defaultHistoryFileName = 'WebSpace_History.csv';

  // Error messages
  static const String invalidDomainError =
      'Please enter a valid website domain';
  static const String webViewLoadError = 'Unable to load website';
  static const String webViewLoadErrorSubtitle =
      'Please check your internet connection or try again.';
}
