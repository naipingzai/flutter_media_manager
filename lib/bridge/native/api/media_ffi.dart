import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Media callback: void fn(const char* id, const char* name, const char* type, int64_t size, const char* path, const char* thumb)
typedef _MediaCb = Void Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int64, Pointer<Utf8>, Pointer<Utf8>);
typedef MediaCb = void Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int, Pointer<Utf8>, Pointer<Utf8>);

typedef _GetAllMediaFn = Int32 Function(Pointer<NativeFunction<_MediaCb>>);
typedef _GetAllMediaDart = int Function(Pointer<NativeFunction<_MediaCb>>);

typedef _SearchMediaFn = Int32 Function(Pointer<Utf8>, Pointer<NativeFunction<_MediaCb>>);
typedef _SearchMediaDart = int Function(Pointer<Utf8>, Pointer<NativeFunction<_MediaCb>>);

typedef _FilterMediaFn = Int32 Function(Pointer<Utf8>, Pointer<NativeFunction<_MediaCb>>);
typedef _FilterMediaDart = int Function(Pointer<Utf8>, Pointer<NativeFunction<_MediaCb>>);

typedef _DeleteMediaFn = Int32 Function(Pointer<Utf8>);
typedef _DeleteMediaDart = int Function(Pointer<Utf8>);

typedef _ImportFileFn = Int32 Function(Pointer<Utf8>);
typedef _ImportFileDart = int Function(Pointer<Utf8>);

typedef _ScanDirFn = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _ScanDirDart = int Function(Pointer<Utf8>, Pointer<Utf8>);

class MediaItemData {
  final String id;
  final String name;
  final String type;
  final int size;
  final String path;
  final String thumbPath;
  MediaItemData(this.id, this.name, this.type, this.size, this.path, this.thumbPath);
}

class MediaFfi {
  static MediaFfi? _inst;
  late final DynamicLibrary _lib;
  MediaFfi._() { _lib = _openLib(); }
  static MediaFfi get instance { _inst ??= MediaFfi._(); return _inst!; }

  DynamicLibrary _openLib() {
    if (Platform.isLinux || Platform.isAndroid) return DynamicLibrary.open('libadvance_media_kb.so');
    if (Platform.isWindows) return DynamicLibrary.open('advance_media_kb.dll');
    if (Platform.isMacOS) return DynamicLibrary.open('libadvance_media_kb.dylib');
    throw UnsupportedError('Unsupported platform');
  }

  List<MediaItemData> getAllMedia() {
    final items = <MediaItemData>[];
    final nativeCb = Pointer.fromFunction<_MediaCb>(_collectMedia);
    // Use zone to pass items list
    _currentItems = items;
    final fn = _lib.lookupFunction<_GetAllMediaFn, _GetAllMediaDart>('amkb_get_all_media');
    fn(nativeCb);
    _currentItems = null;
    return items;
  }

  List<MediaItemData> searchMedia(String query) {
    final items = <MediaItemData>[];
    final nativeCb = Pointer.fromFunction<_MediaCb>(_collectMedia);
    _currentItems = items;
    final q = query.toNativeUtf8();
    final fn = _lib.lookupFunction<_SearchMediaFn, _SearchMediaDart>('amkb_search_media');
    fn(q, nativeCb);
    calloc.free(q);
    _currentItems = null;
    return items;
  }

  List<MediaItemData> filterByType(String type) {
    final items = <MediaItemData>[];
    final nativeCb = Pointer.fromFunction<_MediaCb>(_collectMedia);
    _currentItems = items;
    final t = type.toNativeUtf8();
    final fn = _lib.lookupFunction<_FilterMediaFn, _FilterMediaDart>('amkb_filter_media_by_type');
    fn(t, nativeCb);
    calloc.free(t);
    _currentItems = null;
    return items;
  }

  int deleteMedia(String id) {
    final p = id.toNativeUtf8();
    final fn = _lib.lookupFunction<_DeleteMediaFn, _DeleteMediaDart>('amkb_delete_media');
    final r = fn(p);
    calloc.free(p);
    return r;
  }

  int importFile(String path) {
    final p = path.toNativeUtf8();
    final fn = _lib.lookupFunction<_ImportFileFn, _ImportFileDart>('amkb_import_single_file');
    final r = fn(p);
    calloc.free(p);
    return r;
  }

  int scanDirectory(String dir, String appDir) {
    final d = dir.toNativeUtf8();
    final a = appDir.toNativeUtf8();
    final fn = _lib.lookupFunction<_ScanDirFn, _ScanDirDart>('amkb_scan_directory');
    final r = fn(d, a);
    calloc.free(d);
    calloc.free(a);
    return r;
  }

  // Static callback helper
  static List<MediaItemData>? _currentItems;
  static void _collectMedia(Pointer<Utf8> id, Pointer<Utf8> name, Pointer<Utf8> type, int size, Pointer<Utf8> path, Pointer<Utf8> thumb) {
    _currentItems?.add(MediaItemData(
      id.toDartString(), name.toDartString(), type.toDartString(),
      size, path.toDartString(), thumb.toDartString(),
    ));
  }
}
