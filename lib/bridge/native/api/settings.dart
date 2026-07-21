/// Settings API - C++ FFI implementation
library;

export '../models.dart';

import '../models.dart';
import 'settings_ffi.dart';

Future<AppSettings> getSettings() async {
  final data = SettingsFfi.instance.getSettings();
  return AppSettings(
    themeMode: data.themeMode == 0
        ? ThemeMode.system
        : data.themeMode == 1
            ? ThemeMode.light
            : ThemeMode.dark,
    gridColumns: data.gridColumns,
    albumGridColumns: data.albumGridColumns,
    thumbnailQuality: data.thumbnailQuality,
    language: data.language,
    dynamicColor: data.dynamicColor,
    lastScanPath: data.lastScanPath,
  );
}

Future<void> saveSettings({required AppSettings settings}) async {
  SettingsFfi.instance.saveSettings(
    settings.themeMode == ThemeMode.system
        ? 0
        : settings.themeMode == ThemeMode.light
            ? 1
            : 2,
    settings.gridColumns,
    settings.albumGridColumns,
    settings.thumbnailQuality,
    settings.language,
    settings.dynamicColor,
    settings.lastScanPath,
  );
}

/// Get storage statistics.
Future<StorageStats> getStorageStats() async {
  final data = SettingsFfi.instance.getStorageStats();
  return StorageStats(
    totalMediaCount: data.totalMediaCount,
    totalSize: data.totalSize,
    thumbnailCacheSize: data.thumbnailCacheSize,
    databaseSize: data.databaseSize,
  );
}

/// Clear thumbnail cache. Returns number of files removed.
Future<int> clearThumbnailCache() async {
  return SettingsFfi.instance.clearThumbnailCache();
}

/// Import data from a file path.
Future<void> importData({required String importPath}) async {
  SettingsFfi.instance.importData(importPath);
}

/// Export data to a file path.
Future<void> exportData({required String exportPath}) async {
  SettingsFfi.instance.exportData(exportPath);
}

/// Delete all application data.
Future<void> deleteAllData() async {
  SettingsFfi.instance.deleteAllData();
}
