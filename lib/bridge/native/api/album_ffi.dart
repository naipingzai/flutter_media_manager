import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _AlbumCb = Void Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _GetRootAlbumsFn = Int32 Function(Pointer<NativeFunction<_AlbumCb>>);
typedef _GetChildAlbumsFn = Int32 Function(Pointer<Utf8>, Pointer<NativeFunction<_AlbumCb>>);
typedef _CreateAlbumFn = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _DeleteAlbumFn = Int32 Function(Pointer<Utf8>);
typedef _RenameAlbumFn = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _GetMediaByAlbumFn = Int32 Function(Pointer<Utf8>, Pointer<NativeFunction<_MediaCb>>);
typedef _MediaCb = Void Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int64, Pointer<Utf8>, Pointer<Utf8>);

class AlbumData {
  final String id;
  final String name;
  final int mediaCount;
  AlbumData(this.id, this.name, this.mediaCount);
}

class AlbumFfi {
  static AlbumFfi? _inst;
  late final DynamicLibrary _lib;
  AlbumFfi._() { _lib = _openLib(); }
  static AlbumFfi get instance { _inst ??= AlbumFfi._(); return _inst!; }

  DynamicLibrary _openLib() {
    if (Platform.isLinux || Platform.isAndroid) return DynamicLibrary.open('libadvance_media_kb.so');
    if (Platform.isWindows) return DynamicLibrary.open('advance_media_kb.dll');
    if (Platform.isMacOS) return DynamicLibrary.open('libadvance_media_kb.dylib');
    throw UnsupportedError('Unsupported platform');
  }

  static List<AlbumData>? _currentAlbums;
  static void _collectAlbum(Pointer<Utf8> id, Pointer<Utf8> name, int count) {
    _currentAlbums?.add(AlbumData(id.toDartString(), name.toDartString(), count));
  }

  List<AlbumData> getRootAlbums() {
    _currentAlbums = [];
    final cb = Pointer.fromFunction<_AlbumCb>(_collectAlbum);
    _lib.lookupFunction<_GetRootAlbumsFn, int Function(Pointer<NativeFunction<_AlbumCb>>)>('amkb_get_root_albums')(cb);
    final r = _currentAlbums!; _currentAlbums = null; return r;
  }

  List<AlbumData> getChildAlbums(String parentId) {
    _currentAlbums = [];
    final cb = Pointer.fromFunction<_AlbumCb>(_collectAlbum);
    final p = parentId.toNativeUtf8();
    _lib.lookupFunction<_GetChildAlbumsFn, int Function(Pointer<Utf8>, Pointer<NativeFunction<_AlbumCb>>)>('amkb_get_child_albums')(p, cb);
    calloc.free(p);
    final r = _currentAlbums!; _currentAlbums = null; return r;
  }

  String createAlbum(String name, String? parentId) {
    final n = name.toNativeUtf8();
    final pid = parentId?.toNativeUtf8() ?? nullptr;
    final result = _lib.lookupFunction<_CreateAlbumFn, Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>)>('amkb_create_album')(n, pid);
    calloc.free(n);
    if (parentId != null) calloc.free(pid);
    return result.toDartString();
  }

  int deleteAlbum(String id) {
    final p = id.toNativeUtf8();
    final r = _lib.lookupFunction<_DeleteAlbumFn, int Function(Pointer<Utf8>)>('amkb_delete_album')(p);
    calloc.free(p); return r;
  }

  int renameAlbum(String id, String name) {
    final i = id.toNativeUtf8();
    final n = name.toNativeUtf8();
    final r = _lib.lookupFunction<_RenameAlbumFn, int Function(Pointer<Utf8>, Pointer<Utf8>)>('amkb_rename_album')(i, n);
    calloc.free(i); calloc.free(n); return r;
  }
}
