export '../models.dart';
/// Settings API - C++ FFI implementation
import '../models.dart';
import 'settings_ffi.dart';

Future<AppSettings> getSettings() async {
  return const AppSettings();
}

Future<void> saveSettings({required AppSettings settings}) async {}

Future<StorageStats> getStorageStats() async {
  return const StorageStats();
}

Future<int> clearThumbnailCache() async { return 0; }
Future<void> exportData({required String exportPath}) async { SettingsFfi.instance.exportData(exportPath); }
Future<void> importData({required String importPath}) async { SettingsFfi.instance.importData(importPath); }
Future<void> deleteAllData() async { SettingsFfi.instance.deleteAllData(); }
Future<List<String>> findUnreferencedFiles() async { return []; }
Future<int> deleteUnreferencedFiles() async { return 0; }
Future<void> initApp({required String appDir}) async {}
