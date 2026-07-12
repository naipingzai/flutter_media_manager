import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// C function signatures for settings
typedef AmkbGetSettingsNative = Pointer<Void> Function();
typedef AmkbGetSettingsDart = Pointer<Void> Function();

typedef AmkbSaveSettingsNative = Int32 Function(
    Int32 themeMode,
    Int32 gridCols,
    Int32 albumCols,
    Int32 thumbnailQuality,
    Pointer<Utf8> language,
    Int32 dynamicColor,
    Pointer<Utf8> lastScanPath);
typedef AmkbSaveSettingsDart = int Function(
    int themeMode,
    int gridCols,
    int albumCols,
    int thumbnailQuality,
    Pointer<Utf8> language,
    int dynamicColor,
    Pointer<Utf8> lastScanPath);

typedef AmkbDeleteAllDataNative = Int32 Function();
typedef AmkbDeleteAllDataDart = int Function();

typedef AmkbExportDataNative = Int32 Function(Pointer<Utf8> path);
typedef AmkbExportDataDart = int Function(Pointer<Utf8> path);

typedef AmkbImportDataNative = Int32 Function(Pointer<Utf8> path);
typedef AmkbImportDataDart = int Function(Pointer<Utf8> path);

// Settings callback typedef
typedef _SettingsCb = Void Function(
    Int32 themeMode, Int32 gridCols, Int32 albumCols, Int32 thumbQ,
    Pointer<Utf8> lang, Int32 dynColor, Pointer<Utf8> lastScan);
typedef _GetSettingsCbFn = Int32 Function(Pointer<NativeFunction<_SettingsCb>>);
typedef _SaveSettingsFn = Int32 Function(
    Int32, Int32, Int32, Int32, Pointer<Utf8>, Int32, Pointer<Utf8>);

class SettingsData {
  final int themeMode;
  final int gridColumns;
  final int albumGridColumns;
  final int thumbnailQuality;
  final String language;
  final int dynamicColor;
  final String lastScanPath;
  SettingsData(this.themeMode, this.gridColumns, this.albumGridColumns,
      this.thumbnailQuality, this.language, this.dynamicColor, this.lastScanPath);
}

/// C++ FFI wrapper for settings operations
class SettingsFfi {
  static SettingsFfi? _instance;
  late final DynamicLibrary _lib;

  SettingsFfi._() {
    _lib = _loadLibrary();
  }

  static SettingsFfi get instance {
    _instance ??= SettingsFfi._();
    return _instance!;
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isLinux || Platform.isAndroid) {
      return DynamicLibrary.open('libadvance_media_kb.so');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('advance_media_kb.dll');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libadvance_media_kb.dylib');
    }
    throw UnsupportedError('Platform not supported');
  }

  // Get settings via callback
  static SettingsData? _result;
  static void _settingsCb(int themeMode, int gridCols, int albumCols,
      int thumbQ, Pointer<Utf8> lang, int dynColor, Pointer<Utf8> lastScan) {
    _result = SettingsData(
      themeMode, gridCols, albumCols, thumbQ,
      lang.toDartString(), dynColor, lastScan.toDartString(),
    );
  }

  SettingsData getSettings() {
    _result = null;
    final cb = Pointer.fromFunction<_SettingsCb>(_settingsCb);
    _lib.lookupFunction<_GetSettingsCbFn,
        int Function(Pointer<NativeFunction<_SettingsCb>>)>('amkb_get_settings_cb')(cb);
    final r = _result ?? SettingsData(0, 3, 2, 85, 'zh', 1, '');
    _result = null;
    return r;
  }

  int saveSettings(int themeMode, int gridCols, int albumCols, int thumbQ,
      String lang, int dynColor, String lastScan) {
    final l = lang.toNativeUtf8();
    final s = lastScan.toNativeUtf8();
    final r = _lib.lookupFunction<_SaveSettingsFn,
        int Function(int, int, int, int, Pointer<Utf8>, int, Pointer<Utf8>)>(
        'amkb_save_settings')(themeMode, gridCols, albumCols, thumbQ, l, dynColor, s);
    calloc.free(l);
    calloc.free(s);
    return r;
  }

  /// Delete all data
  int deleteAllData() {
    final fn =
        _lib.lookupFunction<AmkbDeleteAllDataNative, AmkbDeleteAllDataDart>(
            'amkb_delete_all_data');
    return fn();
  }

  /// Export data to path
  int exportData(String path) {
    final pathUtf8 = path.toNativeUtf8();
    final fn = _lib.lookupFunction<AmkbExportDataNative, AmkbExportDataDart>(
        'amkb_export_data');
    final result = fn(pathUtf8);
    calloc.free(pathUtf8);
    return result;
  }

  /// Import data from path
  int importData(String path) {
    final pathUtf8 = path.toNativeUtf8();
    final fn = _lib.lookupFunction<AmkbImportDataNative, AmkbImportDataDart>(
        'amkb_import_data');
    final result = fn(pathUtf8);
    calloc.free(pathUtf8);
    return result;
  }
}
