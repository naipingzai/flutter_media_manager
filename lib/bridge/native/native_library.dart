////////////////////////////////////////////////////////////////////////
// 文件坐标: lib/bridge/native/native_library.dart
// 作用:     Dart FFI 原生库加载器与 C ABI 函数签名声明
// 说明:     定义所有 C++ 导出函数的 Dart 类型签名，并提供单例类
//           NativeLibrary 用于动态加载 .so / .dll / .dylib 并调用函数。
////////////////////////////////////////////////////////////////////////
library;

// --------------------------------------------------------------------
import 'dart:ffi';

// --------------------------------------------------------------------
// 用于判断 Platform.isLinux / isAndroid 等
import 'dart:io';

// --------------------------------------------------------------------
// 提供 Pointer<Utf8>、toNativeUtf8()、calloc.free() 等工具
import 'package:ffi/ffi.dart';

// --------------------------------------------------------------------
// 每对 typedef 包含 Native（C 侧）和 Dart（Dart 侧）签名

// --------------------------------------------------------------------
// C 侧: int fmm_init(const char* appDir)
// 返回 Int32（0 成功），参数为 UTF-8 字符串指针
typedef FmmInitNative = Int32 Function(Pointer<Utf8> appDir);
typedef FmmInitDart = int Function(Pointer<Utf8> appDir);

// --------------------------------------------------------------------
// 回调参数: id, name, type, size, path, thumb
typedef FmmGetAllMediaNative = Int32 Function(
    Pointer<NativeFunction<MediaCallback>> cb);
typedef FmmGetAllMediaDart = int Function(
    Pointer<NativeFunction<MediaCallback>> cb);
typedef MediaCallback = Void Function(Pointer<Utf8> id, Pointer<Utf8> name,
    Pointer<Utf8> type, Int64 size, Pointer<Utf8> path, Pointer<Utf8> thumb);

// --------------------------------------------------------------------
typedef FmmSearchMediaNative = Int32 Function(
    Pointer<Utf8> query, Pointer<NativeFunction<MediaCallback>> cb);
typedef FmmSearchMediaDart = int Function(
    Pointer<Utf8> query, Pointer<NativeFunction<MediaCallback>> cb);

// --------------------------------------------------------------------
typedef FmmFilterMediaByTypeNative = Int32 Function(
    Pointer<Utf8> type, Pointer<NativeFunction<MediaCallback>> cb);
typedef FmmFilterMediaByTypeDart = int Function(
    Pointer<Utf8> type, Pointer<NativeFunction<MediaCallback>> cb);

// --------------------------------------------------------------------
typedef FmmDeleteMediaNative = Int32 Function(Pointer<Utf8> id);
typedef FmmDeleteMediaDart = int Function(Pointer<Utf8> id);

// --------------------------------------------------------------------
typedef FmmImportSingleFileNative = Int32 Function(Pointer<Utf8> path);
typedef FmmImportSingleFileDart = int Function(Pointer<Utf8> path);

// --------------------------------------------------------------------
typedef FmmScanDirectoryNative = Int32 Function(
    Pointer<Utf8> dir, Pointer<Utf8> appDir);
typedef FmmScanDirectoryDart = int Function(
    Pointer<Utf8> dir, Pointer<Utf8> appDir);

// --------------------------------------------------------------------
typedef AlbumCallback = Void Function(
    Pointer<Utf8> id, Pointer<Utf8> name, Int32 mediaCount);
typedef FmmGetRootAlbumsNative = Int32 Function(
    Pointer<NativeFunction<AlbumCallback>> cb);
typedef FmmGetRootAlbumsDart = int Function(
    Pointer<NativeFunction<AlbumCallback>> cb);
typedef FmmGetChildAlbumsNative = Int32 Function(
    Pointer<Utf8> parentId, Pointer<NativeFunction<AlbumCallback>> cb);
typedef FmmGetChildAlbumsDart = int Function(
    Pointer<Utf8> parentId, Pointer<NativeFunction<AlbumCallback>> cb);

// --------------------------------------------------------------------
// 返回 Pointer<Utf8>，指向新相册 ID 字符串
typedef FmmCreateAlbumNative = Pointer<Utf8> Function(
    Pointer<Utf8> name, Pointer<Utf8> parentId);
typedef FmmCreateAlbumDart = Pointer<Utf8> Function(
    Pointer<Utf8> name, Pointer<Utf8> parentId);

// --------------------------------------------------------------------
typedef FmmDeleteAlbumNative = Int32 Function(Pointer<Utf8> id);
typedef FmmDeleteAlbumDart = int Function(Pointer<Utf8> id);

// --------------------------------------------------------------------
typedef FmmRenameAlbumNative = Int32 Function(
    Pointer<Utf8> id, Pointer<Utf8> name);
typedef FmmRenameAlbumDart = int Function(
    Pointer<Utf8> id, Pointer<Utf8> name);

// --------------------------------------------------------------------
typedef FmmGetMediaByAlbumNative = Int32 Function(
    Pointer<Utf8> albumId, Pointer<NativeFunction<MediaCallback>> cb);
