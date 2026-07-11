import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// C ABI function signatures
typedef AmkbInitNative = Int32 Function(Pointer<Utf8> appDir);
typedef AmkbInitDart = int Function(Pointer<Utf8> appDir);

typedef AmkbGetAllMediaNative = Int32 Function(
    Pointer<NativeFunction<MediaCallback>> cb);
typedef AmkbGetAllMediaDart = int Function(
    Pointer<NativeFunction<MediaCallback>> cb);
typedef MediaCallback = Void Function(Pointer<Utf8> id, Pointer<Utf8> name,
    Pointer<Utf8> type, Int64 size, Pointer<Utf8> path, Pointer<Utf8> thumb);

typedef AmkbSearchMediaNative = Int32 Function(
    Pointer<Utf8> query, Pointer<NativeFunction<MediaCallback>> cb);
typedef AmkbSearchMediaDart = int Function(
    Pointer<Utf8> query, Pointer<NativeFunction<MediaCallback>> cb);

typedef AmkbFilterMediaByTypeNative = Int32 Function(
    Pointer<Utf8> type, Pointer<NativeFunction<MediaCallback>> cb);
typedef AmkbFilterMediaByTypeDart = int Function(
    Pointer<Utf8> type, Pointer<NativeFunction<MediaCallback>> cb);

typedef AmkbDeleteMediaNative = Int32 Function(Pointer<Utf8> id);
typedef AmkbDeleteMediaDart = int Function(Pointer<Utf8> id);

typedef AmkbImportSingleFileNative = Int32 Function(Pointer<Utf8> path);
typedef AmkbImportSingleFileDart = int Function(Pointer<Utf8> path);

typedef AmkbScanDirectoryNative = Int32 Function(
    Pointer<Utf8> dir, Pointer<Utf8> appDir);
typedef AmkbScanDirectoryDart = int Function(
    Pointer<Utf8> dir, Pointer<Utf8> appDir);

typedef AlbumCallback = Void Function(
    Pointer<Utf8> id, Pointer<Utf8> name, Int32 mediaCount);
typedef AmkbGetRootAlbumsNative = Int32 Function(
    Pointer<NativeFunction<AlbumCallback>> cb);
typedef AmkbGetRootAlbumsDart = int Function(
    Pointer<NativeFunction<AlbumCallback>> cb);

typedef AmkbGetChildAlbumsNative = Int32 Function(
    Pointer<Utf8> parentId, Pointer<NativeFunction<AlbumCallback>> cb);
typedef AmkbGetChildAlbumsDart = int Function(
    Pointer<Utf8> parentId, Pointer<NativeFunction<AlbumCallback>> cb);

typedef AmkbCreateAlbumNative = Pointer<Utf8> Function(
    Pointer<Utf8> name, Pointer<Utf8> parentId);
typedef AmkbCreateAlbumDart = Pointer<Utf8> Function(
    Pointer<Utf8> name, Pointer<Utf8> parentId);

typedef AmkbDeleteAlbumNative = Int32 Function(Pointer<Utf8> id);
typedef AmkbDeleteAlbumDart = int Function(Pointer<Utf8> id);

typedef AmkbRenameAlbumNative = Int32 Function(
    Pointer<Utf8> id, Pointer<Utf8> name);
typedef AmkbRenameAlbumDart = int Function(
    Pointer<Utf8> id, Pointer<Utf8> name);

typedef AmkbGetMediaByAlbumNative = Int32 Function(
    Pointer<Utf8> albumId, Pointer<NativeFunction<MediaCallback>> cb);
typedef AmkbGetMediaByAlbumDart = int Function(
    Pointer<Utf8> albumId, Pointer<NativeFunction<MediaCallback>> cb);

typedef TagCallback = Void Function(
    Pointer<Utf8> id, Pointer<Utf8> name, Pointer<Utf8> color);
typedef AmkbGetAllTagsNative = Int32 Function(
    Pointer<NativeFunction<TagCallback>> cb);
