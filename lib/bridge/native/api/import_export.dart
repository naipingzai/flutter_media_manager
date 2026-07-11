export '../models.dart';

/// Import/Export API - C++ FFI implementation
import '../models.dart';
import 'settings_ffi.dart';

Future<void> exportData({required String exportPath}) async {
  SettingsFfi.instance.exportData(exportPath);
}

Future<void> importData({required String importPath}) async {
  SettingsFfi.instance.importData(importPath);
}

Future<void> importPackage({
  String? path,
  String? packagePath,
  ConflictStrategy conflictStrategy = ConflictStrategy.skip,
}) async {
  SettingsFfi.instance.importData(path ?? packagePath ?? '');
}

Future<void> exportPackage({
  String? path,
  String? exportPath,
  bool includeMedia = false,
}) async {
  SettingsFfi.instance.exportData(path ?? exportPath ?? '');
}

Future<void> exportToDownload(
    {String? filePath, List<String>? mediaIds}) async {
  SettingsFfi.instance.exportData(filePath ?? '');
}

List<String> getSupportedExtensions() {
  return [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'svg',
    'mp4',
    'avi',
    'mkv',
    'mov',
    'webm',
    'mp3',
    'wav',
    'flac',
    'aac',
    'ogg',
    'pdf',
    'doc',
    'docx',
    'txt',
    'md'
  ];
}