typedef FmmGetMediaByAlbumDart = int Function(
    Pointer<Utf8> albumId, Pointer<NativeFunction<MediaCallback>> cb);

// --------------------------------------------------------------------
typedef TagCallback = Void Function(
    Pointer<Utf8> id, Pointer<Utf8> name, Pointer<Utf8> color);
typedef FmmGetAllTagsNative = Int32 Function(
    Pointer<NativeFunction<TagCallback>> cb);
typedef FmmGetAllTagsDart = int Function(
    Pointer<NativeFunction<TagCallback>> cb);

// --------------------------------------------------------------------
typedef FmmCreateTagNative = Pointer<Utf8> Function(
    Pointer<Utf8> name, Pointer<Utf8> color, Pointer<Utf8> parentId);
typedef FmmCreateTagDart = Pointer<Utf8> Function(
    Pointer<Utf8> name, Pointer<Utf8> color, Pointer<Utf8> parentId);

// --------------------------------------------------------------------
typedef FmmDeleteTagNative = Int32 Function(Pointer<Utf8> id);
typedef FmmDeleteTagDart = int Function(Pointer<Utf8> id);

// --------------------------------------------------------------------
typedef FmmRenameTagNative = Int32 Function(
    Pointer<Utf8> id, Pointer<Utf8> name);
typedef FmmRenameTagDart = int Function(Pointer<Utf8> id, Pointer<Utf8> name);

// --------------------------------------------------------------------
typedef FmmAddTagToMediaNative = Int32 Function(
    Pointer<Utf8> mediaId, Pointer<Utf8> tagId);
typedef FmmAddTagToMediaDart = int Function(
    Pointer<Utf8> mediaId, Pointer<Utf8> tagId);

// --------------------------------------------------------------------
typedef FmmRemoveTagFromMediaNative = Int32 Function(
    Pointer<Utf8> mediaId, Pointer<Utf8> tagId);
typedef FmmRemoveTagFromMediaDart = int Function(
    Pointer<Utf8> mediaId, Pointer<Utf8> tagId);

// --------------------------------------------------------------------
typedef FmmGetMediaTagsNative = Int32 Function(
    Pointer<Utf8> mediaId, Pointer<NativeFunction<TagCallback>> cb);
typedef FmmGetMediaTagsDart = int Function(
    Pointer<Utf8> mediaId, Pointer<NativeFunction<TagCallback>> cb);

// --------------------------------------------------------------------
typedef FmmSaveNoteNative = Int32 Function(
    Pointer<Utf8> mediaId, Pointer<Utf8> content);
typedef FmmSaveNoteDart = int Function(
    Pointer<Utf8> mediaId, Pointer<Utf8> content);

// --------------------------------------------------------------------
typedef FmmDeleteNoteNative = Int32 Function(Pointer<Utf8> id);
typedef FmmDeleteNoteDart = int Function(Pointer<Utf8> id);

// --------------------------------------------------------------------
typedef FmmDeleteAllDataNative = Int32 Function();
typedef FmmDeleteAllDataDart = int Function();

// --------------------------------------------------------------------
typedef FmmExportDataNative = Int32 Function(Pointer<Utf8> path);
typedef FmmExportDataDart = int Function(Pointer<Utf8> path);

// --------------------------------------------------------------------
typedef FmmImportDataNative = Int32 Function(Pointer<Utf8> path);
typedef FmmImportDataDart = int Function(Pointer<Utf8> path);

// --------------------------------------------------------------------
// 7 个 int/string 参数: theme, grid, album_grid, thumb, lang, dyn_color, last_scan
typedef FmmSaveSettingsNative = Int32 Function(
    Int32, Int32, Int32, Int32, Pointer<Utf8>, Int32, Pointer<Utf8>);
typedef FmmSaveSettingsDart = int Function(
    int, int, int, int, Pointer<Utf8>, int, Pointer<Utf8>);

// --------------------------------------------------------------------
// 封装原生动态库加载和常用函数调用
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
    if (Platform.isIOS) {
      // iOS uses statically linked library
      return DynamicLibrary.process();
    } else if (Platform.isLinux) {
      // 加载 libflutter_media_manager_native.so
      return DynamicLibrary.open('libflutter_media_manager_native.so');
    } else if (Platform.isAndroid) {
      // Android 的 .so 已打包到 jniLibs，同名加载
      return DynamicLibrary.open('libflutter_media_manager_native.so');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('flutter_media_manager_native.dll');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libflutter_media_manager_native.dylib');
    }
    throw UnsupportedError('Platform not supported');
  }

  bool get isInitialized => _initialized;

  // ------------------------------------------------------------------
  int init(String appDir) {
    final path = appDir.toNativeUtf8();

    final fn = _lib.lookupFunction<FmmInitNative, FmmInitDart>('fmm_init');

    final result = fn(path);

    calloc.free(path);

    if (result == 0) _initialized = true;

    return result;
  }
}
