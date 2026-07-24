/// Album API - C++ FFI implementation (Windows-safe variant)
library;

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _AlbumCb = Void Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _GetRootAlbumsFn = Int32 Function(Pointer<NativeFunction<_AlbumCb>>);
typedef _GetChildAlbumsFn = Int32 Function(
    Pointer<Utf8>, Pointer<NativeFunction<_AlbumCb>>);
typedef _CreateAlbumFn = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _DeleteAlbumFn = Int32 Function(Pointer<Utf8>);
typedef _RenameAlbumFn = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _GetMediaByAlbumFn = Int32 Function(
    Pointer<Utf8>, Pointer<NativeFunction<_MediaCb>>);
typedef _MediaCb = Void Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>,
    Int64, Pointer<Utf8>, Pointer<Utf8>);
typedef _AddMediaToAlbumFn = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _RemoveMediaFromAlbumFn = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _BreadcrumbCb = Void Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _GetAlbumBreadcrumbFn = Int32 Function(
    Pointer<Utf8>, Pointer<NativeFunction<_BreadcrumbCb>>);

class AlbumData {
  final String id;
  final String name;
  final int mediaCount;
  AlbumData(this.id, this.name, this.mediaCount);
}

class AlbumFfi {
  static AlbumFfi? _inst;
  late final DynamicLibrary _lib;

  AlbumFfi._() {
    _lib = _openLib();
  }

  static AlbumFfi get instance {
    _inst ??= AlbumFfi._();
    return _inst!;
  }

  DynamicLibrary _openLib() {
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    if (Platform.isLinux || Platform.isAndroid) {
      return DynamicLibrary.open('libflutter_media_manager_native.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('flutter_media_manager_native.dll');
    }
    if (Platform.isMacOS) {
      return DynamicLibrary.open('libflutter_media_manager_native.dylib');
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Buffers + callbacks. C++ side now copies string data into thread_local
  /// slots before invoking the callback, so the pointers remain valid for
  /// the full synchronous FFI call (fixes Windows).
  static final List<AlbumData> _albumsBuffer = [];
  static final List<MediaItemData> _mediaBuffer = [];
  static final List<BreadcrumbData> _breadcrumbBuffer = [];

  static void _collectAlbum(Pointer<Utf8> id, Pointer<Utf8> name, int count) {
    _albumsBuffer.add(AlbumData(id.toDartString(), name.toDartString(), count));
  }

  static void _collectMedia(Pointer<Utf8> id, Pointer<Utf8> name,
      Pointer<Utf8> type, int size, Pointer<Utf8> path, Pointer<Utf8> thumb) {
    _mediaBuffer.add(MediaItemData(id.toDartString(), name.toDartString(),
        type.toDartString(), size, path.toDartString(), thumb.toDartString()));
  }

  static void _collectBreadcrumb(Pointer<Utf8> id, Pointer<Utf8> name) {
    _breadcrumbBuffer
        .add(BreadcrumbData(id.toDartString(), name.toDartString()));
  }

  List<AlbumData> getRootAlbums() {
    _albumsBuffer.clear();
    final cb = Pointer.fromFunction<_AlbumCb>(_collectAlbum);
    _lib.lookupFunction<
        _GetRootAlbumsFn,
        int Function(
            Pointer<NativeFunction<_AlbumCb>>)>('fmm_get_root_albums')(cb);
    final snap = List<AlbumData>.from(_albumsBuffer);
    _albumsBuffer.clear();
    return snap;
  }

  List<AlbumData> getChildAlbums(String parentId) {
    _albumsBuffer.clear();
    final cb = Pointer.fromFunction<_AlbumCb>(_collectAlbum);
    final p = parentId.toNativeUtf8();
    _lib.lookupFunction<
        _GetChildAlbumsFn,
        int Function(Pointer<Utf8>,
            Pointer<NativeFunction<_AlbumCb>>)>('fmm_get_child_albums')(p, cb);
    calloc.free(p);
    final snap = List<AlbumData>.from(_albumsBuffer);
    _albumsBuffer.clear();
    return snap;
  }

  String createAlbum(String name, String? parentId) {
    final n = name.toNativeUtf8();
    final pid = parentId?.toNativeUtf8() ?? nullptr;
    final result = _lib.lookupFunction<
        _CreateAlbumFn,
        Pointer<Utf8> Function(
            Pointer<Utf8>, Pointer<Utf8>)>('fmm_create_album')(n, pid);
    calloc.free(n);
    if (parentId != null) calloc.free(pid);
    return result.toDartString();
  }

  int deleteAlbum(String id) {
    final p = id.toNativeUtf8();
    final r = _lib.lookupFunction<_DeleteAlbumFn, int Function(Pointer<Utf8>)>(
        'fmm_delete_album')(p);
    calloc.free(p);
    return r;
  }

  int renameAlbum(String id, String name) {
    final i = id.toNativeUtf8();
    final n = name.toNativeUtf8();
    final r = _lib.lookupFunction<_RenameAlbumFn,
        int Function(Pointer<Utf8>, Pointer<Utf8>)>('fmm_rename_album')(i, n);
    calloc.free(i);
    calloc.free(n);
    return r;
  }

  List<MediaItemData> getMediaByAlbum(String albumId) {
    _mediaBuffer.clear();
    final cb = Pointer.fromFunction<_MediaCb>(_collectMedia);
    final a = albumId.toNativeUtf8();
    _lib.lookupFunction<_GetMediaByAlbumFn,
            int Function(Pointer<Utf8>, Pointer<NativeFunction<_MediaCb>>)>(
        'fmm_get_media_by_album')(a, cb);
    calloc.free(a);
    final snap = List<MediaItemData>.from(_mediaBuffer);
    _mediaBuffer.clear();
    return snap;
  }

  int addMediaToAlbum(String mediaId, String albumId) {
    final m = mediaId.toNativeUtf8();
    final a = albumId.toNativeUtf8();
    final r = _lib.lookupFunction<
        _AddMediaToAlbumFn,
        int Function(Pointer<Utf8>,
            Pointer<Utf8>)>('fmm_add_single_media_to_album')(m, a);
    calloc.free(m);
    calloc.free(a);
    return r;
  }

  int removeMediaFromAlbum(String mediaId, String albumId) {
    final m = mediaId.toNativeUtf8();
    final a = albumId.toNativeUtf8();
    final r = _lib.lookupFunction<
        _RemoveMediaFromAlbumFn,
        int Function(Pointer<Utf8>,
            Pointer<Utf8>)>('fmm_remove_single_media_from_album')(m, a);
    calloc.free(m);
    calloc.free(a);
    return r;
  }

  List<BreadcrumbData> getAlbumBreadcrumb(String albumId) {
    _breadcrumbBuffer.clear();
    final cb = Pointer.fromFunction<_BreadcrumbCb>(_collectBreadcrumb);
    final a = albumId.toNativeUtf8();
    _lib.lookupFunction<
            _GetAlbumBreadcrumbFn,
            int Function(
                Pointer<Utf8>, Pointer<NativeFunction<_BreadcrumbCb>>)>(
        'fmm_get_album_breadcrumb')(a, cb);
    calloc.free(a);
    final snap = List<BreadcrumbData>.from(_breadcrumbBuffer);
    _breadcrumbBuffer.clear();
    return snap;
  }
}

class MediaItemData {
  final String id;
  final String name;
  final String type;
  final int size;
  final String path;
  final String thumbPath;
  MediaItemData(
      this.id, this.name, this.type, this.size, this.path, this.thumbPath);
}

class BreadcrumbData {
  final String id;
  final String name;
  BreadcrumbData(this.id, this.name);
}
