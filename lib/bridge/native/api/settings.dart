export '../models.dart';

/// Settings API - C++ FFI implementation
import '../models.dart';
import 'settings_ffi.dart';

Future<AppSettings> getSettings() async {
  final d = SettingsFfi.instance.getSettings();
  ThemeMode tm;
  switch (d.themeMode) {
    case 1:
      tm = ThemeMode.light;
      break;
    case 2:
      tm = ThemeMode.dark;
      break;
    default:
      tm = ThemeMode.system;
  }
  return AppSettings(
    themeMode: tm,
    gridColumns: d.gridColumns,
    albumGridColumns: d.albumGridColumns,
    thumbnailQuality: d.thumbnailQuality,
    language: d.language,
    dynamicColor: d.dynamicColor,
    lastScanPath: d.lastScanPath,
  );
}

Future<void> saveSettings({required AppSettings settings}) async {
  int tm;
  switch (settings.themeMode) {
    case ThemeMode.light:
      tm = 1;
      break;
    case ThemeMode.dark:
      tm = 2;
      break;
    default:
      tm = 0;
  }
  SettingsFfi.instance.saveSettings(
    tm,
    settings.gridColumns,
    settings.albumGridColumns,
    settings.thumbnailQuality,
    settings.language,
    settings.dynamicColor,
    settings.lastScanPath,
  );
}

Future<StorageStats> getStorageStats() async {
  return const StorageStats();
}

Future<int> clearThumbnailCache() async {
  return 0;
}

Future<void> exportData({required String exportPath}) async {
  SettingsFfi.instance.exportData(exportPath);
}

Future<void> importData({required String importPath}) async {
  SettingsFfi.instance.importData(importPath);
}

Future<void> deleteAllData() async {
  SettingsFfi.instance.deleteAllData();
}

Future<List<String>> findUnreferencedFiles() async {
  return [];
}

Future<int> deleteUnreferencedFiles() async {
  return 0;
}

Future<void> initApp({required String appDir}) async {}