typedef AmkbGetAllTagsDart = int Function(
    Pointer<NativeFunction<TagCallback>> cb);

typedef AmkbCreateTagNative = Pointer<Utf8> Function(
    Pointer<Utf8> name, Pointer<Utf8> color, Pointer<Utf8> parentId);
typedef AmkbCreateTagDart = Pointer<Utf8> Function(
    Pointer<Utf8> name, Pointer<Utf8> color, Pointer<Utf8> parentId);

typedef AmkbDeleteTagNative = Int32 Function(Pointer<Utf8> id);
typedef AmkbDeleteTagDart = int Function(Pointer<Utf8> id);

typedef AmkbRenameTagNative = Int32 Function(
    Pointer<Utf8> id, Pointer<Utf8> name);
typedef AmkbRenameTagDart = int Function(Pointer<Utf8> id, Pointer<Utf8> name);

typedef AmkbAddTagToMediaNative = Int32 Function(
    Pointer<Utf8> mediaId, Pointer<Utf8> tagId);
typedef AmkbAddTagToMediaDart = int Function(
    Pointer<Utf8> mediaId, Pointer<Utf8> tagId);

typedef AmkbRemoveTagFromMediaNative = Int32 Function(
    Pointer<Utf8> mediaId, Pointer<Utf8> tagId);
typedef AmkbRemoveTagFromMediaDart = int Function(
    Pointer<Utf8> mediaId, Pointer<Utf8> tagId);

typedef AmkbGetMediaTagsNative = Int32 Function(
    Pointer<Utf8> mediaId, Pointer<NativeFunction<TagCallback>> cb);
typedef AmkbGetMediaTagsDart = int Function(
    Pointer<Utf8> mediaId, Pointer<NativeFunction<TagCallback>> cb);

typedef AmkbSaveNoteNative = Int32 Function(
    Pointer<Utf8> mediaId, Pointer<Utf8> content);
typedef AmkbSaveNoteDart = int Function(
    Pointer<Utf8> mediaId, Pointer<Utf8> content);

typedef AmkbDeleteNoteNative = Int32 Function(Pointer<Utf8> id);
typedef AmkbDeleteNoteDart = int Function(Pointer<Utf8> id);

typedef AmkbDeleteAllDataNative = Int32 Function();
typedef AmkbDeleteAllDataDart = int Function();

typedef AmkbExportDataNative = Int32 Function(Pointer<Utf8> path);
typedef AmkbExportDataDart = int Function(Pointer<Utf8> path);

typedef AmkbImportDataNative = Int32 Function(Pointer<Utf8> path);
typedef AmkbImportDataDart = int Function(Pointer<Utf8> path);

typedef AmkbSaveSettingsNative = Int32 Function(
    Int32, Int32, Int32, Int32, Pointer<Utf8>, Int32, Pointer<Utf8>);
typedef AmkbSaveSettingsDart = int Function(
    int, int, int, int, Pointer<Utf8>, int, Pointer<Utf8>);

/// Singleton wrapper around the C++ native library
class NativeLibrary {
  static NativeLibrary? _instance;
  late final DynamicLibrary _lib;
  bool _initialized = false;

  NativeLibrary._() {
    _lib = _loadLibrary();
  }

  static NativeLibrary get instance {
    _instance ??= NativeLibrary._();
    return _instance!;
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isLinux) {
      return DynamicLibrary.open('libadvance_media_kb.so');
    } else if (Platform.isAndroid) {
      return DynamicLibrary.open('libadvance_media_kb.so');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('advance_media_kb.dll');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libadvance_media_kb.dylib');
    }
    throw UnsupportedError('Platform not supported');
  }

  bool get isInitialized => _initialized;

  /// Initialize the native database
  int init(String appDir) {
    final path = appDir.toNativeUtf8();
    final fn = _lib.lookupFunction<AmkbInitNative, AmkbInitDart>('amkb_init');
    final result = fn(path);
    calloc.free(path);
    if (result == 0) _initialized = true;
    return result;
  }
}
